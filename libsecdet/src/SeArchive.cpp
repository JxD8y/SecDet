#include "libsecdet/SeArchive.h"


expected<SeArchive,error_code> SeArchive::CreateArchive(uint16_t version,uint16_t compressionLevel, bool preserveMetadata,u16string archivePath){
    // Supported versions: 1
    if(version > 1)
        return unexpected(SeError::VersionNotSupported);
    if(compressionLevel > 0x3 || compressionLevel < 0x1)
        return unexpected(make_error_code(errc::invalid_argument));
    if(!SeArchive::verifyAbsPath(archivePath))
        return unexpected(make_error_code(errc::no_such_file_or_directory));
    
    
    return expected<SeArchive, error_code>(in_place,SeMetadata(version,compressionLevel,preserveMetadata),SeTableOfContent::CreateNewTableOfContent(),archivePath);
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

    return expected<SeArchive, error_code>(in_place, metadata, toc, path);
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

expected<void,error_code> SeArchive::MoveArchiveFile(u16string fileName,u16string destPath){
    if(!this->m_toc.CheckPath(fileName) || !this->m_toc.CheckPath(destPath))
        return unexpected(SeError::TocPathIsInvalid);
    
    auto job = SeJob(JobType::MoveArchiveFile,fileName,destPath);
    
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


// Key will be stored internally by storing its hash value 
expected<void,error_code> SeArchive::RegisterKey(string& key){
    if(this->m_archiveKeys.size() == SE_ARCHIVE_KEY_LIM)
        return unexpected(SeError::KeyLimitReached);
    
    vector<unsigned char> key_hash(crypto_hash_sha256_BYTES);
    auto exp = sha256String(key,key_hash);
    if (!exp)
        return unexpected(exp.error());
    
    bool exists = false;
    for(vector<unsigned char>& hashKey: this->m_archiveKeys){
        if(secureBufferCompare(hashKey,key_hash))
        {
            exists = true;
            break;
        }
    }
    if(exists)
        return unexpected(SeError::KeyAlreadyExists);
    
    this->m_archiveKeys.push_back(move(key_hash));

    return {};
}

bool SeArchive::IsKeyPresent(){
    if(this->m_archiveKeys.size() != 0)
        return true;
    return false;
}

expected<void,error_code> SeArchive::RemoveKey(string& key){
    if(this->m_archiveKeys.size() == SE_ARCHIVE_KEY_LIM)
        return unexpected(SeError::KeyDoesNotExist);
    
    vector<unsigned char> key_hash(crypto_hash_sha256_BYTES);
    auto exp = sha256String(key,key_hash);
    if (!exp)
        return unexpected(exp.error());
    
    bool exists = false;
    for(int i{0}; i <= this->m_archiveKeys.size(); i++){
        auto hashKey = this->m_archiveKeys[i];
        if(secureBufferCompare(hashKey,key_hash))
        {
            this->m_archiveKeys.erase(this->m_archiveKeys.begin() + i);
            exists = true;
            break;
        }
    }
    if(!exists)
        return unexpected(SeError::KeyDoesNotExist);

    return {};
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


expected<void,error_code> SeArchive::TestFileSync(u16string fileName,ProgressCallback callback,stop_token stopToken){
    return {};
}


expected<size_t,error_code> SeArchive::ExtractDirectory(u16string fileName,u16string outputPath,ProgressCallback callback,stop_token stopToken){
    return {};
}

expected<size_t,error_code> SeArchive::ExtractFile(u16string fileName,u16string outputPath, ProgressCallback callback,stop_token stopToken){
    return {};
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

        if(!_result)
            return unexpected(_result.error());
    }
}


// @Private

expected<void,error_code> SeArchive::doAddFileJob(SeJob& job, ProgressCallback callback , stop_token stopToken){
    job.m_status = JobStatus::Pending;
    
    if(stopToken.stop_requested())
        return unexpected(SeError::OperationCanceled);
    
    if(callback != nullptr)
        callback(job);
    
    MappedFileStream inFileStream;
    if(auto _fs = inFileStream.open(job.m_filePath,FileMode::OpenExisting); !_fs){
        return unexpected(_fs.error());
    }

    SeArchiveEntry entry;
    entry.path = job.m_fileName;
    entry.uncompressed_size = inFileStream.size();
    entry.attributes = 0; //Dont know and care how to get and set file attr for now !
    entry.offset = 0;

    size_t fileOffset = this->m_toc.getNextAvailOffset();

    // Setting up file compression

    int cLevel = this->m_metadata.GetCompressionLevel() == 1 ? 1 : this->m_metadata.GetCompressionLevel() == 2 ? 15 : 19;

    size_t param_err = ZSTD_CCtx_setParameter(this->m_zstdCctx.get(), ZSTD_c_compressionLevel, cLevel);
    
    size_t readSz = ZSTD_CStreamInSize();
    size_t writeSz = ZSTD_CStreamOutSize();
    vector<unsigned char> inBuffer(readSz);
    vector<unsigned char> outBuffer(writeSz);

    while (!inFileStream.eof()) {
        auto _rd = inFileStream.read(inBuffer.data(), readSz);
        if (!_rd) {
            return unexpected(_rd.error());
        }
        ZSTD_EndDirective mode = *_rd < readSz ? ZSTD_e_end : ZSTD_e_continue;
        ZSTD_inBuffer inBuff{ inBuffer.data(),*_rd,0 };
        bool finished = false;

        while (!finished) {
            ZSTD_outBuffer outBuff = { outBuffer.data(),writeSz,0 };

            size_t remaining = ZSTD_compressStream2(this->m_zstdCctx.get(), &outBuff, &inBuff, mode);

            if (ZSTD_isError(remaining)) {
                return unexpected(SeError::ZSTDCompressionError);
            }

            finished = *_rd < readSz ? (remaining == 0) : (inBuff.pos == inBuff.size); // Either not fully take the input in or it needs one more pass to write footer
        

        }
    }



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
