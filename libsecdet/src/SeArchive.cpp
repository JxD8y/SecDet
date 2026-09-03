#include "libsecdet/SeArchive.h"


expected<SeArchive,error_code> SeArchive::CreateArchive(uint16_t version,uint16_t compressionLevel, bool preserveMetadata,u16string archivePath){
    // Supported versions: 1
    if(version > 1)
        return unexpected(SeError::VersionNotSupported);
    if(compressionLevel > 0x3 || compressionLevel < 0x1)
        return unexpected(make_error_code(errc::invalid_argument));
    if(!SeArchive::verifyAbsPath(archivePath))
        return unexpected(make_error_code(errc::no_such_file_or_directory));
    
    auto _cctx = AesGcmContextProvider::CreateContext();

    if (!_cctx)
        return unexpected(_cctx.error());

    return expected<SeArchive, error_code>(in_place,SeMetadata(version,compressionLevel,preserveMetadata),SeTableOfContent::CreateNewTableOfContent(),archivePath,*move(_cctx));
}

expected<SeArchive,error_code> SeArchive::LoadArchiveFile(u16string path){
    
    if(!SeArchive::verifyAbsPath(path))
        return unexpected(make_error_code(errc::no_such_file_or_directory));
    

    MappedFileStream fs;
    if(auto _fs = fs.open(path); !_fs)
        return unexpected(_fs.error());

    fs.seek(0);
    
    vector<unsigned char> metadata_bytes(SE_METADATA_SIZE);

    // Just found out about the if with initializer !

    if(auto _sz = fs.read(metadata_bytes.data(),SE_METADATA_SIZE); !_sz){
        return unexpected(_sz.error());
    }
    
    auto _metadata = SeMetadata::LoadMetadataFromBytes(metadata_bytes);
    if(!_metadata)
        return unexpected(_metadata.error());
    
    SeMetadata metadata = *_metadata;

    uint64_t toc_offset = metadata.m_toc_offset;

    if(toc_offset > fs.size() )
        return unexpected(SeError::NoTOCFound);

    if(auto _cursor = fs.seek(toc_offset); !_cursor)
        return unexpected(_cursor.error());
    
    uint64_t toc_size = fs.size() - toc_offset;

    vector<unsigned char> toc_bytes(toc_size);

    if(auto _read = fs.read(toc_bytes.data(),toc_size); !_read) // WARN: current version has no recovery method , a simple truncation at the end of the file causes the TOC to be unreadable!
        return unexpected(_read.error());
    
    auto _toc = SeTableOfContent::LoadTableOfContentFromBytes(toc_bytes);
    if (!_toc)
        return unexpected(_toc.error());
    
    SeTableOfContent toc = *_toc;

    auto _cctx = AesGcmContextProvider::CreateContext();
    if (!_cctx)
        return unexpected(_cctx.error());

    return expected<SeArchive, error_code>(in_place, metadata, toc, path,*move(_cctx));
}

bool SeArchive::verifyAbsPath(u16string path){
    filesystem::path p(path);
    error_code err;
    if(!p.is_absolute())
        return false;

    return filesystem::exists(p,err) && !err;
}

expected<void,error_code> SeArchive::AddFile(u16string filePath,u16string fileName){
    if(!this->m_toc.CheckParentPath(filePath))
        return unexpected(SeError::TocPathIsInvalid);
    
    if(!this->verifyAbsPath(fileName))
        return unexpected(make_error_code(errc::no_such_file_or_directory));

    auto job = SeJob(JobType::AddFile,filePath,fileName);

    if(!this->addJob(job))
        return unexpected(SeError::CannotCreateJob);

    return {};
}

expected<void,error_code> SeArchive::RemoveFile(u16string fileName){
    if(!this->m_toc.CheckParentPath(fileName))
    return unexpected(SeError::TocPathIsInvalid);
    
    auto job = SeJob(JobType::RemoveFile,fileName,u"");
    
    if(!this->addJob(job))
        return unexpected(SeError::CannotCreateJob);

    return {};
}

expected<void,error_code> SeArchive::AddDirectory(u16string fileName){
    if(!this->m_toc.CheckParentPath(fileName))
    return unexpected(SeError::TocPathIsInvalid);
    
    auto job = SeJob(JobType::AddDirectory,fileName,u"");
    
    if(!this->addJob(job))
        return unexpected(SeError::CannotCreateJob);

    return {};
}

expected<void,error_code> SeArchive::DeleteDirectory(u16string fileName){
    if(!this->m_toc.CheckParentPath(fileName) || !this->m_toc.CheckPath(fileName))
        return unexpected(SeError::TocPathIsInvalid);
    
    auto job = SeJob(JobType::DeleteDirectory,fileName,u"");
    
    if(!this->addJob(job))
        return unexpected(SeError::CannotCreateJob);

    return {};
}

expected<void,error_code> SeArchive::MoveArchiveFile(u16string src,u16string dst){
    if(!this->m_toc.CheckPath(src) || !this->m_toc.CheckPath(dst))
        return unexpected(SeError::TocPathIsInvalid);
    
    auto job = SeJob(JobType::MoveArchiveFile,src,dst);
    
    if(!this->addJob(job))
        return unexpected(SeError::CannotCreateJob);

    return {};
}

expected<void,error_code> SeArchive::MoveDirectory(u16string fileName,u16string destPath){
    if(!this->m_toc.CheckPath(fileName) || !this->m_toc.CheckPath(destPath))
        return unexpected(SeError::TocPathIsInvalid);
    
    auto job = SeJob(JobType::MoveDirectory,fileName,destPath);
    
    if(!this->addJob(job))
        return unexpected(SeError::CannotCreateJob);

    return {};
}


    
expected<void,error_code> SeArchive::RegisterKey(string& key){ // Master Key does not go through a KDF we just use its hash value
    
    vector<unsigned char> key_hash(crypto_hash_sha256_BYTES);
    auto exp = sha256String(key,key_hash);
    if (!exp)
        return unexpected(exp.error());
    
    
    this->m_cryptoCtx.SetMasterKey(key_hash); // Set master key is not responsible for cleaning the left over of masterkey

    sodium_memzero(key_hash.data(), key_hash.size());

    return {};
}

bool SeArchive::IsKeyPresent(){
    return this->m_cryptoCtx.keyExists();
}

const vector<SeJob>& SeArchive::GetJobs(){
    return this->m_jobs;
}

expected<void,error_code> SeArchive::RemoveJob(int id){
    int removed = erase_if(this->m_jobs,[id](SeJob& job){
        if(job.m_id == id)
            return true;
        return false;
    });
    if(removed == 0)
        return unexpected(SeError::JobNotFound);
    
    return {};
}

void SeArchive::SetPreserveMetadata(bool preserve){
    if(this->m_metadata.m_preserve_metadata != preserve)
        this->m_metadata.SetPreserveMetadata(preserve);
}

void SeArchive::SetCompressionLevel(uint32_t compressionLevel){
    if(this->m_metadata.m_compression_level != compressionLevel)
        this->m_metadata.SetCompressionLevel(compressionLevel);
}

expected<void,error_code> SeArchive::SaveChangesSync(ProgressCallback callback , stop_token stopToken){
    // ProcessCallback will be called with jobs queued in the job container
    // Optimize queued jobs (merge duplicates, cancel transient ops, fold moves) prior to verification and execution
    this->optimizeJobs();

    if(!verifyJobs())
        return unexpected(SeError::ConflictingJobFound);
    
    // Checking the Io Status and preparing it ( check the archive file existance )
    // verifying TOC

    auto _exfs = this->m_archiveStream.open(this->m_archiveFilePath);
    if(!_exfs && _exfs.error() != SeError::StreamAlreadyOpen)
        return unexpected(_exfs.error());

    auto& fs = this->m_archiveStream;
    fs.seek(0);
    
    vector<unsigned char> metadata_bytes(SE_METADATA_SIZE);
    if(auto _sz = fs.read(metadata_bytes.data(),SE_METADATA_SIZE); !_sz){
        return unexpected(_sz.error());
    }
    auto _metadata = SeMetadata::LoadMetadataFromBytes(metadata_bytes);
    if(!_metadata)
        return unexpected(_metadata.error());
    SeMetadata metadata = *_metadata;

    if(metadata != this->m_metadata)
        return unexpected(SeError::ArchiveModified);


    uint64_t toc_offset = metadata.m_toc_offset;
    if(toc_offset > fs.size() )
        return unexpected(SeError::NoTOCFound);
    if(auto _cursor = fs.seek(toc_offset); !_cursor)
        return unexpected(_cursor.error());
    uint64_t toc_size = fs.size() - toc_offset;
    vector<unsigned char> toc_bytes(toc_size);
    if(auto _read = fs.read(toc_bytes.data(),toc_size); !_read)
        return unexpected(_read.error());
    auto _toc = SeTableOfContent::LoadTableOfContentFromBytes(toc_bytes);
    if(!_toc)
        return unexpected(SeError::NoTOCFound);
    auto fileToc = *_toc;
    if(fileToc != this->m_toc)
        return unexpected(SeError::ArchiveModified);
    
    fs.seek(0);

    // Toc verified now we can start the operations
    if(!this->IsReady())
    {
        //either TOC or metadata was modified internally and not saved on disk we have to address that
        return unexpected(SeError::ArchiveModified); // In any archive modified case you have to reload it again to be sure.
    }
    
    
    for(int i{0}; i < this->m_jobs.size() ; i++){
        
        auto& job = this->m_jobs[i];

        if(stopToken.stop_requested())
            return unexpected(SeError::OperationCanceled);

        if(job.m_status != JobStatus::Idle)
            return unexpected(SeError::JobIsNotIdle);
        
        // WARN: this level of job seperation will introduce overhead with archives that have complex file system -> jobs should be able to merge
        expected<void,error_code> _result;
    
        switch (job.m_type)
        {
            case JobType::None: 
                return unexpected(SeError::InvalidJob);
            case JobType::AddFile:
                _result = doAddFileJob(job,callback,stopToken);
                break;
            case JobType::RemoveFile:
                _result = doRemoveFileJob(job,callback,stopToken);
                break;
            case JobType::AddDirectory:
                _result = doAddDirectoryJob(job,callback,stopToken);
                break;
            case JobType::DeleteDirectory:
                _result = doDeleteDirectoryJob(job,callback,stopToken);
                break;
            case JobType::MoveArchiveFile:
                _result = doMoveFileJob(job,callback,stopToken);
                break;
            case JobType::MoveDirectory:
                _result = doMoveDirectoryJob(job,callback,stopToken);
                break;
            case JobType::CompressionLevelChange:
                _result = doChangeCompressionLevel(job,callback,stopToken);
                break;
            case JobType::TestFile:
                _result = doTestFile(job,callback,stopToken);
                break;
        }

        if(!_result) // whatever happen here we should fix the TOC then exit
            return unexpected(_result.error());

        // after doing this ops the TOC and metadata both should be updated and re-written on disk!
    }
}


// @Private

expected<void,error_code> SeArchive::doAddFileJob(SeJob& job, ProgressCallback callback , stop_token stopToken){
    job.m_status = JobStatus::Pending;
    
    if (stopToken.stop_requested()) {
        job.setStatus(JobStatus::Aborted);
        if (callback)
            callback(job);

        return unexpected(SeError::OperationCanceled);
    }
    
    if(callback != nullptr)
        callback(job);
    
    MappedFileStream inFileStream;
    if(auto _fs = inFileStream.open(job.m_filePath,FileMode::OpenExisting); !_fs){
        return unexpected(_fs.error());
    }

    SeArchiveEntry entry = SeArchiveEntry::CreateFileEntry(this->m_toc.GetFileName(job.m_fileName)); // Important: the header entry will have only file name, the TOC will contains full path!
    entry.uncompressed_size = inFileStream.size();
    entry.attributes = 0; //Dont know and care how to get and set file attr for now !
    entry.offset = this->m_toc.getNextAvailOffset();
    entry.fileUid = getSecureRandom();
    entry.crc32 = CRC32C_INIT;

    size_t fileOffset = this->m_toc.getNextAvailOffset();

    // Before doing anything we will start writing the file header ( entry placeholder in its place )
    
    if (auto _sk = this->m_archiveStream.seek(entry.offset); !_sk)
    {
        // either the file is not big enough or some error in the getNextAvailOffset caused this
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

    m_archiveStream.flush(); // assuming that the only possible error here is closed handle which will likely occure on top!

    // Setting up file compression

    int cLevel = this->m_metadata.GetCompressionLevel() == 1 ? 1 : this->m_metadata.GetCompressionLevel() == 2 ? 15 : 19;

    size_t param_err = ZSTD_CCtx_setParameter(this->m_zstdCctx.get(), ZSTD_c_compressionLevel, cLevel);
    
    size_t readSz = ZSTD_CStreamInSize();
    size_t writeSz = ZSTD_CStreamOutSize();

    vector<unsigned char> inBuffer(readSz);
    vector<unsigned char> outBuffer(writeSz);

    auto _cryptoStream = this->m_cryptoCtx.createSession(entry.fileUid);
    if (!_cryptoStream) {
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);

        return unexpected(_cryptoStream.error());
    }

    unique_ptr<AesGcmStreamSession> cryptoStreamSession = *move(_cryptoStream);

    vector<unsigned char> cryptoOutBuffer(writeSz + AesGcmStreamSession::TAG_BYTES);

    bool isLastChunk = false;

    job.setStatus(JobStatus::Running);
    job.totalBytes = inFileStream.size();

    if (callback)
        callback(job);

    size_t processedBytes = 0;
    while (!isLastChunk) {
        
        if (stopToken.stop_requested()) {
            if (entry.compressed_size > 0) {
                // Reverting disk changes
                this->m_archiveStream.seek(entry.offset);
                // No other disk changes required
                job.setStatus(JobStatus::Aborted);
                if (callback)
                    callback(job);
                return unexpected(SeError::OperationCanceled);
            }
        }

        auto _rd = inFileStream.read(inBuffer.data(), readSz);
        if (!_rd) {
            job.setStatus(JobStatus::Failed);
            if (callback)
                callback(job);
            return unexpected(_rd.error());
        }

        isLastChunk = (*_rd < readSz) || inFileStream.eof(); // if file size is exact multiple of readsz then it wouldnt exit the loop in time causing problem!
        ZSTD_EndDirective mode = isLastChunk ? ZSTD_e_end : ZSTD_e_continue;

        ZSTD_inBuffer inBuff{ inBuffer.data(),*_rd,0 };
        bool finished = false;

        while (!finished) {
            ZSTD_outBuffer outBuff = { outBuffer.data(),writeSz,0 };

            size_t remaining = ZSTD_compressStream2(this->m_zstdCctx.get(), &outBuff, &inBuff, mode);

            if (ZSTD_isError(remaining)) {
                job.setStatus(JobStatus::Failed);
                if (callback)
                    callback(job);

                return unexpected(SeError::ZSTDCompressionError);
            }

            
            if (outBuff.pos > 0) {
                processedBytes += inBuff.size;

                auto _cryptoResult = cryptoStreamSession->encryptChunk(span<unsigned char>{reinterpret_cast<unsigned char*>(outBuff.dst), outBuff.pos}, cryptoOutBuffer);
                entry.compressed_size += outBuff.pos + AesGcmStreamSession::TAG_BYTES; // the outbuff.pos is the real byte count out of compression

                if (!_cryptoResult) {
                    job.setStatus(JobStatus::Failed);
                    if (callback)
                        callback(job);
                    return unexpected(_cryptoResult.error());
                }

                auto _wLError = m_archiveStream.write(cryptoOutBuffer);

                // Status report
                job.processedBytes = entry.compressed_size;
                job.percentage = inFileStream.size() == 0 ? 100 : (processedBytes / inFileStream.size()) * 100;

                if (callback)
                    callback(job);

                if (!_wLError) {
                    job.setStatus(JobStatus::Failed);
                    if (callback)
                        callback(job);
                    return unexpected(_wLError.error());
                }
            }
            
            if (mode == ZSTD_e_end) {
                finished = remaining == 0;
            }
            else {
                finished = inBuff.pos == inBuff.size;
            }


        }
        // doing the crc32 and compression tracking
        uint64_t t_crc = entry.crc32;
        entry.crc32 = crc32c_update(t_crc, inBuff.src, inBuff.size);
    }

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

    this->m_toc.AddEntry(entry); // Unlikely to get an error here !

    job.setStatus(JobStatus::Finished);
    if (callback)
        callback(job);
}

expected<void, error_code> SeArchive::doRemoveFileJob(SeJob& job, ProgressCallback callback, stop_token stopToken) {

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
    auto& entry = *_entError;
    
    auto inFileEntrySize = entry.GetDiskSize();
    // Move files that are in front of the requested file entry.compressedSize + entrysize backward then truncate
    auto frontEntries = this->m_toc.GetEntriesFollowing(entry);

    if (frontEntries.size() == 0) {
        job.setStatus(JobStatus::Running);
        if (callback)
            callback(job);
        // No front entries
        // Only trunking
        if (auto _err = this->m_archiveStream.truncate(this->m_archiveStream.size() - inFileEntrySize); !_err) {
            job.setStatus(JobStatus::Failed);
            if (callback)
                callback(job);

            return unexpected(_err.error());
        }

        job.setStatus(JobStatus::Finished);
        if (callback)
            callback(job);
        
        return {};
    }
    else {
        // Files are in front of entry
        // Pushing them back one by one until the last one!
        
        // The front entries does not return entries sorted by their offset!
        job.setStatus(JobStatus::Running);
        if (callback)
            callback(job);

        sort(frontEntries.begin(), frontEntries.end(), [](SeArchiveEntry& a , SeArchiveEntry& b) {
            return a.offset < b.offset;
        });

        size_t shifted = 0;

        for (int i{ 0 }; i < frontEntries.size(); i++) { // cancelation token will be ignored here; else it would be too time consuming to revert everything back to before!
            auto& frontEnt = frontEntries[i];

            job.percentage = (i / frontEntries.size()) * 100;
            if (callback)
                callback(job);
            
            size_t entrySize = frontEnt.GetDiskSize();

            if (auto _err = this->m_archiveStream.shift_bytes(shifted + entry.offset, frontEnt.offset, entrySize); !_err) {
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

expected<void, error_code> SeArchive::doAddDirectoryJob(SeJob& job, ProgressCallback callback, stop_token stopToken) {
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

expected<void, error_code> SeArchive::doDeleteDirectoryJob(SeJob& job, ProgressCallback callback, stop_token stopToken) {
    
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
    }
    else {
        // Removing files

        for (int i{ 0 }; i < dirEntries.size(); i++) { // Same as doRemoveFile no stopToken is processed here cause makes the reverting task harder!
            
            auto fileEntry = dirEntries[i];

            job.percentage = (i / dirEntries.size()) * 100;
            if (callback)
                callback(job);

            // Not very efficient but i will call the doRemoveFile with my own file entries

            SeJob jFileRemove(JobType::RemoveFile, fileEntry.path, u"");
            auto _remove = doRemoveFileJob(jFileRemove, nullptr, stopToken); // no need for callback since we are the reporter!
            if (!_remove) {

                job.setStatus(JobStatus::Failed);
                if (callback)
                    callback(job);
                return unexpected(_remove.error());
            }
        }

        this->m_toc.RemoveEntry(dir);
        job.setStatus(JobStatus::Finished);
        if (callback)
            callback(job);
        return {};
    }
}

expected<void, error_code> SeArchive::doMoveFileJob(SeJob& job, ProgressCallback callback, stop_token stopToken) {
    // File header entries are just file name and not needed to be moved around upon the file moves!

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

    if (!this->m_toc.CheckPath(job.m_filePath) || !this->m_toc.IsDirectory(job.m_filePath)) {
        // Sloppiness at job verification can cause this
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);
        return unexpected(SeError::TocPathIsInvalid);
    }
    
    auto finalPath = this->m_toc.CreateFilePath(job.m_filePath, fileName); // No need to retrieve the dest directory entry
    
    this->m_toc.RemoveEntry(entry);

    entry.path = finalPath;
    
    this->m_toc.AddEntry(entry);

    job.setStatus(JobStatus::Finished);
    if (callback)
        callback(job);
    return {};
    
}

expected<void, error_code> SeArchive::doMoveDirectoryJob(SeJob& job, ProgressCallback callback, stop_token stopToken) {
    
    job.setStatus(JobStatus::Pending);
    if (callback)
        callback(job);

    if (stopToken.stop_requested()) {
        job.setStatus(JobStatus::Aborted);
        if (callback)
            callback(job);
        return unexpected(SeError::OperationCanceled);
    }

    if (!this->m_toc.CheckPath(job.m_fileName) || !this->m_toc.IsDirectory(job.m_fileName) || !this->m_toc.CheckPath(job.m_filePath) || !this->m_toc.IsDirectory(job.m_filePath)) {
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);
        return unexpected(SeError::TocPathIsInvalid);
    }

    auto _ent = this->m_toc.GetEntry(job.m_fileName);
    if (!_ent){
        job.setStatus(JobStatus::Failed);
        if (callback)
            callback(job);
        return unexpected(_ent.error());
    }
    auto entry = *_ent;

    auto newDirPath = this->m_toc.CreateDirPath(job.m_filePath, this->m_toc.GetFileName(entry.path));

    auto entrySubs = this->m_toc.GetDirectoryFileEntries(entry);

    if (entrySubs.size() == 0) {
        this->m_toc.RemoveEntry(entry);
        entry.path = newDirPath;
        this->m_toc.AddEntry(entry);

        job.setStatus(JobStatus::Finished);
        if (callback)
            callback(job);
        return {};
    }
    else {
        
        for (int i{ 0 }; i < entrySubs.size(); i++) {

            auto subEntry = entrySubs[i];
            
            if (subEntry.isDirectory()) {
                auto newPath = this->m_toc.CreateDirPath(newDirPath, this->m_toc.GetFileName(subEntry.path));
                SeJob jMove(JobType::MoveDirectory, subEntry.path, newPath);
                auto _move = doMoveDirectoryJob(jMove, nullptr, stopToken);
                if (!_move)
                {
                    job.setStatus(JobStatus::Failed);
                    if (callback)
                        callback(job);
                    return unexpected(_move.error());
                }
            }
            else {
                auto newPath = this->m_toc.CreateDirPath(newDirPath, this->m_toc.GetFileName(subEntry.path));
                SeJob jMove(JobType::MoveArchiveFile, subEntry.path, newPath);
                auto _move = doMoveFileJob(jMove, nullptr, stopToken);
                if (!_move)
                {
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

expected<void, error_code> SeArchive::doChangeCompressionLevel(SeJob& job, ProgressCallback callback, stop_token stopToken) { // left un declared until tests
    // This one here is also a fundamental task! its much safer to apply the changes in a temp archive then rename it to the main !
    return {};
}

expected<void, error_code> SeArchive::doTestFile(SeJob& job, ProgressCallback callback, stop_token stopToken) {
    // Just test Extract file and calculate the uncompressed size and crc32
    return {};
}

expected<size_t, error_code> SeArchive::ExtractFileSync(u16string fileName, u16string outputPath, ProgressCallback callback, stop_token stopToken) {
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
    
    if (stopToken.stop_requested()) {
        job.setStatus(JobStatus::Aborted);
        if (callback)
            callback(job);
        return unexpected(SeError::OperationCanceled);
    }


    return {};
}

expected<size_t, error_code> SeArchive::ExtractDirectorySync(u16string fileName, u16string outputPath, ProgressCallback callback, stop_token stopToken) {
    // these are going to be sync functions
    return {};
}


bool SeArchive::verifyJobs(){
    // Extraction jobs are strictly synchronous and cannot be queued or processed as archive modification jobs
    for (const auto& job : this->m_jobs) {
        if (job.m_type == JobType::ExtractFile || job.m_type == JobType::ExtractDirectory || job.m_type == JobType::None) {
            return false;
        }
        if (job.m_status != JobStatus::Idle) {
            return false;
        }
    }
    return true;
}

bool SeArchive::addJob(const SeJob& job){
    // Extraction jobs are synchronous operations and cannot be queued as archive modification jobs
    if (job.m_type == JobType::ExtractFile || job.m_type == JobType::ExtractDirectory || job.m_type == JobType::None) {
        return false;
    }

    if (any_of(m_jobs.begin(), m_jobs.end(), [job](const SeJob& value) {
        return job.m_id == value.m_id;
    }))
    {
        return false;
    }
    
    m_jobs.push_back(job);
    return true;
}

void SeArchive::optimizeJobs() {
    // Helper lambda to normalize archive path separators
    auto normalizeArchivePath = [](const u16string& path) -> u16string {
        u16string res = path;
        for (auto& ch : res) {
            if (ch == u'\\') ch = u'/';
        }
        return res;
    };

    // Helper lambda to compare paths uniformly
    auto arePathsEqual = [&](const u16string& p1, const u16string& p2) -> bool {
        return normalizeArchivePath(p1) == normalizeArchivePath(p2);
    };

    // Helper lambda to extract base item name (file or directory name)
    auto getArchiveItemName = [&](const u16string& path) -> u16string {
        u16string norm = normalizeArchivePath(path);
        if (norm.empty()) return u"";
        while (norm.size() > 1 && norm.back() == u'/') {
            norm.pop_back();
        }
        size_t lastSlash = norm.find_last_of(u'/');
        if (lastSlash != u16string::npos) {
            return norm.substr(lastSlash + 1);
        }
        return norm;
    };

    // Helper lambda to combine parent directory and item name
    auto combineArchivePath = [&](const u16string& dir, const u16string& name) -> u16string {
        u16string normDir = normalizeArchivePath(dir);
        u16string normName = normalizeArchivePath(name);
        while (!normName.empty() && normName.front() == u'/') {
            normName.erase(normName.begin());
        }
        if (normDir.empty()) {
            return normName;
        }
        if (normDir.back() != u'/') {
            normDir.push_back(u'/');
        }
        return normDir + normName;
    };

    // Helper lambda to extract parent directory path from a full path
    auto getArchiveItemDir = [&](const u16string& path) -> u16string {
        u16string norm = normalizeArchivePath(path);
        if (norm.empty()) return u"";
        while (norm.size() > 1 && norm.back() == u'/') {
            norm.pop_back();
        }
        size_t lastSlash = norm.find_last_of(u'/');
        if (lastSlash != u16string::npos) {
            return norm.substr(0, lastSlash + 1);
        }
        return u"";
    };

    // Helper lambda to check if child path resides inside parent directory
    auto isUnderDirectory = [&](const u16string& child, const u16string& parentDir) -> bool {
        u16string normChild = normalizeArchivePath(child);
        u16string normParent = normalizeArchivePath(parentDir);
        if (normParent.empty()) return false;
        if (normParent.back() != u'/') {
            normParent.push_back(u'/');
        }
        return normChild.size() > normParent.size() && normChild.compare(0, normParent.size(), normParent) == 0;
    };

    // Helper lambda to check if a path already exists in current archive TOC
    auto existsInTOC = [&](const u16string& path) -> bool {
        u16string norm = normalizeArchivePath(path);
        for (const auto& entry : this->m_toc.GetEntries()) {
            if (normalizeArchivePath(entry.path) == norm) {
                return true;
            }
        }
        return false;
    };

    // --- Pass 1: Deduplicate CompressionLevelChange jobs ---
    // If multiple compression changes are queued in a single transaction, keep only the latest one.
    int lastCompressionIdx = -1;
    for (int i = 0; i < static_cast<int>(this->m_jobs.size()); ++i) {
        if (this->m_jobs[i].m_type == JobType::CompressionLevelChange) {
            lastCompressionIdx = i;
        }
    }
    if (lastCompressionIdx != -1) {
        vector<SeJob> filtered;
        filtered.reserve(this->m_jobs.size());
        for (int i = 0; i < static_cast<int>(this->m_jobs.size()); ++i) {
            if (this->m_jobs[i].m_type == JobType::CompressionLevelChange) {
                if (i == lastCompressionIdx) {
                    filtered.push_back(move(this->m_jobs[i]));
                }
            } else {
                filtered.push_back(move(this->m_jobs[i]));
            }
        }
        this->m_jobs = move(filtered);
    }

    // --- Pass 2: Iterative I/O Optimizer Loop ---
    // Simulates an I/O request scheduler: merges repeated jobs, cancels transient additions/removals,
    // eliminates redundant directory additions/deletions, and folds move operations until a fixpoint is reached.
    bool changed = true;
    while (changed) {
        changed = false;

        for (size_t i = 0; i < this->m_jobs.size(); ++i) {
            auto& jobA = this->m_jobs[i];

            // 1. File Operation Optimizations
            if (jobA.m_type == JobType::AddFile) {
                for (size_t j = i + 1; j < this->m_jobs.size(); ++j) {
                    auto& jobB = this->m_jobs[j];

                    // Case 1A: Double AddFile on same archive destination
                    // AddFile(P, disk1) followed by AddFile(P, disk2) -> drop jobA (disk2 overwrites disk1)
                    if (jobB.m_type == JobType::AddFile && arePathsEqual(jobA.m_fileName, jobB.m_fileName)) {
                        this->m_jobs.erase(this->m_jobs.begin() + i);
                        changed = true;
                        break;
                    }

                    // Case 1B: AddFile followed by RemoveFile on same archive path
                    if (jobB.m_type == JobType::RemoveFile && arePathsEqual(jobA.m_fileName, jobB.m_fileName)) {
                        if (!existsInTOC(jobA.m_fileName)) {
                            // File was transient (created and deleted within this uncommitted queue session).
                            // Both jobs cancel out completely!
                            this->m_jobs.erase(this->m_jobs.begin() + j); // Erase later job first
                            this->m_jobs.erase(this->m_jobs.begin() + i);
                        } else {
                            // File already existed in TOC originally. The AddFile was an overwrite,
                            // but RemoveFile means it should be deleted. Drop AddFile, keep RemoveFile.
                            this->m_jobs.erase(this->m_jobs.begin() + i);
                        }
                        changed = true;
                        break;
                    }

                    // Case 1C: AddFile followed by MoveArchiveFile
                    // AddFile(src, disk) followed by MoveArchiveFile(src, dstDir) ->
                    // Directly AddFile(dstDir/fileName, disk) and eliminate MoveArchiveFile.
                    if (jobB.m_type == JobType::MoveArchiveFile && arePathsEqual(jobA.m_fileName, jobB.m_fileName)) {
                        u16string fileName = getArchiveItemName(jobA.m_fileName);
                        u16string targetPath = combineArchivePath(jobB.m_filePath, fileName);
                        jobA.m_fileName = targetPath;
                        this->m_jobs.erase(this->m_jobs.begin() + j);
                        changed = true;
                        break;
                    }
                }
                if (changed) break;
            }
            else if (jobA.m_type == JobType::RemoveFile) {
                for (size_t j = i + 1; j < this->m_jobs.size(); ++j) {
                    auto& jobB = this->m_jobs[j];
                    // Case 1D: Duplicate RemoveFile
                    if (jobB.m_type == JobType::RemoveFile && arePathsEqual(jobA.m_fileName, jobB.m_fileName)) {
                        this->m_jobs.erase(this->m_jobs.begin() + j);
                        changed = true;
                        break;
                    }
                    // If an AddFile occurs on same path, stop scanning (valid sequence: delete old, add new)
                    if (jobB.m_type == JobType::AddFile && arePathsEqual(jobA.m_fileName, jobB.m_fileName)) {
                        break;
                    }
                }
                if (changed) break;
            }
            // 2. Directory Operation Optimizations
            else if (jobA.m_type == JobType::AddDirectory) {
                for (size_t j = i + 1; j < this->m_jobs.size(); ++j) {
                    auto& jobB = this->m_jobs[j];

                    // Case 2A: Double AddDirectory
                    if (jobB.m_type == JobType::AddDirectory && arePathsEqual(jobA.m_fileName, jobB.m_fileName)) {
                        this->m_jobs.erase(this->m_jobs.begin() + j);
                        changed = true;
                        break;
                    }

                    // Case 2B: AddDirectory followed by DeleteDirectory
                    if (jobB.m_type == JobType::DeleteDirectory && arePathsEqual(jobA.m_fileName, jobB.m_fileName)) {
                        if (!existsInTOC(jobA.m_fileName)) {
                            // Transient directory created & deleted in same batch -> cancel both out!
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
                    if (jobB.m_type == JobType::MoveDirectory && arePathsEqual(jobA.m_fileName, jobB.m_fileName)) {
                        u16string dirName = getArchiveItemName(jobA.m_fileName);
                        u16string targetPath = combineArchivePath(jobB.m_filePath, dirName);
                        if (targetPath.empty() || targetPath.back() != u'/') {
                            targetPath.push_back(u'/');
                        }
                        jobA.m_fileName = targetPath;
                        this->m_jobs.erase(this->m_jobs.begin() + j);
                        changed = true;
                        break;
                    }
                }
                if (changed) break;
            }
            else if (jobA.m_type == JobType::DeleteDirectory) {
                // Case 2D: Duplicate DeleteDirectory
                for (size_t j = i + 1; j < this->m_jobs.size(); ++j) {
                    auto& jobB = this->m_jobs[j];
                    if (jobB.m_type == JobType::DeleteDirectory && arePathsEqual(jobA.m_fileName, jobB.m_fileName)) {
                        this->m_jobs.erase(this->m_jobs.begin() + j);
                        changed = true;
                        break;
                    }
                }
                if (changed) break;

                // Case 2E: DeleteDirectory subsumes newly added files/dirs inside this directory
                for (size_t k = 0; k < i; ++k) {
                    auto& priorJob = this->m_jobs[k];
                    if ((priorJob.m_type == JobType::AddFile || priorJob.m_type == JobType::AddDirectory) &&
                        isUnderDirectory(priorJob.m_fileName, jobA.m_fileName)) {
                        if (!existsInTOC(priorJob.m_fileName)) {
                            // Transient item inside deleted directory; erase prior add job
                            this->m_jobs.erase(this->m_jobs.begin() + k);
                            changed = true;
                            break;
                        }
                    }
                }
                if (changed) break;
            }
            // 3. Move Operation Merging & Folding
            else if (jobA.m_type == JobType::MoveArchiveFile) {
                // jobA: move from jobA.m_fileName (source file) to directory jobA.m_filePath
                u16string fileBaseName = getArchiveItemName(jobA.m_fileName);
                u16string destFile = combineArchivePath(jobA.m_filePath, fileBaseName);

                for (size_t j = i + 1; j < this->m_jobs.size(); ++j) {
                    auto& jobB = this->m_jobs[j];

                    // Case 3A: MoveArchiveFile followed by MoveArchiveFile (Chained move)
                    if (jobB.m_type == JobType::MoveArchiveFile && arePathsEqual(destFile, jobB.m_fileName)) {
                        u16string origDir = getArchiveItemDir(jobA.m_fileName);
                        // Check for round-trip move (moved back to original directory)
                        if (arePathsEqual(origDir, jobB.m_filePath)) {
                            // Net move is a no-op! Both moves cancel out completely.
                            this->m_jobs.erase(this->m_jobs.begin() + j);
                            this->m_jobs.erase(this->m_jobs.begin() + i);
                        } else {
                            // Chain: update jobA destination directory to jobB destination directory
                            jobA.m_filePath = jobB.m_filePath;
                            this->m_jobs.erase(this->m_jobs.begin() + j);
                        }
                        changed = true;
                        break;
                    }

                    // Case 3B: MoveArchiveFile followed by RemoveFile on destination
                    if (jobB.m_type == JobType::RemoveFile && arePathsEqual(destFile, jobB.m_fileName)) {
                        jobA.m_type = JobType::RemoveFile;
                        jobA.m_filePath.clear();
                        this->m_jobs.erase(this->m_jobs.begin() + j);
                        changed = true;
                        break;
                    }
                }
                if (changed) break;
            }
            else if (jobA.m_type == JobType::MoveDirectory) {
                // jobA: move directory from jobA.m_fileName to directory jobA.m_filePath
                u16string dirBaseName = getArchiveItemName(jobA.m_fileName);
                u16string destDir = combineArchivePath(jobA.m_filePath, dirBaseName);
                if (destDir.empty() || destDir.back() != u'/') destDir.push_back(u'/');

                for (size_t j = i + 1; j < this->m_jobs.size(); ++j) {
                    auto& jobB = this->m_jobs[j];

                    // Case 4A: Chained directory moves
                    if (jobB.m_type == JobType::MoveDirectory && arePathsEqual(destDir, jobB.m_fileName)) {
                        u16string origParentDir = getArchiveItemDir(jobA.m_fileName);
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
                    if (jobB.m_type == JobType::DeleteDirectory && arePathsEqual(destDir, jobB.m_fileName)) {
                        jobA.m_type = JobType::DeleteDirectory;
                        jobA.m_filePath.clear();
                        this->m_jobs.erase(this->m_jobs.begin() + j);
                        changed = true;
                        break;
                    }
                }
                if (changed) break;
            }
        }
    }
}
