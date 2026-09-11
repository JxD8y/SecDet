#pragma once
#include <algorithm>
#include <expected>
#include <filesystem>
#include <functional>
#include <span>
#include <stack>
#include <string>
#include <thread>
#include <vector>
#include <unordered_set>
#include <zstd.h>


#include "SeCRC32.h"
#include "SeCrypto/AesGcmContextProvider.h"
#include "SeCrypto/AesGcmStreamSession.h"
#include "SeCrypto/SeCryptoUtils.h"
#include "SeError.h"
#include "SeJob.h"
#include "SeMMStream.h"
#include "SeMetadata.h"
#include "SeTOC.h"
#include "SeTaskHandle.h"


using namespace std;
#define SE_JOB_MAX_COUNT 10
#define SE_ARCHIVE_KEY_LIM 1

class SeArchive {
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
  explicit SeArchive(SeMetadata metadata, SeTableOfContent toc,
                     u16string archivePath, AesGcmContextProvider crypto)
      : m_metadata(metadata), m_toc(toc), m_archiveFilePath(archivePath),
        m_cryptoCtx(move(crypto)) {
    this->m_isReady = true;
  }

  SeArchive(SeArchive &&) noexcept = default;
  SeArchive &operator=(SeArchive &&) noexcept = default;
  SeArchive(const SeArchive &) = delete;
  SeArchive &operator=(const SeArchive &) = delete;

  struct DiscoveredItem {
      u16string diskPath;
      u16string archiveRelPath;
      u16string name;
      bool isDirectory = false;
      uint64_t size = 0;
  };
  using IndexProgressCallback = std::function<void(size_t filesCount, size_t dirsCount)>;
  using ProgressCallback = std::function<void(const SeJob&)>;

  
  static expected<SeArchive, error_code> LoadArchiveFile(u16string path);
  static expected<SeArchive, error_code> CreateArchive(uint16_t version, uint16_t compressionLevel, bool preserveMetadata, u16string archivePath, string password);

  /// @brief Recovers an archive by deep searching for local file entry headers, reconstructing a virtual TOC, and parsing available TOC fragments.
  static expected<SeArchive, error_code> RecoverArchiveFile(u16string path);
  static expected<SeArchive, error_code> RecoverArchiveSync(u16string path, stop_token stopToken = {});
  static SeTaskHandle<SeArchive> RecoverArchiveAsync(u16string path);

  const SeMetadata& GetMetadata() const noexcept { return this->m_metadata; }

  const SeTableOfContent& GetTOC() const noexcept { return this->m_toc; }

  [[nodiscard]] const string& GetMetadataHealth() const noexcept { return this->m_metadataHealth; }
  [[nodiscard]] const string& GetTOCHealth() const noexcept { return this->m_tocHealth; }

  /// @brief Registers a file addition job for archive; To make the changes
  /// happen you have to call SaveChanges
  /// @param filePath Relative file path related to the internal archive
  /// structure
  /// @param fileName Absolute target file path located on disk
  /// @return
  expected<void, error_code> AddFile(u16string filePath, u16string fileName, uint64_t fileSize = 0);

  /// @brief Registers a file removal job; Action wont take place until you call
  /// SaveChanges
  /// @param fileName Relative file path related to internal archive
  /// @return
  expected<void, error_code> RemoveFile(u16string fileName);

  /// @brief Registers a directory creation job inside the archive; You must
  /// call SaveChanges to apply
  /// @param fileName Relative directory path inside archive (e.g. /Folder/)
  /// @return
  expected<void, error_code> CreateArchiveDirectory(u16string fileName);


  /// @brief Recursively iterates through a directory on disk and registers jobs
  /// to create all subdirectories and add all files
  /// @param filePath Directory path on disk (or archive parent directory)
  /// @param fileName Archive parent directory (or directory path on disk)
  /// @return
  expected<void, error_code> AddDirectory(u16string filePath,u16string fileName);


  /// @brief Recursively iterates through a directory on disk and registers jobs,
  /// returning metadata for all discovered items in a single pass.
  /// @param filePath Directory path on disk (or archive parent directory)
  /// @param fileName Archive parent directory (or directory path on disk)
  /// @param progressCallback Optional callback for indexing progress
  /// @return Vector of discovered items with paths, names, types, and sizes
  expected<vector<DiscoveredItem>, error_code> AddDirectoryWithDetails(u16string filePath, u16string fileName, IndexProgressCallback progressCallback = nullptr);

  /// @brief Registers a remove directory job, it will remove the files inside
  /// the directory completely
  /// @param fileName Relative file path
  /// @return
  expected<void, error_code> DeleteDirectory(u16string fileName); // Remove a directory ( still deciding
                                      

  /// @brief Moves a file within the archive from one directory to another;Still
  /// need to call SaveChanges
  /// @param fileName Source file relative path
  /// @param destPath Destination file relative path
  /// @return
  expected<void, error_code> MoveArchiveFile( u16string fileName, u16string destPath); // Moving file from one directory to another

  /// @brief Moves a directory within the archive; you have to call SaveChanges
  /// to save the new TOC
  /// @param fileName Source file relative path
  /// @param destPath Destination file relative path
  /// @return
  expected<void, error_code> MoveDirectory(u16string fileName, u16string destPath); // Moving a directory to another with all

  /// @brief Extract a full directory; you have to register a key before calling
  /// this function
  /// @param fileName Relative file path
  /// @param outputPath Output file on disk
  /// @param callback Function to notify of job status
  /// @param stopToken Cancelation token
  /// @return Number of files extracted ( Does not count the created directories
  /// )
  expected<size_t, error_code> ExtractDirectorySync(u16string fileName, u16string outputPath, ProgressCallback callback, stop_token stopToken = {}, SePauseToken pauseToken = {});

  /// @brief Asynchronously extracts a full directory in a separate thread.
  /// @param fileName Relative directory path
  /// @param outputPath Output directory on disk
  /// @param callback Function to notify of job status (optional)
  /// @return SeTaskHandle to control, monitor, and await the asynchronous
  /// directory extraction
  SeTaskHandle<size_t> ExtractDirectoryAsync(u16string fileName, u16string outputPath,ProgressCallback callback = nullptr);

  /// @brief Extract a file into disk; you have to register a key before calling
  /// this function
  /// @param fileName Relative file path in archive
  /// @param outputPath Output file on disk
  /// @param callback Function to notify you about job status
  /// @param stopToken Cancelation token
  /// @param pauseToken Pause token
  /// @return Bytes extracted
  expected<size_t, error_code> ExtractFileSync(u16string fileName,u16string outputPath,ProgressCallback callback,stop_token stopToken = {}, SePauseToken pauseToken = {});

  /// @brief Asynchronously extracts a file into disk in a separate thread.
  /// @param fileName Relative file path in archive
  /// @param outputPath Output directory on disk
  /// @param callback Function to notify of job status (optional)
  /// @return SeTaskHandle to control, monitor, and await the asynchronous file
  /// extraction
  SeTaskHandle<size_t> ExtractFileAsync(u16string fileName,u16string outputPath,ProgressCallback callback = nullptr);

  /// @brief Writes every requested job to the file
  /// @param callback Progress report
  /// @param stopToken Cancelation token
  /// @param pauseToken Pause token
  /// @return
  expected<void, error_code> SaveChangesSync(ProgressCallback callback = nullptr,
                                             stop_token stopToken = {},
                                             SePauseToken pauseToken = {});

  /// @brief Asynchronously writes every requested job to the file in a separate
  /// thread.
  /// @param callback Progress report callback (optional)
  /// @return SeTaskHandle to control, monitor, and await the asynchronous save
  /// operation
  SeTaskHandle<void> SaveChangesAsync(ProgressCallback callback = nullptr);

  /// @brief Register a key for archive manipulation tasks
  /// @param key ASCII key string
  /// @return
  expected<void, error_code> RegisterKey(string key);

  /// @brief Checks if a key exists within the current SeArchive object
  /// @return
  bool IsKeyPresent();

  /// @brief Tests if a key correctly decrypts an entry by extracting and authenticating only its first buffer
  /// @param entryPath Relative path of the entry in the archive
  /// @param key Password to test (if empty, uses currently registered archive key)
  /// @return true if key is valid for this file entry, false otherwise
  expected<bool, error_code> TestKeySync(u16string entryPath, string key = "");

  /// @brief Tests if a key correctly decrypts an entry by extracting and authenticating only its first buffer
  /// @param entry File entry from TOC
  /// @param key Password to test (if empty, uses currently registered archive key)
  /// @return true if key is valid for this file entry, false otherwise
  expected<bool, error_code> TestKeySync(const SeArchiveEntry &entry, string key = "");

  /// @brief Asynchronously tests if a key decrypts an entry in a separate thread
  /// @param entryPath Relative path of the entry in the archive
  /// @param key Password to test (if empty, uses currently registered archive key)
  /// @return SeTaskHandle to await the test result
  SeTaskHandle<bool> TestKeyAsync(u16string entryPath, string key = "");

  /// @brief Tests a file in the archive against its TOC entry
  /// @param fileName Relative file path in archive
  /// @param callback Progress callback
  /// @param stopToken Cancelation token
  /// @param pauseToken Pause token
  /// @return true if file integrity is intact, unexpected error otherwise
  expected<bool, error_code> TestFileSync(u16string fileName,
                                          ProgressCallback callback = nullptr,
                                          stop_token stopToken = {},
                                          SePauseToken pauseToken = {});

  /// @brief Asynchronously tests a file in the archive in a separate thread
  /// @param fileName Relative file path in archive
  /// @param callback Progress callback
  /// @return SeTaskHandle to await the test result
  SeTaskHandle<bool> TestFileAsync(u16string fileName,
                                   ProgressCallback callback = nullptr);

  /// @brief Get a list of pending jobs on the Archive
  /// @return
  const vector<SeJob> &GetJobs();
  /// @brief Remove a job with its id
  /// @param id Id ofthe desired job
  /// @return
  expected<void, error_code> RemoveJob(int id);

  /// @brief Resets a job back to Idle with 0 progress so it can be retried
  /// @param id Id of the desired job (-1 or 0 resets all failed/aborted jobs)
  /// @return
  expected<void, error_code> ResetJob(int id);

  /// @brief Removes all completed (Finished) jobs from the queue
  void RemoveCompletedJobs();

  /// @brief Resets all failed or aborted jobs back to Idle for retry
  void ResetFailedJobs();

  void SetPreserveMetadata(bool preserve);
  void SetCompressionLevel(uint32_t compressionLevel);
  expected<void, error_code> ChangeCompressionLevel(uint32_t compressionLevel);

  /// @brief Optimizes queued jobs by merging redundant operations, cancelling
  /// transient actions, and folding moves. Returns IDs of eliminated jobs in order.
  vector<int> optimizeJobs();

  bool IsReady();

private:
  // WARN: ALIGNMENT IS NON_EXISTANT

  bool verifyKey();

  bool verifyJobs();

  bool addJob(SeJob &);

  bool checkParentPath(const u16string &path) const;
  bool checkPathExists(const u16string &path) const;

  // Low overhead sub-routines to do archive jobs
  expected<void, error_code> doAddFileJob(SeJob &job, ProgressCallback callback,
                                          stop_token stopToken, SePauseToken pauseToken = {});
  expected<void, error_code>
  doRemoveFileJob(SeJob &job, ProgressCallback callback, stop_token stopToken, SePauseToken pauseToken = {});
  expected<void, error_code> doCreateDirectoryJob(SeJob &job,
                                                  ProgressCallback callback,
                                                  stop_token stopToken, SePauseToken pauseToken = {});
  expected<void, error_code> doAddDirectoryJob(SeJob &job,
                                               ProgressCallback callback,
                                               stop_token stopToken, SePauseToken pauseToken = {});
  expected<void, error_code> doDeleteDirectoryJob(SeJob &job,
                                                  ProgressCallback callback,
                                                  stop_token stopToken, SePauseToken pauseToken = {});
  expected<void, error_code>
  doMoveFileJob(SeJob &job, ProgressCallback callback, stop_token stopToken, SePauseToken pauseToken = {});
  expected<void, error_code> doMoveDirectoryJob(SeJob &job,
                                                ProgressCallback callback,
                                                stop_token stopToken, SePauseToken pauseToken = {});
  expected<void, error_code> doChangeCompressionLevel(SeJob &job,
                                                      ProgressCallback callback,
                                                      stop_token stopToken, SePauseToken pauseToken = {});
  expected<void, error_code> doTestFile(SeJob &job, ProgressCallback callback,
                                        stop_token stopToken, SePauseToken pauseToken = {});

  /// @brief Applies the stored SE_ATTR_* attribute flags from an archive entry
  /// to the extracted file on disk, translating to platform-native attributes.
  void applyAttributes(const SeArchiveEntry &entry, const u16string &diskPath);

  AesGcmContextProvider m_cryptoCtx;

  MappedFileStream m_archiveStream;
  vector<SeJob> m_jobs;
  u16string m_archiveFilePath = u"";
  SeMetadata m_metadata;
  SeTableOfContent m_toc;
  string m_metadataHealth = "Healthy (Valid Header)";
  string m_tocHealth = "Healthy (Valid TOC)";
  bool m_isReady = false;

  int m_jobCtr = 1;
  unordered_set<u16string> m_queuedDirs;
  unordered_set<u16string> m_queuedFiles;
  void rebuildQueuedPathSets();

  unique_ptr<ZSTD_CCtx, decltype(&ZSTD_freeCCtx)> m_zstdCctx{ZSTD_createCCtx(),
                                                             ZSTD_freeCCtx};

  unique_ptr<ZSTD_DCtx, decltype(&ZSTD_freeDCtx)> m_zstdDctx{ZSTD_createDCtx(),
                                                             ZSTD_freeDCtx};
};
