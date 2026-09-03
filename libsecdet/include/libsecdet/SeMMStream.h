#pragma once

#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <expected>
#include <filesystem>
#include <mutex>
#include <span>
#include <string_view>
#include <system_error>

enum class FileMode {
    CreateAlways, // Create new, overwrite if exists (Read/Write)
    OpenExisting, // Open existing file (Read/Write)
    OpenOrCreate  // Open if exists, create if not (Read/Write)
};

enum class SeekFrom {
    Begin,
    Current,
    End
};

class MappedFileStream {
public:
    static constexpr size_t DEFAULT_RESERVE = 64 * 1024; // 64 KB alignment

    std::expected<void, std::error_code> open(
        const std::filesystem::path& path,
        FileMode mode = FileMode::OpenOrCreate,
        size_t initial_reserve = DEFAULT_RESERVE) {
        
        if(this->is_open())
            return std::unexpected(SeError::StreamAlreadyOpen);
        
        auto res = this->init(path, mode, initial_reserve);
        if (!res) {
            return std::unexpected(res.error());
        }
        
        return {};
    }

    MappedFileStream() = default;
    ~MappedFileStream() { close(); }

    // Thread-safe Move Semantics (Non-copyable)
    MappedFileStream(const MappedFileStream&) = delete;
    MappedFileStream& operator=(const MappedFileStream&) = delete;

    MappedFileStream(MappedFileStream&& other) noexcept {
        std::lock_guard lock(other.m_mutex);
        move_from(std::move(other));
    }

    MappedFileStream& operator=(MappedFileStream&& other) noexcept {
        if (this != &other) {
            std::scoped_lock lock(m_mutex, other.m_mutex);
            close_internal();
            move_from(std::move(other));
        }
        return *this;
    }

    // --- Thread-Safe Core Operations ---
    std::expected<void, std::error_code> shift_bytes(size_t dst_offset, size_t src_offset, size_t count) {
        if (count == 0 || dst_offset == src_offset) {
            return {};
        }

        std::lock_guard lock(m_mutex);
        if (m_file_handle == INVALID_HANDLE_VALUE) {
            return std::unexpected(std::make_error_code(std::errc::bad_file_descriptor));
        }

        // Validate boundaries and order 
        // only backward shifts are allowed in this function, the expantion logic is not here!
        if (dst_offset > src_offset) {
            return std::unexpected(std::make_error_code(std::errc::invalid_argument));
        }

        // Overflow check: src_offset + count
        if (src_offset > SIZE_MAX - count || (src_offset + count) > m_file_size) {
            return std::unexpected(std::make_error_code(std::errc::result_out_of_range));
        }

        // Ensure mapped view is active
        if (!m_view) {
            return std::unexpected(std::make_error_code(std::errc::bad_address));
        }

        // std::memmove safely handles overlapping memory windows
        std::memmove(m_view + dst_offset, m_view + src_offset, count);

        return {};
    }

    std::expected<void, std::error_code> truncate(size_t new_size) {
        std::lock_guard lock(m_mutex);
        if (m_file_handle == INVALID_HANDLE_VALUE) {
            return std::unexpected(std::make_error_code(std::errc::bad_file_descriptor));
        }

        // 1. Flush dirty pages before tearing down the view
        if (m_view) {
            FlushViewOfFile(m_view, 0);
        }

        // 2. MUST unmap view and close mapping handle before SetEndOfFile
        unmap_view();

        // 3. Move file pointer and commit new physical end of file
        LARGE_INTEGER li;
        li.QuadPart = static_cast<LONGLONG>(new_size);
        if (!SetFilePointerEx(m_file_handle, li, nullptr, FILE_BEGIN) || !SetEndOfFile(m_file_handle)) {
            auto err = last_error();
            // Attempt to restore minimum state
            m_file_size = 0;
            return std::unexpected(err);
        }

        m_file_size = new_size;
        if (m_cursor > m_file_size) {
            m_cursor = m_file_size;
        }

        // 4. Re-establish mapping for future read/write operations
        size_t map_size = std::max(m_file_size, m_granularity);
        map_size = align_to_granularity(map_size);

        auto remap_res = remap_to_capacity(map_size);
        if (!remap_res) {
            return std::unexpected(remap_res.error());
        }

        return {};
    }

    std::expected<size_t, std::error_code> write(const void* data, size_t byte_count) {
        if (!data || byte_count == 0) return 0;

        std::lock_guard lock(m_mutex);
        if (m_file_handle == INVALID_HANDLE_VALUE) {
            return std::unexpected(std::make_error_code(std::errc::bad_file_descriptor));
        }

        const size_t required_capacity = m_cursor + byte_count;
        if (required_capacity > m_mapped_capacity) {
            auto expand_res = expand_mapping(required_capacity);
            if (!expand_res) return std::unexpected(expand_res.error());
        }

        std::memcpy(m_view + m_cursor, data, byte_count);
        m_cursor += byte_count;

        if (m_cursor > m_file_size) {
            m_file_size = m_cursor;
        }

        return byte_count;
    }

    std::expected<size_t, std::error_code> write(std::string_view str) {
        return write(str.data(), str.size());
    }

    std::expected<size_t, std::error_code> write(std::span<unsigned char> bytes) {
        return write(bytes.data(), bytes.size_bytes());
    }

    std::expected<size_t, std::error_code> read(void* dest, size_t byte_count) {
        if (!dest || byte_count == 0) return 0;

        std::lock_guard lock(m_mutex);
        if (m_file_handle == INVALID_HANDLE_VALUE) {
            return std::unexpected(std::make_error_code(std::errc::bad_file_descriptor));
        }

        if (m_cursor >= m_file_size) {
            return 0; // EOF reached
        }

        const size_t available = m_file_size - m_cursor;
        const size_t bytes_to_read = std::min(available, byte_count);

        std::memcpy(dest, m_view + m_cursor, bytes_to_read);
        m_cursor += bytes_to_read;

        return bytes_to_read;
    }

    std::expected<size_t, std::error_code> seek(int64_t offset, SeekFrom origin = SeekFrom::Begin) {
        std::lock_guard lock(m_mutex);
        if (m_file_handle == INVALID_HANDLE_VALUE) {
            return std::unexpected(std::make_error_code(std::errc::bad_file_descriptor));
        }

        int64_t new_cursor = 0;
        switch (origin) {
            case SeekFrom::Begin:   new_cursor = offset; break;
            case SeekFrom::Current: new_cursor = static_cast<int64_t>(m_cursor) + offset; break;
            case SeekFrom::End:     new_cursor = static_cast<int64_t>(m_file_size) + offset; break;
        }

        if (new_cursor < 0) {
            return std::unexpected(std::make_error_code(std::errc::invalid_seek));
        }

        m_cursor = static_cast<size_t>(new_cursor);
        return m_cursor;
    }

    std::expected<void, std::error_code> flush() {
        std::lock_guard lock(m_mutex);
        return flush_internal();
    }

    void close() {
        std::lock_guard lock(m_mutex);
        close_internal();
    }

    // Direct pointer access into current view (Use with care under concurrency)
    [[nodiscard]] const std::byte* data() const noexcept {
        std::lock_guard lock(m_mutex);
        return reinterpret_cast<const std::byte*>(m_view);
    }

    [[nodiscard]] size_t size() const noexcept {
        std::lock_guard lock(m_mutex);
        return m_file_size;
    }

    [[nodiscard]] size_t tell() const noexcept {
        std::lock_guard lock(m_mutex);
        return m_cursor;
    }

    [[nodiscard]] bool eof() const noexcept {
        std::lock_guard lock(m_mutex);
        return m_cursor >= m_file_size;
    }
    
    [[nodiscard]] bool is_open() const noexcept {
        std::lock_guard lock(m_mutex);
        return m_file_handle != INVALID_HANDLE_VALUE;
    }

private:
    mutable std::mutex m_mutex;

    HANDLE m_file_handle{INVALID_HANDLE_VALUE};
    HANDLE m_map_handle{nullptr};
    char* m_view{nullptr};

    size_t m_file_size{0};
    size_t m_mapped_capacity{0};
    size_t m_cursor{0};
    size_t m_granularity{65536};

    static std::error_code last_error() noexcept {
        return std::error_code(static_cast<int>(GetLastError()), std::system_category());
    }

    size_t align_to_granularity(size_t size) const noexcept {
        return (size + m_granularity - 1) & ~(m_granularity - 1);
    }

    std::expected<void, std::error_code> init(
        const std::filesystem::path& path,
        FileMode mode,
        size_t initial_reserve) {
        
        SYSTEM_INFO si;
        GetSystemInfo(&si);
        m_granularity = si.dwAllocationGranularity;

        DWORD disposition = 0;
        switch (mode) {
            case FileMode::CreateAlways: disposition = CREATE_ALWAYS; break;
            case FileMode::OpenExisting: disposition = OPEN_EXISTING; break;
            case FileMode::OpenOrCreate:  disposition = OPEN_ALWAYS; break;
        }

        m_file_handle = CreateFileW(
            path.c_str(),
            GENERIC_READ | GENERIC_WRITE, // READ ONLY FILES MAY NOT OPEN!
            FILE_SHARE_READ | FILE_SHARE_WRITE,
            nullptr,
            disposition,
            FILE_ATTRIBUTE_NORMAL,
            nullptr
        );

        if (m_file_handle == INVALID_HANDLE_VALUE) {
            return std::unexpected(last_error());
        }

        LARGE_INTEGER fs;
        if (!GetFileSizeEx(m_file_handle, &fs)) {
            auto err = last_error();
            close_internal();
            return std::unexpected(err);
        }

        m_file_size = static_cast<size_t>(fs.QuadPart);
        size_t map_size = std::max(m_file_size, align_to_granularity(initial_reserve));
        
        if (map_size == 0) {
            map_size = m_granularity;
        }

        auto remap_res = remap_to_capacity(map_size);
        if (!remap_res) {
            close_internal();
            return std::unexpected(remap_res.error());
        }

        return {};
    }

    std::expected<void, std::error_code> expand_mapping(size_t min_capacity) {
        size_t new_cap = m_mapped_capacity ? m_mapped_capacity : m_granularity;
        while (new_cap < min_capacity) {
            new_cap *= 2;
        }
        return remap_to_capacity(align_to_granularity(new_cap));
    }

    std::expected<void, std::error_code> remap_to_capacity(size_t capacity) {
        unmap_view();

        ULARGE_INTEGER li;
        li.QuadPart = capacity;

        m_map_handle = CreateFileMappingW(
            m_file_handle,
            nullptr,
            PAGE_READWRITE,
            li.HighPart,
            li.LowPart,
            nullptr
        );

        if (!m_map_handle) {
            return std::unexpected(last_error());
        }

        m_view = static_cast<char*>(MapViewOfFile(
            m_map_handle,
            FILE_MAP_ALL_ACCESS,
            0,
            0,
            capacity
        ));

        if (!m_view) {
            CloseHandle(m_map_handle);
            m_map_handle = nullptr;
            return std::unexpected(last_error());
        }

        m_mapped_capacity = capacity;
        return {};
    }

    void unmap_view() noexcept {
        if (m_view) {
            UnmapViewOfFile(m_view);
            m_view = nullptr;
        }
        if (m_map_handle) {
            CloseHandle(m_map_handle);
            m_map_handle = nullptr;
        }
        m_mapped_capacity = 0;
    }

    std::expected<void, std::error_code> flush_internal() noexcept { // FIX: ERROR_USER_MAPPED_FILE which caused by setEndofFile call if the file shrinks using trunk
        if (m_view) {
            if (!FlushViewOfFile(m_view, 0)) {
                return std::unexpected(last_error());
            }
        }
        if (m_file_handle != INVALID_HANDLE_VALUE) {
            if (!FlushFileBuffers(m_file_handle)) {
                return std::unexpected(last_error());
            }
        }
        return {};
    }

    void close_internal() noexcept {
        if (m_file_handle != INVALID_HANDLE_VALUE) {
            // 1. Flush memory view
            if (m_view) {
                FlushViewOfFile(m_view, 0);
            }

            // 2. Release mapping handles to permit SetEndOfFile
            unmap_view();

            // 3. Physically truncate the file to the exact logical size
            LARGE_INTEGER li;
            li.QuadPart = static_cast<LONGLONG>(m_file_size);
            if (SetFilePointerEx(m_file_handle, li, nullptr, FILE_BEGIN)) {
                SetEndOfFile(m_file_handle);
            }

            FlushFileBuffers(m_file_handle);
            CloseHandle(m_file_handle);
            m_file_handle = INVALID_HANDLE_VALUE;
            m_file_size = 0;
            m_cursor = 0;
        }
    }

    void move_from(MappedFileStream&& other) noexcept {
        m_file_handle = other.m_file_handle;
        m_map_handle = other.m_map_handle;
        m_view = other.m_view;
        m_file_size = other.m_file_size;
        m_mapped_capacity = other.m_mapped_capacity;
        m_cursor = other.m_cursor;
        m_granularity = other.m_granularity;

        other.m_file_handle = INVALID_HANDLE_VALUE;
        other.m_map_handle = nullptr;
        other.m_view = nullptr;
        other.m_file_size = 0;
        other.m_mapped_capacity = 0;
        other.m_cursor = 0;
    }
};