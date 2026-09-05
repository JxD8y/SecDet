#include <filesystem>
#include "libsecdet/SeMetadata.h"
#include "libsecdet/SeTOC.h"


expected<SeArchiveEntry,error_code> SeArchiveEntry::CreateFromBytes(span<unsigned char> bytes){
    SeArchiveEntry _sEntry;
    size_t offset = 0;

    auto read = [&bytes,&offset](void*dest,size_t size) -> expected<void, error_code> {
        if(offset + size > bytes.size()){
            return unexpected(SeError::BufferUnderflow);
        }
        memcpy(dest,bytes.data()+offset , size);
        offset += size;
        return {};
    };
    uint32_t cCount = 0;
    auto _err = read(&cCount,sizeof(cCount)); // ? is it valid?
    if(cCount > 0){
        size_t path_bytes = cCount * sizeof(char16_t);
        if(offset + path_bytes > bytes.size()){
            return unexpected(SeError::BufferStringOverflow);
        }
        _sEntry.path.resize(cCount);
        memcpy(_sEntry.path.data(),bytes.data()+offset,path_bytes);
        offset += path_bytes;
    }
    _err = read(&_sEntry.uncompressed_size,sizeof(_sEntry.uncompressed_size));
    _err = read(&_sEntry.compressed_size,sizeof(_sEntry.compressed_size));
    _err = read(&_sEntry.attributes,sizeof(_sEntry.attributes));
    _err = read(&_sEntry.offset,sizeof(_sEntry.offset));
    _err = read(&_sEntry.crc32,sizeof(_sEntry.crc32));
    _err = read(&_sEntry.fileUid,sizeof(_sEntry.fileUid));

    if (!_err)
        return unexpected(_err.error());

    return _sEntry;
}

//important to return the Vector ,returning span causes RVO to fail and vector to be freed before return
vector<unsigned char> SeArchiveEntry::Serialize(){
    vector<unsigned char> buffer;

    auto append_buffer = [&buffer](const void* src, size_t size){
        const unsigned char* byte_ptr = reinterpret_cast<const unsigned char*>(src);
        buffer.insert(buffer.end(), byte_ptr, byte_ptr + size);
    };

    uint32_t cCount = (uint32_t)(path.size()); // Damn sure that the path wont exceed 2^32 len
    append_buffer(&cCount,sizeof(cCount));
    if(cCount > 0)
        append_buffer(this->path.data(),cCount * sizeof(char16_t));
    
    append_buffer(&this->uncompressed_size,sizeof(this->uncompressed_size));
    append_buffer(&this->compressed_size,sizeof(this->compressed_size));
    append_buffer(&this->attributes,sizeof(this->attributes));
    append_buffer(&this->offset,sizeof(this->offset));
    append_buffer(&this->crc32,sizeof(this->crc32));
    append_buffer(&this->fileUid, sizeof(this->fileUid));
    
    return buffer;
}

SeTableOfContent SeTableOfContent::CreateNewTableOfContent(){
    SeTableOfContent _sTOC;
    return _sTOC;
}

expected<SeTableOfContent,error_code> SeTableOfContent::LoadTableOfContentFromBytes(span<unsigned char> data){

    // Overview of TOC in byte: 
    // [Entry1]
    // [PAD - bytes]
    // [ENTRY2]
    // ...
    // [ENTRY N]
    // [PAD]

    if (data.size() < 4) {
        return unexpected(SeError::NoTOCFound);
    }

    if (memcmp(data.data(), SE_TOC_MAGIC, 4) != 0) {
        return unexpected(SeError::InvalidTOCMagic);
    }
    
    // Save original bytes for m_serializedBytes
    span<unsigned char> origData = data;

    // Skipping Toc magic
    data = data.subspan(4);

    SeTableOfContent _toc;

    const unsigned char pad[] = {0x04, 0x03, 0x4B, 0x50};
    span<const unsigned char> pad_span(pad, 4);

    while (!data.empty()) {
        auto m_range = ranges::search(data, pad_span);
        if (m_range.empty()) {
            break;
        }
        size_t tEntry_sz = static_cast<size_t>(std::distance(data.begin(), m_range.begin()));
        
        // Cross-verify with entry header size if valid to prevent false positive matches
        if (data.size() >= sizeof(uint32_t)) {
            uint32_t cCount = 0;
            memcpy(&cCount, data.data(), sizeof(cCount));
            size_t expectedSz = sizeof(uint32_t) + (static_cast<size_t>(cCount) * sizeof(char16_t)) + 40;
            if (expectedSz <= data.size() - 4 && memcmp(data.data() + expectedSz, pad, 4) == 0) {
                tEntry_sz = expectedSz;
            }
        }

        span<unsigned char> tEntry_bytes = data.first(tEntry_sz);
        
        auto _aEE = SeArchiveEntry::CreateFromBytes(tEntry_bytes);
        if (!_aEE) {
            return unexpected(_aEE.error());
        }
        _toc.m_entries.push_back(move(*_aEE));
        
        data = data.subspan(tEntry_sz + 4);
    }

    _toc.m_serializedBytes.assign(origData.begin(), origData.end());
    _toc.m_isReady = true;

    return _toc;
}

SeTableOfContent::SeTableOfContent() : m_isReady(false) {}

u16string SeTableOfContent::NormalizeArchivePath(u16string path) {
    if (path.empty()) {
        return u"/";
    }
    for (auto &ch : path) {
        if (ch == u'\\') ch = u'/';
    }
    u16string collapsed;
    collapsed.reserve(path.size() + 2);
    bool lastWasSlash = false;
    for (auto ch : path) {
        if (ch == u'/') {
            if (!lastWasSlash) {
                collapsed.push_back(u'/');
                lastWasSlash = true;
            }
        } else {
            collapsed.push_back(ch);
            lastWasSlash = false;
        }
    }
    if (collapsed.empty() || collapsed.front() != u'/') {
        collapsed.insert(collapsed.begin(), u'/');
    }
    return collapsed;
}

u16string SeTableOfContent::NormalizeDirectoryPath(u16string path) {
    u16string norm = NormalizeArchivePath(path);
    if (norm.back() != u'/') {
        norm.push_back(u'/');
    }
    return norm;
}

u16string SeTableOfContent::NormalizeFilePath(u16string path) {
    u16string norm = NormalizeArchivePath(path);
    while (norm.size() > 1 && norm.back() == u'/') {
        norm.pop_back();
    }
    return norm;
}

bool SeTableOfContent::IsDirectory(u16string path) {
    if (path.empty())
        return false;
    for (auto &ch : path) {
        if (ch == u'\\') ch = u'/';
    }
    return path == u"/" || path.back() == u'/';
}

u16string SeTableOfContent::GetFileName(u16string entryPath) {
    if (entryPath.empty() || entryPath == u"/")
        return u"";
    for (auto &ch : entryPath) {
        if (ch == u'\\') ch = u'/';
    }
    while (entryPath.size() > 1 && entryPath.back() == u'/') {
        entryPath.pop_back();
    }
    size_t lastSlash = entryPath.find_last_of(u'/');
    if (lastSlash != u16string::npos) {
        return entryPath.substr(lastSlash + 1);
    }
    return entryPath;
}

u16string SeTableOfContent::CreateFilePath(u16string parentDir, u16string fileName) {
    u16string normParent = NormalizeDirectoryPath(parentDir);
    for (auto &ch : fileName) {
        if (ch == u'\\') ch = u'/';
    }
    while (!fileName.empty() && fileName.front() == u'/') {
        fileName.erase(fileName.begin());
    }
    while (!fileName.empty() && fileName.back() == u'/') {
        fileName.pop_back();
    }
    return normParent + fileName;
}

u16string SeTableOfContent::CreateDirPath(u16string parentDir, u16string dirName) {
    u16string normParent = NormalizeDirectoryPath(parentDir);
    for (auto &ch : dirName) {
        if (ch == u'\\') ch = u'/';
    }
    while (!dirName.empty() && dirName.front() == u'/') {
        dirName.erase(dirName.begin());
    }
    while (!dirName.empty() && dirName.back() == u'/') {
        dirName.pop_back();
    }
    if (dirName.empty()) {
        return normParent;
    }
    return normParent + dirName + u'/';
}

u16string SeTableOfContent::mergePath(u16string path, u16string fileName) {
    filesystem::path p(path);
    p /= filesystem::path(fileName);
    return p.u16string();
}

bool SeTableOfContent::verifyAbsPath(u16string path) {
    filesystem::path p(path);
    error_code err;
    if (!p.is_absolute())
        return false;
    return filesystem::exists(p, err) && !err;
}

bool SeTableOfContent::isAbsPathDir(u16string path) {
    filesystem::path p(path);
    error_code err;
    if (!p.is_absolute())
        return false;
    return filesystem::is_directory(p, err) && !err;
}

bool SeTableOfContent::CheckPath(u16string path) const {
    if (path.empty())
        return false;
    u16string norm = NormalizeArchivePath(path);
    if (norm == u"/")
        return true;
    bool isDir = (norm.back() == u'/');
    for (const auto &entry : m_entries) {
        u16string entryNorm = NormalizeArchivePath(entry.path);
        if (entry.isDirectory() && entryNorm.back() != u'/') {
            entryNorm.push_back(u'/');
        } else if (!entry.isDirectory() && entryNorm.size() > 1 && entryNorm.back() == u'/') {
            entryNorm.pop_back();
        }
        if (entryNorm == norm) {
            return true;
        }
        if (!isDir && entry.isDirectory() && (entryNorm == norm + u'/')) {
            return true;
        }
        if (isDir && !entry.isDirectory() && (norm == entryNorm + u'/')) {
            return true;
        }
    }
    return false;
}

u16string SeTableOfContent::GetParentDirectory(u16string path) {
    if (path.empty())
        return u"/";
    u16string norm = NormalizeArchivePath(path);
    if (norm == u"/")
        return u"/";
    while (norm.size() > 1 && norm.back() == u'/') {
        norm.pop_back();
    }
    size_t lastSlash = norm.find_last_of(u'/');
    if (lastSlash == u16string::npos || lastSlash == 0) {
        return u"/"; // Parent is root "/"
    }
    return norm.substr(0, lastSlash + 1);
}

bool SeTableOfContent::CheckParentPath(u16string path) const {
    if (path.empty())
        return false;
    return CheckPath(GetParentDirectory(path));
}

expected<void, error_code> SeTableOfContent::AddEntry(SeArchiveEntry entry) {
    if (entry.isDirectory()) {
        entry.path = NormalizeDirectoryPath(entry.path);
    } else {
        entry.path = NormalizeFilePath(entry.path);
    }
    if (!any_of(this->m_entries.begin(), this->m_entries.end(), [&](const SeArchiveEntry &val) {
        return entry == val;
    })) {
        this->m_entries.push_back(entry);
        this->m_isReady = false;
        return {};
    } else {
        return unexpected(SeError::AddingExistingEntry);
    }
}

bool SeTableOfContent::RemoveEntry(u16string entryPath) {
    u16string norm = NormalizeArchivePath(entryPath);
    bool isDir = (norm.back() == u'/');
    auto n = erase_if(this->m_entries, [&](const SeArchiveEntry &sEntry) {
        u16string ep = NormalizeArchivePath(sEntry.path);
        if (sEntry.isDirectory() && ep.back() != u'/') {
            ep.push_back(u'/');
        } else if (!sEntry.isDirectory() && ep.size() > 1 && ep.back() == u'/') {
            ep.pop_back();
        }
        if (ep == norm) return true;
        if (!isDir && sEntry.isDirectory() && (ep == norm + u'/')) return true;
        if (isDir && !sEntry.isDirectory() && (norm == ep + u'/')) return true;
        return false;
    });
    this->m_isReady = false;
    return n > 0;
}

bool SeTableOfContent::RemoveEntry(SeArchiveEntry &entry) {
    auto n = erase_if(this->m_entries, [&](const SeArchiveEntry &val) {
        return entry == val;
    });
    this->m_isReady = false;
    return n > 0;
}

expected<SeArchiveEntry, error_code> SeTableOfContent::GetEntry(u16string path) {
    if (path.empty())
        return unexpected(SeError::TocPathIsInvalid);
    u16string norm = NormalizeArchivePath(path);
    bool isDir = (norm.back() == u'/');
    for (auto &entry : m_entries) {
        u16string entryNorm = NormalizeArchivePath(entry.path);
        if (entry.isDirectory() && entryNorm.back() != u'/') {
            entryNorm.push_back(u'/');
        } else if (!entry.isDirectory() && entryNorm.size() > 1 && entryNorm.back() == u'/') {
            entryNorm.pop_back();
        }
        if (entryNorm == norm) {
            return entry;
        }
        if (!isDir && entry.isDirectory() && (entryNorm == norm + u'/')) {
            return entry;
        }
        if (isDir && !entry.isDirectory() && (norm == entryNorm + u'/')) {
            return entry;
        }
    }
    return unexpected(SeError::TocPathIsInvalid);
}

expected<const SeArchiveEntry, error_code> SeTableOfContent::GetEntry(u16string path) const {
    if (path.empty())
        return unexpected(SeError::TocPathIsInvalid);
    u16string norm = NormalizeArchivePath(path);
    bool isDir = (norm.back() == u'/');
    for (const auto &entry : m_entries) {
        u16string entryNorm = NormalizeArchivePath(entry.path);
        if (entry.isDirectory() && entryNorm.back() != u'/') {
            entryNorm.push_back(u'/');
        } else if (!entry.isDirectory() && entryNorm.size() > 1 && entryNorm.back() == u'/') {
            entryNorm.pop_back();
        }
        if (entryNorm == norm) {
            return entry;
        }
        if (!isDir && entry.isDirectory() && (entryNorm == norm + u'/')) {
            return entry;
        }
        if (isDir && !entry.isDirectory() && (norm == entryNorm + u'/')) {
            return entry;
        }
    }
    return unexpected(SeError::TocPathIsInvalid);
}

vector<SeArchiveEntry> SeTableOfContent::GetEntriesFollowing(SeArchiveEntry &entry) {
    vector<SeArchiveEntry> following;
    for (const auto &e : m_entries) {
        if (!e.isDirectory() && e.offset > entry.offset) {
            following.push_back(e);
        }
    }
    return following;
}

vector<SeArchiveEntry> SeTableOfContent::GetDirectoryFileEntries(SeArchiveEntry &dirEntry, bool recursive) {
    vector<SeArchiveEntry> result;
    u16string parentPath = NormalizeDirectoryPath(dirEntry.path);
    for (const auto &e : m_entries) {
        u16string ep = e.isDirectory() ? NormalizeDirectoryPath(e.path) : NormalizeFilePath(e.path);
        if (ep == parentPath)
            continue;
        if (!ep.starts_with(parentPath))
            continue;
        if (!recursive) {
            u16string rel = ep.substr(parentPath.size());
            if (rel.empty())
                continue;
            if (e.isDirectory()) {
                size_t firstSlash = rel.find_first_of(u'/');
                if (firstSlash != rel.size() - 1)
                    continue;
            } else {
                if (rel.find_first_of(u'/') != u16string::npos)
                    continue;
            }
        }
        result.push_back(e);
    }
    return result;
}

size_t SeTableOfContent::getNextAvailOffset() {
    uint64_t maxOffset = SE_METADATA_SIZE;
    for (const auto &entry : m_entries) {
        if (!entry.isDirectory()) {
            uint64_t entryEnd = entry.offset + entry.GetDiskSize();
            if (entryEnd > maxOffset) {
                maxOffset = entryEnd;
            }
        }
    }
    return maxOffset;
}

expected<size_t, error_code> SeTableOfContent::Serialize() {
    m_serializedBytes.clear();
    const unsigned char magic[] = SE_TOC_MAGIC;
    m_serializedBytes.insert(m_serializedBytes.end(), magic, magic + 4);
    const unsigned char pad[] = SE_TOC_ENTRY_PAD;
    for (auto &entry : m_entries) {
        auto entryBytes = entry.Serialize();
        m_serializedBytes.insert(m_serializedBytes.end(), entryBytes.begin(), entryBytes.end());
        m_serializedBytes.insert(m_serializedBytes.end(), pad, pad + 4);
    }
    m_isReady = true;
    return m_serializedBytes.size();
}

vector<unsigned char> SeTableOfContent::SerializeToBytes() const {
    if (m_isReady && !m_serializedBytes.empty()) {
        return m_serializedBytes;
    }
    vector<unsigned char> bytes;
    const unsigned char magic[] = SE_TOC_MAGIC;
    bytes.insert(bytes.end(), magic, magic + 4);
    const unsigned char pad[] = SE_TOC_ENTRY_PAD;
    for (auto entry : m_entries) {
        auto entryBytes = entry.Serialize();
        bytes.insert(bytes.end(), entryBytes.begin(), entryBytes.end());
        bytes.insert(bytes.end(), pad, pad + 4);
    }
    return bytes;
}

bool SeTableOfContent::operator==(const SeTableOfContent &b) const {
    if (this->m_entries.size() != b.m_entries.size())
        return false;
    for (const auto &entryA : this->m_entries) {
        bool found = false;
        for (const auto &entryB : b.m_entries) {
            if (entryA == entryB) {
                found = true;
                break;
            }
        }
        if (!found)
            return false;
    }
    return true;
}