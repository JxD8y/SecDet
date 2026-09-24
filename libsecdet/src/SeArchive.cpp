#include "libsecdet/SeArchive.h"
#include "libsecdet/SeFileAttributes.h"
#include <unordered_set>
#include <unordered_map>
#include <algorithm>

namespace {
    inline bool arePathsEqual(const std::u16string &p1, const std::u16string &p2) {
      return SeTableOfContent::NormalizeArchivePath(p1) ==
             SeTableOfContent::NormalizeArchivePath(p2);
    }

    inline std::string toHex(uint64_t val) {
      char buf[32];
      snprintf(buf, sizeof(buf), "%llX", static_cast<unsigned long long>(val));
      return std::string(buf);
    }

    bool validateAndParseLocalEntry(std::span<const unsigned char> bytes,
                                    uint64_t expectedOffset,
                                    SeArchiveEntry &outEntry,
                                    size_t &outHeaderSize) {
      if (bytes.size() < 44) {
        return false;
      }

      uint32_t cCount = 0;
      std::memcpy(&cCount, bytes.data(), sizeof(cCount));
      if (cCount == 0 || cCount > 4096) {
        return false;
      }

      size_t pathBytes = static_cast<size_t>(cCount) * sizeof(char16_t);
      size_t expectedHeaderSize = sizeof(uint32_t) + pathBytes + 40;
      if (expectedHeaderSize > bytes.size()) {
        return false;
      }

      const char16_t *chars = reinterpret_cast<const char16_t *>(bytes.data() + sizeof(uint32_t));
      // In SecDet, archive paths must start with '/' or '\'
      if (chars[0] != u'/' && chars[0] != u'\\') {
        return false;
      }

      for (size_t i = 0; i < cCount; ++i) {
        char16_t ch = chars[i];
        if (ch == u'\0' || (ch < 32 && ch != u'\t')) {
          return false;
        }
        if (ch == u'<' || ch == u'>' || ch == u'"' || ch == u'|' || ch == u'*' || ch == u'?') {
          return false;
        }
      }

      auto entryRes = SeArchiveEntry::CreateFromBytes(
          std::span<unsigned char>(const_cast<unsigned char *>(bytes.data()), expectedHeaderSize));
      if (!entryRes) {
        return false;
      }

      SeArchiveEntry entry = *entryRes;

      constexpr uint32_t knownAttrs = SE_ATTR_DIR | SE_ATTR_READONLY | SE_ATTR_HIDDEN | SE_ATTR_SYSTEM;
      if ((entry.attributes & ~knownAttrs) != 0) {
        return false;
      }

      if (entry.isDirectory()) {
        if (entry.compressed_size != 0 || entry.uncompressed_size != 0) {
          return false;
        }
      }

      outEntry = std::move(entry);
      outHeaderSize = expectedHeaderSize;
      return true;
    }
} // namespace

expected<SeArchive, error_code> SeArchive::CreateArchive(uint16_t version, uint16_t compressionLevel, bool preserveMetadata, u16string archivePath, string password) {
    // Supported versions: 1
    if (version > 1)
    return unexpected(SeError::VersionNotSupported);
    if (compressionLevel > 0x3 || compressionLevel < 0x1)
    return unexpected(make_error_code(errc::invalid_argument));
    if (!SeTableOfContent::verifyAbsPath(archivePath))
    return unexpected(make_error_code(errc::no_such_file_or_directory));
    if (password.empty())
    return unexpected(SeError::CRYPTOStringWasEmpty);

    array<unsigned char, SE_SALT_SIZE> salt{};
    generateSalt(salt);

    vector<unsigned char> master_key(AesGcmContextProvider::KEY_BYTES);
    auto exp = deriveMasterKeyArgon2id(password, salt, master_key);
    if (!exp) {
      sodium_memzero(master_key.data(), master_key.size());
      return unexpected(exp.error());
    }

    auto pvvExp = calculatePVV(master_key);
    if (!pvvExp) {
      sodium_memzero(master_key.data(), master_key.size());
      return unexpected(pvvExp.error());
    }
    uint16_t pvv = *pvvExp;

    auto _cctx = AesGcmContextProvider::CreateContext();
    if (!_cctx) {
      sodium_memzero(master_key.data(), master_key.size());
      return unexpected(_cctx.error());
    }

    auto setKeyRes = _cctx->SetMasterKey(master_key);
    sodium_memzero(master_key.data(), master_key.size());
    if (!setKeyRes)
      return unexpected(setKeyRes.error());

    SeArchive arc(SeMetadata(version, compressionLevel, preserveMetadata, pvv, salt),
        SeTableOfContent::CreateNewTableOfContent(), archivePath,
        *move(_cctx));

    return arc;
}

expected<SeArchive, error_code> SeArchive::LoadArchiveFile(u16string path) {

  if (!SeTableOfContent::verifyAbsPath(path))
    return unexpected(make_error_code(errc::no_such_file_or_directory));

  MappedFileStream fs;
  if (auto _fs = fs.open(path); !_fs)
    return unexpected(_fs.error());

  (void)fs.seek(0);

  vector<unsigned char> metadata_bytes(SE_METADATA_SIZE);

  // Just found out about the if with initializer !

  if (auto _sz = fs.read(metadata_bytes.data(), SE_METADATA_SIZE); !_sz) {
    return unexpected(_sz.error());
  }

  auto _metadata = SeMetadata::LoadMetadataFromBytes(metadata_bytes);
  if (!_metadata)
    return unexpected(_metadata.error());

  SeMetadata metadata = *_metadata;

  uint64_t toc_offset = metadata.m_toc_offset;

  if (toc_offset > fs.size())
    return unexpected(SeError::NoTOCFound);

  if (auto _cursor = fs.seek(toc_offset); !_cursor)
    return unexpected(_cursor.error());

  uint64_t toc_size = fs.size() - toc_offset;

  vector<unsigned char> toc_bytes(toc_size);

  if (auto _read = fs.read(toc_bytes.data(), toc_size);
      !_read) // WARN: current version has no recovery method , a simple
              // truncation at the end of the file causes the TOC to be
              // unreadable!
    return unexpected(_read.error());

  auto _toc = SeTableOfContent::LoadTableOfContentFromBytes(toc_bytes);
  if (!_toc)
    return unexpected(_toc.error());

  SeTableOfContent toc = *_toc;

  auto _cctx = AesGcmContextProvider::CreateContext();
  if (!_cctx)
    return unexpected(_cctx.error());

  return expected<SeArchive,error_code>(in_place, metadata, toc, path, *move(_cctx));
}

expected<SeArchive, error_code> SeArchive::RecoverArchiveSync(u16string path, stop_token stopToken) {
    if (!SeTableOfContent::verifyAbsPath(path))
        return unexpected(make_error_code(errc::no_such_file_or_directory));

    MappedFileStream fs;
    if (auto _fs = fs.open(path, FileMode::OpenExisting); !_fs)
        return unexpected(_fs.error());

    size_t fileSize = fs.size();
    const unsigned char *dataPtr = reinterpret_cast<const unsigned char *>(fs.data());
    if (!dataPtr && fileSize > 0)
        return unexpected(make_error_code(errc::io_error));

    string metaHealth;
    string tocHealth;

    SeMetadata metadata(1, 1, true, 0, {});
    bool metadataValid = false;

    // 1. Recover Metadata
    if (fileSize >= SE_METADATA_SIZE) {
        auto _meta = SeMetadata::LoadMetadataFromBytes(std::span<unsigned char>(const_cast<unsigned char *>(dataPtr), SE_METADATA_SIZE));
        if (_meta) {
            metadata = *_meta;
            metadataValid = true;
            metaHealth = "Version " + std::to_string(metadata.m_version) +
                ", Compression Level " + std::to_string(metadata.m_compression_level);
        }
    }

    if (!metadataValid) { // Without metadata PVV and salt are not present meaning no file can be decrypted
        return unexpected(SeError::RequiredFieldMissing);
    }

    vector<SeArchiveEntry> parsedBodyEntries;
    size_t cur = SE_METADATA_SIZE;
    size_t detectedTocOffset = (size_t)-1;
    const unsigned char pad[] = {0x04, 0x03, 0x4B, 0x50};

    while (cur < fileSize) { // Searching for local file header
        if (stopToken.stop_requested())
            return unexpected(SeError::OperationCanceled);

        if (cur + 4 <= fileSize && memcmp(dataPtr + cur, SE_TOC_MAGIC, 4) == 0) { // Detected TOC magic
            detectedTocOffset = cur;
            break;
        }

        if (metadataValid && cur == metadata.m_toc_offset && cur + 4 <= fileSize && memcmp(dataPtr + cur, SE_TOC_MAGIC, 4) == 0) { // Reached TOC
            detectedTocOffset = cur;
            break;
        }

        bool foundEntry = false;
        SeArchiveEntry candEntry;
        size_t candHeaderSize = 0;
        size_t entryStartOffset = cur;
        size_t payloadStartOffset = cur;

        // Check if SE_TOC_ENTRY_PAD precedes the entry header
        if (cur + 4 <= fileSize && memcmp(dataPtr + cur, pad, 4) == 0) {
            std::span<const unsigned char> rem(dataPtr + cur + 4, fileSize - (cur + 4));
            if (validateAndParseLocalEntry(rem, cur + 4, candEntry, candHeaderSize)) {
                foundEntry = true;
                entryStartOffset = cur;
                payloadStartOffset = cur + 4 + candHeaderSize;
                candEntry.offset = cur;
            }
        }

        // Check if entry header starts directly at cur
        if (!foundEntry && cur + 44 <= fileSize) {
            std::span<const unsigned char> rem(dataPtr + cur, fileSize - cur);
            if (validateAndParseLocalEntry(rem, cur, candEntry, candHeaderSize)) {
                foundEntry = true;
                entryStartOffset = cur;
                payloadStartOffset = cur + candHeaderSize;
                candEntry.offset = cur;
            }
        }

        if (foundEntry) {
            size_t expectedEnd = payloadStartOffset + candEntry.compressed_size;
            // Skip optional trailing pad if present
            if (expectedEnd + 4 <= fileSize && memcmp(dataPtr + expectedEnd, pad, 4) == 0) {
                expectedEnd += 4;
            }

            if (payloadStartOffset + candEntry.compressed_size > fileSize) {
                candEntry.recoveryState = EntryRecoveryState::FoundTruncated;
                parsedBodyEntries.push_back(std::move(candEntry));
                break;
            }

            else {
                parsedBodyEntries.push_back(std::move(candEntry));
                cur = expectedEnd;
                continue;
            }
        }

        // Fast-forward to next potential boundary
        cur++;
        while (cur + 4 <= fileSize) {
            if (memcmp(dataPtr + cur, pad, 4) == 0 || memcmp(dataPtr + cur, SE_TOC_MAGIC, 4) == 0) { // Check for entry or TOC begin
                break;
            }
            if (cur + 6 <= fileSize && dataPtr[cur + 4] == 0x2F && dataPtr[cur + 5] == 0x00) { // Looking for local entry path ( / ) 
                // in case of pad missing ( rare )!
                break;
            }
            cur++;
        }
    }

    // parsed as much entry as we could , going toward TOC

    size_t effectiveTocOffset = (size_t)-1;
    if (detectedTocOffset != (size_t)-1) {
        effectiveTocOffset = detectedTocOffset;
    }
    else if (metadataValid && metadata.m_toc_offset >= SE_METADATA_SIZE && metadata.m_toc_offset < fileSize) {
        effectiveTocOffset = metadata.m_toc_offset;
    }

    vector<SeArchiveEntry> tocEntries;
    bool tocHeaderValid = false;
    bool tocFullyRead = false;
    size_t tocEntriesParsed = 0;

    if (effectiveTocOffset < fileSize) {
        std::span<const unsigned char> tocSpan(dataPtr + effectiveTocOffset, fileSize - effectiveTocOffset);
        if (tocSpan.size() >= 4 && memcmp(tocSpan.data(), SE_TOC_MAGIC, 4) == 0) {
            tocHeaderValid = true;
            tocSpan = tocSpan.subspan(4);

            std::span<const unsigned char> padSpan(pad, 4);

            while (!tocSpan.empty()) {
              if (stopToken.stop_requested())
                    return unexpected(SeError::OperationCanceled);

                size_t tEntry_sz = 0;
                bool found = false;

                if (tocSpan.size() >= sizeof(uint32_t)) {
                    uint32_t cCount = 0;
                    memcpy(&cCount, tocSpan.data(), sizeof(cCount));
                    size_t expectedSz = sizeof(uint32_t) + (static_cast<size_t>(cCount) * sizeof(char16_t)) + 40;
                    if (expectedSz <= tocSpan.size() - 4 && memcmp(tocSpan.data() + expectedSz, pad, 4) == 0) {
                    tEntry_sz = expectedSz;
                    found = true;
                    }
                }

                if (!found) {
                    auto m_range = ranges::search(tocSpan, padSpan);
                    if (m_range.empty()) {
                    break;
                    }
                    tEntry_sz = static_cast<size_t>(std::distance(tocSpan.begin(), m_range.begin()));
                }

                std::span<const unsigned char> tEntry_bytes = tocSpan.first(tEntry_sz);
                auto _aEE = SeArchiveEntry::CreateFromBytes(
                    std::span<unsigned char>(const_cast<unsigned char *>(tEntry_bytes.data()), tEntry_sz));
                if (!_aEE) {
                    break;
                }

                tocEntries.push_back(std::move(*_aEE));
                tocEntriesParsed++;

                if (tEntry_sz + 4 <= tocSpan.size()) {
                    tocSpan = tocSpan.subspan(tEntry_sz + 4);
                } else {
                    tocSpan = tocSpan.subspan(tocSpan.size());
                }
            }

            if (tocSpan.empty()) {
                tocFullyRead = true;
            }
        }
    }

    // 4. Reconcile entries into a new virtual TOC
    SeTableOfContent virtualToc = SeTableOfContent::CreateNewTableOfContent();

    unordered_map<u16string, SeArchiveEntry> tocMap;
    for (auto &te : tocEntries) {
        tocMap[SeTableOfContent::CanonicalizePathKey(te.path)] = te;
    }

    unordered_set<u16string> bodyPaths;
    size_t foundIndexedCount = 0;
    size_t foundOkCount = 0;
    size_t foundTruncatedCount = 0;
    size_t notFoundCount = 0;

    for (auto &be : parsedBodyEntries) {
        u16string key = SeTableOfContent::CanonicalizePathKey(be.path);
        bodyPaths.insert(key);

        if (be.recoveryState == EntryRecoveryState::FoundTruncated) {
            foundTruncatedCount++;
        }
        else {
            if (tocMap.find(key) != tocMap.end()) {
                be.recoveryState = EntryRecoveryState::FoundIndexed;
                foundIndexedCount++;
            } 
            else {
                be.recoveryState = EntryRecoveryState::FoundOk;
                foundOkCount++;
            }
        }

        // Auto-create parent directory entries if missing
        u16string parentDir = SeTableOfContent::GetParentDirectory(be.path);
        while (!parentDir.empty() && parentDir != u"/") {
            if (!virtualToc.CheckPath(parentDir)) {
                SeArchiveEntry dirEntry = SeArchiveEntry::CreateDirectoryEntry(parentDir);
                dirEntry.recoveryState = EntryRecoveryState::FoundIndexed;
                (void)virtualToc.AddEntry(dirEntry);
            }
            u16string nextParent = SeTableOfContent::GetParentDirectory(parentDir);
            if (nextParent == parentDir)
                break;
            parentDir = nextParent;
        }

        (void)virtualToc.AddEntry(be);
    }

    // Process entries present in TOC but NOT found in parsed body entries
    for (auto &[key, te] : tocMap) {
        if (bodyPaths.find(key) == bodyPaths.end()) {
            if (te.isDirectory()) {
            if (!virtualToc.CheckPath(te.path)) {
                te.recoveryState = EntryRecoveryState::FoundIndexed;
                (void)virtualToc.AddEntry(te);
            }
            } else {
                te.recoveryState = EntryRecoveryState::NotFound;
                notFoundCount++;
                (void)virtualToc.AddEntry(te);
            }
        }
    }

    // 5. Generate TOC health status string
    if (tocHeaderValid && tocFullyRead && notFoundCount == 0 && foundOkCount == 0 && foundTruncatedCount == 0) {
        tocHealth = "OK: All " + std::to_string(tocEntriesParsed) + " entries fully indexed";
    }
    else if (!tocHeaderValid) {
        if (effectiveTocOffset >= fileSize) {
            tocHealth = "Damaged: TOC offset (0x" + toHex(effectiveTocOffset) + ") out of bounds; " +
                        std::to_string(parsedBodyEntries.size()) + " items reconstructed from archive body";
        } else {
            tocHealth = "Damaged: Invalid TOC signature at offset 0x" + toHex(effectiveTocOffset) + "; " +
                        std::to_string(parsedBodyEntries.size()) + " items reconstructed from archive body";
        }
    } else if (!tocFullyRead || foundTruncatedCount > 0 || foundOkCount > 0 || notFoundCount > 0) {
        tocHealth = "Damaged: EOF cut off at 0x" + toHex(fileSize) + " • " +
                std::to_string(parsedBodyEntries.size()) + " items reconstructed (" +
                std::to_string(foundIndexedCount) + " indexed, " +
                std::to_string(foundOkCount) + " unindexed, " +
                std::to_string(foundTruncatedCount) + " truncated, " +
                std::to_string(notFoundCount) + " missing)";
    }
    else {
        tocHealth = "Recovered: " + std::to_string(parsedBodyEntries.size()) + " items reconstructed from body";
    }

    // 6. Build and return recovered SeArchive
    auto _cctx = AesGcmContextProvider::CreateContext();
    if (!_cctx)
    return unexpected(_cctx.error());

    metadata.m_toc_offset = virtualToc.getNextAvailOffset();

    SeArchive archive(metadata, std::move(virtualToc), path, *move(_cctx));
    archive.m_metadataHealth = std::move(metaHealth);
    archive.m_tocHealth = std::move(tocHealth);

    return archive;
}

expected<SeArchive, error_code> SeArchive::RecoverArchiveFile(u16string path) {
  return RecoverArchiveSync(path);
}

SeTaskHandle<SeArchive> SeArchive::RecoverArchiveAsync(u16string path) {
  auto promise = std::make_shared<std::promise<expected<SeArchive, error_code>>>();
  auto future = promise->get_future().share();

  std::jthread worker([path = std::move(path), promise](std::stop_token stopToken) {
    try {
      auto res = RecoverArchiveSync(path, stopToken);
      promise->set_value(std::move(res));
    } catch (...) {
      promise->set_exception(std::current_exception());
    }
  });

  return SeTaskHandle<SeArchive>(std::move(worker), std::move(future));
}

bool SeArchive::IsReady() { return this->m_isReady; }

expected<void, error_code> SeArchive::AddFile(u16string filePath,
                                              u16string fileName,
                                              uint64_t fileSize) {
  filePath = SeTableOfContent::NormalizeFilePath(filePath);
  if (!this->checkParentPath(filePath))
    return unexpected(SeError::TocPathIsInvalid);

  if (!SeTableOfContent::verifyAbsPath(fileName))
    return unexpected(make_error_code(errc::no_such_file_or_directory));

  auto job = SeJob(JobType::AddFile, filePath, fileName);
  if (fileSize > 0) {
    job.totalBytes = fileSize;
  } else {
    error_code ec;
    uint64_t fsz = filesystem::file_size(filesystem::path(fileName), ec);
    if (!ec) {
      job.totalBytes = fsz;
    }
  }

  if (!this->addJob(job))
    return unexpected(SeError::CannotCreateJob);

  return {};
}

expected<void, error_code> SeArchive::RemoveFile(u16string fileName) {
  fileName = SeTableOfContent::NormalizeFilePath(fileName);
  bool existsInToc = this->m_toc.CheckPath(fileName);
  bool existsInJobs = false;
  for (const auto &j : this->m_jobs) {
    if (j.m_type == JobType::AddFile && arePathsEqual(j.m_fileName, fileName)) {
      existsInJobs = true;
      break;
    }
  }
  if (!existsInToc && !existsInJobs)
    return unexpected(SeError::TocPathIsInvalid);

  auto job = SeJob(JobType::RemoveFile, fileName, u"");

  if (!this->addJob(job))
    return unexpected(SeError::CannotCreateJob);

  return {};
}

expected<void, error_code> SeArchive::CreateArchiveDirectory(u16string fileName) {
  fileName = SeTableOfContent::NormalizeDirectoryPath(fileName);
  if (!this->checkParentPath(fileName))
    return unexpected(SeError::TocPathIsInvalid);

  if (this->checkPathExists(fileName))
    return unexpected(SeError::AddingExistingEntry);

  auto job = SeJob(JobType::CreateArchiveDirectory, fileName, u"");

  if (!this->addJob(job))
    return unexpected(SeError::CannotCreateJob);

  return {};
}

expected<vector<SeArchive::DiscoveredItem>, error_code>
SeArchive::AddDirectoryWithDetails(u16string filePath, u16string fileName,
                                   IndexProgressCallback progressCallback) {
  u16string diskDirPath;
  u16string archiveParentPath;

  if (SeTableOfContent::verifyAbsPath(filePath) &&
      SeTableOfContent::isAbsPathDir(filePath)) {
    diskDirPath = filePath;
    archiveParentPath = fileName;
  } else if (SeTableOfContent::verifyAbsPath(fileName) &&
             SeTableOfContent::isAbsPathDir(fileName)) {
    diskDirPath = fileName;
    archiveParentPath = filePath;
  } else {
    if (!SeTableOfContent::verifyAbsPath(filePath) &&
        !SeTableOfContent::verifyAbsPath(fileName))
      return unexpected(make_error_code(errc::no_such_file_or_directory));
    return unexpected(SeError::ExpectedDirectory);
  }

  archiveParentPath =
      SeTableOfContent::NormalizeDirectoryPath(archiveParentPath);
  if (archiveParentPath != u"/" && !this->checkPathExists(archiveParentPath)) {
    return unexpected(SeError::TocPathIsInvalid);
  }

  filesystem::path diskPath(diskDirPath);
  filesystem::path leaf = diskPath.filename();
  if (leaf.empty() || leaf == ".") {
    leaf = diskPath.parent_path().filename();
  }
  u16string dirName = leaf.u16string();

  u16string baseArchiveDir;
  u16string parentLeaf = SeTableOfContent::GetFileName(archiveParentPath);
  if (!parentLeaf.empty() && parentLeaf == dirName) {
    baseArchiveDir = archiveParentPath;
  } else if (!dirName.empty()) {
    baseArchiveDir = SeTableOfContent::CreateDirPath(archiveParentPath, dirName);
  } else {
    baseArchiveDir = archiveParentPath;
  }

  vector<DiscoveredItem> discoveredItems;
  size_t dirCount = 0;
  size_t fileCount = 0;
  uint64_t totalBytes = 0;

  if (baseArchiveDir != u"/" && !this->checkPathExists(baseArchiveDir)) {
    DiscoveredItem rootItem;
    rootItem.diskPath = diskPath.u16string();
    rootItem.archiveRelPath = baseArchiveDir;
    rootItem.name = dirName;
    rootItem.isDirectory = true;
    rootItem.size = 0;
    discoveredItems.push_back(std::move(rootItem));
    dirCount++;
  }

  error_code ec;
  filesystem::recursive_directory_iterator it(
      diskPath, filesystem::directory_options::skip_permission_denied, ec);
  if (ec)
    return unexpected(ec);

  // Compute base prefix length for fast in-memory relative path slicing
  // Completely avoids MSVC std::filesystem::relative which invokes weakly_canonical and Win32 I/O
  std::u16string diskU16 = diskPath.u16string();
  size_t baseLen = diskU16.size();
  while (baseLen > 0 && (diskU16[baseLen - 1] == u'/' || diskU16[baseLen - 1] == u'\\')) {
    baseLen--;
  }

  filesystem::recursive_directory_iterator endIt;
  while (it != endIt) {
    const auto &entry = *it;
    error_code statusEc;
    bool isDir = entry.is_directory(statusEc);
    bool isReg = !isDir && entry.is_regular_file(statusEc);

    std::u16string entryU16 = entry.path().u16string();
    std::u16string relU16;
    if (entryU16.size() > baseLen) {
      size_t start = baseLen;
      if (entryU16[start] == u'/' || entryU16[start] == u'\\') {
        start++;
      }
      relU16 = entryU16.substr(start);
      for (auto &ch : relU16) {
        if (ch == u'\\') ch = u'/';
      }
    }

    if (!relU16.empty()) {
      if (isDir) {
        u16string subArchiveDir =
            SeTableOfContent::CreateDirPath(baseArchiveDir, relU16);
        DiscoveredItem dirItem;
        dirItem.diskPath = entryU16;
        dirItem.archiveRelPath = subArchiveDir;
        dirItem.name = entry.path().filename().u16string();
        dirItem.isDirectory = true;
        dirItem.size = 0;
        discoveredItems.push_back(std::move(dirItem));
        dirCount++;
      } else if (isReg) {
        u16string fileArchivePath =
            SeTableOfContent::CreateFilePath(baseArchiveDir, relU16);

        error_code szEc;
        uint64_t fileSize = entry.file_size(szEc);
        uint64_t actualSize = szEc ? 0 : fileSize;
        totalBytes += actualSize;

        DiscoveredItem fileItem;
        fileItem.diskPath = entryU16;
        fileItem.archiveRelPath = fileArchivePath;
        fileItem.name = entry.path().filename().u16string();
        fileItem.isDirectory = false;
        fileItem.size = actualSize;
        discoveredItems.push_back(std::move(fileItem));
        fileCount++;
      }

      if (progressCallback && (((dirCount + fileCount) & 0xFF) == 0)) {
        progressCallback(fileCount, dirCount);
      }
    }

    it.increment(ec);
    if (ec) {
      ec.clear();
    }
  }

  if (progressCallback) {
    progressCallback(fileCount, dirCount);
  }

  // Create exactly one job for the entire directory addition
  auto job = SeJob(JobType::AddDirectory, baseArchiveDir, diskDirPath);
  job.totalBytes = totalBytes;

  if (!this->addJob(job))
    return unexpected(SeError::CannotCreateJob);

  return discoveredItems;
}

expected<void, error_code> SeArchive::AddDirectory(u16string filePath,
                                                   u16string fileName) {
  auto res = this->AddDirectoryWithDetails(std::move(filePath), std::move(fileName));
  if (!res)
    return unexpected(res.error());
  return {};
}

expected<void, error_code> SeArchive::DeleteDirectory(u16string fileName) {
  fileName = SeTableOfContent::NormalizeDirectoryPath(fileName);
  if (fileName == u"/")
    return unexpected(SeError::TocPathIsInvalid);

  bool existsInToc = this->m_toc.CheckPath(fileName);
  bool existsInJobs = false;
  for (const auto &j : this->m_jobs) {
    if ((j.m_type == JobType::CreateArchiveDirectory ||
         j.m_type == JobType::AddDirectory) &&
        arePathsEqual(j.m_fileName, fileName)) {
      existsInJobs = true;
      break;
    }
  }
  if (!existsInToc && !existsInJobs)
    return unexpected(SeError::TocPathIsInvalid);

  auto job = SeJob(JobType::DeleteDirectory, fileName, u"");

  if (!this->addJob(job))
    return unexpected(SeError::CannotCreateJob);

  return {};
}

expected<void, error_code> SeArchive::MoveArchiveFile(u16string src,
                                                      u16string dst) {
  src = SeTableOfContent::NormalizeFilePath(src);
  dst = SeTableOfContent::NormalizeDirectoryPath(dst);
  if (!this->m_toc.CheckPath(src) || !this->m_toc.CheckPath(dst) ||
      !this->m_toc.IsDirectory(dst))
    return unexpected(SeError::TocPathIsInvalid);

  auto job = SeJob(JobType::MoveArchiveFile, src, dst);

  if (!this->addJob(job))
    return unexpected(SeError::CannotCreateJob);

  return {};
}

expected<void, error_code> SeArchive::MoveDirectory(u16string fileName,
                                                    u16string destPath) {
  fileName = SeTableOfContent::NormalizeDirectoryPath(fileName);
  destPath = SeTableOfContent::NormalizeDirectoryPath(destPath);
  if (fileName == u"/" || destPath.starts_with(fileName))
    return unexpected(SeError::TocPathIsInvalid);

  if (!this->m_toc.CheckPath(fileName) || !this->m_toc.IsDirectory(fileName) ||
      !this->m_toc.CheckPath(destPath) || !this->m_toc.IsDirectory(destPath))
    return unexpected(SeError::TocPathIsInvalid);

  auto job = SeJob(JobType::MoveDirectory, fileName, destPath);

  if (!this->addJob(job))
    return unexpected(SeError::CannotCreateJob);

  return {};
}

expected<void, error_code>
SeArchive::RegisterKey(string key) {
  if (key.empty())
    return unexpected(SeError::CRYPTOStringWasEmpty);

  auto salt = this->m_metadata.GetSalt();
  vector<unsigned char> candidate_key(AesGcmContextProvider::KEY_BYTES);
  auto exp = deriveMasterKeyArgon2id(key, salt, candidate_key);
  if (!exp) {
    sodium_memzero(candidate_key.data(), candidate_key.size());
    return unexpected(exp.error());
  }

  auto pvvExp = calculatePVV(candidate_key);
  if (!pvvExp) {
    sodium_memzero(candidate_key.data(), candidate_key.size());
    return unexpected(pvvExp.error());
  }

  if (*pvvExp != this->m_metadata.GetPVV()) {
    sodium_memzero(candidate_key.data(), candidate_key.size());
    return unexpected(SeError::InvalidKey);
  }

  auto setRes = this->m_cryptoCtx.SetMasterKey(candidate_key);
  sodium_memzero(candidate_key.data(), candidate_key.size());
  if (!setRes)
    return unexpected(setRes.error());

  return {};
}

bool SeArchive::IsKeyPresent() { return this->m_cryptoCtx.keyExists(); }

expected<bool, error_code>
SeArchive::TestKeySync(u16string entryPath, string key) {
  auto _entry = this->m_toc.GetEntry(entryPath);
  if (!_entry) {
    return unexpected(_entry.error());
  }
  return this->TestKeySync(*_entry, std::move(key));
}

expected<bool, error_code>
SeArchive::TestKeySync(const SeArchiveEntry &entry, string key) {
  if (entry.isDirectory()) {
    return true;
  }
  if (entry.compressed_size == 0 && entry.uncompressed_size == 0) {
    return true;
  }

  // Ensure archive stream is open
  if (!this->m_archiveStream.is_open()) {
    auto _openArchive = this->m_archiveStream.open(this->m_archiveFilePath);
    if (!_openArchive && _openArchive.error() != SeError::StreamAlreadyOpen) {
      return unexpected(_openArchive.error());
    }
  }

  // Read header size to locate payload
  uint32_t cCount = 0;
  auto rdCount = this->m_archiveStream.read_at(entry.offset, &cCount, sizeof(cCount));
  if (!rdCount || *rdCount != sizeof(cCount)) {
    return false;
  }

  size_t headerSize = sizeof(uint32_t) + (cCount * sizeof(char16_t)) +
                      (4 * sizeof(uint64_t)) + (2 * sizeof(uint32_t));
  uint64_t payloadOffset = entry.offset + headerSize;

  const size_t cipherChunkSize =
      AesGcmStreamSession<Mode::Decryption>::BUFFER_SIZE +
      AesGcmStreamSession<Mode::Decryption>::TAG_BYTES;
  size_t toRead = std::min(static_cast<uint64_t>(cipherChunkSize), entry.compressed_size);

  if (toRead < crypto_aead_aes256gcm_ABYTES) {
    return false;
  }

  // Thread-local scratch buffers to avoid repeated heap allocation on 10,000+ files
  thread_local vector<unsigned char> cipherBuffer(cipherChunkSize);
  thread_local vector<unsigned char> plainBuffer(AesGcmStreamSession<Mode::Decryption>::BUFFER_SIZE);

  auto rdCipher = this->m_archiveStream.read_at(payloadOffset, cipherBuffer.data(), toRead);
  if (!rdCipher || *rdCipher != toRead) {
    return false;
  }

  if (key.empty()) {
    if (!this->m_cryptoCtx.keyExists()) {
      return false;
    }
    auto _cryptoSess = this->m_cryptoCtx.createSession<Mode::Decryption>(entry.fileUid);
    if (!_cryptoSess) {
      return false;
    }
    auto &cryptoSess = *_cryptoSess;
    if (toRead == cipherChunkSize) {
      auto res = cryptoSess->decrypt(
          span<unsigned char>{cipherBuffer.data(), toRead}, plainBuffer);
      return res.has_value();
    } else {
      auto res = cryptoSess->decrypt(
          span<unsigned char>{cipherBuffer.data(), toRead}, plainBuffer);
      auto fin = cryptoSess->finalizeDecryption(plainBuffer);
      return fin.has_value();
    }
  } else {
    auto salt = this->m_metadata.GetSalt();
    vector<unsigned char> candidate_key(AesGcmContextProvider::KEY_BYTES);
    auto exp = deriveMasterKeyArgon2id(key, salt, candidate_key);
    if (!exp) {
      sodium_memzero(candidate_key.data(), candidate_key.size());
      return unexpected(exp.error());
    }

    auto pvvExp = calculatePVV(candidate_key);
    if (!pvvExp || *pvvExp != this->m_metadata.GetPVV()) {
      sodium_memzero(candidate_key.data(), candidate_key.size());
      return false;
    }

    vector<unsigned char> subkey(AesGcmContextProvider::KEY_BYTES);
    if (crypto_kdf_derive_from_key(subkey.data(), subkey.size(), entry.fileUid,
                                   "file_enc", candidate_key.data()) != 0) {
      sodium_memzero(candidate_key.data(), candidate_key.size());
      return false;
    }

    vector<unsigned char> nonceDeriv(crypto_kdf_BYTES_MIN);
    if (crypto_kdf_derive_from_key(nonceDeriv.data(), nonceDeriv.size(),
                                   entry.fileUid, "file_non", candidate_key.data()) != 0) {
      sodium_memzero(candidate_key.data(), candidate_key.size());
      sodium_memzero(subkey.data(), subkey.size());
      return false;
    }

    sodium_memzero(candidate_key.data(), candidate_key.size());

    unsigned char baseNonce[crypto_aead_aes256gcm_NPUBBYTES];
    memcpy(baseNonce, nonceDeriv.data(), sizeof(baseNonce));
    sodium_memzero(nonceDeriv.data(), nonceDeriv.size());

    unsigned long long plainLen = 0;
    int res = crypto_aead_aes256gcm_decrypt(
        plainBuffer.data(), &plainLen, nullptr,
        cipherBuffer.data(), toRead,
        nullptr, 0,
        baseNonce, subkey.data());

    sodium_memzero(subkey.data(), subkey.size());
    return (res == 0);
  }
}

SeTaskHandle<bool>
SeArchive::TestKeyAsync(u16string entryPath, string key) {
  auto promise = std::make_shared<std::promise<expected<bool, error_code>>>();
  auto future = promise->get_future().share();

  std::jthread worker([this, entryPath = std::move(entryPath),
                       key = std::move(key), promise](std::stop_token stopToken) {
    try {
      auto res = this->TestKeySync(entryPath, key);
      promise->set_value(res);
    } catch (...) {
      promise->set_exception(std::current_exception());
    }
  });

  return SeTaskHandle<bool>(std::move(worker), std::move(future));
}

const vector<SeJob> &SeArchive::GetJobs() { return this->m_jobs; }

expected<void, error_code> SeArchive::RemoveJob(int id) {
    for (auto it = this->m_jobs.begin(); it != this->m_jobs.end(); ++it) {
        if (it->m_id == id) {
            if (it->m_type == JobType::CreateArchiveDirectory || it->m_type == JobType::AddDirectory) {
                this->m_queuedDirs.erase(SeTableOfContent::NormalizeDirectoryPath(it->m_fileName));
            }
            else if (it->m_type == JobType::AddFile) {
                this->m_queuedFiles.erase(SeTableOfContent::NormalizeFilePath(it->m_fileName));
            }
            this->m_jobs.erase(it);
            return {};
        }
    }
    return unexpected(SeError::JobNotFound);
}

expected<void, error_code> SeArchive::ResetJob(int id) {
  bool found = false;
  for (auto &job : this->m_jobs) {
    if (job.m_id == id || (found && (job.m_status == JobStatus::Failed || job.m_status == JobStatus::Aborted))) {
      found = true;
      job.m_status = JobStatus::Idle;
      job.processedBytes = 0;
      job.compressedBytes = 0;
      job.percentage = 0;
    }
  }
  if (!found) {
    for (auto &job : this->m_jobs) {
      if (job.m_status == JobStatus::Failed || job.m_status == JobStatus::Aborted) {
        job.m_status = JobStatus::Idle;
        job.processedBytes = 0;
        job.compressedBytes = 0;
        job.percentage = 0;
        found = true;
      }
    }
  }
  if (!found && id > 0)
    return unexpected(SeError::JobNotFound);

  return {};
}

void SeArchive::RemoveCompletedJobs() {
  // Logic removed: completed jobs are preserved in job list
}

void SeArchive::ResetFailedJobs() {
  for (auto &job : this->m_jobs) {
    if (job.m_status == JobStatus::Failed || job.m_status == JobStatus::Aborted) {
      job.m_status = JobStatus::Idle;
      job.processedBytes = 0;
      job.compressedBytes = 0;
      job.percentage = 0;
    }
  }
}

void SeArchive::SetPreserveMetadata(bool preserve) {
  if (this->m_metadata.m_preserve_metadata != preserve)
    this->m_metadata.SetPreserveMetadata(preserve);
}

void SeArchive::SetCompressionLevel(uint32_t compressionLevel) {
  this->ChangeCompressionLevel(compressionLevel);
}

expected<void, error_code>
SeArchive::ChangeCompressionLevel(uint32_t compressionLevel) {
  if (compressionLevel < 1 || compressionLevel > 3)
    return unexpected(make_error_code(errc::invalid_argument));

  u16string levelStr;
  levelStr.push_back(static_cast<char16_t>(u'0' + compressionLevel));

  // If an idle CompressionLevelChange job already exists in the queue, update its target level
  for (auto &job : this->m_jobs) {
    if (job.m_type == JobType::CompressionLevelChange &&
        job.m_status == JobStatus::Idle) {
      job.m_fileName = levelStr;
      return {};
    }
  }

  SeJob job(JobType::CompressionLevelChange, levelStr, u"");
  if (!this->addJob(job))
    return unexpected(SeError::CannotCreateJob);

  return {};
}

expected<void, error_code> SeArchive::SaveChangesSync(ProgressCallback callback,
                                                      stop_token stopToken,
                                                      SePauseToken pauseToken) {
  // Before optimizing and verifying, reset any failed or aborted jobs from
  // prior attempts back to Idle so recommitting changes proceeds cleanly
  this->ResetFailedJobs();

  // ProcessCallback will be called with jobs queued in the job container
  // Jobs are pre-optimized explicitly by the caller prior to verification and execution
  if (!verifyJobs())
    return unexpected(SeError::ConflictingJobFound);

  // Checking the Io Status and preparing it ( check the archive file existance
  // ) verifying TOC

  auto _exfs = this->m_archiveStream.open(this->m_archiveFilePath);
  if (!_exfs && _exfs.error() != SeError::StreamAlreadyOpen)
    return unexpected(_exfs.error());

  auto &fs = this->m_archiveStream;
  fs.seek(0);

  if (fs.size() > SE_METADATA_SIZE) {
      vector<unsigned char> metadata_bytes(SE_METADATA_SIZE);
      if (auto _sz = fs.read(metadata_bytes.data(), SE_METADATA_SIZE); !_sz) {
          return unexpected(_sz.error());
      }
      auto _metadata = SeMetadata::LoadMetadataFromBytes(metadata_bytes);
      if (!_metadata)
          return unexpected(_metadata.error());
      SeMetadata metadata = *_metadata;

      if (metadata.m_toc_offset != this->m_metadata.m_toc_offset ||
          metadata.m_version != this->m_metadata.m_version)
          return unexpected(SeError::ArchiveModified);

      uint64_t toc_offset = metadata.m_toc_offset;
      if (toc_offset > fs.size())
          return unexpected(SeError::NoTOCFound);
      if (auto _cursor = fs.seek(toc_offset); !_cursor)
          return unexpected(_cursor.error());
      uint64_t toc_size = fs.size() - toc_offset;
      vector<unsigned char> toc_bytes(toc_size);
      if (auto _read = fs.read(toc_bytes.data(), toc_size); !_read)
          return unexpected(_read.error());
      auto _toc = SeTableOfContent::LoadTableOfContentFromBytes(toc_bytes);
      if (!_toc)
          return unexpected(SeError::NoTOCFound);
      auto fileToc = *_toc;
      if (fileToc != this->m_toc)
          return unexpected(SeError::ArchiveModified);
    fs.seek(0);
  }

  // Toc verified now we can start the operations
  if (!this->IsReady()) {
    // either TOC or metadata was modified internally and not saved on disk we
    // have to address that
    return unexpected(
        SeError::ArchiveModified); // In any archive modified case you have to
                                   // reload it again to be sure.
  }

  this->m_isReady = false;

  int completedJobsCount = 0;
  bool hasFailed = false;
  error_code failureCode{};

  for (int i{0}; i < this->m_jobs.size(); i++) {

    auto &job = this->m_jobs[i];

    pauseToken.wait_if_paused(stopToken);

    if (stopToken.stop_requested()) {
      hasFailed = true;
      failureCode = SeError::OperationCanceled;
      break;
    }

    if (job.m_status == JobStatus::Finished) {
      completedJobsCount++;
      continue;
    }

    if (job.m_status != JobStatus::Idle) {
      hasFailed = true;
      failureCode = SeError::JobIsNotIdle;
      break;
    }

    // WARN: this level of job seperation will introduce overhead with archives
    // that have complex file system -> jobs should be able to merge
    expected<void, error_code> _result;

    switch (job.m_type) {
    case JobType::None:
      return unexpected(SeError::InvalidJob);
    case JobType::AddFile:
      _result = doAddFileJob(job, callback, stopToken, pauseToken);
      break;
    case JobType::RemoveFile:
      _result = doRemoveFileJob(job, callback, stopToken, pauseToken);
      break;
    case JobType::CreateArchiveDirectory:
      _result = doCreateDirectoryJob(job, callback, stopToken, pauseToken);
      break;
    case JobType::AddDirectory:
      _result = doAddDirectoryJob(job, callback, stopToken, pauseToken);
      break;
    case JobType::DeleteDirectory:
      _result = doDeleteDirectoryJob(job, callback, stopToken, pauseToken);
      break;
    case JobType::MoveArchiveFile:
      _result = doMoveFileJob(job, callback, stopToken, pauseToken);
      break;
    case JobType::MoveDirectory:
      _result = doMoveDirectoryJob(job, callback, stopToken, pauseToken);
      break;
    case JobType::CompressionLevelChange:
      _result = doChangeCompressionLevel(job, callback, stopToken, pauseToken);
      break;
    case JobType::TestFile:
      _result = doTestFile(job, callback, stopToken, pauseToken);
      break;
    }

    if (!_result) {
      hasFailed = true;
      failureCode = _result.error();
      break;
    } else {
      completedJobsCount++;
    }
  }

  if (hasFailed) {
    for (auto &j : this->m_jobs) {
      if (j.m_status == JobStatus::Running) {
        j.setStatus(JobStatus::Aborted);
      }
    }

    // in any case if the result was an op cancelation we have to write the TOC in file 
    // bug fixed !
    if (failureCode == SeError::OperationCanceled) {
      size_t newTocOffset = this->m_toc.getNextAvailOffset();
      auto _ser = this->m_toc.Serialize();
      if (_ser) {
        auto tocBytes = this->m_toc.GetTOCBytes();
        if (auto _sk = this->m_archiveStream.seek(newTocOffset); _sk) {
          if (auto _wr = this->m_archiveStream.write(tocBytes.data(), tocBytes.size()); _wr) {
            this->m_archiveStream.truncate(newTocOffset + tocBytes.size());
            this->m_metadata.m_toc_offset = newTocOffset;
            vector<unsigned char> metaBytes(SE_METADATA_SIZE);
            this->m_metadata.GetMetadataBytes(metaBytes);
            if (auto _skMeta = this->m_archiveStream.seek(0); _skMeta) {
              this->m_archiveStream.write(metaBytes.data(), metaBytes.size());
              this->m_archiveStream.flush();
            }
          }
        }
      }
    }

    // 2. Mark archive ready so subsequent recommit or actions can proceed
    this->m_isReady = true;

    return unexpected(failureCode);
  }

  // Persist updated TOC and Metadata to disk
  size_t newTocOffset = this->m_toc.getNextAvailOffset();
  auto _ser = this->m_toc.Serialize();
  if (!_ser)
    return unexpected(_ser.error());

  auto tocBytes = this->m_toc.GetTOCBytes();
  if (auto _sk = this->m_archiveStream.seek(newTocOffset); !_sk)
    return unexpected(_sk.error());

  if (auto _wr = this->m_archiveStream.write(tocBytes.data(), tocBytes.size()); !_wr)
    return unexpected(_wr.error());

  if (auto _tr = this->m_archiveStream.truncate(newTocOffset + tocBytes.size()); !_tr)
    return unexpected(_tr.error());

  this->m_metadata.m_toc_offset = newTocOffset;
  vector<unsigned char> metaBytes(SE_METADATA_SIZE);
  this->m_metadata.GetMetadataBytes(metaBytes);

  if (auto _sk = this->m_archiveStream.seek(0); !_sk)
    return unexpected(_sk.error());

  if (auto _wr = this->m_archiveStream.write(metaBytes.data(), metaBytes.size()); !_wr)
    return unexpected(_wr.error());

  this->m_archiveStream.flush();
  this->m_jobs.clear();
  this->m_isReady = true;

  return {};
}

SeTaskHandle<void> SeArchive::SaveChangesAsync(ProgressCallback callback) {
  auto promise = std::make_shared<std::promise<expected<void, error_code>>>();
  auto future = promise->get_future().share();
  auto pauseState = std::make_shared<SePauseState>();
  SePauseToken pauseToken(pauseState);

  std::jthread worker([this, callback = std::move(callback),
                       promise, pauseToken](std::stop_token stopToken) {
    try {
      auto res = this->SaveChangesSync(callback, stopToken, pauseToken);
      promise->set_value(res);
    } catch (...) {
      promise->set_exception(std::current_exception());
    }
  });

  return SeTaskHandle<void>(std::move(worker), std::move(future), std::move(pauseState));
}

// @Private

expected<void, error_code> SeArchive::doAddFileJob(SeJob &job, ProgressCallback callback, stop_token stopToken, SePauseToken pauseToken) {
    job.m_status = JobStatus::Pending;

    pauseToken.wait_if_paused(stopToken);

    if (stopToken.stop_requested()) {
        job.setStatus(JobStatus::Aborted);
        if (callback)
            callback(job);

        return unexpected(SeError::OperationCanceled);
    }

    if (callback)
        callback(job);

    MappedFileStream inFileStream;
    if (auto _fs = inFileStream.open(job.m_filePath, FileMode::OpenExisting); !_fs) {
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);
        return unexpected(_fs.error());
    }

    if (!this->m_archiveStream.is_open()) {
        auto _openArchive = this->m_archiveStream.open(this->m_archiveFilePath);
        if (!_openArchive && _openArchive.error() != SeError::StreamAlreadyOpen) {
            job.setStatus(JobStatus::Failed);
            if (callback)
            callback(job);
            return unexpected(_openArchive.error());
        }
    }

    SeArchiveEntry entry = SeArchiveEntry::CreateFileEntry(job.m_fileName);

    entry.uncompressed_size = inFileStream.size();
    entry.attributes = 0;

    if (this->m_metadata.GetPreserveMetadata()) {
        entry.attributes = se::GetFileAttributes(job.m_filePath);
    }

    entry.offset = this->m_toc.getNextAvailOffset();
    entry.fileUid = getSecureRandom();
    entry.crc32 = CRC32C_INIT;

    if (auto _sk = this->m_archiveStream.seek(entry.offset); !_sk) {
        // either the file is not big enough or some error in the getNextAvailOffset
        // caused this
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);
        return unexpected(_sk.error());
    }
    auto entryPlaceHolderBytes = entry.Serialize();
    auto _wentryError = m_archiveStream.write(entryPlaceHolderBytes);

    if (!_wentryError) {
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);

        return unexpected(_wentryError.error());
    }

    m_archiveStream.flush(); // assuming that the only possible error here is
                            // closed handle which will likely occure on top!

    // Setting up file compression

    int cLevel = this->m_metadata.GetCompressionLevel() == 1   ? 1
                : this->m_metadata.GetCompressionLevel() == 2 ? 15
                                                                : 19;

    ZSTD_CCtx_reset(this->m_zstdCctx.get(), ZSTD_reset_session_only);
    size_t param_err = ZSTD_CCtx_setParameter(this->m_zstdCctx.get(),ZSTD_c_compressionLevel, cLevel);

    size_t readSz = ZSTD_CStreamInSize();
    size_t writeSz = ZSTD_CStreamOutSize();

    vector<unsigned char> inBuffer(readSz);
    vector<unsigned char> outBuffer(writeSz);

    auto _cryptoStream = this->m_cryptoCtx.createSession<Mode::Encryption>(entry.fileUid);
    if (!_cryptoStream) {
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);

        return unexpected(_cryptoStream.error());
    }

    unique_ptr<AesGcmStreamSession<Mode::Encryption>> cryptoStreamSession = *move(_cryptoStream);

    const size_t cipherChunkSize =
        AesGcmStreamSession<Mode::Encryption>::BUFFER_SIZE +
        AesGcmStreamSession<Mode::Encryption>::TAG_BYTES;

    vector<unsigned char> cryptoOutBuffer(cipherChunkSize);

    bool isLastChunk = false;

    job.setStatus(JobStatus::Running);
    job.totalBytes = inFileStream.size();
    job.processedBytes = 0;
    job.compressedBytes = 0;
    job.percentage = 0;

    if (callback)
        callback(job);

    size_t processedBytes = 0;
    while (!isLastChunk) {

        pauseToken.wait_if_paused(stopToken, [&]() {
            job.setStatus(JobStatus::Paused);
            if (callback)
            callback(job);
        }, [&]() {
            job.setStatus(JobStatus::Running);
            if (callback)
                callback(job);
        });

        if (stopToken.stop_requested()) {
            this->m_archiveStream.seek(entry.offset);
            job.setStatus(JobStatus::Aborted);
            if (callback)
            callback(job);
            return unexpected(SeError::OperationCanceled);
        }

        auto _rd = inFileStream.read(inBuffer.data(), readSz);
        if (!_rd) {
            job.setStatus(JobStatus::Failed);
            if (callback)
            callback(job);
            return unexpected(_rd.error());
        }

        processedBytes += *_rd;
        isLastChunk = (*_rd < readSz) || inFileStream.eof();
        ZSTD_EndDirective mode = isLastChunk ? ZSTD_e_end : ZSTD_e_continue;

        ZSTD_inBuffer inBuff{inBuffer.data(), *_rd, 0};
        bool finished = false;

        while (!finished) {
            pauseToken.wait_if_paused(stopToken, [&]() {
                job.setStatus(JobStatus::Paused);
                if (callback)
                    callback(job);
                }, [&]() {
                    job.setStatus(JobStatus::Running);
                    if (callback)
                        callback(job);
            });

            if (stopToken.stop_requested()) {
                this->m_archiveStream.seek(entry.offset);
                job.setStatus(JobStatus::Aborted);
                if (callback)
                    callback(job);
                return unexpected(SeError::OperationCanceled);
            }

            ZSTD_outBuffer outBuff = {outBuffer.data(), writeSz, 0};

            size_t remaining =
                ZSTD_compressStream2(this->m_zstdCctx.get(), &outBuff, &inBuff, mode);

            if (ZSTD_isError(remaining)) {
                job.setStatus(JobStatus::Failed);
                if (callback)
                    callback(job);

                return unexpected(SeError::ZSTDCompressionError);
            }

            if (outBuff.pos > 0) {
                auto _cryptoResult = cryptoStreamSession->encrypt(
                    span<unsigned char>{reinterpret_cast<unsigned char *>(outBuff.dst),
                                        outBuff.pos},
                    cryptoOutBuffer);
                if (_cryptoResult) {
                    entry.compressed_size += cipherChunkSize;

                    auto _wLError = m_archiveStream.write(span<unsigned char>{cryptoOutBuffer.data(), cipherChunkSize});

                    // Status report
                    job.processedBytes = processedBytes;
                    job.compressedBytes = entry.compressed_size;
                    job.percentage = inFileStream.size() == 0
                                        ? 100
                                        : static_cast<uint32_t>((processedBytes * 100) /
                                                                inFileStream.size());

                    if (callback)
                        callback(job);

                    if (!_wLError) {
                        job.setStatus(JobStatus::Failed);
                        if (callback)
                            callback(job);
                        return unexpected(_wLError.error());
                    }
                }
                if (!_cryptoResult && _cryptoResult.error() != SeError::CRYPTOStageTooSmall) { // Ignoring staged buffer warns
                        job.setStatus(JobStatus::Failed);
                        if (callback)
                        callback(job);
                        return unexpected(_cryptoResult.error());
                }
            }

            if (mode == ZSTD_e_end) {
                finished = remaining == 0;
            } else {
                finished = inBuff.pos == inBuff.size;
            }
        }
        // doing the crc32 and compression tracking
        uint64_t t_crc = entry.crc32;
        entry.crc32 = crc32c_update(t_crc, inBuff.src, inBuff.size);
    }

    // Flushing the cryptoBuffer by finalizing the session
    auto _cryptoResult = cryptoStreamSession->finalizeEncryption(cryptoOutBuffer);
    if (!_cryptoResult) {
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);
        return unexpected(_cryptoResult.error());
    }

    size_t finalCipherBytes = *_cryptoResult;
    if (finalCipherBytes > 0) {
        entry.compressed_size += finalCipherBytes;
        auto _wLError = m_archiveStream.write(span<unsigned char>{cryptoOutBuffer.data(), finalCipherBytes});
        if (!_wLError) {
            job.setStatus(JobStatus::Failed);
            if (callback)
            callback(job);
            return unexpected(_wLError.error());
        }
    }

    ZSTD_CCtx_reset(this->m_zstdCctx.get(), ZSTD_reset_session_only);

    uint64_t t_crc = entry.crc32;
    entry.crc32 = crc32c_finalize(t_crc);

    // Replacing the entry placeholder:
    auto entryBytes = entry.Serialize();

    this->m_archiveStream.seek(entry.offset);

    if (auto _entErr = this->m_archiveStream.write(entryBytes); !_entErr) {
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);
        return unexpected(_entErr.error());
    }

    this->m_archiveStream.flush();

    // Modifying entry's path from file name to full path
    entry.path = job.m_fileName;

    if (auto _addErr = this->m_toc.AddEntry(entry); !_addErr) {
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);
        return unexpected(_addErr.error());
    }

    job.setStatus(JobStatus::Finished);
    job.processedBytes = inFileStream.size();
    job.compressedBytes = entry.compressed_size;
    job.percentage = 100;
    job.crc32 = entry.crc32;
    if (callback)
        callback(job);

    return {};
}

expected<void, error_code> SeArchive::doRemoveFileJob(SeJob &job,
                                                      ProgressCallback callback,
                                                      stop_token stopToken,
                                                      SePauseToken pauseToken) {

  job.setStatus(JobStatus::Pending);
  pauseToken.wait_if_paused(stopToken);
  if (callback)
    callback(job);
  if (stopToken.stop_requested()) {
    job.setStatus(JobStatus::Aborted);
    if (callback)
      callback(job);

    return unexpected(SeError::OperationCanceled);
  }

  auto _entError = this->m_toc.GetEntry(job.m_fileName);
  if (!_entError) {
    job.setStatus(JobStatus::Failed);
    if (callback)
      callback(job);
    return unexpected(_entError.error());
  }
  auto entry = *_entError;

  auto inFileEntrySize = entry.GetDiskSize();
  auto frontEntries = this->m_toc.GetEntriesFollowing(entry);

  job.setStatus(JobStatus::Running);
  if (callback)
    callback(job);

  if (!frontEntries.empty() && inFileEntrySize > 0) {
    sort(frontEntries.begin(), frontEntries.end(),
         [](const SeArchiveEntry &a, const SeArchiveEntry &b) {
           return a.offset < b.offset;
         });

    for (size_t i = 0; i < frontEntries.size(); i++) {
      pauseToken.wait_if_paused(stopToken);
      if (stopToken.stop_requested()) {
        job.setStatus(JobStatus::Aborted);
        if (callback)
          callback(job);
        return unexpected(SeError::OperationCanceled);
      }

      auto &frontEnt = frontEntries[i];

      job.percentage = static_cast<uint32_t>((i * 100) / frontEntries.size());
      if (callback)
        callback(job);

      size_t entrySize = frontEnt.GetDiskSize();
      if (entrySize > 0) {
        size_t targetOffset = frontEnt.offset - inFileEntrySize;
        if (auto _err = this->m_archiveStream.shift_bytes(
                targetOffset, frontEnt.offset, entrySize);
            !_err) {
          job.setStatus(JobStatus::Failed);
          if (callback)
            callback(job);
          return unexpected(_err.error());
        }
      }

      // Update the offset of frontEnt in m_toc
      for (auto &tocEnt : this->m_toc.m_entries) {
        if (!tocEnt.isDirectory() && tocEnt.path == frontEnt.path) {
          tocEnt.offset -= inFileEntrySize;
          break;
        }
      }
    }
  }

  // Always remove the deleted entry from m_toc
  this->m_toc.RemoveEntry(entry.path);

  job.percentage = 100;
  job.setStatus(JobStatus::Finished);
  if (callback)
    callback(job);
  return {};
}

expected<void, error_code>
SeArchive::doCreateDirectoryJob(SeJob &job, ProgressCallback callback,
                             stop_token stopToken,
                             SePauseToken pauseToken) {
  job.setStatus(JobStatus::Pending);
  pauseToken.wait_if_paused(stopToken);
  if (callback)
    callback(job);

  if (stopToken.stop_requested()) {
    job.setStatus(JobStatus::Aborted);
    if (callback)
      callback(job);
    return unexpected(SeError::OperationCanceled);
  }

  // Verifying the parent directory path ensuring it does exist
  if (!this->m_toc.CheckParentPath(job.m_fileName)) {
    job.setStatus(JobStatus::Failed);
    if (callback)
      callback(job);
    return unexpected(SeError::TocPathIsInvalid);
  }

  SeArchiveEntry entry = SeArchiveEntry::CreateDirectoryEntry(job.m_fileName);

  if (auto _err = this->m_toc.AddEntry(entry); !_err) {
    return unexpected(_err.error());
  }

  job.setStatus(JobStatus::Finished);
  if (callback)
    callback(job);
  return {};
}

expected<void, error_code>
SeArchive::doAddDirectoryJob(SeJob &job, ProgressCallback callback,stop_token stopToken, SePauseToken pauseToken) {
    job.setStatus(JobStatus::Pending);
    pauseToken.wait_if_paused(stopToken);

    if (callback)
        callback(job);

    if (stopToken.stop_requested()) {
        job.setStatus(JobStatus::Aborted);

        if (callback)
            callback(job);
        return unexpected(SeError::OperationCanceled);
    }

    u16string baseArchiveDir = SeTableOfContent::NormalizeDirectoryPath(job.m_fileName);
    u16string diskDirPath = job.m_filePath;

    if (!SeTableOfContent::verifyAbsPath(diskDirPath) || !SeTableOfContent::isAbsPathDir(diskDirPath)) {
        job.setStatus(JobStatus::Failed);

        if (callback)
            callback(job);
            return unexpected(SeError::ExpectedDirectory);
        }

        if (baseArchiveDir != u"/" && !this->m_toc.CheckParentPath(baseArchiveDir)) {
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);
            return unexpected(SeError::TocPathIsInvalid);
        }

        if (baseArchiveDir != u"/" && !this->m_toc.CheckPath(baseArchiveDir)) {
        SeArchiveEntry baseEntry = SeArchiveEntry::CreateDirectoryEntry(baseArchiveDir);
        if (auto _err = this->m_toc.AddEntry(baseEntry); !_err) {
            job.setStatus(JobStatus::Failed);
            if (callback)
            callback(job);
            return unexpected(_err.error());
        }
    }

    filesystem::path diskPath(diskDirPath);
    std::u16string diskU16 = diskPath.u16string();
    size_t baseLen = diskU16.size();

    while (baseLen > 0 && (diskU16[baseLen - 1] == u'/' || diskU16[baseLen - 1] == u'\\') ) {
        baseLen--;
    }

    error_code ec;
    filesystem::recursive_directory_iterator it(diskPath, filesystem::directory_options::skip_permission_denied, ec);
    if (ec) {
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);
        return unexpected(ec);
    }

    struct PendingSubDir {
        u16string archivePath;
    };

    struct PendingSubFile {
        u16string archivePath;
        u16string diskPath;
        uint64_t fileSize;
    };

    vector<PendingSubDir> pendingDirs;
    vector<PendingSubFile> pendingFiles;
    uint64_t totalBytes = 0;

    filesystem::recursive_directory_iterator endIt;
    while (it != endIt) {
        const auto &entry = *it;
        error_code statusEc;
        bool isDir = entry.is_directory(statusEc);
        bool isReg = !isDir && entry.is_regular_file(statusEc);

        std::u16string entryU16 = entry.path().u16string();
        std::u16string relU16;
        if (entryU16.size() > baseLen) {
            size_t start = baseLen;
            if (entryU16[start] == u'/' || entryU16[start] == u'\\') {
            start++;
            }
            relU16 = entryU16.substr(start);
            for (auto &ch : relU16) {
            if (ch == u'\\')
                ch = u'/';
            }
        }

        if (!relU16.empty()) {
            if (isDir) {
            u16string subArchiveDir = SeTableOfContent::CreateDirPath(baseArchiveDir, relU16);
            pendingDirs.push_back({subArchiveDir});
            } 
            else if (isReg) {
                u16string fileArchivePath = SeTableOfContent::CreateFilePath(baseArchiveDir, relU16);
                error_code szEc;
                uint64_t sz = entry.file_size(szEc);
                uint64_t fileSize = szEc ? 0 : sz;
                totalBytes += fileSize;
                pendingFiles.push_back({fileArchivePath, entryU16, fileSize});
            }
        }

        it.increment(ec);
        if (ec)
            ec.clear();
    }

    // Create subdirectories in TOC via doCreateDirectoryJob
    for (const auto &d : pendingDirs) {
        if (!this->m_toc.CheckPath(d.archivePath)) {
            job.SetFileName(d.archivePath);
            // doCreateDirectoryJob reads job.m_fileName for the directory path
            auto _dirResult = this->doCreateDirectoryJob(job, nullptr, stopToken, pauseToken);
            if (!_dirResult) {
                if (callback)
                    callback(job);
                return unexpected(_dirResult.error());
            }
        }
    }

    if (stopToken.stop_requested()) {
        job.setStatus(JobStatus::Aborted);
        if (callback)
            callback(job);
        return unexpected(SeError::OperationCanceled);
    }

    job.setStatus(JobStatus::Running);
    job.totalBytes = totalBytes;
    job.processedBytes = 0;
    job.compressedBytes = 0;
    job.percentage = (totalBytes == 0) ? 100 : 0;
    if (callback)
        callback(job);

    if (pendingFiles.empty()) {
        job.SetFileName(baseArchiveDir);
        job.setStatus(JobStatus::Finished);
        job.percentage = 100;
        if (callback)
            callback(job);
        return {};
    }

    uint64_t cumulativeProcessed = 0;
    uint64_t cumulativeCompressed = 0;

    for (const auto &pf : pendingFiles) {
        job.SetFileName(pf.archivePath);
        job.m_filePath = pf.diskPath;

        uint64_t baseProcessed = cumulativeProcessed;
        uint64_t baseCompressed = cumulativeCompressed;

        ProgressCallback wrappedCallback = nullptr;
        if (callback) {
            wrappedCallback = [&](const SeJob &j) {
                SeJob adjusted = j;
                adjusted.processedBytes = baseProcessed + j.processedBytes;
                adjusted.compressedBytes = baseCompressed + j.compressedBytes;
                adjusted.totalBytes = totalBytes;
                adjusted.percentage = totalBytes > 0
                    ? std::min<uint32_t>(100, static_cast<uint32_t>((static_cast<double>(adjusted.processedBytes) / static_cast<double>(totalBytes)) * 100.0))
                    : 100;
                adjusted.m_status = JobStatus::Running;
                callback(adjusted);
            };
        }

        auto _fileResult = this->doAddFileJob(job, wrappedCallback, stopToken, pauseToken);
        job.setStatus(JobStatus::Running);

        if (!_fileResult) {
            return unexpected(_fileResult.error());
        }

        cumulativeProcessed += job.processedBytes;
        cumulativeCompressed += job.compressedBytes;

        job.setStatus(JobStatus::Running);
    }

    job.SetFileName(baseArchiveDir);
    job.setStatus(JobStatus::Finished);
    job.processedBytes = totalBytes;
    job.compressedBytes = cumulativeCompressed;
    job.percentage = 100;
    if (callback)
    callback(job);

    return {};
}

expected<void, error_code>
SeArchive::doDeleteDirectoryJob(SeJob &job, ProgressCallback callback,
                                stop_token stopToken,
                                SePauseToken pauseToken) {

  job.setStatus(JobStatus::Pending);
  pauseToken.wait_if_paused(stopToken);
  if (callback)
    callback(job);

  if (stopToken.stop_requested()) {
    job.setStatus(JobStatus::Aborted);
    if (callback)
      callback(job);
    return unexpected(SeError::OperationCanceled);
  }

  if (!this->m_toc.CheckPath(job.m_fileName)) {
    job.setStatus(JobStatus::Failed);
    if (callback)
      callback(job);
    return unexpected(SeError::TocPathIsInvalid);
  }

  auto _dir = this->m_toc.GetEntry(job.m_fileName);
  if (!_dir) {
    job.setStatus(JobStatus::Failed);
    if (callback)
      callback(job);
    return unexpected(SeError::TocPathIsInvalid);
  }
  auto dir = *_dir;

  auto dirEntries = this->m_toc.GetDirectoryFileEntries(dir);

  job.setStatus(JobStatus::Running);
  if (callback)
    callback(job);

  for (size_t i = 0; i < dirEntries.size(); i++) {
    pauseToken.wait_if_paused(stopToken);
    if (stopToken.stop_requested()) {
      job.setStatus(JobStatus::Aborted);
      if (callback)
        callback(job);
      return unexpected(SeError::OperationCanceled);
    }

    auto fileEntry = dirEntries[i];

    job.percentage = static_cast<uint32_t>((i * 100) / dirEntries.size());
    if (callback)
      callback(job);

    if (fileEntry.isDirectory()) {
      SeJob jDirDel(JobType::DeleteDirectory, fileEntry.path, u"");
      auto _remove = doDeleteDirectoryJob(jDirDel, nullptr, stopToken, pauseToken);
      if (!_remove) {
        job.setStatus(_remove.error() == SeError::OperationCanceled ? JobStatus::Aborted : JobStatus::Failed);
        if (callback)
          callback(job);
        return unexpected(_remove.error());
      }
    } else {
      SeJob jFileRemove(JobType::RemoveFile, fileEntry.path, u"");
      auto _remove = doRemoveFileJob(jFileRemove, nullptr, stopToken, pauseToken);
      if (!_remove) {
        job.setStatus(_remove.error() == SeError::OperationCanceled ? JobStatus::Aborted : JobStatus::Failed);
        if (callback)
          callback(job);
        return unexpected(_remove.error());
      }
    }
  }

  this->m_toc.RemoveEntry(dir.path);
  job.percentage = 100;
  job.setStatus(JobStatus::Finished);
  if (callback)
    callback(job);
  return {};
}

expected<void, error_code> SeArchive::doMoveFileJob(SeJob &job,
                                                    ProgressCallback callback,
                                                    stop_token stopToken,
                                                    SePauseToken pauseToken) {
  job.setStatus(JobStatus::Pending);
  pauseToken.wait_if_paused(stopToken);
  if (callback)
    callback(job);

  if (stopToken.stop_requested()) {
    job.setStatus(JobStatus::Aborted);
    if (callback)
      callback(job);
    return unexpected(SeError::OperationCanceled);
  }

  auto _ent = this->m_toc.GetEntry(job.m_fileName);
  if (!_ent) {
    job.setStatus(JobStatus::Failed);
    if (callback)
      callback(job);
    return unexpected(_ent.error());
  }

  job.setStatus(JobStatus::Running);
  if (callback)
    callback(job);

  auto entry = *_ent;

  // Verifying the destination and constructing path
  auto fileName = this->m_toc.GetFileName(entry.path);

  if (!this->m_toc.CheckPath(job.m_filePath) ||
      !this->m_toc.IsDirectory(job.m_filePath)) {
    job.setStatus(JobStatus::Failed);
    if (callback)
      callback(job);
    return unexpected(SeError::TocPathIsInvalid);
  }

  auto finalPath = this->m_toc.CreateFilePath(job.m_filePath, fileName);

  u16string normOldPath = SeTableOfContent::NormalizeFilePath(job.m_fileName);
  u16string normNewPath = SeTableOfContent::NormalizeFilePath(finalPath);

  if (normOldPath != normNewPath) {
    for (auto &tocEnt : this->m_toc.m_entries) {
      if (!tocEnt.isDirectory() &&
          SeTableOfContent::NormalizeFilePath(tocEnt.path) == normOldPath) {
        tocEnt.path = normNewPath;
        break;
      }
    }
    this->m_toc.rebuildPathIndex();
    this->m_toc.m_isReady = false;
  }

  job.percentage = 100;
  job.setStatus(JobStatus::Finished);
  if (callback)
    callback(job);
  return {};
}

expected<void, error_code>
SeArchive::doMoveDirectoryJob(SeJob &job, ProgressCallback callback,
                              stop_token stopToken,
                              SePauseToken pauseToken) {

  job.setStatus(JobStatus::Pending);
  pauseToken.wait_if_paused(stopToken);
  if (callback)
    callback(job);

  if (stopToken.stop_requested()) {
    job.setStatus(JobStatus::Aborted);
    if (callback)
      callback(job);
    return unexpected(SeError::OperationCanceled);
  }

  if (!this->m_toc.CheckPath(job.m_fileName) ||
      !this->m_toc.IsDirectory(job.m_fileName) ||
      !this->m_toc.CheckPath(job.m_filePath) ||
      !this->m_toc.IsDirectory(job.m_filePath)) {
    job.setStatus(JobStatus::Failed);
    if (callback)
      callback(job);
    return unexpected(SeError::TocPathIsInvalid);
  }

  auto _ent = this->m_toc.GetEntry(job.m_fileName);
  if (!_ent) {
    job.setStatus(JobStatus::Failed);
    if (callback)
      callback(job);
    return unexpected(_ent.error());
  }
  auto entry = *_ent;

  u16string oldDirPath = SeTableOfContent::NormalizeDirectoryPath(entry.path);
  u16string dirBaseName = this->m_toc.GetFileName(oldDirPath);
  u16string newDirPath = this->m_toc.CreateDirPath(job.m_filePath, dirBaseName);

  if (newDirPath.starts_with(oldDirPath) && newDirPath != oldDirPath) {
    job.setStatus(JobStatus::Failed);
    if (callback)
      callback(job);
    return unexpected(SeError::TocPathIsInvalid);
  }

  job.setStatus(JobStatus::Running);
  if (callback)
    callback(job);

  if (newDirPath != oldDirPath) {
    for (auto &tocEnt : this->m_toc.m_entries) {
      u16string normEntryPath =
          tocEnt.isDirectory()
              ? SeTableOfContent::NormalizeDirectoryPath(tocEnt.path)
              : SeTableOfContent::NormalizeFilePath(tocEnt.path);
      if (normEntryPath == oldDirPath) {
        tocEnt.path = newDirPath;
      } else if (normEntryPath.starts_with(oldDirPath)) {
        u16string subRel = normEntryPath.substr(oldDirPath.size());
        tocEnt.path = newDirPath + subRel;
      }
    }
    this->m_toc.rebuildPathIndex();
    this->m_toc.m_isReady = false;
  }

  job.percentage = 100;
  job.setStatus(JobStatus::Finished);
  if (callback)
    callback(job);
  return {};
}

expected<void, error_code> SeArchive::doChangeCompressionLevel(SeJob &job, ProgressCallback callback, stop_token stopToken,SePauseToken pauseToken) {
    job.setStatus(JobStatus::Pending);
    pauseToken.wait_if_paused(stopToken);

    if (callback)
        callback(job);

    if (stopToken.stop_requested()) {
        job.setStatus(JobStatus::Aborted);
        if (callback)
            callback(job);
        return unexpected(SeError::OperationCanceled);
    }

    uint32_t newLevel = this->m_metadata.GetCompressionLevel();
    if (!job.m_fileName.empty() && job.m_fileName[0] >= u'1' && job.m_fileName[0] <= u'3') {
        newLevel = job.m_fileName[0] - u'0';
    }

    if (newLevel < 1 || newLevel > 3) {
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);
        return unexpected(make_error_code(errc::invalid_argument));
    }

    if (this->m_archiveFilePath.empty()) {
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);
        return unexpected(make_error_code(errc::bad_file_descriptor));
    }

    if (!this->m_archiveStream.is_open()) {
        auto _openArchive = this->m_archiveStream.open(this->m_archiveFilePath);
        if (!_openArchive && _openArchive.error() != SeError::StreamAlreadyOpen) {
            job.setStatus(JobStatus::Failed);
            if (callback)
                callback(job);
            return unexpected(_openArchive.error());
        }
    }

    if (!this->IsKeyPresent()) {
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);
        return unexpected(SeError::KeyDoesNotExist);
    }

    auto allEntries = this->m_toc.GetEntries();
    vector<SeArchiveEntry> filesToRecompress;

    for (const auto &entry : allEntries) {
        if (!entry.isDirectory()) {
            filesToRecompress.push_back(entry);
        }
    }

    if (filesToRecompress.empty()) {
        this->m_metadata.SetCompressionLevel(newLevel);
        job.setStatus(JobStatus::Finished);
        job.percentage = 100;
        if (callback)
            callback(job);
        return {};
    }

    uint64_t totalBytesAllFiles = 0;
    for (const auto &e : filesToRecompress) {
        totalBytesAllFiles += e.uncompressed_size;
    }

    uint64_t totalProcessedBytes = 0;

    job.setStatus(JobStatus::Running);
    job.totalBytes = totalBytesAllFiles;
    job.processedBytes = 0;
    job.compressedBytes = 0;
    job.percentage = 0;

    if (callback)
        callback(job);

    filesystem::path origPath(this->m_archiveFilePath);
    filesystem::path tempPath = origPath;
    tempPath += u".recomp.tmp";

    error_code ec;
    filesystem::remove(tempPath, ec);

    MappedFileStream tempStream;
    if (auto _openTemp = tempStream.open(tempPath.u16string(), FileMode::CreateAlways); !_openTemp) {
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);
        return unexpected(_openTemp.error());
    }

    bool isSuccess = false;
    auto cleanupOnFailure = [&]() {
        if (!isSuccess) {
            tempStream.close();
            error_code remEc;
            filesystem::remove(tempPath, remEc);
        }
    };

    SeMetadata tempMetadata = this->m_metadata;
    tempMetadata.SetCompressionLevel(newLevel);
    tempMetadata.m_toc_offset = 0;
    vector<unsigned char> metaBytes(SE_METADATA_SIZE);
    tempMetadata.GetMetadataBytes(metaBytes);

    if (auto _wrMeta = tempStream.write(metaBytes.data(), metaBytes.size()); !_wrMeta) { // writing metadata
        cleanupOnFailure();
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);
        return unexpected(_wrMeta.error());
    }
    tempStream.flush();

    int targetCLevel = (newLevel == 1) ? 1 : (newLevel == 2) ? 15 : 19;
    const size_t cipherChunkSize =
        AesGcmStreamSession<Mode::Decryption>::BUFFER_SIZE +
        AesGcmStreamSession<Mode::Decryption>::TAG_BYTES;

    vector<unsigned char> cipherInBuf(cipherChunkSize);
    vector<unsigned char> cryptoPlainBuf(AesGcmStreamSession<Mode::Decryption>::BUFFER_SIZE);
    vector<unsigned char> decomOutBuf(ZSTD_DStreamOutSize());
    vector<unsigned char> compOutBuf(ZSTD_CStreamOutSize());
    vector<unsigned char> cryptoCipherBuf(cipherChunkSize);

    SeTableOfContent newTOC = SeTableOfContent::CreateNewTableOfContent();
    for (const auto &entry : allEntries) {
        if (entry.isDirectory()) {
            newTOC.AddEntry(entry);
        }
    }

    for (const auto &fileEntry : filesToRecompress) {
        pauseToken.wait_if_paused(stopToken);

        if (stopToken.stop_requested()) {
            cleanupOnFailure();
            job.setStatus(JobStatus::Aborted);
            if (callback)
            callback(job);
            return unexpected(SeError::OperationCanceled);
        }

        // Seek to existing file entry offset in archive stream
        if (auto _sk = this->m_archiveStream.seek(fileEntry.offset); !_sk) {
            cleanupOnFailure();
            job.setStatus(JobStatus::Failed);
            if (callback)
                callback(job);
            return unexpected(_sk.error());
        }

        // Read header to validate against TOC
        uint32_t cCount = 0;
        if (auto _rdCount = this->m_archiveStream.read(&cCount, sizeof(cCount)); !_rdCount || *_rdCount != sizeof(cCount)) {
            cleanupOnFailure();
            job.setStatus(JobStatus::Failed);
            if (callback)
                callback(job);
            return unexpected(_rdCount ? make_error_code(errc::io_error): _rdCount.error());
        }

        size_t remainingHeaderSize = (cCount * sizeof(char16_t)) + (4 * sizeof(uint64_t)) + (2 * sizeof(uint32_t));
        vector<unsigned char> headerBytes(sizeof(cCount) + remainingHeaderSize);

        memcpy(headerBytes.data(), &cCount, sizeof(cCount));

        if (auto _rdRemaining = this->m_archiveStream.read(headerBytes.data() + sizeof(cCount), remainingHeaderSize); !_rdRemaining || *_rdRemaining != remainingHeaderSize) {
            cleanupOnFailure();
            job.setStatus(JobStatus::Failed);
            if (callback)
            callback(job);
            return unexpected(_rdRemaining ? make_error_code(errc::io_error) : _rdRemaining.error());
        }

        auto _pseudoEntry = SeArchiveEntry::CreateFromBytes(headerBytes);
        if (!_pseudoEntry) {
            cleanupOnFailure();
            job.setStatus(JobStatus::Failed);
            if (callback)
            callback(job);
            return unexpected(_pseudoEntry.error());
        }

        const auto &pseudoEntry = *_pseudoEntry;
        bool pathMatches = (pseudoEntry.path == fileEntry.path || pseudoEntry.path == SeTableOfContent::GetFileName(fileEntry.path));
        if (!pathMatches ||
            pseudoEntry.uncompressed_size != fileEntry.uncompressed_size ||
            pseudoEntry.compressed_size != fileEntry.compressed_size ||
            pseudoEntry.crc32 != fileEntry.crc32 ||
            pseudoEntry.fileUid != fileEntry.fileUid) {

            cleanupOnFailure();
            job.setStatus(JobStatus::Failed);
            if (callback)
                callback(job);
            return unexpected(SeError::ArchiveModified);
        }

        // Set up new entry in temp archive
        uint64_t newFileOffset = tempStream.size();
        SeArchiveEntry newEntry = fileEntry;
        newEntry.offset = newFileOffset;
        newEntry.compressed_size = 0;

        SeArchiveEntry fileHeaderEntry = SeArchiveEntry::CreateFileEntry(pseudoEntry.path);
        fileHeaderEntry.uncompressed_size = fileEntry.uncompressed_size;
        fileHeaderEntry.attributes = fileEntry.attributes;
        fileHeaderEntry.offset = newFileOffset;
        fileHeaderEntry.fileUid = fileEntry.fileUid;
        fileHeaderEntry.crc32 = fileEntry.crc32;
        fileHeaderEntry.compressed_size = 0;

        auto placeholderBytes = fileHeaderEntry.Serialize();
        if (auto _wrHdr = tempStream.write(placeholderBytes.data(), placeholderBytes.size()); !_wrHdr) { // BUG:
            cleanupOnFailure();
            job.setStatus(JobStatus::Failed);
            if (callback)
            callback(job);
            return unexpected(_wrHdr.error());
        }
        tempStream.flush();

        // Create crypto sessions
        auto _decryptSess = this->m_cryptoCtx.createSession<Mode::Decryption>(fileEntry.fileUid);
        if (!_decryptSess) {
            cleanupOnFailure();
            job.setStatus(JobStatus::Failed);
            if (callback)
            callback(job);
            return unexpected(_decryptSess.error());
        }
        auto decryptSess = *move(_decryptSess);

        auto _encryptSess = this->m_cryptoCtx.createSession<Mode::Encryption>(fileEntry.fileUid);
        if (!_encryptSess) {
            cleanupOnFailure();
            job.setStatus(JobStatus::Failed);
            if (callback)
            callback(job);
            return unexpected(_encryptSess.error());
        }
        auto encryptSess = *move(_encryptSess);

        ZSTD_DCtx_reset(this->m_zstdDctx.get(), ZSTD_reset_session_only);
        ZSTD_CCtx_reset(this->m_zstdCctx.get(), ZSTD_reset_session_only);
        ZSTD_CCtx_setParameter(this->m_zstdCctx.get(), ZSTD_c_compressionLevel, targetCLevel);

        uint32_t runningCrc = CRC32C_INIT;
        uint64_t fileCompressedBytes = 0;

       
        auto compressAndEncrypt = [&](span<const unsigned char> plainData, ZSTD_EndDirective mode) -> expected<void, error_code> {

            ZSTD_inBuffer inBuff = {plainData.data(), plainData.size(), 0};
            bool finished = false;
            while (!finished) {
                pauseToken.wait_if_paused(stopToken);

                if (stopToken.stop_requested()) {
                    return unexpected(SeError::OperationCanceled);
                }

                ZSTD_outBuffer outBuff = {compOutBuf.data(), compOutBuf.size(), 0};
                size_t remaining =
                    ZSTD_compressStream2(this->m_zstdCctx.get(), &outBuff, &inBuff, mode);
                if (ZSTD_isError(remaining)) {
                    return unexpected(SeError::ZSTDCompressionError);
                }

                if (outBuff.pos > 0) {
                    auto _encRes = encryptSess->encrypt(
                        span<unsigned char>{
                            reinterpret_cast<unsigned char *>(outBuff.dst), outBuff.pos},
                        cryptoCipherBuf);
                    if (_encRes) {
                    fileCompressedBytes += cipherChunkSize;
                    auto _wr = tempStream.write(cryptoCipherBuf.data(), cipherChunkSize);
                    if (!_wr)
                        return unexpected(_wr.error());
                    } else if (_encRes.error() != SeError::CRYPTOStageTooSmall) {
                    return unexpected(_encRes.error());
                    }
                }

                if (mode == ZSTD_e_end) {
                    finished = (remaining == 0);
                } else {
                    finished = (inBuff.pos == inBuff.size);
                }
            }
            return {};
        };

        auto decompressAndRecompress = [&](span<const unsigned char> cipherPlain) -> expected<void, error_code> {
            pauseToken.wait_if_paused(stopToken);

            ZSTD_inBuffer decomIn = {cipherPlain.data(), cipherPlain.size(), 0};
            while (decomIn.pos < decomIn.size) {
                if (stopToken.stop_requested()) {
                    return unexpected(SeError::OperationCanceled);
                }

                ZSTD_outBuffer decomOut = {decomOutBuf.data(), decomOutBuf.size(), 0};
                size_t rem = ZSTD_decompressStream(this->m_zstdDctx.get(), &decomOut, &decomIn);
                if (ZSTD_isError(rem)) {
                    return unexpected(SeError::ZSTDCompressionError);
                }

                if (decomOut.pos > 0) {
                    runningCrc = crc32c_update(runningCrc, decomOut.dst, decomOut.pos);
                    totalProcessedBytes += decomOut.pos;

                    job.processedBytes = totalProcessedBytes;
                    job.compressedBytes = fileCompressedBytes;
                    job.percentage =
                        totalBytesAllFiles == 0
                            ? 100
                            : static_cast<uint32_t>((totalProcessedBytes * 100) /
                                                    totalBytesAllFiles);
                    if (callback)
                        callback(job);

                    auto _ceErr = compressAndEncrypt(
                        span<const unsigned char>{
                            reinterpret_cast<const unsigned char *>(decomOut.dst),
                            decomOut.pos},
                        ZSTD_e_continue);
                    if (!_ceErr)
                    return unexpected(_ceErr.error());
                }
            }
            return {};
        };

        // Read and stream ciphertext from archiveStream
        uint64_t remainingCipher = fileEntry.compressed_size;

        while (remainingCipher > 0) {
            pauseToken.wait_if_paused(stopToken);

            if (stopToken.stop_requested()) {
                cleanupOnFailure();
                job.setStatus(JobStatus::Aborted);
                if (callback)
                    callback(job);
                return unexpected(SeError::OperationCanceled);
            }

            size_t toRead = std::min(static_cast<uint64_t>(cipherChunkSize), remainingCipher);
            auto _rd = this->m_archiveStream.read(cipherInBuf.data(), toRead);
            if (!_rd) {
                cleanupOnFailure();
                job.setStatus(JobStatus::Failed);
                if (callback)
                    callback(job);
                return unexpected(_rd.error());
            }
            if (*_rd == 0)
                break;

            remainingCipher -= *_rd;

            auto _decResult = decryptSess->decrypt(
                span<unsigned char>{cipherInBuf.data(), *_rd}, cryptoPlainBuf);
            if (_decResult) {
                auto _procErr = decompressAndRecompress(span<const unsigned char>{cryptoPlainBuf.data(),
                    AesGcmStreamSession<Mode::Decryption>::BUFFER_SIZE});

                if (!_procErr) {
                    cleanupOnFailure();
                    job.setStatus(JobStatus::Failed);
                    if (callback)
                    callback(job);
                    return unexpected(_procErr.error());
                }
            }
            else if (_decResult.error() != SeError::CRYPTOStageTooSmall) {
                cleanupOnFailure();
                job.setStatus(JobStatus::Failed);
                if (callback)
                    callback(job);
                return unexpected(_decResult.error());
            }
        }

        auto _finDec = decryptSess->finalizeDecryption(cryptoPlainBuf);
        if (!_finDec) {
            cleanupOnFailure();
            job.setStatus(JobStatus::Failed);
            if (callback)
            callback(job);
            return unexpected(_finDec.error());
        }

        size_t finalPlainBytes = *_finDec;
        if (finalPlainBytes > 0) {
            auto _procErr = decompressAndRecompress(
                span<const unsigned char>{cryptoPlainBuf.data(), finalPlainBytes});
            if (!_procErr) {
                cleanupOnFailure();
                job.setStatus(JobStatus::Failed);
                if (callback)
                    callback(job);
                return unexpected(_procErr.error());
            }
        }

        // Flush any residual decompressed bytes from ZSTD decompressor
        while (true) {
            ZSTD_inBuffer emptyIn = {nullptr, 0, 0};
            ZSTD_outBuffer decomOut = {decomOutBuf.data(), decomOutBuf.size(), 0};
            size_t rem = ZSTD_decompressStream(this->m_zstdDctx.get(), &decomOut, &emptyIn);
            if (ZSTD_isError(rem)) {
                break;
            }
            if (decomOut.pos > 0) {
                runningCrc = crc32c_update(runningCrc, decomOut.dst, decomOut.pos);
                totalProcessedBytes += decomOut.pos;

                job.processedBytes = totalProcessedBytes;
                job.compressedBytes = fileCompressedBytes;
                job.percentage =
                    totalBytesAllFiles == 0
                        ? 100
                        : static_cast<uint32_t>((totalProcessedBytes * 100) /
                                                totalBytesAllFiles);
                if (callback)
                    callback(job);

                auto _ceErr = compressAndEncrypt(
                    span<const unsigned char>{
                        reinterpret_cast<const unsigned char *>(decomOut.dst),
                        decomOut.pos},
                    ZSTD_e_continue);
                if (!_ceErr) {
                    cleanupOnFailure();
                    job.setStatus(JobStatus::Failed);
                    if (callback)
                    callback(job);
                    return unexpected(_ceErr.error());
                }
            }
            if (decomOut.pos < decomOutBuf.size() || rem == 0) {
                break;
            }
        }

        // Finish compression
        auto _endComp = compressAndEncrypt({}, ZSTD_e_end);
        if (!_endComp) {
            cleanupOnFailure();
            job.setStatus(JobStatus::Failed);
            if (callback)
            callback(job);
            return unexpected(_endComp.error());
        }

        // Finalize encryption
        auto _finEnc = encryptSess->finalizeEncryption(cryptoCipherBuf);
        if (!_finEnc) {
            cleanupOnFailure();
            job.setStatus(JobStatus::Failed);
            if (callback)
            callback(job);
            return unexpected(_finEnc.error());
        }

        size_t finalCipherBytes = *_finEnc;
        if (finalCipherBytes > 0) {
            fileCompressedBytes += finalCipherBytes;
            auto _wr = tempStream.write(cryptoCipherBuf.data(), finalCipherBytes);
            if (!_wr) {
                cleanupOnFailure();
                job.setStatus(JobStatus::Failed);
                if (callback)
                    callback(job);
                return unexpected(_wr.error());
            }
        }

        // Verify CRC32
        uint32_t finalCrc = crc32c_finalize(runningCrc);
        if (finalCrc != fileEntry.crc32) {
            cleanupOnFailure();
            job.setStatus(JobStatus::Failed);
            if (callback)
            callback(job);
            return unexpected(SeError::CrcChecksumFailed);
        }

        // Overwrite header placeholder in temp archive
        fileHeaderEntry.compressed_size = fileCompressedBytes;
        fileHeaderEntry.crc32 = finalCrc;
        auto realHeaderBytes = fileHeaderEntry.Serialize();

        if (auto _skHdr = tempStream.seek(newFileOffset); !_skHdr) {
            cleanupOnFailure();
            job.setStatus(JobStatus::Failed);
            if (callback)
            callback(job);
            return unexpected(_skHdr.error());
        }

        if (auto _wrHdr = tempStream.write(realHeaderBytes.data(), realHeaderBytes.size()); !_wrHdr) {
            cleanupOnFailure();
            job.setStatus(JobStatus::Failed);
            if (callback)
            callback(job);
            return unexpected(_wrHdr.error());
        }

        // Restore tempStream write position to end of file
        if (auto _skEnd = tempStream.seek(tempStream.size()); !_skEnd) {
            cleanupOnFailure();
            job.setStatus(JobStatus::Failed);
            if (callback)
            callback(job);
            return unexpected(_skEnd.error());
        }
        tempStream.flush();

        newEntry.compressed_size = fileCompressedBytes;
        newEntry.crc32 = finalCrc;
        newTOC.AddEntry(newEntry);
    }

    // Write TOC and Metadata to tempStream
    size_t newTocOffset = tempStream.size();
    auto _ser = newTOC.Serialize();
    if (!_ser) {
        cleanupOnFailure();
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);
        return unexpected(_ser.error());
    }

    auto tocBytes = newTOC.GetTOCBytes();
    if (auto _wrToc = tempStream.write(tocBytes.data(), tocBytes.size()); !_wrToc) {
        cleanupOnFailure();
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);
        return unexpected(_wrToc.error());
    }

    tempMetadata.m_toc_offset = newTocOffset;
    tempMetadata.GetMetadataBytes(metaBytes);

    if (auto _skMeta = tempStream.seek(0); !_skMeta) {
        cleanupOnFailure();
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);
        return unexpected(_skMeta.error());
    }

    if (auto _wrMeta = tempStream.write(metaBytes.data(), metaBytes.size());!_wrMeta) {
        cleanupOnFailure();
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);
        return unexpected(_wrMeta.error());
    }

    tempStream.flush();

    // Close both streams and perform atomic swap
    tempStream.close();
    this->m_archiveStream.close();

    filesystem::path backupPath = origPath;
    backupPath += u".bak";
    error_code renEc;
    filesystem::remove(backupPath, renEc);

    filesystem::rename(origPath, backupPath, renEc);
    if (renEc) {
        filesystem::copy_file(tempPath, origPath, filesystem::copy_options::overwrite_existing, renEc);
        if (renEc) {
            cleanupOnFailure();
            this->m_archiveStream.open(this->m_archiveFilePath);
            job.setStatus(JobStatus::Failed);
            if (callback)
            callback(job);
            return unexpected(renEc);
        }
    }
    else {
        filesystem::rename(tempPath, origPath, renEc);
        if (renEc) {
            error_code revEc;
            filesystem::rename(backupPath, origPath, revEc);
            cleanupOnFailure();
            (void)this->m_archiveStream.open(this->m_archiveFilePath);
            job.setStatus(JobStatus::Failed);
            if (callback)
            callback(job);
            return unexpected(renEc);
        }
        filesystem::remove(backupPath, renEc);
    }

    filesystem::remove(tempPath, renEc);
    isSuccess = true;

    auto _reopen = this->m_archiveStream.open(this->m_archiveFilePath);
    if (!_reopen) {
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);
        return unexpected(_reopen.error());
    }

    this->m_metadata = tempMetadata;
    this->m_toc = newTOC;
    this->m_isReady = true;

    job.setStatus(JobStatus::Finished);
    job.processedBytes = totalBytesAllFiles;
    job.compressedBytes = totalBytesAllFiles;
    job.percentage = 100;
    if (callback)
        callback(job);

    return {};
}

expected<void, error_code> SeArchive::doTestFile(SeJob &job,
                                                 ProgressCallback callback,
                                                 stop_token stopToken,
                                                 SePauseToken pauseToken) {
  job.setStatus(JobStatus::Pending);
  pauseToken.wait_if_paused(stopToken);
  if (callback)
    callback(job);

  if (stopToken.stop_requested()) {
    job.setStatus(JobStatus::Aborted);
    if (callback)
      callback(job);
    return unexpected(SeError::OperationCanceled);
  }

  auto _entry = this->m_toc.GetEntry(job.m_fileName);
  if (!_entry) {
    job.setStatus(JobStatus::Failed);
    if (callback)
      callback(job);
    return unexpected(_entry.error());
  }
  auto entry = *_entry;

  if (entry.isDirectory()) {
    job.setStatus(JobStatus::Finished);
    if (callback)
      callback(job);
    return {};
  }

  // Ensure archive stream is open
  if (!this->m_archiveStream.is_open()) {
    auto _openArchive = this->m_archiveStream.open(this->m_archiveFilePath);
    if (!_openArchive && _openArchive.error() != SeError::StreamAlreadyOpen) {
      job.setStatus(JobStatus::Failed);
      if (callback)
        callback(job);
      return unexpected(_openArchive.error());
    }
  }

  // Seek to the TOC entry file offset
  if (auto _sk = this->m_archiveStream.seek(entry.offset); !_sk) {
    job.setStatus(JobStatus::Failed);
    if (callback)
      callback(job);
    return unexpected(_sk.error());
  }

  // Read entry header from archive stream and construct a pseudo entry to
  // validate against TOC
  uint32_t cCount = 0;
  if (auto _rdCount = this->m_archiveStream.read(&cCount, sizeof(cCount));
      !_rdCount || *_rdCount != sizeof(cCount)) {
    job.setStatus(JobStatus::Failed);
    if (callback)
      callback(job);
    return unexpected(_rdCount ? make_error_code(errc::io_error)
                               : _rdCount.error());
  }

  size_t remainingHeaderSize = (cCount * sizeof(char16_t)) +
                               (4 * sizeof(uint64_t)) + (2 * sizeof(uint32_t));
  vector<unsigned char> headerBytes(sizeof(cCount) + remainingHeaderSize);
  memcpy(headerBytes.data(), &cCount, sizeof(cCount));

  if (auto _rdRemaining = this->m_archiveStream.read(
          headerBytes.data() + sizeof(cCount), remainingHeaderSize);
      !_rdRemaining || *_rdRemaining != remainingHeaderSize) {
    job.setStatus(JobStatus::Failed);
    if (callback)
      callback(job);
    return unexpected(_rdRemaining ? make_error_code(errc::io_error)
                                   : _rdRemaining.error());
  }

  auto _pseudoEntry = SeArchiveEntry::CreateFromBytes(headerBytes);
  if (!_pseudoEntry) {
    job.setStatus(JobStatus::Failed);
    if (callback)
      callback(job);
    return unexpected(_pseudoEntry.error());
  }

  const auto &pseudoEntry = *_pseudoEntry;

  // Check pseudo entry against TOC entry (every field except offset)
  bool pathMatches =
      (pseudoEntry.path == entry.path ||
       pseudoEntry.path == SeTableOfContent::GetFileName(entry.path));
  if (!pathMatches ||
      pseudoEntry.uncompressed_size != entry.uncompressed_size ||
      pseudoEntry.compressed_size != entry.compressed_size ||
      pseudoEntry.attributes != entry.attributes ||
      pseudoEntry.crc32 != entry.crc32 ||
      pseudoEntry.fileUid != entry.fileUid) {
    job.setStatus(JobStatus::Failed);
    if (callback)
      callback(job);
    return unexpected(SeError::ArchiveModified);
  }

  // Initiating the crypto session
  auto _cryptoSess =
      this->m_cryptoCtx.createSession<Mode::Decryption>(entry.fileUid);
  if (!_cryptoSess) {
    job.setStatus(JobStatus::Failed);
    if (callback)
      callback(job);
    return unexpected(_cryptoSess.error());
  }

  auto cryptoSess = *move(_cryptoSess);

  const size_t cipherChunkSize =
      AesGcmStreamSession<Mode::Decryption>::BUFFER_SIZE +
      AesGcmStreamSession<Mode::Decryption>::TAG_BYTES;
  vector<unsigned char> cipherBuffer(cipherChunkSize);
  vector<unsigned char> cryptoOutBuffer(
      AesGcmStreamSession<Mode::Decryption>::BUFFER_SIZE);

  const size_t outBufSize = ZSTD_DStreamOutSize();
  vector<unsigned char> decomOutBuff(outBufSize);

  ZSTD_DCtx_reset(this->m_zstdDctx.get(), ZSTD_reset_session_only);

  job.setStatus(JobStatus::Running);
  job.totalBytes = entry.uncompressed_size;
  job.processedBytes = 0;
  job.compressedBytes = 0;
  job.percentage = 0;
  if (callback)
    callback(job);

  uint64_t calculatedUncompressedSize = 0;
  uint64_t totalReadCipherBytes = 0;
  uint32_t currentCrc = CRC32C_INIT;

  auto decompressAndProcess =
      [&](span<const unsigned char> plain) -> expected<void, error_code> {
    ZSTD_inBuffer inBuff = {plain.data(), plain.size(), 0};
    while (inBuff.pos < inBuff.size) {
      pauseToken.wait_if_paused(stopToken);
      if (stopToken.stop_requested()) {
        job.setStatus(JobStatus::Aborted);
        if (callback)
          callback(job);
        return unexpected(SeError::OperationCanceled);
      }

      ZSTD_outBuffer outBuff = {decomOutBuff.data(), decomOutBuff.size(), 0};
      size_t remaining =
          ZSTD_decompressStream(this->m_zstdDctx.get(), &outBuff, &inBuff);
      if (ZSTD_isError(remaining)) {
        job.setStatus(JobStatus::Failed);
        if (callback)
          callback(job);
        return unexpected(SeError::ZSTDCompressionError);
      }

      if (outBuff.pos > 0) {
        calculatedUncompressedSize += outBuff.pos;
        currentCrc = crc32c_update(currentCrc, outBuff.dst, outBuff.pos);

        job.processedBytes = calculatedUncompressedSize;
        job.compressedBytes = totalReadCipherBytes;
        job.percentage =
            entry.uncompressed_size == 0
                ? 100
                : static_cast<uint32_t>((calculatedUncompressedSize * 100) /
                                        entry.uncompressed_size);
        if (callback)
          callback(job);
      }
    }
    return {};
  };

  uint64_t remainingCipher = entry.compressed_size;
  while (remainingCipher > 0) {
    pauseToken.wait_if_paused(stopToken);
    if (stopToken.stop_requested()) {
      job.setStatus(JobStatus::Aborted);
      if (callback)
        callback(job);
      return unexpected(SeError::OperationCanceled);
    }

    size_t toRead =
        std::min(static_cast<uint64_t>(cipherChunkSize), remainingCipher);
    auto _rd = this->m_archiveStream.read(cipherBuffer.data(), toRead);
    if (!_rd) {
      job.setStatus(JobStatus::Failed);
      if (callback)
        callback(job);
      return unexpected(_rd.error());
    }

    if (*_rd == 0) {
      break;
    }

    totalReadCipherBytes += *_rd;
    remainingCipher -= *_rd;

    auto _cryptoResult = cryptoSess->decrypt(
        span<unsigned char>{cipherBuffer.data(), *_rd}, cryptoOutBuffer);

    if (_cryptoResult) {
      auto _decErr = decompressAndProcess(span<const unsigned char>{
          cryptoOutBuffer.data(),
          AesGcmStreamSession<Mode::Decryption>::BUFFER_SIZE});
      if (!_decErr) {
        return unexpected(_decErr.error());
      }
    } else if (_cryptoResult.error() != SeError::CRYPTOStageTooSmall) {
      job.setStatus(JobStatus::Failed);
      if (callback)
        callback(job);
      return unexpected(_cryptoResult.error());
    }
  }

  // Finalize crypto session to flush any remaining staged plaintext
  auto _finalCrypto = cryptoSess->finalizeDecryption(cryptoOutBuffer);
  if (!_finalCrypto) {
    job.setStatus(JobStatus::Failed);
    if (callback)
      callback(job);
    return unexpected(_finalCrypto.error());
  }

  size_t finalPlainBytes = *_finalCrypto;
  if (finalPlainBytes > 0) {
    auto _decErr = decompressAndProcess(
        span<const unsigned char>{cryptoOutBuffer.data(), finalPlainBytes});
    if (!_decErr) {
      return unexpected(_decErr.error());
    }
  }

  // Flush any residual decompressed bytes from the ZSTD stream
  while (true) {
    ZSTD_inBuffer emptyIn = {nullptr, 0, 0};
    ZSTD_outBuffer outBuff = {decomOutBuff.data(), decomOutBuff.size(), 0};
    size_t remaining =
        ZSTD_decompressStream(this->m_zstdDctx.get(), &outBuff, &emptyIn);
    if (ZSTD_isError(remaining)) {
      break;
    }
    if (outBuff.pos > 0) {
      calculatedUncompressedSize += outBuff.pos;
      currentCrc = crc32c_update(currentCrc, outBuff.dst, outBuff.pos);
    }
    if (outBuff.pos < decomOutBuff.size() || remaining == 0) {
      break;
    }
  }

  ZSTD_DCtx_reset(this->m_zstdDctx.get(), ZSTD_reset_session_only);

  currentCrc = crc32c_finalize(currentCrc);

  // Verify CRC and uncompressed size against TOC entry
  if (currentCrc != entry.crc32 ||
      calculatedUncompressedSize != entry.uncompressed_size) {
    job.setStatus(JobStatus::Failed);
    if (callback)
      callback(job);
    return unexpected(SeError::CrcChecksumFailed);
  }

  job.setStatus(JobStatus::Finished);
  job.processedBytes = calculatedUncompressedSize;
  job.compressedBytes = entry.compressed_size;
  job.percentage = 100;
  if (callback)
    callback(job);

  return {};
}

expected<bool, error_code>
SeArchive::TestFileSync(u16string fileName, ProgressCallback callback,
                        stop_token stopToken, SePauseToken pauseToken) {
  SeJob job(JobType::TestFile, fileName, u"");
  auto res = this->doTestFile(job, callback, stopToken, pauseToken);
  if (!res) {
    return unexpected(res.error());
  }
  return true;
}

SeTaskHandle<bool>
SeArchive::TestFileAsync(u16string fileName, ProgressCallback callback) {
  auto promise = std::make_shared<std::promise<expected<bool, error_code>>>();
  auto future = promise->get_future().share();
  auto pauseState = std::make_shared<SePauseState>();
  SePauseToken pauseToken(pauseState);

  std::jthread worker([this, fileName = std::move(fileName),
                       callback = std::move(callback),
                       promise, pauseToken](std::stop_token stopToken) {
    try {
      auto res = this->TestFileSync(fileName, callback, stopToken, pauseToken);
      promise->set_value(res);
    } catch (...) {
      promise->set_exception(std::current_exception());
    }
  });

  return SeTaskHandle<bool>(std::move(worker), std::move(future), std::move(pauseState));
}

expected<size_t, error_code> SeArchive::ExtractFileSync(u16string fileName, 
                                                        u16string outputPath, ProgressCallback callback, stop_token stopToken,
                                                        SePauseToken pauseToken) {
  // Only directory output path are allowed
  // Job handling is internal to this function no registration required
    SeJob job(JobType::ExtractFile, fileName, outputPath);
    job.setStatus(JobStatus::Pending);
    if (callback)
        callback(job);
    if (!SeTableOfContent::verifyAbsPath(outputPath) || !SeTableOfContent::isAbsPathDir(outputPath)) {
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);
        return unexpected(SeError::ExpectedDirectory);
    }

    if (pauseToken.wait_if_paused(stopToken,
            [&]() {
                job.setStatus(JobStatus::Paused);
                if (callback) callback(job);
            },
            [&]() {
                job.setStatus(JobStatus::Running);
                if (callback) callback(job);
            })) {
        job.setStatus(JobStatus::Aborted);
        if (callback)
            callback(job);
        return unexpected(SeError::OperationCanceled);
    }

    if (stopToken.stop_requested()) {
        job.setStatus(JobStatus::Aborted);
        if (callback)
            callback(job);
        return unexpected(SeError::OperationCanceled);
    }

    auto _entry = this->m_toc.GetEntry(fileName);
    if (!_entry) {
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);
        return unexpected(_entry.error());
    }
    auto entry = *_entry;
    auto path = SeTableOfContent::mergePath(outputPath, SeTableOfContent::GetFileName(fileName));

    MappedFileStream outFs;
    if (auto _openErr = outFs.open(path, FileMode::CreateAlways); !_openErr) {
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);
        return unexpected(_openErr.error());
    }

    // Initiating the crypto session
    auto _cryptoSess = this->m_cryptoCtx.createSession<Mode::Decryption>(entry.fileUid);
    if (!_cryptoSess) {
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);
        return unexpected(_cryptoSess.error());
    }

    auto cryptoSess = *move(_cryptoSess);

    const size_t outBufSize = ZSTD_DStreamOutSize();
    vector<unsigned char> decomOutBuff(outBufSize);

    // Ensure archive stream is open
    if (!this->m_archiveStream.is_open()) {
        auto _openArchive = this->m_archiveStream.open(this->m_archiveFilePath);
        if (!_openArchive && _openArchive.error() != SeError::StreamAlreadyOpen) {
            job.setStatus(JobStatus::Failed);
            if (callback)
                callback(job);
            return unexpected(_openArchive.error());
        }
    }

    // Seek to the TOC entry file offset
    if (auto _sk = this->m_archiveStream.seek(entry.offset); !_sk) {
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);
        return unexpected(_sk.error());
    }

    // Read entry header from archive stream and construct a pseudo entry to
    // validate against TOC
    uint32_t cCount = 0;
    if (auto _rdCount = this->m_archiveStream.read(&cCount, sizeof(cCount)); !_rdCount || *_rdCount != sizeof(cCount)) {
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);
        return unexpected(_rdCount ? make_error_code(errc::io_error)
                                    : _rdCount.error());
    }

    size_t remainingHeaderSize = (cCount * sizeof(char16_t)) + (4 * sizeof(uint64_t)) + (2 * sizeof(uint32_t));
    vector<unsigned char> headerBytes(sizeof(cCount) + remainingHeaderSize);
    memcpy(headerBytes.data(), &cCount, sizeof(cCount));

    if (auto _rdRemaining = this->m_archiveStream.read(headerBytes.data() + sizeof(cCount), remainingHeaderSize);
                                                        !_rdRemaining || *_rdRemaining != remainingHeaderSize) 
    {
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);
        return unexpected(_rdRemaining ? make_error_code(errc::io_error)
                                        : _rdRemaining.error());
    }

    auto _pseudoEntry = SeArchiveEntry::CreateFromBytes(headerBytes);
    if (!_pseudoEntry) {
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);
        return unexpected(_pseudoEntry.error());
    }

    const auto &pseudoEntry = *_pseudoEntry;

    // Check pseudo entry against TOC entry (every field except offset)
    bool pathMatches =
        (pseudoEntry.path == entry.path ||
        pseudoEntry.path == SeTableOfContent::GetFileName(entry.path));
    if (!pathMatches ||
        pseudoEntry.uncompressed_size != entry.uncompressed_size ||
        pseudoEntry.compressed_size != entry.compressed_size ||
        pseudoEntry.attributes != entry.attributes ||
        pseudoEntry.crc32 != entry.crc32 ||
        pseudoEntry.fileUid != entry.fileUid) {
    job.setStatus(JobStatus::Failed);
    if (callback)
        callback(job);
    return unexpected(SeError::ArchiveModified);
    }

    // Stream is now positioned right at the beginning of the encrypted file
    // payload
    const size_t cipherChunkSize =
        AesGcmStreamSession<Mode::Decryption>::BUFFER_SIZE +
        AesGcmStreamSession<Mode::Decryption>::TAG_BYTES;
    vector<unsigned char> cipherBuffer(cipherChunkSize);
    vector<unsigned char> cryptoOutBuffer(
        AesGcmStreamSession<Mode::Decryption>::BUFFER_SIZE);

    ZSTD_DCtx_reset(this->m_zstdDctx.get(), ZSTD_reset_session_only);

    job.setStatus(JobStatus::Running);
    job.totalBytes = entry.uncompressed_size;
    job.processedBytes = 0;
    job.compressedBytes = 0;
    job.percentage = 0;
    if (callback)
    callback(job);

    uint64_t totalExtractedBytes = 0;
    uint64_t totalReadCipherBytes = 0;
    uint32_t currentCrc = CRC32C_INIT;

    auto decompressAndWrite =
        [&](span<const unsigned char> plain) -> expected<void, error_code> {
    ZSTD_inBuffer inBuff = {plain.data(), plain.size(), 0};
    while (inBuff.pos < inBuff.size) {
        if (pauseToken.wait_if_paused(stopToken,
                [&]() {
                job.setStatus(JobStatus::Paused);
                if (callback) callback(job);
                },
                [&]() {
                job.setStatus(JobStatus::Running);
                if (callback) callback(job);
                })) {
        outFs.abort();
        job.setStatus(JobStatus::Aborted);
        if (callback)
            callback(job);
        return unexpected(SeError::OperationCanceled);
        }

        if (stopToken.stop_requested()) {
        outFs.abort();
        job.setStatus(JobStatus::Aborted);
        if (callback)
            callback(job);
        return unexpected(SeError::OperationCanceled);
        }

        ZSTD_outBuffer outBuff = {decomOutBuff.data(), decomOutBuff.size(), 0};
        size_t remaining =
            ZSTD_decompressStream(this->m_zstdDctx.get(), &outBuff, &inBuff);
        if (ZSTD_isError(remaining)) {
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);
        return unexpected(SeError::ZSTDCompressionError);
        }

        if (outBuff.pos > 0) {
        auto _wr = outFs.write(outBuff.dst, outBuff.pos);
        if (!_wr) {
            job.setStatus(JobStatus::Failed);
            if (callback)
            callback(job);
            return unexpected(_wr.error());
        }

        totalExtractedBytes += outBuff.pos;
        currentCrc = crc32c_update(currentCrc, outBuff.dst, outBuff.pos);

        job.processedBytes = totalExtractedBytes;
        job.compressedBytes = totalReadCipherBytes;
        job.percentage =
            entry.uncompressed_size == 0
                ? 100
                : static_cast<uint32_t>((totalExtractedBytes * 100) /
                                        entry.uncompressed_size);
        if (callback)
            callback(job);
        }
    }
    return {};
    };

    uint64_t remainingCipher = entry.compressed_size;
    while (remainingCipher > 0) {
    if (pauseToken.wait_if_paused(stopToken,
            [&]() {
                job.setStatus(JobStatus::Paused);
                if (callback) callback(job);
            },
            [&]() {
                job.setStatus(JobStatus::Running);
                if (callback) callback(job);
            })) {
        outFs.abort();
        job.setStatus(JobStatus::Aborted);
        if (callback)
        callback(job);
        return unexpected(SeError::OperationCanceled);
    }

    if (stopToken.stop_requested()) {
        outFs.abort();
        job.setStatus(JobStatus::Aborted);
        if (callback)
        callback(job);
        return unexpected(SeError::OperationCanceled);
    }

    size_t toRead =
        std::min(static_cast<uint64_t>(cipherChunkSize), remainingCipher);
    auto _rd = this->m_archiveStream.read(cipherBuffer.data(), toRead);
    if (!_rd) {
        job.setStatus(JobStatus::Failed);
        if (callback)
        callback(job);
        return unexpected(_rd.error());
    }

    if (*_rd == 0) {
        break;
    }

    totalReadCipherBytes += *_rd;
    remainingCipher -= *_rd;

    auto _cryptoResult = cryptoSess->decrypt(
        span<unsigned char>{cipherBuffer.data(), *_rd}, cryptoOutBuffer);

    if (_cryptoResult) {
        auto _decErr = decompressAndWrite(span<const unsigned char>{
            cryptoOutBuffer.data(),
            AesGcmStreamSession<Mode::Decryption>::BUFFER_SIZE});
        if (!_decErr) {
        return unexpected(_decErr.error());
        }
    } else if (_cryptoResult.error() != SeError::CRYPTOStageTooSmall) {
        job.setStatus(JobStatus::Failed);
        if (callback)
        callback(job);
        return unexpected(_cryptoResult.error());
    }
    }

    // Finalize crypto session to flush any remaining staged plaintext
    auto _finalCrypto = cryptoSess->finalizeDecryption(cryptoOutBuffer);
    if (!_finalCrypto) {
    job.setStatus(JobStatus::Failed);
    if (callback)
        callback(job);
    return unexpected(_finalCrypto.error());
    }

    size_t finalPlainBytes = *_finalCrypto;
    if (finalPlainBytes > 0) {
    auto _decErr = decompressAndWrite(
        span<const unsigned char>{cryptoOutBuffer.data(), finalPlainBytes});
    if (!_decErr) {
        return unexpected(_decErr.error());
    }
    }

    // Flush any residual decompressed bytes from the ZSTD stream
    while (true) {
    ZSTD_inBuffer emptyIn = {nullptr, 0, 0};
    ZSTD_outBuffer outBuff = {decomOutBuff.data(), decomOutBuff.size(), 0};
    size_t remaining =
        ZSTD_decompressStream(this->m_zstdDctx.get(), &outBuff, &emptyIn);
    if (ZSTD_isError(remaining)) {
        break;
    }
    if (outBuff.pos > 0) {
        auto _wr = outFs.write(outBuff.dst, outBuff.pos);
        if (!_wr) {
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);
        return unexpected(_wr.error());
        }
        totalExtractedBytes += outBuff.pos;
        currentCrc = crc32c_update(currentCrc, outBuff.dst, outBuff.pos);
    }
    if (outBuff.pos < decomOutBuff.size() || remaining == 0) {
        break;
    }
    }

    // Finalize compression and output stream
    ZSTD_DCtx_reset(this->m_zstdDctx.get(), ZSTD_reset_session_only);
    (void)outFs.flush();

    currentCrc = crc32c_finalize(currentCrc);

    job.setStatus(JobStatus::Finished);
    job.processedBytes = totalExtractedBytes;
    job.compressedBytes = entry.compressed_size;
    job.percentage = 100;
    if (callback)
    callback(job);

    return totalExtractedBytes;
    }

    SeTaskHandle<size_t>
    SeArchive::ExtractFileAsync(u16string fileName, u16string outputPath,
                            ProgressCallback callback) {
    auto pauseState = std::make_shared<SePauseState>();
    SePauseToken pauseToken(pauseState);
    auto promise = std::make_shared<std::promise<expected<size_t, error_code>>>();
    auto future = promise->get_future().share();

    std::jthread worker([this, fileName = std::move(fileName),
                        outputPath = std::move(outputPath),
                        callback = std::move(callback),
                        pauseToken,
                        promise](std::stop_token stopToken) {
    try {
        auto res =
            this->ExtractFileSync(fileName, outputPath, callback, stopToken, pauseToken);
        promise->set_value(res);
    } catch (...) {
        promise->set_exception(std::current_exception());
    }
    });

    return SeTaskHandle<size_t>(std::move(worker), std::move(future), std::move(pauseState));
}

expected<size_t, error_code> SeArchive::ExtractDirectorySync(u16string fileName, u16string outputPath, ProgressCallback callback, stop_token stopToken, SePauseToken pauseToken) {
    
    u16string normDir = SeTableOfContent::NormalizeDirectoryPath(fileName);
    SeJob job(JobType::ExtractDirectory, normDir, outputPath);
    job.setStatus(JobStatus::Pending);

    if (callback)
        callback(job);

    if (!SeTableOfContent::verifyAbsPath(outputPath) || !SeTableOfContent::isAbsPathDir(outputPath)) {
        job.setStatus(JobStatus::Failed);

        if (callback)
            callback(job);
        return unexpected(SeError::ExpectedDirectory);
    }

    if (pauseToken.wait_if_paused(stopToken, [&]() {
                job.setStatus(JobStatus::Paused);
                if (callback) callback(job);
            },
            [&]() {
                job.setStatus(JobStatus::Running);
                if (callback) callback(job);
            }))
    {
        job.setStatus(JobStatus::Aborted);
        if (callback)
            callback(job);
        return unexpected(SeError::OperationCanceled);
    }

    if (stopToken.stop_requested()) {
        job.setStatus(JobStatus::Aborted);
        if (callback)
            callback(job);
        return unexpected(SeError::OperationCanceled);
    }

    if (normDir != u"/") {
        if (!this->m_toc.CheckPath(normDir) || !this->m_toc.IsDirectory(normDir)) {
            job.setStatus(JobStatus::Failed);
            if (callback)
            callback(job);
            return unexpected(SeError::TocPathIsInvalid);
        }
    }

    filesystem::path baseExtractDir(outputPath);
    if (normDir != u"/") {
        u16string dirName = SeTableOfContent::GetFileName(normDir);
        filesystem::path outLeaf = baseExtractDir.filename();
        if (outLeaf.empty()) {
            outLeaf = baseExtractDir.parent_path().filename();
        }
        if (outLeaf.u16string() != dirName) {
            baseExtractDir /= filesystem::path(dirName);
        }
    }

    error_code ec;
    filesystem::create_directories(baseExtractDir, ec);
    if (ec) {
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);
        return unexpected(ec);
    }

    // Separate directory entries and file entries belonging to this folder
    vector<SeArchiveEntry> dirsToExtract;
    vector<SeArchiveEntry> filesToExtract;
    size_t prefixLen = (normDir == u"/") ? 1 : normDir.size();

    if (normDir == u"/") {
        for (const auto &entry : this->m_toc.GetEntries()) { // Full archive extraction
            if (entry.path == u"/")
                continue;
            if (entry.isDirectory()) {
                dirsToExtract.push_back(entry);
            } else {
                filesToExtract.push_back(entry);
            }
        }
    } 
    else {
        auto _dirEnt = this->m_toc.GetEntry(normDir);
        if (!_dirEnt) {
            job.setStatus(JobStatus::Failed);
            if (callback)
                callback(job);
            return unexpected(_dirEnt.error());
        }
        auto allSubs = this->m_toc.GetDirectoryFileEntries(*_dirEnt, true);

        for (const auto &entry : allSubs) {
            if (entry.isDirectory()) {
                dirsToExtract.push_back(entry);
            } else {
                filesToExtract.push_back(entry);
            }
        }
    }

    uint64_t totalBytes = 0;
    for (const auto &fileEntry : filesToExtract) {
        totalBytes += fileEntry.uncompressed_size;
    }

    job.setStatus(JobStatus::Running);
    job.totalBytes = totalBytes;
    job.processedBytes = 0;
    job.percentage = filesToExtract.empty() ? 100 : 0;
    if (callback)
        callback(job);

    for (const auto &dirEntry : dirsToExtract) {
        if (pauseToken.wait_if_paused(stopToken,
                [&]() {
                    job.setStatus(JobStatus::Paused);
                    if (callback) callback(job);
                },
                [&]() {
                    job.setStatus(JobStatus::Running);
                    if (callback) callback(job);
                })) {
            job.setStatus(JobStatus::Aborted);
            if (callback)
            callback(job);
            return unexpected(SeError::OperationCanceled);
        }

        if (stopToken.stop_requested()) {
            job.setStatus(JobStatus::Aborted);
            if (callback)
            callback(job);
            return unexpected(SeError::OperationCanceled);
        }

        u16string sub = dirEntry.path.substr(prefixLen);
        filesystem::path dirOnDisk = baseExtractDir / filesystem::path(sub);

        filesystem::create_directories(dirOnDisk, ec);
        if (ec) {
            job.setStatus(JobStatus::Failed);
            if (callback)
            callback(job);
            return unexpected(ec);
        }
    }

    // Extract all files
    size_t extractedFilesCount = 0;
    uint64_t cumulativeProcessedBytes = 0;
    uint64_t cumulativeCompressedBytes = 0;

    for (const auto &fileEntry : filesToExtract) {
        if (pauseToken.wait_if_paused(stopToken,
                [&]() {
                    job.setStatus(JobStatus::Paused);
                    if (callback) callback(job);
                },
                [&]() {
                    job.setStatus(JobStatus::Running);
                    if (callback) callback(job);
                })) {
            job.setStatus(JobStatus::Aborted);
            if (callback)
            callback(job);
            return unexpected(SeError::OperationCanceled);
        }

        if (stopToken.stop_requested()) {
            job.setStatus(JobStatus::Aborted);
            if (callback)
            callback(job);
            return unexpected(SeError::OperationCanceled);
        }

        u16string sub = fileEntry.path.substr(prefixLen);
        filesystem::path fileSubPath(sub);
        filesystem::path fileParentDir = baseExtractDir / fileSubPath.parent_path();

        filesystem::create_directories(fileParentDir, ec);
        if (ec) {
            job.setStatus(JobStatus::Failed);
            if (callback)
            callback(job);
            return unexpected(ec);
        }

        u16string targetDirStr = fileParentDir.u16string();
        if (targetDirStr.empty() ||
            (targetDirStr.back() != u'/' && targetDirStr.back() != u'\\')) {
            targetDirStr += u'/';
        }

        uint64_t baseProcessed = cumulativeProcessedBytes;
        uint64_t baseCompressed = cumulativeCompressedBytes;

        auto fileProgressCb = [&](const SeJob &fileSubJob) {
            if (fileSubJob.GetStatus() == JobStatus::Paused) {
                job.setStatus(JobStatus::Paused);
            if (callback) callback(job);
            } 
            else if (fileSubJob.GetStatus() == JobStatus::Running && job.GetStatus() == JobStatus::Paused) {
                job.setStatus(JobStatus::Running);
                if (callback) callback(job);
            } 
            else {
                SeJob fJob = fileSubJob;
                fJob.SetFileName(fileEntry.path);
                fJob.processedBytes = baseProcessed + fileSubJob.processedBytes;
                fJob.compressedBytes = baseCompressed + fileSubJob.compressedBytes;
                fJob.totalBytes = totalBytes;
                fJob.percentage = totalBytes > 0
                    ? std::min<uint32_t>(100, static_cast<uint32_t>((static_cast<double>(fJob.processedBytes) / static_cast<double>(totalBytes)) * 100.0))
                    : 100;
                fJob.setStatus(JobStatus::Running);
                if (callback) callback(fJob);
            }
        };

        auto _extractRes = this->ExtractFileSync(fileEntry.path, targetDirStr, callback ? ProgressCallback(fileProgressCb) : nullptr, stopToken, pauseToken);
        if (!_extractRes) {
            if (_extractRes.error() == SeError::OperationCanceled) {
            job.setStatus(JobStatus::Aborted);
            } else {
            job.setStatus(JobStatus::Failed);
            }
            if (callback)
            callback(job);
            return unexpected(_extractRes.error());
        }

        extractedFilesCount++;
        cumulativeProcessedBytes += fileEntry.uncompressed_size;
        cumulativeCompressedBytes += fileEntry.compressed_size;
    }

    job.SetFileName(normDir);
    job.setStatus(JobStatus::Finished);
    job.processedBytes = totalBytes;
    job.compressedBytes = cumulativeCompressedBytes;
    job.percentage = 100;
    if (callback)
        callback(job);

    return extractedFilesCount;
}

SeTaskHandle<size_t> SeArchive::ExtractDirectoryAsync(u16string fileName, u16string outputPath, ProgressCallback callback) {
    auto pauseState = std::make_shared<SePauseState>();
    SePauseToken pauseToken(pauseState);
    auto promise = std::make_shared<std::promise<expected<size_t, error_code>>>();
    auto future = promise->get_future().share();

    std::jthread worker([this, fileName = std::move(fileName),
                        outputPath = std::move(outputPath),
                        callback = std::move(callback),
                        pauseToken,promise](std::stop_token stopToken)
    {
        try {
            auto res = this->ExtractDirectorySync(fileName, outputPath, callback, stopToken, pauseToken);
            promise->set_value(res);
        } catch (...) {
            promise->set_exception(std::current_exception());
        }
    });
    return SeTaskHandle<size_t>(std::move(worker), std::move(future), std::move(pauseState));
}

bool SeArchive::verifyJobs() {

    for (const auto &job : this->m_jobs) {
        if (job.m_type == JobType::ExtractFile ||
            job.m_type == JobType::ExtractDirectory ||
            job.m_type == JobType::None) {
            return false;
        }
        if (job.m_status != JobStatus::Idle) {
            return false;
        }
    }
    return true;
}

bool SeArchive::addJob(SeJob &job) {
    if (job.m_type == JobType::ExtractFile ||
        job.m_type == JobType::ExtractDirectory || job.m_type == JobType::None) {
        return false;
    } // Extraction is instant no commiting required

    job.m_id = this->m_jobCtr++;

    if (job.m_type == JobType::CreateArchiveDirectory || job.m_type == JobType::AddDirectory) {
        this->m_queuedDirs.insert(SeTableOfContent::NormalizeDirectoryPath(job.m_fileName));
    } else if (job.m_type == JobType::AddFile) {
        this->m_queuedFiles.insert(SeTableOfContent::NormalizeFilePath(job.m_fileName));
    }

    m_jobs.push_back(job);
    return true;
}

void SeArchive::rebuildQueuedPathSets() {
    this->m_queuedDirs.clear();
    this->m_queuedFiles.clear();
    for (const auto &j : this->m_jobs) {

        if (j.m_type == JobType::CreateArchiveDirectory || j.m_type == JobType::AddDirectory) {
            this->m_queuedDirs.insert(SeTableOfContent::NormalizeDirectoryPath(j.m_fileName));
        } else if (j.m_type == JobType::AddFile) {
            this->m_queuedFiles.insert(SeTableOfContent::NormalizeFilePath(j.m_fileName));
        }
    }
}

bool SeArchive::checkParentPath(const u16string &path) const {
    u16string parent = SeTableOfContent::GetParentDirectory(path);
    if (parent == u"/")
        return true;
    if (this->m_queuedDirs.find(parent) != this->m_queuedDirs.end())
        return true;
    for (const auto &d : this->m_queuedDirs) {
        if (parent.starts_with(d))
            return true;
    }
    return this->m_toc.CheckPath(parent);
}

bool SeArchive::checkPathExists(const u16string &path) const {
  u16string norm = SeTableOfContent::NormalizeArchivePath(path);
  if (norm == u"/")
    return true;

  u16string dirNorm = norm;
  if (dirNorm.back() != u'/') {
    dirNorm.push_back(u'/');
  }
  u16string fileNorm = norm;
  while (fileNorm.size() > 1 && fileNorm.back() == u'/') {
    fileNorm.pop_back();
  }

  if (this->m_queuedDirs.find(dirNorm) != this->m_queuedDirs.end() ||
      this->m_queuedFiles.find(fileNorm) != this->m_queuedFiles.end()) {
    return true;
  }
  return this->m_toc.CheckPath(norm);
}

vector<int> SeArchive::optimizeJobs() {
    if (this->m_jobs.empty()) {
        return {};
    }

    vector<int> originalJobIds;
    originalJobIds.reserve(this->m_jobs.size());
    for (const auto &j : this->m_jobs) {
    originalJobIds.push_back(j.GetId());
    }

    // Kill duplicate change compression level jobs
    int lastCompressionIdx = -1;
    for (int i = 0; i < static_cast<int>(this->m_jobs.size()); ++i) {
        if (this->m_jobs[i].m_type == JobType::CompressionLevelChange) {
            lastCompressionIdx = i;
        }
    }
    if (lastCompressionIdx != -1) {
        vector<SeJob> filtered;
        filtered.reserve(this->m_jobs.size());
        filtered.push_back(move(this->m_jobs[lastCompressionIdx]));
        for (int i = 0; i < static_cast<int>(this->m_jobs.size()); ++i) {
            if (this->m_jobs[i].m_type != JobType::CompressionLevelChange &&
                this->m_jobs[i].m_type != JobType::None) {
            filtered.push_back(move(this->m_jobs[i]));
            }
        }
        this->m_jobs = move(filtered);
    }

    const size_t numJobs = this->m_jobs.size();

    
    struct JobPaths {
        u16string target;   
        u16string secondary;
    };

    vector<JobPaths> paths(numJobs);

    for (size_t i = 0; i < numJobs; ++i) {
        auto &job = this->m_jobs[i];
        if (job.m_type == JobType::None)
            continue;

        switch (job.m_type) {
            case JobType::AddFile:
                paths[i].target = SeTableOfContent::NormalizeFilePath(job.m_fileName);
                paths[i].secondary = job.m_filePath;
                job.m_fileName = paths[i].target;
                break;
            case JobType::RemoveFile:
                paths[i].target = SeTableOfContent::NormalizeFilePath(job.m_fileName);
                job.m_fileName = paths[i].target;
                break;
            case JobType::CreateArchiveDirectory:
            case JobType::AddDirectory:
                paths[i].target = SeTableOfContent::NormalizeDirectoryPath(job.m_fileName);
                job.m_fileName = paths[i].target;
                break;
            case JobType::DeleteDirectory:
                paths[i].target = SeTableOfContent::NormalizeDirectoryPath(job.m_fileName);
                job.m_fileName = paths[i].target;
                break;
            case JobType::MoveArchiveFile:
                paths[i].target = SeTableOfContent::NormalizeFilePath(job.m_fileName);
                paths[i].secondary = SeTableOfContent::NormalizeDirectoryPath(job.m_filePath);
                job.m_fileName = paths[i].target;
                job.m_filePath = paths[i].secondary;
                break;
            case JobType::MoveDirectory:
                paths[i].target = SeTableOfContent::NormalizeDirectoryPath(job.m_fileName);
                paths[i].secondary = SeTableOfContent::NormalizeDirectoryPath(job.m_filePath);
                job.m_fileName = paths[i].target;
                job.m_filePath = paths[i].secondary;
                break;
            default:
                break;
        }
    }

    // --- Pass 3: Chronological State Machine Simulation (O(N * L)) ---
    unordered_map<u16string, int> activeFileJobs;
    unordered_map<u16string, int> activeDirJobs;
    unordered_map<u16string, int> pendingFileDeletes;
    unordered_map<u16string, int> pendingDirDeletes;
    unordered_set<u16string> deletedDirectories;

    activeFileJobs.reserve(numJobs);
    activeDirJobs.reserve(numJobs / 4);

    for (size_t i = 0; i < numJobs; ++i) {
        auto &job = this->m_jobs[i];
        if (job.m_type == JobType::None)
            continue;

        // --- File Operations ---
        if (job.m_type == JobType::AddFile) {
            const auto &p = paths[i].target;
            auto it = activeFileJobs.find(p);
            if (it != activeFileJobs.end()) {
                int priorIdx = it->second;
                // Double AddFile on same archive destination -> drop prior add
                this->m_jobs[priorIdx].m_type = JobType::None;
                it->second = static_cast<int>(i);
            } else {
                activeFileJobs[p] = static_cast<int>(i);
            }
            pendingFileDeletes.erase(p);
        }
        else if (job.m_type == JobType::RemoveFile) {
            const auto &p = paths[i].target;
            auto it = activeFileJobs.find(p);
            if (it != activeFileJobs.end()) {
                int priorIdx = it->second;
                auto &priorJob = this->m_jobs[priorIdx];

                if (priorJob.m_type == JobType::AddFile) {
                    // Case 1B: AddFile followed by RemoveFile
                    if (!this->m_toc.CheckPath(p)) {
                    // Transient file -> both cancel out
                        priorJob.m_type = JobType::None;
                        job.m_type = JobType::None;
                    } else {
                    // Pre-existed in TOC -> drop AddFile overwrite, keep RemoveFile
                        priorJob.m_type = JobType::None;
                        pendingFileDeletes[p] = static_cast<int>(i);
                    }
                    activeFileJobs.erase(it);
                } 
                else if (priorJob.m_type == JobType::MoveArchiveFile) {
                    // Case 3B: MoveArchiveFile followed by RemoveFile on destination
                    priorJob.m_type = JobType::RemoveFile;
                    priorJob.m_filePath.clear();
                    job.m_type = JobType::None;
                    activeFileJobs.erase(it);
                    pendingFileDeletes[priorJob.m_fileName] = priorIdx;
                }
            }
            else {
                auto delIt = pendingFileDeletes.find(p);
                if (delIt != pendingFileDeletes.end()) {
                    // Case 1D: Duplicate RemoveFile
                    job.m_type = JobType::None;
                } else {
                    pendingFileDeletes[p] = static_cast<int>(i);
                }
            }
        }
        else if (job.m_type == JobType::MoveArchiveFile) {
            const auto &src = paths[i].target;
            const auto &dstDir = paths[i].secondary;
            u16string fileName = SeTableOfContent::GetFileName(src);
            u16string dstFile = SeTableOfContent::NormalizeFilePath(
                SeTableOfContent::CreateFilePath(dstDir, fileName));

            auto it = activeFileJobs.find(src);
            if (it != activeFileJobs.end()) {
            int priorIdx = it->second;
            auto &priorJob = this->m_jobs[priorIdx];

            if (priorJob.m_type == JobType::AddFile) {
                // Case 1C: AddFile followed by MoveArchiveFile
                priorJob.m_fileName = dstFile;
                paths[priorIdx].target = dstFile;
                job.m_type = JobType::None;

                activeFileJobs.erase(it);
                activeFileJobs[dstFile] = priorIdx;
            } else if (priorJob.m_type == JobType::MoveArchiveFile) {
                // Case 3A: Chained move (A -> B -> C)
                u16string origDir = SeTableOfContent::GetParentDirectory(priorJob.m_fileName);
                if (origDir == dstDir) {
                // Round-trip move cancelled out
                priorJob.m_type = JobType::None;
                job.m_type = JobType::None;
                activeFileJobs.erase(it);
                } else {
                priorJob.m_filePath = dstDir;
                paths[priorIdx].secondary = dstDir;
                job.m_type = JobType::None;

                activeFileJobs.erase(it);
                activeFileJobs[dstFile] = priorIdx;
                }
            }
            } else {
            activeFileJobs[dstFile] = static_cast<int>(i);
            }
        }
        else if (job.m_type == JobType::CreateArchiveDirectory || job.m_type == JobType::AddDirectory) {
            const auto &d = paths[i].target;
            auto it = activeDirJobs.find(d);
            if (it != activeDirJobs.end()) {
            // Case 2A: Double AddDirectory
            job.m_type = JobType::None;
            } else {
            activeDirJobs[d] = static_cast<int>(i);
            }
            pendingDirDeletes.erase(d);
        }
        else if (job.m_type == JobType::DeleteDirectory) {
            const auto &d = paths[i].target;
            deletedDirectories.insert(d);

            auto it = activeDirJobs.find(d);
            if (it != activeDirJobs.end()) {
            int priorIdx = it->second;
            auto &priorJob = this->m_jobs[priorIdx];

            if (priorJob.m_type == JobType::CreateArchiveDirectory ||
                priorJob.m_type == JobType::AddDirectory) {
                // Case 2B: AddDirectory followed by DeleteDirectory
                if (!this->m_toc.CheckPath(d)) {
                // Transient directory -> both cancel out
                priorJob.m_type = JobType::None;
                job.m_type = JobType::None;
                } else {
                priorJob.m_type = JobType::None;
                pendingDirDeletes[d] = static_cast<int>(i);
                }
                activeDirJobs.erase(it);
            } else if (priorJob.m_type == JobType::MoveDirectory) {
                // Case 4B: MoveDirectory followed by DeleteDirectory
                priorJob.m_type = JobType::DeleteDirectory;
                priorJob.m_filePath.clear();
                job.m_type = JobType::None;
                activeDirJobs.erase(it);
                deletedDirectories.insert(priorJob.m_fileName);
                pendingDirDeletes[priorJob.m_fileName] = priorIdx;
            }
            } else {
            auto delIt = pendingDirDeletes.find(d);
            if (delIt != pendingDirDeletes.end()) {
                // Case 2D: Duplicate DeleteDirectory
                job.m_type = JobType::None;
            } else {
                pendingDirDeletes[d] = static_cast<int>(i);
            }
            }
        }
        else if (job.m_type == JobType::MoveDirectory) {
            const auto &src = paths[i].target;
            const auto &dstDir = paths[i].secondary;
            u16string dirName = SeTableOfContent::GetFileName(src);
            u16string dstPath = SeTableOfContent::NormalizeDirectoryPath(
                SeTableOfContent::CreateDirPath(dstDir, dirName));

            auto it = activeDirJobs.find(src);
            if (it != activeDirJobs.end()) {
            int priorIdx = it->second;
            auto &priorJob = this->m_jobs[priorIdx];

            if (priorJob.m_type == JobType::CreateArchiveDirectory ||
                priorJob.m_type == JobType::AddDirectory) {
                // Case 2C: AddDirectory followed by MoveDirectory
                priorJob.m_fileName = dstPath;
                paths[priorIdx].target = dstPath;
                job.m_type = JobType::None;

                activeDirJobs.erase(it);
                activeDirJobs[dstPath] = priorIdx;
            } else if (priorJob.m_type == JobType::MoveDirectory) {
                // Case 4A: Chained directory moves
                u16string origParentDir = SeTableOfContent::GetParentDirectory(priorJob.m_fileName);
                if (origParentDir == dstDir) {
                priorJob.m_type = JobType::None;
                job.m_type = JobType::None;
                activeDirJobs.erase(it);
                } else {
                priorJob.m_filePath = dstDir;
                paths[priorIdx].secondary = dstDir;
                job.m_type = JobType::None;

                activeDirJobs.erase(it);
                activeDirJobs[dstPath] = priorIdx;
                }
            }
            } else {
            activeDirJobs[dstPath] = static_cast<int>(i);
            }
        }
    }
    if (!deletedDirectories.empty()) {
        for (size_t i = 0; i < numJobs; ++i) {
            auto &job = this->m_jobs[i];
            if (job.m_type != JobType::AddFile &&
                job.m_type != JobType::CreateArchiveDirectory &&
                job.m_type != JobType::AddDirectory) {
            continue;
            }

            const auto &itemPath = paths[i].target;
            if (this->m_toc.CheckPath(itemPath)) {
            continue; // Pre-existed in TOC
            }

            u16string currParent = SeTableOfContent::GetParentDirectory(itemPath);
            while (!currParent.empty()) {
            if (deletedDirectories.count(currParent)) {
                job.m_type = JobType::None;
                break;
            }
            if (currParent == u"/") {
                break;
            }
            currParent = SeTableOfContent::GetParentDirectory(currParent);
            }
        }
    }

    // Topological Depth-Ordered Orphan Pruning
    unordered_set<u16string> validDirectories;
    validDirectories.insert(u"/");

    vector<pair<int, u16string>> activeDirs;
    activeDirs.reserve(activeDirJobs.size());
    for (size_t i = 0; i < numJobs; ++i) {
        if (this->m_jobs[i].m_type == JobType::CreateArchiveDirectory ||
            this->m_jobs[i].m_type == JobType::AddDirectory) {
            activeDirs.emplace_back(static_cast<int>(i), paths[i].target);
        }
    }

    std::sort(activeDirs.begin(), activeDirs.end(),
            [](const auto &a, const auto &b) {
                size_t depthA = std::count(a.second.begin(), a.second.end(), u'/');
                size_t depthB = std::count(b.second.begin(), b.second.end(), u'/');
                return depthA < depthB;
            });

    for (const auto &dirItem : activeDirs) {
        u16string parent = SeTableOfContent::GetParentDirectory(dirItem.second);
        bool parentValid = (parent == u"/" ||
                            validDirectories.count(parent) ||
                            this->m_toc.CheckPath(parent));
        if (parentValid) {
            validDirectories.insert(dirItem.second);
        } else {
            this->m_jobs[dirItem.first].m_type = JobType::None;
        }
    }

    // Prune orphan AddFile jobs
    for (size_t i = 0; i < numJobs; ++i) {
        if (this->m_jobs[i].m_type == JobType::AddFile) {
            u16string parent = SeTableOfContent::GetParentDirectory(paths[i].target);
            bool parentValid = (parent == u"/" ||
                                validDirectories.count(parent) ||
                                this->m_toc.CheckPath(parent));
            if (!parentValid) {
            this->m_jobs[i].m_type = JobType::None;
            }
        }
    }

    erase_if(this->m_jobs, [](const SeJob &job) {
        return job.m_type == JobType::None;
    });

    this->rebuildQueuedPathSets();

    unordered_set<int> remainingIds;
    remainingIds.reserve(this->m_jobs.size());
    for (const auto &j : this->m_jobs) {
        remainingIds.insert(j.GetId());
    }

    vector<int> deletedIds;
    deletedIds.reserve(originalJobIds.size() - this->m_jobs.size());
    for (int id : originalJobIds) {
        if (remainingIds.find(id) == remainingIds.end()) {
            deletedIds.push_back(id);
        }
    }

    return deletedIds;
}
