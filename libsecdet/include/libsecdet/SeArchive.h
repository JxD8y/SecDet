#pragma once
#include <string>
#include <vector>
#include <expected>
#include <span>
#include <algorithm>
#include <stack>

#include "SeMetadata.h"
#include "SeError.h"
#include "SeTOC.h"

using namespace std;


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
    // The archivePath file should exist otherwise a error will be returned
    static expected<SeArchive,error_code> CreateArchive(uint16_t version,uint16_t compressionLevel, bool preserveMetadata,u16string archivePath);
    static expected<SeArchive,error_code> LoadArchiveFile(u16string path);

    ~SeArchive(); // there will be synchornisity objects and streams that need to be handled here

    static bool verifyAbsPath(u16string path);

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
    expected<void,error_code> CreateArchiveDirectory(u16string fileName);

    /// @brief Registers a remove directory job, it will remove the files inside the directory completely
    /// @param fileName Relative file path
    /// @return 
    expected<void,error_code> RemoveArchiveDirectory(u16string fileName); // Remove a directory ( still deciding what to do with the files inside it!)

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

    /// @brief Extract the file into temp directory, calculate its checksum, compare the uncompressed and compressed size in TOC to verify the file health; You have to register a key before calling this function
    /// @param fileName Relative file path
    /// @return 
    expected<void,error_code> TestFile(u16string fileName); 

    /// @brief Extract a full directory; you have to register a key before calling this function
    /// @param fileName Relative file path
    /// @param outputPath Output file on disk
    /// @return Number of files extracted ( Does not count the created directories )
    expected<size_t,error_code> ExtractDirectory(u16string fileName,u16string outputPath); 
    
    /// @brief Extract a file into disk; you have to register a key before calling this function
    /// @param fileName Relative file path in archive
    /// @param outputPath Output file on disk
    /// @return Bytes extracted 
    expected<size_t,error_code> ExtractFile(u16string fileName,u16string outputPath);

    /// @brief Register a key for archive manipulation tasks
    /// @param key ASCII key string
    /// @return 
    expected<void,error_code> RegisterKey(string key);

    /// @brief Checks if a key exists within the current SeArchive object
    /// @return 
    expected<bool,error_code> IsKeyPresent();

    /// @brief Remove the present key from the SeArchive
    /// @return 
    expected<void,error_code> RemoveKey();

    /// @brief Get a list of pending jobs on the Archive
    /// @return 
    expected<const stack<SeJob>&,error_code> GetJobs();
    /// @brief Remove a job with its id
    /// @param id Id ofthe desired job
    /// @return 
    expected<void,error_code> RemoveJob(int id);


    void SetPreserveMetadata(bool preserve);
    void SetCompressionLevel(uint32_t compressionLevel);

    expected<void,error_code> SaveChangesSync(); // Lemme think about the callback datastruct

    bool IsReady();
private:
    SeArchive(SeMetadata metadata,SeTableOfContent toc, u16string archivePath):m_metadata(metadata),
                                                        m_toc(toc),
                                                        m_archiveFilePath(archivePath)
    {}

    bool verifyKey();

    u16string m_archiveFilePath = s"";
    SeMetadata m_metadata;
    SeTableOfContent m_toc;
    bool m_isReady = false;
};
