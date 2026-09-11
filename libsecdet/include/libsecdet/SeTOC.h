#pragma once
#include <algorithm>
#include <expected>
#include <span>
#include <string>
#include <mutex>
#include <vector>
#include <unordered_map>

#include "SeCrypto/SeCryptoUtils.h"
#include "SeError.h"

using namespace std;

#define SE_TOC_MAGIC "\x7F\x54\x4F\x43"     // 7F TOC
#define SE_TOC_ENTRY_PAD "\x04\x03\x4B\x50" // ZIP similar delimiter

// Cross-platform file attribute bit flags (stored in SeArchiveEntry::attributes)
#define SE_ATTR_DIR      0x01u  // Entry is a directory
#define SE_ATTR_READONLY 0x02u  // File is read-only / not writable
#define SE_ATTR_HIDDEN   0x04u  // File is hidden
#define SE_ATTR_SYSTEM   0x08u  // System file (Windows-specific, harmless elsewhere)

enum class EntryRecoveryState {
  NotFound,       // File entry was present in the TOC but not in the parsed entries
  FoundOk,        // File was found and parsed but was not in the TOC
  FoundIndexed,   // File entry was found and was present in TOC
  FoundTruncated  // File entry was found but its length was shorter than expected length
};

class SeArchive;

class SeArchiveEntry {

public:
  static expected<SeArchiveEntry, error_code>
      CreateFromBytes(span<unsigned char>);

  static SeArchiveEntry
  CreateFileEntry(u16string _path, uint64_t _uncompressed_sz = 0,
                  uint64_t _compressed_sz = 0, uint32_t _attributes = 0,
                  uint32_t _offset = 0, uint32_t _crc32 = 0) {

    SeArchiveEntry entry;
    entry.path = _path;
    entry.uncompressed_size = _uncompressed_sz;
    entry.compressed_size = _compressed_sz;
    entry.attributes = _attributes;
    entry.offset = _offset;
    entry.crc32 = _crc32;
    entry.fileUid = getSecureRandom();

    return entry;
  }

  static SeArchiveEntry CreateDirectoryEntry(u16string _path) {

    SeArchiveEntry entry;
    entry.path = _path;
    entry.attributes = SE_ATTR_DIR;
    entry.crc32 = -1;
    entry.offset = 0;
    entry.fileUid = 0;

    return entry;
  }

  SeArchiveEntry() { // Upon refactoring def ctor should be private!
    this->fileUid = getSecureRandom();
  }

  uint64_t uncompressed_size = 0;
  u16string path; // Relative path
  uint64_t compressed_size = 0;
  uint64_t offset = 0;
  uint64_t fileUid = 0;
  uint32_t attributes = 0;
  uint32_t crc32 = 0;
  EntryRecoveryState recoveryState = EntryRecoveryState::FoundIndexed; // In-memory recovery placeholder

  vector<unsigned char> Serialize();

  uint64_t GetDiskSize() const noexcept {
    uint64_t size = 0;
    size += sizeof(uint32_t) + (path.size() * sizeof(char16_t)) +
            (4 * sizeof(uint64_t)) + (2 * sizeof(uint32_t)); // header fields: cCount, path, 4x uint64_t, 2x uint32_t
    size += compressed_size;
    return size;
  }

  bool isDirectory() const { return (attributes & SE_ATTR_DIR) != 0; }
  bool isReadOnly()  const { return (attributes & SE_ATTR_READONLY) != 0; }
  bool isHidden()    const { return (attributes & SE_ATTR_HIDDEN) != 0; }
  bool isSystem()    const { return (attributes & SE_ATTR_SYSTEM) != 0; }
  // Entries should serialize their size !
  bool operator==(const SeArchiveEntry &value) const {
    if (path == value.path && offset == value.offset && crc32 == value.crc32)
      return true;
    return false;
  }
  bool operator!=(const SeArchiveEntry &value) const {
    return !(*this == value);
  }
};

class SeTableOfContent {

public:
  static expected<SeTableOfContent, error_code> LoadTableOfContentFromBytes(span<unsigned char> data);

  static SeTableOfContent CreateNewTableOfContent();

  static u16string NormalizeArchivePath(u16string path);
  static u16string NormalizeDirectoryPath(u16string path);
  static u16string NormalizeFilePath(u16string path);
  static u16string CanonicalizePathKey(const u16string &path);

  static bool IsDirectory(u16string);    // Path should end with / to count as directory
  static u16string GetParentDirectory(u16string path);

  static u16string GetFileName(u16string entryPath); // if the path is: /Folder1/MyFiles/file -> file or

  static u16string CreateFilePath(u16string parentDir, u16string fileName);

  static u16string CreateDirPath(u16string parentDir, u16string dirName); // just puts a / in the end

  static u16string mergePath(u16string path, u16string fileName);

  static bool verifyAbsPath(u16string path);

  static bool isAbsPathDir(u16string path);

  bool CheckPath(u16string) const;       // Checks if path exists whether dir or file

  bool CheckParentPath(u16string) const; // Check if the parent directory exist

  void rebuildPathIndex();

  SeTableOfContent(const SeTableOfContent& other) {
      std::lock_guard<mutex> lock(other.m_mutex);
      this->m_entries = other.m_entries;
      this->m_pathIndex = other.m_pathIndex;
      this->m_isReady = true;
  }
  
  SeTableOfContent(SeTableOfContent&& other) noexcept {
      std::lock_guard<mutex> lock(other.m_mutex);
      this->m_entries = move(other.m_entries);
      this->m_pathIndex = move(other.m_pathIndex);
      this->m_isReady = true;
  }

  SeTableOfContent& operator=(const SeTableOfContent& other) {
      if (this == &other) 
          return *this;

      std::scoped_lock<mutex,mutex> lock(m_mutex,other.m_mutex);
      this->m_entries = other.m_entries;
      this->m_pathIndex = other.m_pathIndex;
      this->m_isReady = true;
      return *this;
  }

  SeTableOfContent& operator=(SeTableOfContent&& other) noexcept {
      if (this == &other)
          return *this;

      std::scoped_lock<mutex, mutex> lock(m_mutex, other.m_mutex);
      this->m_entries = move(other.m_entries);
      this->m_pathIndex = move(other.m_pathIndex);
      this->m_isReady = true;
      return *this;
  }


  expected<void, error_code> AddEntry(SeArchiveEntry);
  bool RemoveEntry(u16string);
  bool RemoveEntry(SeArchiveEntry &);

  // We should not use ref in vector like this
  expected<SeArchiveEntry, error_code> GetEntry(u16string path);
  expected<const SeArchiveEntry, error_code> GetEntry(u16string path) const;

  vector<SeArchiveEntry> GetEntriesFollowing(
      SeArchiveEntry &entry); // Entries after the passed entry offset

  vector<SeArchiveEntry> GetDirectoryFileEntries(
      SeArchiveEntry
          &dirEntry, bool recursive = false); // Contains files + subdirectories inside

  [[nodiscard]] span<const SeArchiveEntry> GetEntries() const noexcept {
    return m_entries;
  }

  expected<size_t, error_code> Serialize();
  vector<unsigned char> SerializeToBytes() const;
  span<const unsigned char> GetTOCBytes() const noexcept {
    return m_serializedBytes;
  }

  bool IsReady() const noexcept { return m_isReady; }

  // Iterate through the toc tree and find the next empty spot

  size_t getNextAvailOffset();

  friend class SeArchive;

  // should add a relative path verifier and logic
  //  ex. should user add a file named: Dir/ then add files in it ?
  //  which causes the entry become polluted with tons of byte less entries
  //  or we should add the directory when the user adds files into it
  //  which again causes that user loss all the empty directories which are many
  //  of theM!

  bool operator==(const SeTableOfContent &) const;

  bool operator!=(const SeTableOfContent &b) const { return !(*this == b); }

private:
  SeTableOfContent();

  vector<SeArchiveEntry> m_entries; // Possible high memory usage if the archive
                                    // contains too many files
  vector<unsigned char> m_serializedBytes;
  unordered_map<u16string, size_t> m_pathIndex;

  mutable std::mutex m_mutex;

  bool m_isReady = false;
};
