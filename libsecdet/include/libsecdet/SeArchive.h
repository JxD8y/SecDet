#pragma once
#include <string>
#include <vector>
#include <expected>
#include <span>
#include <algorithm>
#include <stack>
#include <filesystem>
#include <functional>
#include <thread>
#include <zstd.h>

#include "SeMetadata.h"
#include "SeError.h"
#include "SeTOC.h"
#include "SeJob.h"
#include "SeCRC32.h"
#include "SeMMStream.h"
#include "SeCrypto/SeCryptoUtils.h"
#include "SeCrypto/AesGcmContextProvider.h"
#include "SeCrypto/AesGcmStreamSession.h"

using namespace std;
#define SE_JOB_MAX_COUNT 10
#define SE_ARCHIVE_KEY_LIM 1

using ProgressCallback = std::function<void(const SeJob&)>;


class SeArchive{
    // [MetaData bytes]
    // [File1-info byte (needs its seperate definition)]
    // [File1 enc-bytes]
    // [File2-info]
    // [File2 enc-bytes]
    // ..
    // [FileN-info]
    // [FileN enc-bytes]
    // [TOC bytes]

public:
    explicit SeArchive(SeMetadata metadata, SeTableOfContent toc, u16string archivePath,AesGcmContextProvider crypto) :m_metadata(metadata),
        m_toc(toc),
        m_archiveFilePath(archivePath),
        m_cryptoCtx(move(crypto))
    {
    }
    // The archivePath file should exist otherwise a error will be returned
    static expected<SeArchive,error_code> CreateArchive(uint16_t version,uint16_t compressionLevel, bool preserveMetadata,u16string archivePath);
    static expected<SeArchive,error_code> LoadArchiveFile(u16string path);

    ~SeArchive(); // there will be synchornisity objects and streams that need to be handled here

    // Concurrent object - disabling the copy and move ctors
    SeArchive(const SeArchive&) = delete;
    SeArchive& operator=(const SeArchive&) = delete;
    SeArchive(const SeArchive&&) = delete;
    SeArchive& operator=(const SeArchive&&) = delete;

    const SeMetadata& GetMetadata() const noexcept {
        return this->m_metadata;
    }

    const SeTableOfContent& GetTOC() const noexcept {
        return this->m_toc;
    }

    /// @brief Registers a file addition job for archive; To make the changes happen you have to call SaveChanges
    /// @param filePath Relative file path related to the internal archive structure
    /// @param fileName Absolute target file path located on disk
    /// @return
    expected<void,error_code> AddFile(u16string filePath,u16string fileName);
    
    /// @brief Registers a file removal job; Action wont take place until you call SaveChanges
    /// @param fileName Relative file path related to internal archive
    /// @return 
    expected<void,error_code> RemoveFile(u16string fileName);

    /// @brief Registers a Create directory job 
    /// @param fileName Relative file path
    /// @return 
    expected<void,error_code> AddDirectory(u16string fileName);

    /// @brief Registers a remove directory job, it will remove the files inside the directory completely
    /// @param fileName Relative file path
    /// @return 
    expected<void,error_code> DeleteDirectory(u16string fileName); // Remove a directory ( still deciding what to do with the files inside it!)

    /// @brief Moves a file within the archive from one directory to another;Still need to call SaveChanges
    /// @param fileName Source file relative path
    /// @param destPath Destination file relative path
    /// @return 
    expected<void,error_code> MoveArchiveFile(u16string fileName,u16string destPath); // Moving file from one directory to another

    /// @brief Moves a directory within the archive; you have to call SaveChanges to save the new TOC
    /// @param fileName Source file relative path
    /// @param destPath Destination file relative path
    /// @return 
    expected<void,error_code> MoveDirectory(u16string fileName, u16string destPath); // Moving a directory to another with all of its files

    /// @brief Extract a full directory; you have to register a key before calling this function
    /// @param fileName Relative file path
    /// @param outputPath Output file on disk
    /// @param callback Function to notify of job status
    /// @param stopToken Cancelation token
    /// @return Number of files extracted ( Does not count the created directories )
    expected<size_t,error_code> ExtractDirectorySync(u16string fileName,u16string outputPath,ProgressCallback callback,stop_token stopToken); 
    
    /// @brief Extract a file into disk; you have to register a key before calling this function
    /// @param fileName Relative file path in archive
    /// @param outputPath Output file on disk
    /// @param callback Function to notify you about job status
    /// @param stopToken Cancelation token
    /// @return Bytes extracted 
    expected<size_t,error_code> ExtractFileSync(u16string fileName,u16string outputPath, ProgressCallback callback,stop_token stopToken);


    /// @brief Writes every requested job to the file
    /// @param callback Progress report
    /// @param stopToken Cancelation token
    /// @return 
    expected<void,error_code> SaveChangesSync(ProgressCallback callback , stop_token stopToken);

    /// @brief Register a key for archive manipulation tasks
    /// @param key ASCII key string
    /// @return 
    expected<void,error_code> RegisterKey(string& key);

    /// @brief Checks if a key exists within the current SeArchive object
    /// @return 
    bool IsKeyPresent();

    /// @brief Get a list of pending jobs on the Archive
    /// @return 
    const vector<SeJob>& GetJobs();
    /// @brief Remove a job with its id
    /// @param id Id ofthe desired job
    /// @return 
    expected<void,error_code> RemoveJob(int id);


    void SetPreserveMetadata(bool preserve);
    void SetCompressionLevel(uint32_t compressionLevel);

    bool IsReady();
private:
    
    // WARN: ALIGNMENT IS NON_EXISTANT

    bool verifyKey();

    bool verifyJobs();

    /// @brief Optimizes queued jobs by merging redundant operations, cancelling transient actions, and folding moves
    void optimizeJobs();

    bool addJob(const SeJob&);

    // Low overhead sub-routines to do archive jobs
    expected<void,error_code> doAddFileJob(SeJob& job, ProgressCallback callback , stop_token stopToken);
    expected<void,error_code> doRemoveFileJob(SeJob& job, ProgressCallback callback , stop_token stopToken);
    expected<void,error_code> doAddDirectoryJob(SeJob& job, ProgressCallback callback , stop_token stopToken);
    expected<void,error_code> doDeleteDirectoryJob(SeJob& job, ProgressCallback callback , stop_token stopToken);
    expected<void,error_code> doMoveFileJob(SeJob& job, ProgressCallback callback , stop_token stopToken);
    expected<void,error_code> doMoveDirectoryJob(SeJob& job, ProgressCallback callback , stop_token stopToken);
    expected<void,error_code> doChangeCompressionLevel(SeJob& job, ProgressCallback callback , stop_token stopToken);
    expected<void,error_code> doTestFile(SeJob& job, ProgressCallback callback , stop_token stopToken);

    AesGcmContextProvider m_cryptoCtx;

    MappedFileStream m_archiveStream;
    vector<SeJob> m_jobs;
    u16string m_archiveFilePath = u"";
    SeMetadata m_metadata;
    SeTableOfContent m_toc;
    bool m_isReady = false;
    
    unique_ptr<ZSTD_CCtx, decltype(&ZSTD_freeCCtx)> m_zstdCctx{ ZSTD_createCCtx(), ZSTD_freeCCtx };

    unique_ptr<ZSTD_DCtx, decltype(&ZSTD_freeDCtx)> m_zstdDctx{ ZSTD_createDCtx(), ZSTD_freeDCtx };
};
