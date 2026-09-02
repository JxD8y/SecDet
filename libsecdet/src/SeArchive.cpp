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
    //ProcessCallback will be called with jobs qeued in the job container
    
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
            case JobType::RemoveFile:
                _result = doRemoveFileJob(job,callback,stopToken);
            case JobType::AddDirectory:
                _result = doAddDirectoryJob(job,callback,stopToken);
            case JobType::DeleteDirectory:
                _result = doDeleteDirectoryJob(job,callback,stopToken);
            case JobType::MoveArchiveFile:
                _result = doMoveFileJob(job,callback,stopToken);
            case JobType::MoveDirectory:
                _result = doMoveDirectoryJob(job,callback,stopToken);
            case JobType::CompressionLevelChange:
                _result = doChangeCompressionLevel(job,callback,stopToken);
            case JobType::TestFile:
                _result = doTestFile(job,callback,stopToken);
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

                auto _cryptoResult = cryptoStreamSession->encryptChunk(span<unsigned char>{reinterpret_cast<unsigned char*>(outBuff.dst), outBuff.size}, cryptoOutBuffer);
                entry.compressed_size += cryptoOutBuffer.size(); // since we need the final size we have to include the aes tag bytes

                if (!_cryptoResult) {
                    job.setStatus(JobStatus::Failed);
                    if (callback)
                        callback(job);
                    return unexpected(_cryptoResult.error());
                }

                auto _wLError = m_archiveStream.write(cryptoOutBuffer);

                // Status report
                job.processedBytes = entry.compressed_size;
                job.percentage = (processedBytes / inFileStream.size()) * 100;

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
            this->m_toc.RemoveEntry(entry);
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

expected<size_t, error_code> SeArchive::ExtractDirectory(u16string fileName, u16string outputPath, ProgressCallback callback, stop_token stopToken) {
    // these are going to be sync functions
    return {};
}

expected<size_t, error_code> SeArchive::ExtractFile(u16string fileName, u16string outputPath, ProgressCallback callback, stop_token stopToken) {
    return {};
}

bool SeArchive::verifyJobs(){
    // Verifying job is not about telling wether its runned or not! you should check to see if it does conflict with other jobs or not!
    return true;
}

bool SeArchive::addJob(const SeJob& job){
    if (any_of(m_jobs.begin(), m_jobs.end(), [job](const SeJob& value) {
        return job.m_id == value.m_id;
    }))
    {
        return false;
    }
    
    m_jobs.push_back(job);
    return true;
}
