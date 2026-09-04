#include "libsecdet/SeArchive.h"

expected<SeArchive, error_code> SeArchive::CreateArchive(uint16_t version, uint16_t compressionLevel,
                         bool preserveMetadata, u16string archivePath) {
  // Supported versions: 1
  if (version > 1)
    return unexpected(SeError::VersionNotSupported);
  if (compressionLevel > 0x3 || compressionLevel < 0x1)
    return unexpected(make_error_code(errc::invalid_argument));
  if (!SeTableOfContent::verifyAbsPath(archivePath))
    return unexpected(make_error_code(errc::no_such_file_or_directory));

  auto _cctx = AesGcmContextProvider::CreateContext();

  if (!_cctx)
    return unexpected(_cctx.error());

  return expected<SeArchive,error_code>(in_place, SeMetadata(version, compressionLevel, preserveMetadata),
      SeTableOfContent::CreateNewTableOfContent(), archivePath,
      *move(_cctx));
}

expected<SeArchive, error_code> SeArchive::LoadArchiveFile(u16string path) {

  if (!SeTableOfContent::verifyAbsPath(path))
    return unexpected(make_error_code(errc::no_such_file_or_directory));

  MappedFileStream fs;
  if (auto _fs = fs.open(path); !_fs)
    return unexpected(_fs.error());

  fs.seek(0);

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

SeArchive::~SeArchive() = default;

bool SeArchive::IsReady() { return this->m_isReady; }

expected<void, error_code> SeArchive::AddFile(u16string filePath,
                                              u16string fileName) {
  filePath = SeTableOfContent::NormalizeFilePath(filePath);
  if (!this->m_toc.CheckParentPath(filePath))
    return unexpected(SeError::TocPathIsInvalid);

  if (!SeTableOfContent::verifyAbsPath(fileName))
    return unexpected(make_error_code(errc::no_such_file_or_directory));

  auto job = SeJob(JobType::AddFile, filePath, fileName);

  if (!this->addJob(job))
    return unexpected(SeError::CannotCreateJob);

  return {};
}

expected<void, error_code> SeArchive::RemoveFile(u16string fileName) {
  fileName = SeTableOfContent::NormalizeFilePath(fileName);
  if (!this->m_toc.CheckPath(fileName))
    return unexpected(SeError::TocPathIsInvalid);

  auto job = SeJob(JobType::RemoveFile, fileName, u"");

  if (!this->addJob(job))
    return unexpected(SeError::CannotCreateJob);

  return {};
}

expected<void, error_code> SeArchive::AddDirectory(u16string fileName) {
  fileName = SeTableOfContent::NormalizeDirectoryPath(fileName);
  if (!this->m_toc.CheckParentPath(fileName))
    return unexpected(SeError::TocPathIsInvalid);

  if (this->m_toc.CheckPath(fileName))
    return unexpected(SeError::AddingExistingEntry);

  auto job = SeJob(JobType::AddDirectory, fileName, u"");

  if (!this->addJob(job))
    return unexpected(SeError::CannotCreateJob);

  return {};
}

expected<void, error_code> SeArchive::DeleteDirectory(u16string fileName) {
  fileName = SeTableOfContent::NormalizeDirectoryPath(fileName);
  if (fileName == u"/" || !this->m_toc.CheckPath(fileName))
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
SeArchive::RegisterKey(string &key) { // Master Key does not go through a KDF we
                                      // just use its hash value

  vector<unsigned char> key_hash(crypto_hash_sha256_BYTES);
  auto exp = sha256String(key, key_hash);
  if (!exp)
    return unexpected(exp.error());

  this->m_cryptoCtx.SetMasterKey(
      key_hash); // Set master key is not responsible for cleaning the left over
                 // of masterkey

  sodium_memzero(key_hash.data(), key_hash.size());

  return {};
}

bool SeArchive::IsKeyPresent() { return this->m_cryptoCtx.keyExists(); }

const vector<SeJob> &SeArchive::GetJobs() { return this->m_jobs; }

expected<void, error_code> SeArchive::RemoveJob(int id) {
  int removed = erase_if(this->m_jobs, [id](SeJob &job) {
    if (job.m_id == id)
      return true;
    return false;
  });
  if (removed == 0)
    return unexpected(SeError::JobNotFound);

  return {};
}

void SeArchive::SetPreserveMetadata(bool preserve) {
  if (this->m_metadata.m_preserve_metadata != preserve)
    this->m_metadata.SetPreserveMetadata(preserve);
}

void SeArchive::SetCompressionLevel(uint32_t compressionLevel) {
  if (this->m_metadata.m_compression_level != compressionLevel)
    this->m_metadata.SetCompressionLevel(compressionLevel);
  this->ChangeCompressionLevel(compressionLevel);
}

expected<void, error_code>
SeArchive::ChangeCompressionLevel(uint32_t compressionLevel) {
  if (compressionLevel < 1 || compressionLevel > 3)
    return unexpected(make_error_code(errc::invalid_argument));

  u16string levelStr;
  levelStr.push_back(static_cast<char16_t>(u'0' + compressionLevel));
  SeJob job(JobType::CompressionLevelChange, levelStr, u"");
  if (!this->addJob(job))
    return unexpected(SeError::CannotCreateJob);

  return {};
}

expected<void, error_code> SeArchive::SaveChangesSync(ProgressCallback callback,
                                                      stop_token stopToken) {
  // ProcessCallback will be called with jobs queued in the job container
  // Optimize queued jobs (merge duplicates, cancel transient ops, fold moves)
  // prior to verification and execution
  this->optimizeJobs();

  if (!verifyJobs())
    return unexpected(SeError::ConflictingJobFound);

  // Checking the Io Status and preparing it ( check the archive file existance
  // ) verifying TOC

  auto _exfs = this->m_archiveStream.open(this->m_archiveFilePath);
  if (!_exfs && _exfs.error() != SeError::StreamAlreadyOpen)
    return unexpected(_exfs.error());

  auto &fs = this->m_archiveStream;
  fs.seek(0);

  vector<unsigned char> metadata_bytes(SE_METADATA_SIZE);
  if (auto _sz = fs.read(metadata_bytes.data(), SE_METADATA_SIZE); !_sz) {
    return unexpected(_sz.error());
  }
  auto _metadata = SeMetadata::LoadMetadataFromBytes(metadata_bytes);
  if (!_metadata)
    return unexpected(_metadata.error());
  SeMetadata metadata = *_metadata;

  if (metadata != this->m_metadata)
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

  // Toc verified now we can start the operations
  if (!this->IsReady()) {
    // either TOC or metadata was modified internally and not saved on disk we
    // have to address that
    return unexpected(
        SeError::ArchiveModified); // In any archive modified case you have to
                                   // reload it again to be sure.
  }

  this->m_isReady = false;

  for (int i{0}; i < this->m_jobs.size(); i++) {

    auto &job = this->m_jobs[i];

    if (stopToken.stop_requested())
      return unexpected(SeError::OperationCanceled);

    if (job.m_status != JobStatus::Idle)
      return unexpected(SeError::JobIsNotIdle);

    // WARN: this level of job seperation will introduce overhead with archives
    // that have complex file system -> jobs should be able to merge
    expected<void, error_code> _result;

    switch (job.m_type) {
    case JobType::None:
      return unexpected(SeError::InvalidJob);
    case JobType::AddFile:
      _result = doAddFileJob(job, callback, stopToken);
      break;
    case JobType::RemoveFile:
      _result = doRemoveFileJob(job, callback, stopToken);
      break;
    case JobType::AddDirectory:
      _result = doAddDirectoryJob(job, callback, stopToken);
      break;
    case JobType::DeleteDirectory:
      _result = doDeleteDirectoryJob(job, callback, stopToken);
      break;
    case JobType::MoveArchiveFile:
      _result = doMoveFileJob(job, callback, stopToken);
      break;
    case JobType::MoveDirectory:
      _result = doMoveDirectoryJob(job, callback, stopToken);
      break;
    case JobType::CompressionLevelChange:
      _result = doChangeCompressionLevel(job, callback, stopToken);
      break;
    case JobType::TestFile:
      _result = doTestFile(job, callback, stopToken);
      break;
    }

    if (!_result) // whatever happen here we should fix the TOC then exit
      return unexpected(_result.error());
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

  std::jthread worker([this, callback = std::move(callback),
                       promise](std::stop_token stopToken) {
    try {
      auto res = this->SaveChangesSync(callback, stopToken);
      promise->set_value(res);
    } catch (...) {
      promise->set_exception(std::current_exception());
    }
  });

  return SeTaskHandle<void>(std::move(worker), std::move(future));
}

// @Private

expected<void, error_code> SeArchive::doAddFileJob(SeJob &job,
                                                   ProgressCallback callback,
                                                   stop_token stopToken) {
  job.m_status = JobStatus::Pending;

  if (stopToken.stop_requested()) {
    job.setStatus(JobStatus::Aborted);
    if (callback)
      callback(job);

    return unexpected(SeError::OperationCanceled);
  }

  if (callback != nullptr)
    callback(job);

  MappedFileStream inFileStream;
  if (auto _fs = inFileStream.open(job.m_filePath, FileMode::OpenExisting);
      !_fs) {
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

  SeArchiveEntry entry =
      SeArchiveEntry::CreateFileEntry(this->m_toc.GetFileName(
          job.m_fileName)); // Important: the header entry will have only file
                            // name, the TOC will contains full path!
  entry.uncompressed_size = inFileStream.size();
  entry.attributes =
      0; // Dont know and care how to get and set file attr for now !
  entry.offset = this->m_toc.getNextAvailOffset();
  entry.fileUid = getSecureRandom();
  entry.crc32 = CRC32C_INIT;

  // Before doing anything we will start writing the file header ( entry
  // placeholder in its place )

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
  size_t param_err = ZSTD_CCtx_setParameter(this->m_zstdCctx.get(),
                                            ZSTD_c_compressionLevel, cLevel);

  size_t readSz = ZSTD_CStreamInSize();
  size_t writeSz = ZSTD_CStreamOutSize();

  vector<unsigned char> inBuffer(readSz);
  vector<unsigned char> outBuffer(writeSz);

  auto _cryptoStream =
      this->m_cryptoCtx.createSession<Mode::Encryption>(entry.fileUid);
  if (!_cryptoStream) {
    job.setStatus(JobStatus::Failed);
    if (callback)
      callback(job);

    return unexpected(_cryptoStream.error());
  }

  unique_ptr<AesGcmStreamSession<Mode::Encryption>> cryptoStreamSession =
      *move(_cryptoStream);

  const size_t cipherChunkSize =
      AesGcmStreamSession<Mode::Encryption>::BUFFER_SIZE +
      AesGcmStreamSession<Mode::Encryption>::TAG_BYTES;
  vector<unsigned char> cryptoOutBuffer(cipherChunkSize);

  bool isLastChunk = false;

  job.setStatus(JobStatus::Running);
  job.totalBytes = inFileStream.size();
  job.processedBytes = 0;
  job.percentage = 0;

  if (callback)
    callback(job);

  size_t processedBytes = 0;
  while (!isLastChunk) {

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
        if (!_cryptoResult &&
            _cryptoResult.error() !=
                SeError::CRYPTOStageTooSmall) { // Ignoring staged buffer warns
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
  job.percentage = 100;
  if (callback)
    callback(job);

  return {};
}

expected<void, error_code> SeArchive::doRemoveFileJob(SeJob &job,
                                                      ProgressCallback callback,
                                                      stop_token stopToken) {

  job.setStatus(JobStatus::Pending);
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
  auto &entry = *_entError;

  auto inFileEntrySize = entry.GetDiskSize();
  // Move files that are in front of the requested file entry.compressedSize +
  // entrysize backward then truncate
  auto frontEntries = this->m_toc.GetEntriesFollowing(entry);

  if (frontEntries.size() == 0) {
    job.setStatus(JobStatus::Running);
    if (callback)
      callback(job);
    // No front entries
    // Only trunking
    if (auto _err = this->m_archiveStream.truncate(
            this->m_archiveStream.size() - inFileEntrySize);
        !_err) {
      job.setStatus(JobStatus::Failed);
      if (callback)
        callback(job);

      return unexpected(_err.error());
    }

    job.setStatus(JobStatus::Finished);
    if (callback)
      callback(job);

    return {};
  } else {
    // Files are in front of entry
    // Pushing them back one by one until the last one!

    // The front entries does not return entries sorted by their offset!
    job.setStatus(JobStatus::Running);
    if (callback)
      callback(job);

    sort(frontEntries.begin(), frontEntries.end(),
         [](SeArchiveEntry &a, SeArchiveEntry &b) {
           return a.offset < b.offset;
         });

    size_t shifted = 0;

    for (int i{0}; i < frontEntries.size();
         i++) { // cancelation token will be ignored here; else it would be too
                // time consuming to revert everything back to before!
      auto &frontEnt = frontEntries[i];

      job.percentage = (i / frontEntries.size()) * 100;
      if (callback)
        callback(job);

      size_t entrySize = frontEnt.GetDiskSize();

      if (auto _err = this->m_archiveStream.shift_bytes(
              shifted + entry.offset, frontEnt.offset, entrySize);
          !_err) {
        job.setStatus(JobStatus::Failed);
        if (callback)
          callback(job);

        return unexpected(_err.error());
      }

      frontEnt.offset = shifted + entry.offset;
      this->m_toc.RemoveEntry(frontEnt);
      this->m_toc.AddEntry(frontEnt);
      shifted += entrySize;
    }

    this->m_toc.RemoveEntry(entry);

    job.setStatus(JobStatus::Finished);
    if (callback)
      callback(job);
    return {};
  }
}

expected<void, error_code>
SeArchive::doAddDirectoryJob(SeJob &job, ProgressCallback callback,
                             stop_token stopToken) {
  job.setStatus(JobStatus::Pending);
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
SeArchive::doDeleteDirectoryJob(SeJob &job, ProgressCallback callback,
                                stop_token stopToken) {

  job.setStatus(JobStatus::Pending);
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
  if (dirEntries.size() == 0) {
    // Removing empty directory

    this->m_toc.RemoveEntry(dir);

    job.setStatus(JobStatus::Finished);
    if (callback)
      callback(job);
    return {};
  } else {
    // Removing files

    for (int i{0}; i < dirEntries.size();
         i++) { // Same as doRemoveFile no stopToken is processed here cause
                // makes the reverting task harder!

      auto fileEntry = dirEntries[i];

      job.percentage =
          static_cast<uint32_t>((i * 100) / dirEntries.size());
      if (callback)
        callback(job);

      if (fileEntry.isDirectory()) {
        SeJob jDirDel(JobType::DeleteDirectory, fileEntry.path, u"");
        auto _remove = doDeleteDirectoryJob(jDirDel, nullptr, stopToken);
        if (!_remove) {
          job.setStatus(JobStatus::Failed);
          if (callback)
            callback(job);
          return unexpected(_remove.error());
        }
      } else {
        SeJob jFileRemove(JobType::RemoveFile, fileEntry.path, u"");
        auto _remove = doRemoveFileJob(
            jFileRemove, nullptr,
            stopToken); // no need for callback since we are the reporter!
        if (!_remove) {
          job.setStatus(JobStatus::Failed);
          if (callback)
            callback(job);
          return unexpected(_remove.error());
        }
      }
    }

    this->m_toc.RemoveEntry(dir);
    job.setStatus(JobStatus::Finished);
    if (callback)
      callback(job);
    return {};
  }
}

expected<void, error_code> SeArchive::doMoveFileJob(SeJob &job,
                                                    ProgressCallback callback,
                                                    stop_token stopToken) {
  // File header entries are just file name and not needed to be moved around
  // upon the file moves!

  job.setStatus(JobStatus::Pending);
  if (callback)
    callback(job);

  if (stopToken.stop_requested()) {
    job.setStatus(JobStatus::Aborted);
    if (callback)
      callback(job);
    return unexpected(SeError::OperationCanceled);
  }
  // Assuming the job as registered & file name is src , file path is dst

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
    // Sloppiness at job verification can cause this
    job.setStatus(JobStatus::Failed);
    if (callback)
      callback(job);
    return unexpected(SeError::TocPathIsInvalid);
  }

  auto finalPath = this->m_toc.CreateFilePath(
      job.m_filePath, fileName); // No need to retrieve the dest directory entry

  this->m_toc.RemoveEntry(entry);

  entry.path = finalPath;

  this->m_toc.AddEntry(entry);

  job.setStatus(JobStatus::Finished);
  if (callback)
    callback(job);
  return {};
}

expected<void, error_code>
SeArchive::doMoveDirectoryJob(SeJob &job, ProgressCallback callback,
                              stop_token stopToken) {

  job.setStatus(JobStatus::Pending);
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

  auto newDirPath = this->m_toc.CreateDirPath(
      job.m_filePath, this->m_toc.GetFileName(entry.path));

  auto entrySubs = this->m_toc.GetDirectoryFileEntries(entry);

  if (entrySubs.size() == 0) {
    this->m_toc.RemoveEntry(entry);
    entry.path = newDirPath;
    this->m_toc.AddEntry(entry);

    job.setStatus(JobStatus::Finished);
    if (callback)
      callback(job);
    return {};
  } else {

    for (int i{0}; i < entrySubs.size(); i++) {

      auto subEntry = entrySubs[i];

      if (subEntry.isDirectory()) {
        SeJob jMove(JobType::MoveDirectory, subEntry.path, newDirPath);
        auto _move = doMoveDirectoryJob(jMove, nullptr, stopToken);
        if (!_move) {
          job.setStatus(JobStatus::Failed);
          if (callback)
            callback(job);
          return unexpected(_move.error());
        }
      } else {
        SeJob jMove(JobType::MoveArchiveFile, subEntry.path, newDirPath);
        auto _move = doMoveFileJob(jMove, nullptr, stopToken);
        if (!_move) {
          job.setStatus(JobStatus::Failed);
          if (callback)
            callback(job);
          return unexpected(_move.error());
        }
      }
    }
    this->m_toc.RemoveEntry(entry);
    entry.path = newDirPath;
    this->m_toc.AddEntry(entry);

    job.setStatus(JobStatus::Finished);
    if (callback)
      callback(job);
    return {};
  }
}

expected<void, error_code> SeArchive::doChangeCompressionLevel(
    SeJob &job, ProgressCallback callback,
    stop_token stopToken) {
  job.setStatus(JobStatus::Pending);
  if (callback)
    callback(job);

  if (stopToken.stop_requested()) {
    job.setStatus(JobStatus::Aborted);
    if (callback)
      callback(job);
    return unexpected(SeError::OperationCanceled);
  }

  uint32_t newLevel = this->m_metadata.GetCompressionLevel();
  if (!job.m_fileName.empty() && job.m_fileName[0] >= u'1' &&
      job.m_fileName[0] <= u'3') {
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
  job.percentage = 0;
  if (callback)
    callback(job);

  filesystem::path origPath(this->m_archiveFilePath);
  filesystem::path tempPath = origPath;
  tempPath += u".recomp.tmp";

  error_code ec;
  filesystem::remove(tempPath, ec);

  MappedFileStream tempStream;
  if (auto _openTemp =
          tempStream.open(tempPath.u16string(), FileMode::CreateAlways);
      !_openTemp) {
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

  if (auto _wrMeta =
          tempStream.write(metaBytes.data(), metaBytes.size());
      !_wrMeta) {
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
  vector<unsigned char> cryptoPlainBuf(
      AesGcmStreamSession<Mode::Decryption>::BUFFER_SIZE);
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
    if (auto _rdCount = this->m_archiveStream.read(&cCount, sizeof(cCount));
        !_rdCount || *_rdCount != sizeof(cCount)) {
      cleanupOnFailure();
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
      cleanupOnFailure();
      job.setStatus(JobStatus::Failed);
      if (callback)
        callback(job);
      return unexpected(_rdRemaining ? make_error_code(errc::io_error)
                                     : _rdRemaining.error());
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
    bool pathMatches =
        (pseudoEntry.path == fileEntry.path ||
         pseudoEntry.path == SeTableOfContent::GetFileName(fileEntry.path));
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

    SeArchiveEntry fileHeaderEntry =
        SeArchiveEntry::CreateFileEntry(SeTableOfContent::GetFileName(fileEntry.path));
    fileHeaderEntry.uncompressed_size = fileEntry.uncompressed_size;
    fileHeaderEntry.attributes = fileEntry.attributes;
    fileHeaderEntry.offset = newFileOffset;
    fileHeaderEntry.fileUid = fileEntry.fileUid;
    fileHeaderEntry.crc32 = fileEntry.crc32;
    fileHeaderEntry.compressed_size = 0;

    auto placeholderBytes = fileHeaderEntry.Serialize();
    if (auto _wrHdr =
            tempStream.write(placeholderBytes.data(), placeholderBytes.size());
        !_wrHdr) {
      cleanupOnFailure();
      job.setStatus(JobStatus::Failed);
      if (callback)
        callback(job);
      return unexpected(_wrHdr.error());
    }
    tempStream.flush();

    // Create crypto sessions
    auto _decryptSess =
        this->m_cryptoCtx.createSession<Mode::Decryption>(fileEntry.fileUid);
    if (!_decryptSess) {
      cleanupOnFailure();
      job.setStatus(JobStatus::Failed);
      if (callback)
        callback(job);
      return unexpected(_decryptSess.error());
    }
    auto decryptSess = *move(_decryptSess);

    auto _encryptSess =
        this->m_cryptoCtx.createSession<Mode::Encryption>(fileEntry.fileUid);
    if (!_encryptSess) {
      cleanupOnFailure();
      job.setStatus(JobStatus::Failed);
      if (callback)
        callback(job);
      return unexpected(_encryptSess.error());
    }
    auto encryptSess = *move(_encryptSess);

    // Reset ZSTD sessions
    ZSTD_DCtx_reset(this->m_zstdDctx.get(), ZSTD_reset_session_only);
    ZSTD_CCtx_reset(this->m_zstdCctx.get(), ZSTD_reset_session_only);
    ZSTD_CCtx_setParameter(this->m_zstdCctx.get(), ZSTD_c_compressionLevel,
                           targetCLevel);

    uint32_t runningCrc = CRC32C_INIT;
    uint64_t fileCompressedBytes = 0;

    // Helper lambda: compress plaintext and encrypt ciphertext to tempStream
    auto compressAndEncrypt =
        [&](span<const unsigned char> plainData,
            ZSTD_EndDirective mode) -> expected<void, error_code> {
      ZSTD_inBuffer inBuff = {plainData.data(), plainData.size(), 0};
      bool finished = false;
      while (!finished) {
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

    // Helper lambda: decompress decrypted chunk and process
    auto decompressAndRecompress =
        [&](span<const unsigned char> cipherPlain) -> expected<void, error_code> {
      ZSTD_inBuffer decomIn = {cipherPlain.data(), cipherPlain.size(), 0};
      while (decomIn.pos < decomIn.size) {
        if (stopToken.stop_requested()) {
          return unexpected(SeError::OperationCanceled);
        }

        ZSTD_outBuffer decomOut = {decomOutBuf.data(), decomOutBuf.size(), 0};
        size_t rem =
            ZSTD_decompressStream(this->m_zstdDctx.get(), &decomOut, &decomIn);
        if (ZSTD_isError(rem)) {
          return unexpected(SeError::ZSTDCompressionError);
        }

        if (decomOut.pos > 0) {
          runningCrc = crc32c_update(runningCrc, decomOut.dst, decomOut.pos);
          totalProcessedBytes += decomOut.pos;

          job.processedBytes = totalProcessedBytes;
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
      if (stopToken.stop_requested()) {
        cleanupOnFailure();
        job.setStatus(JobStatus::Aborted);
        if (callback)
          callback(job);
        return unexpected(SeError::OperationCanceled);
      }

      size_t toRead =
          std::min(static_cast<uint64_t>(cipherChunkSize), remainingCipher);
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
        auto _procErr = decompressAndRecompress(span<const unsigned char>{
            cryptoPlainBuf.data(),
            AesGcmStreamSession<Mode::Decryption>::BUFFER_SIZE});
        if (!_procErr) {
          cleanupOnFailure();
          job.setStatus(JobStatus::Failed);
          if (callback)
            callback(job);
          return unexpected(_procErr.error());
        }
      } else if (_decResult.error() != SeError::CRYPTOStageTooSmall) {
        cleanupOnFailure();
        job.setStatus(JobStatus::Failed);
        if (callback)
          callback(job);
        return unexpected(_decResult.error());
      }
    }

    // Finalize decryption session
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
      size_t rem =
          ZSTD_decompressStream(this->m_zstdDctx.get(), &decomOut, &emptyIn);
      if (ZSTD_isError(rem)) {
        break;
      }
      if (decomOut.pos > 0) {
        runningCrc = crc32c_update(runningCrc, decomOut.dst, decomOut.pos);
        totalProcessedBytes += decomOut.pos;

        job.processedBytes = totalProcessedBytes;
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

    if (auto _wrHdr =
            tempStream.write(realHeaderBytes.data(), realHeaderBytes.size());
        !_wrHdr) {
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

  if (auto _wrMeta = tempStream.write(metaBytes.data(), metaBytes.size());
      !_wrMeta) {
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
    filesystem::copy_file(tempPath, origPath,
                          filesystem::copy_options::overwrite_existing, renEc);
    if (renEc) {
      cleanupOnFailure();
      this->m_archiveStream.open(this->m_archiveFilePath);
      job.setStatus(JobStatus::Failed);
      if (callback)
        callback(job);
      return unexpected(renEc);
    }
  } else {
    filesystem::rename(tempPath, origPath, renEc);
    if (renEc) {
      error_code revEc;
      filesystem::rename(backupPath, origPath, revEc);
      cleanupOnFailure();
      this->m_archiveStream.open(this->m_archiveFilePath);
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
  job.percentage = 100;
  if (callback)
    callback(job);

  return {};
}

expected<void, error_code> SeArchive::doTestFile(SeJob &job,
                                                 ProgressCallback callback,
                                                 stop_token stopToken) {
  job.setStatus(JobStatus::Pending);
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
  job.percentage = 0;
  if (callback)
    callback(job);

  uint64_t calculatedUncompressedSize = 0;
  uint32_t currentCrc = CRC32C_INIT;

  auto decompressAndProcess =
      [&](span<const unsigned char> plain) -> expected<void, error_code> {
    ZSTD_inBuffer inBuff = {plain.data(), plain.size(), 0};
    while (inBuff.pos < inBuff.size) {
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
    job.setStatus(JobStatus::Finished);
    if (callback)
      callback(job);
    return unexpected(SeError::CrcChecksumFailed);
  }

  job.setStatus(JobStatus::Finished);
  job.processedBytes = calculatedUncompressedSize;
  job.percentage = 100;
  if (callback)
    callback(job);

  return {};
}

expected<size_t, error_code>
SeArchive::ExtractFileSync(u16string fileName, u16string outputPath,
                           ProgressCallback callback, stop_token stopToken) {
  // Only directory output path are allowed
  // Job handling is internal to this function no registration required
  SeJob job(JobType::ExtractFile, fileName, outputPath);
  job.setStatus(JobStatus::Pending);
  if (callback)
    callback(job);
  if (!SeTableOfContent::verifyAbsPath(outputPath) ||
      !SeTableOfContent::isAbsPathDir(outputPath)) {
    job.setStatus(JobStatus::Failed);
    if (callback)
      callback(job);
    return unexpected(SeError::ExpectedDirectory);
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
  auto path = SeTableOfContent::mergePath(
      outputPath, SeTableOfContent::GetFileName(fileName));

  MappedFileStream outFs;
  if (auto _openErr = outFs.open(path, FileMode::CreateAlways); !_openErr) {
    job.setStatus(JobStatus::Failed);
    if (callback)
      callback(job);
    return unexpected(_openErr.error());
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
  job.percentage = 0;
  if (callback)
    callback(job);

  uint64_t totalExtractedBytes = 0;
  uint32_t currentCrc = CRC32C_INIT;

  auto decompressAndWrite =
      [&](span<const unsigned char> plain) -> expected<void, error_code> {
    ZSTD_inBuffer inBuff = {plain.data(), plain.size(), 0};
    while (inBuff.pos < inBuff.size) {
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
  outFs.flush();

  currentCrc = crc32c_finalize(currentCrc);

  job.setStatus(JobStatus::Finished);
  job.processedBytes = totalExtractedBytes;
  job.percentage = 100;
  if (callback)
    callback(job);

  return totalExtractedBytes;
}

expected<size_t, error_code>
SeArchive::ExtractDirectorySync(u16string fileName, u16string outputPath,
                                ProgressCallback callback,
                                stop_token stopToken) {
  u16string normDir = SeTableOfContent::NormalizeDirectoryPath(fileName);
  SeJob job(JobType::ExtractDirectory, normDir, outputPath);
  job.setStatus(JobStatus::Pending);
  if (callback)
    callback(job);

  if (!SeTableOfContent::verifyAbsPath(outputPath) ||
      !SeTableOfContent::isAbsPathDir(outputPath)) {
    job.setStatus(JobStatus::Failed);
    if (callback)
      callback(job);
    return unexpected(SeError::ExpectedDirectory);
  }

  if (stopToken.stop_requested()) {
    job.setStatus(JobStatus::Aborted);
    if (callback)
      callback(job);
    return unexpected(SeError::OperationCanceled);
  }

  // Verify directory exists in TOC if a specific subdirectory was requested
  if (normDir != u"/") {
    if (!this->m_toc.CheckPath(normDir) || !this->m_toc.IsDirectory(normDir)) {
      job.setStatus(JobStatus::Failed);
      if (callback)
        callback(job);
      return unexpected(SeError::TocPathIsInvalid);
    }
  }

  // Determine the base extraction directory on disk
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
    for (const auto &entry : this->m_toc.GetEntries()) {
      if (entry.path == u"/")
        continue;
      if (entry.isDirectory()) {
        dirsToExtract.push_back(entry);
      } else {
        filesToExtract.push_back(entry);
      }
    }
  } else {
    auto _dirEnt = this->m_toc.GetEntry(normDir);
    if (!_dirEnt) {
      job.setStatus(JobStatus::Failed);
      if (callback)
        callback(job);
      return unexpected(_dirEnt.error());
    }
    auto allSubs =
        this->m_toc.GetDirectoryFileEntries(*_dirEnt, true /* recursive */);
    for (const auto &entry : allSubs) {
      if (entry.isDirectory()) {
        dirsToExtract.push_back(entry);
      } else {
        filesToExtract.push_back(entry);
      }
    }
  }

  job.setStatus(JobStatus::Running);
  job.totalBytes = filesToExtract.size();
  job.processedBytes = 0;
  job.percentage = filesToExtract.empty() ? 100 : 0;
  if (callback)
    callback(job);

  // Create subdirectories on disk
  for (const auto &dirEntry : dirsToExtract) {
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

  for (const auto &fileEntry : filesToExtract) {
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

    auto _extractRes =
        this->ExtractFileSync(fileEntry.path, targetDirStr, nullptr, stopToken);
    if (!_extractRes) {
      job.setStatus(JobStatus::Failed);
      if (callback)
        callback(job);
      return unexpected(_extractRes.error());
    }

    extractedFilesCount++;
    job.processedBytes = extractedFilesCount;
    job.percentage = filesToExtract.empty()
                         ? 100
                         : static_cast<uint32_t>((extractedFilesCount * 100) /
                                                 filesToExtract.size());
    if (callback)
      callback(job);
  }

  job.setStatus(JobStatus::Finished);
  job.processedBytes = extractedFilesCount;
  job.percentage = 100;
  if (callback)
    callback(job);

  return extractedFilesCount;
}

bool SeArchive::verifyJobs() {
  // Extraction jobs are strictly synchronous and cannot be queued or processed
  // as archive modification jobs
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

bool SeArchive::addJob(const SeJob &job) {
  // Extraction jobs are synchronous operations and cannot be queued as archive
  // modification jobs
  if (job.m_type == JobType::ExtractFile ||
      job.m_type == JobType::ExtractDirectory || job.m_type == JobType::None) {
    return false;
  }

  if (any_of(m_jobs.begin(), m_jobs.end(),
             [job](const SeJob &value) { return job.m_id == value.m_id; })) {
    return false;
  }

  m_jobs.push_back(job);
  return true;
}

void SeArchive::optimizeJobs() {
  auto arePathsEqual = [](const u16string &p1, const u16string &p2) -> bool {
    return SeTableOfContent::NormalizeArchivePath(p1) ==
           SeTableOfContent::NormalizeArchivePath(p2);
  };

  auto isUnderDirectory = [](const u16string &child,
                             const u16string &parentDir) -> bool {
    u16string normParent = SeTableOfContent::NormalizeDirectoryPath(parentDir);
    u16string normChild = SeTableOfContent::NormalizeArchivePath(child);
    return normChild.size() > normParent.size() &&
           normChild.starts_with(normParent);
  };

  // --- Pass 1: Deduplicate CompressionLevelChange jobs ---
  // If multiple compression changes are queued in a single transaction, keep
  // only the latest one.
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
      if (this->m_jobs[i].m_type != JobType::CompressionLevelChange) {
        filtered.push_back(move(this->m_jobs[i]));
      }
    }
    this->m_jobs = move(filtered);
  }

  // --- Pass 2: Iterative I/O Optimizer Loop ---
  // Simulates an I/O request scheduler: merges repeated jobs, cancels transient
  // additions/removals, eliminates redundant directory additions/deletions, and
  // folds move operations until a fixpoint is reached.
  bool changed = true;
  while (changed) {
    changed = false;

    for (size_t i = 0; i < this->m_jobs.size(); ++i) {
      auto &jobA = this->m_jobs[i];

      // 1. File Operation Optimizations
      if (jobA.m_type == JobType::AddFile) {
        for (size_t j = i + 1; j < this->m_jobs.size(); ++j) {
          auto &jobB = this->m_jobs[j];

          // Case 1A: Double AddFile on same archive destination
          // AddFile(P, disk1) followed by AddFile(P, disk2) -> drop jobA (disk2
          // overwrites disk1)
          if (jobB.m_type == JobType::AddFile &&
              arePathsEqual(jobA.m_fileName, jobB.m_fileName)) {
            this->m_jobs.erase(this->m_jobs.begin() + i);
            changed = true;
            break;
          }

          // Case 1B: AddFile followed by RemoveFile on same archive path
          if (jobB.m_type == JobType::RemoveFile &&
              arePathsEqual(jobA.m_fileName, jobB.m_fileName)) {
            if (!this->m_toc.CheckPath(jobA.m_fileName)) {
              // File was transient (created and deleted within this uncommitted
              // queue session). Both jobs cancel out completely!
              this->m_jobs.erase(this->m_jobs.begin() +
                                 j); // Erase later job first
              this->m_jobs.erase(this->m_jobs.begin() + i);
            } else {
              // File already existed in TOC originally. The AddFile was an
              // overwrite, but RemoveFile means it should be deleted. Drop
              // AddFile, keep RemoveFile.
              this->m_jobs.erase(this->m_jobs.begin() + i);
            }
            changed = true;
            break;
          }

          // Case 1C: AddFile followed by MoveArchiveFile
          // AddFile(src, disk) followed by MoveArchiveFile(src, dstDir) ->
          // Directly AddFile(dstDir/fileName, disk) and eliminate
          // MoveArchiveFile.
          if (jobB.m_type == JobType::MoveArchiveFile &&
              arePathsEqual(jobA.m_fileName, jobB.m_fileName)) {
            u16string fileName =
                SeTableOfContent::GetFileName(jobA.m_fileName);
            u16string targetPath =
                SeTableOfContent::CreateFilePath(jobB.m_filePath, fileName);
            jobA.m_fileName = targetPath;
            this->m_jobs.erase(this->m_jobs.begin() + j);
            changed = true;
            break;
          }
        }
        if (changed)
          break;
      } else if (jobA.m_type == JobType::RemoveFile) {
        for (size_t j = i + 1; j < this->m_jobs.size(); ++j) {
          auto &jobB = this->m_jobs[j];
          // Case 1D: Duplicate RemoveFile
          if (jobB.m_type == JobType::RemoveFile &&
              arePathsEqual(jobA.m_fileName, jobB.m_fileName)) {
            this->m_jobs.erase(this->m_jobs.begin() + j);
            changed = true;
            break;
          }
          // If an AddFile occurs on same path, stop scanning (valid sequence:
          // delete old, add new)
          if (jobB.m_type == JobType::AddFile &&
              arePathsEqual(jobA.m_fileName, jobB.m_fileName)) {
            break;
          }
        }
        if (changed)
          break;
      }
      // 2. Directory Operation Optimizations
      else if (jobA.m_type == JobType::AddDirectory) {
        for (size_t j = i + 1; j < this->m_jobs.size(); ++j) {
          auto &jobB = this->m_jobs[j];

          // Case 2A: Double AddDirectory
          if (jobB.m_type == JobType::AddDirectory &&
              arePathsEqual(jobA.m_fileName, jobB.m_fileName)) {
            this->m_jobs.erase(this->m_jobs.begin() + j);
            changed = true;
            break;
          }

          // Case 2B: AddDirectory followed by DeleteDirectory
          if (jobB.m_type == JobType::DeleteDirectory &&
              arePathsEqual(jobA.m_fileName, jobB.m_fileName)) {
            if (!this->m_toc.CheckPath(jobA.m_fileName)) {
              // Transient directory created & deleted in same batch -> cancel
              // both out!
              this->m_jobs.erase(this->m_jobs.begin() + j);
              this->m_jobs.erase(this->m_jobs.begin() + i);
            } else {
              // Pre-existed in TOC -> drop redundant Add, keep Delete
              this->m_jobs.erase(this->m_jobs.begin() + i);
            }
            changed = true;
            break;
          }

          // Case 2C: AddDirectory followed by MoveDirectory
          // AddDirectory(src) followed by MoveDirectory(src, dstDir) ->
          // Directly AddDirectory(dstDir/srcName) and eliminate MoveDirectory
          if (jobB.m_type == JobType::MoveDirectory &&
              arePathsEqual(jobA.m_fileName, jobB.m_fileName)) {
            u16string dirName =
                SeTableOfContent::GetFileName(jobA.m_fileName);
            u16string targetPath =
                SeTableOfContent::CreateDirPath(jobB.m_filePath, dirName);
            jobA.m_fileName = targetPath;
            this->m_jobs.erase(this->m_jobs.begin() + j);
            changed = true;
            break;
          }
        }
        if (changed)
          break;
      } else if (jobA.m_type == JobType::DeleteDirectory) {
        // Case 2D: Duplicate DeleteDirectory
        for (size_t j = i + 1; j < this->m_jobs.size(); ++j) {
          auto &jobB = this->m_jobs[j];
          if (jobB.m_type == JobType::DeleteDirectory &&
              arePathsEqual(jobA.m_fileName, jobB.m_fileName)) {
            this->m_jobs.erase(this->m_jobs.begin() + j);
            changed = true;
            break;
          }
        }
        if (changed)
          break;

        // Case 2E: DeleteDirectory subsumes newly added files/dirs inside this
        // directory
        for (size_t k = 0; k < i; ++k) {
          auto &priorJob = this->m_jobs[k];
          if ((priorJob.m_type == JobType::AddFile ||
               priorJob.m_type == JobType::AddDirectory) &&
              isUnderDirectory(priorJob.m_fileName, jobA.m_fileName)) {
            if (!this->m_toc.CheckPath(priorJob.m_fileName)) {
              // Transient item inside deleted directory; erase prior add job
              this->m_jobs.erase(this->m_jobs.begin() + k);
              changed = true;
              break;
            }
          }
        }
        if (changed)
          break;
      }
      // 3. Move Operation Merging & Folding
      else if (jobA.m_type == JobType::MoveArchiveFile) {
        // jobA: move from jobA.m_fileName (source file) to directory
        // jobA.m_filePath
        u16string fileBaseName =
            SeTableOfContent::GetFileName(jobA.m_fileName);
        u16string destFile =
            SeTableOfContent::CreateFilePath(jobA.m_filePath, fileBaseName);

        for (size_t j = i + 1; j < this->m_jobs.size(); ++j) {
          auto &jobB = this->m_jobs[j];

          // Case 3A: MoveArchiveFile followed by MoveArchiveFile (Chained move)
          if (jobB.m_type == JobType::MoveArchiveFile &&
              arePathsEqual(destFile, jobB.m_fileName)) {
            u16string origDir =
                SeTableOfContent::GetParentDirectory(jobA.m_fileName);
            // Check for round-trip move (moved back to original directory)
            if (arePathsEqual(origDir, jobB.m_filePath)) {
              // Net move is a no-op! Both moves cancel out completely.
              this->m_jobs.erase(this->m_jobs.begin() + j);
              this->m_jobs.erase(this->m_jobs.begin() + i);
            } else {
              // Chain: update jobA destination directory to jobB destination
              // directory
              jobA.m_filePath = jobB.m_filePath;
              this->m_jobs.erase(this->m_jobs.begin() + j);
            }
            changed = true;
            break;
          }

          // Case 3B: MoveArchiveFile followed by RemoveFile on destination
          if (jobB.m_type == JobType::RemoveFile &&
              arePathsEqual(destFile, jobB.m_fileName)) {
            jobA.m_type = JobType::RemoveFile;
            jobA.m_filePath.clear();
            this->m_jobs.erase(this->m_jobs.begin() + j);
            changed = true;
            break;
          }
        }
        if (changed)
          break;
      } else if (jobA.m_type == JobType::MoveDirectory) {
        // jobA: move directory from jobA.m_fileName to directory
        // jobA.m_filePath
        u16string dirBaseName =
            SeTableOfContent::GetFileName(jobA.m_fileName);
        u16string destDir =
            SeTableOfContent::CreateDirPath(jobA.m_filePath, dirBaseName);

        for (size_t j = i + 1; j < this->m_jobs.size(); ++j) {
          auto &jobB = this->m_jobs[j];

          // Case 4A: Chained directory moves
          if (jobB.m_type == JobType::MoveDirectory &&
              arePathsEqual(destDir, jobB.m_fileName)) {
            u16string origParentDir =
                SeTableOfContent::GetParentDirectory(jobA.m_fileName);
            if (arePathsEqual(origParentDir, jobB.m_filePath)) {
              // Round-trip move cancelled out
              this->m_jobs.erase(this->m_jobs.begin() + j);
              this->m_jobs.erase(this->m_jobs.begin() + i);
            } else {
              jobA.m_filePath = jobB.m_filePath;
              this->m_jobs.erase(this->m_jobs.begin() + j);
            }
            changed = true;
            break;
          }

          // Case 4B: MoveDirectory followed by DeleteDirectory
          if (jobB.m_type == JobType::DeleteDirectory &&
              arePathsEqual(destDir, jobB.m_fileName)) {
            jobA.m_type = JobType::DeleteDirectory;
            jobA.m_filePath.clear();
            this->m_jobs.erase(this->m_jobs.begin() + j);
            changed = true;
            break;
          }
        }
        if (changed)
          break;
      }
    }
  }
}
