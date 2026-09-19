#include "ArchiveRecoveryInterface.h"
#include "SeFileEntryObject.h"

#include <libsecdet/SeCRC32.h>
#include <libsecdet/SeError.h>

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QMetaObject>
#include <QTemporaryDir>
#include <QUrl>

#include <algorithm>
#include <chrono>
#include <future>
#include <thread>

ArchiveRecoveryInterface::ArchiveRecoveryInterface(QObject *parent)
    : QObject(parent) {}

ArchiveRecoveryInterface::~ArchiveRecoveryInterface() {
  cancelCurrentOperation();
  if (m_currentTask) {
    m_currentTask->request_stop();
  }
}

void ArchiveRecoveryInterface::setBusy(bool busy) {
  if (m_isBusy != busy) {
    m_isBusy = busy;
    emit isBusyChanged(m_isBusy);
  }
}

void ArchiveRecoveryInterface::resetProgress() {
  m_overallProgress = 0.0;
  m_fileProgress = 0.0;
  m_processedFiles = 0;
  m_totalFiles = 0;
  m_totalProcessedBytes = 0;
  m_totalCompressedBytes = 0;
  m_totalBytes = 0;
  m_currentFileName.clear();
  m_currentOperationName.clear();
  emit progressChanged();
}

bool ArchiveRecoveryInterface::loadArchive(const QString &filePath, const QString &password) {
  if (filePath.isEmpty()) {
    return false;
  }

  QString cleanPath = filePath;
  if (cleanPath.startsWith(QStringLiteral("file:///"))) {
    cleanPath = QUrl(cleanPath).toLocalFile();
  } else if (cleanPath.startsWith(QStringLiteral("file://"))) {
    cleanPath = cleanPath.mid(7);
  }

  QFileInfo fi(cleanPath);
  if (!fi.exists() || !fi.isFile()) {
    emit errorOccurred(QStringLiteral("Recovery Error"),
                       QStringLiteral("File does not exist or is not a regular file."));
    return false;
  }

  // Cancel any currently running operation before loading new archive
  cancelCurrentOperation();

  m_isLoading = true;
  m_archivePath = cleanPath;
  emit recoveryStatusChanged();

  // Run the recovery scan, key registration, and item parsing on a dedicated background worker thread
  std::jthread workerThread([this, cleanPath, password](std::stop_token stopToken) {
    auto result = SeArchive::RecoverArchiveSync(cleanPath.toStdU16String(), stopToken);

    if (stopToken.stop_requested()) {
      QMetaObject::invokeMethod(this, [this]() {
        m_isLoading = false;
        emit recoveryStatusChanged();
      }, Qt::QueuedConnection);
      return;
    }

    if (!result) {
      QString errorTitle = QStringLiteral("Critical Crypto Data Missing");
      QString errorDetail;
      if (result.error() == SeError::RequiredFieldMissing ||
          result.error() == SeError::InvalidMetadataMagic ||
          result.error() == std::errc::invalid_argument) {
        errorDetail = QStringLiteral(
            "Cannot open archive for recovery: Critical cryptographic parameters "
            "(Salt or Password Verification Value) are damaged or unreadable in the metadata header.\n\n"
            "Without valid Salt and PVV, cryptographic derivation and decryption cannot take place.");
      } else {
        errorTitle = QStringLiteral("Recovery Analysis Failed");
        errorDetail = QStringLiteral("Failed to open archive for recovery: ") +
                      QString::fromLocal8Bit(result.error().message().c_str());
      }

      QMetaObject::invokeMethod(this, [this, errorTitle, errorDetail]() {
        m_isLoading = false;
        m_archive.reset();
        m_recoveryItems.clear();
        m_isMetadataHealthy = false;
        m_metadataHealthState = QStringLiteral("Corrupted / Unreadable");
        m_metadataDetails = errorDetail;
        m_isTocHealthy = false;
        m_tocHealthState = QStringLiteral("Unavailable");
        m_tocDetails = QStringLiteral("Cannot reconstruct Table of Contents without valid cryptographic metadata.");
        m_okCount = 0;
        m_foundOkCount = 0;
        m_truncatedCount = 0;
        m_notFoundCount = 0;

        emit recoveryStatusChanged();
        emit recoveryItemsChanged();
        emit recoveryCompleted(false, errorDetail);
        emit errorOccurred(errorTitle, errorDetail);
      }, Qt::QueuedConnection);
      return;
    }

    auto archive = std::make_unique<SeArchive>(std::move(*result));

    // Register key in worker thread off the UI thread to keep UI completely smooth
    if (!password.isEmpty()) {
      (void)archive->RegisterKey(password.toStdString());
    }
    bool keyRegistered = archive->IsKeyPresent();

    QString metaHealthStr = QString::fromStdString(archive->GetMetadataHealth());
    bool isMetaHealthy = !metaHealthStr.contains(QStringLiteral("Corrupt"), Qt::CaseInsensitive) &&
                         !metaHealthStr.contains(QStringLiteral("Invalid"), Qt::CaseInsensitive);
    QString metaHealthState = isMetaHealthy ? QStringLiteral("Healthy (Valid Header)")
                                           : QStringLiteral("Corrupted / Damaged");

    QString tocHealthStr = QString::fromStdString(archive->GetTOCHealth());
    bool isTocHealthy = !tocHealthStr.contains(QStringLiteral("Truncated"), Qt::CaseInsensitive) &&
                        !tocHealthStr.contains(QStringLiteral("Damaged"), Qt::CaseInsensitive) &&
                        !tocHealthStr.contains(QStringLiteral("Corrupt"), Qt::CaseInsensitive);
    QString tocHealthState = isTocHealthy ? QStringLiteral("Valid (Full TOC)")
                                         : QStringLiteral("Truncated / Reconstructed");

    // Parse and precalculate all recovery entries and counters on worker thread
    const auto &entries = archive->GetTOC().GetEntries();
    uint64_t totalRealBytes = 0;
    for (const auto &e : entries) {
      if (e.path == u"/") continue;
      totalRealBytes += e.uncompressed_size;
    }

    int okC = 0;
    int foundOkC = 0;
    int truncatedC = 0;
    int notFoundC = 0;
    QVariantList items;
    items.reserve(static_cast<qsizetype>(entries.size()));

    for (const auto &e : entries) {
      if (e.path == u"/") continue;

      QString itemPath = QString::fromStdU16String(e.path);
      QString itemName = QFileInfo(itemPath).fileName();
      if (itemName.isEmpty()) {
        itemName = itemPath;
      }

      QString stateStr;
      switch (e.recoveryState) {
        case EntryRecoveryState::FoundIndexed:
          stateStr = QStringLiteral("Ok");
          okC++;
          break;
        case EntryRecoveryState::FoundOk:
          stateStr = QStringLiteral("Found OK");
          foundOkC++;
          break;
        case EntryRecoveryState::FoundTruncated:
          stateStr = QStringLiteral("Found Truncated");
          truncatedC++;
          break;
        case EntryRecoveryState::NotFound:
          stateStr = QStringLiteral("Not Found");
          notFoundC++;
          break;
      }

      QString crcStr;
      if (e.recoveryState == EntryRecoveryState::NotFound || e.crc32 == 0) {
        crcStr = QStringLiteral("N/A");
      } else {
        crcStr = QString::asprintf("0x%08X", e.crc32);
      }

      double sharePct = 0.0;
      if (totalRealBytes > 0 && e.uncompressed_size > 0) {
        sharePct = (static_cast<double>(e.uncompressed_size) / static_cast<double>(totalRealBytes)) * 100.0;
      }
      QString shareStr = QString::asprintf("%.1f%%", sharePct);

      QVariantMap itemMap;
      itemMap[QStringLiteral("name")] = itemName;
      itemMap[QStringLiteral("path")] = itemPath;
      itemMap[QStringLiteral("isFolder")] = e.isDirectory();
      itemMap[QStringLiteral("state")] = stateStr;
      itemMap[QStringLiteral("compSize")] = SeFileEntryObject::formatBytes(e.compressed_size);
      itemMap[QStringLiteral("realSize")] = SeFileEntryObject::formatBytes(e.uncompressed_size);
      itemMap[QStringLiteral("crc")] = crcStr;
      itemMap[QStringLiteral("share")] = shareStr;
      itemMap[QStringLiteral("checked")] = (e.recoveryState != EntryRecoveryState::NotFound);

      items.append(itemMap);
    }

    uint64_t totalArcSize = 0;
    QFileInfo arcFi(cleanPath);
    if (arcFi.exists()) {
      totalArcSize = static_cast<uint64_t>(arcFi.size());
    }

    QMetaObject::invokeMethod(
        this,
        [this, arc = std::move(archive), items = std::move(items), keyRegistered,
         isMetaHealthy, metaHealthState, metaHealthStr, isTocHealthy, tocHealthState,
         tocHealthStr, okC, foundOkC, truncatedC, notFoundC, totalArcSize]() mutable {
          m_archive = std::move(arc);
          m_recoveryItems = std::move(items);
          m_isKeyRegistered = keyRegistered;
          m_isMetadataHealthy = isMetaHealthy;
          m_metadataHealthState = metaHealthState;
          m_metadataDetails = metaHealthStr;
          m_isTocHealthy = isTocHealthy;
          m_tocHealthState = tocHealthState;
          m_tocDetails = tocHealthStr;
          m_okCount = okC;
          m_foundOkCount = foundOkC;
          m_truncatedCount = truncatedC;
          m_notFoundCount = notFoundC;
          m_totalArchiveSize = totalArcSize;
          m_isLoading = false;

          emit recoveryStatusChanged();
          emit recoveryKeyStatusChanged(m_isKeyRegistered);
          emit recoveryItemsChanged();
          emit recoveryCompleted(true, QStringLiteral("Archive recovery analysis completed successfully."));
        },
        Qt::QueuedConnection);
  });

  workerThread.detach();
  return true;
}

void ArchiveRecoveryInterface::unloadArchive() {
  cancelCurrentOperation();
  m_archive.reset();
  m_archivePath.clear();
  m_metadataHealthState = QStringLiteral("Unknown");
  m_metadataDetails.clear();
  m_isMetadataHealthy = false;
  m_tocHealthState = QStringLiteral("Unknown");
  m_tocDetails.clear();
  m_isTocHealthy = false;
  m_okCount = 0;
  m_foundOkCount = 0;
  m_truncatedCount = 0;
  m_notFoundCount = 0;
  m_recoveryItems.clear();
  m_isLoading = false;
  m_isKeyRegistered = false;
  resetProgress();

  emit recoveryStatusChanged();
  emit recoveryItemsChanged();
  emit recoveryKeyStatusChanged(false);
}

bool ArchiveRecoveryInterface::registerKey(const QString &password) {
  if (!m_archive) return false;

  auto res = m_archive->RegisterKey(password.toStdString());
  if (res) {
    m_isKeyRegistered = true;
    emit recoveryKeyStatusChanged(true);
    return true;
  }
  return false;
}

bool ArchiveRecoveryInterface::extractRecoveryItem(const QString &archiveRelativePath,
                                                 const QString &outputDir) {
  return extractRecoveryBatch(QStringList() << archiveRelativePath, outputDir);
}

bool ArchiveRecoveryInterface::extractRecoveryBatch(const QStringList &archiveRelativePaths,
                                                   const QString &outputDir) {
  if (!m_archive) {
    emit errorOccurred(QStringLiteral("Extraction Error"), QStringLiteral("No recovery archive loaded."));
    return false;
  }

  if (archiveRelativePaths.isEmpty()) {
    emit errorOccurred(QStringLiteral("Extraction Error"), QStringLiteral("No files specified for extraction."));
    return false;
  }

  QString cleanOut = outputDir;
  if (cleanOut.startsWith(QStringLiteral("file:///"))) {
    cleanOut = QUrl(cleanOut).toLocalFile();
  } else if (cleanOut.startsWith(QStringLiteral("file://"))) {
    cleanOut = cleanOut.mid(7);
  }

  if (cleanOut.isEmpty()) {
    emit errorOccurred(QStringLiteral("Extraction Error"), QStringLiteral("Invalid destination directory."));
    return false;
  }

  QDir().mkpath(cleanOut);

  // Compute total uncompressed bytes for accurate progress calculation
  uint64_t totalBytesToExtract = 0;
  for (const QString &rawPath : archiveRelativePaths) {
    QString normPath = rawPath;
    if (!normPath.startsWith(u'/')) normPath.prepend(u'/');
    auto entryOpt = m_archive->GetTOC().GetEntry(normPath.toStdU16String());
    if (entryOpt) {
      totalBytesToExtract += entryOpt->uncompressed_size;
    }
  }

  m_stopSource = std::stop_source();
  std::stop_token stopToken = m_stopSource.get_token();
  auto pauseState = std::make_shared<SePauseState>();
  SePauseToken pauseToken(pauseState);

  auto promise = std::make_shared<std::promise<expected<bool, error_code>>>();
  auto future = promise->get_future().share();

  setBusy(true);
  m_currentOperationName = QStringLiteral("Extracting Recovered Files...");
  m_processedFiles = 0;
  m_totalFiles = archiveRelativePaths.size();
  m_totalBytes = totalBytesToExtract;
  m_totalProcessedBytes = 0;
  m_totalCompressedBytes = 0;
  m_overallProgress = 0.0;
  m_fileProgress = 0.0;
  emit progressChanged();

  std::jthread workerThread([this, paths = archiveRelativePaths, cleanOut, totalBytesToExtract,
                             stopToken, pauseToken, promise]() {
    int extractedCount = 0;
    int failedCount = 0;
    QString lastError;
    uint64_t accumulatedBytes = 0;

    auto lastDispatch = std::make_shared<std::atomic<int64_t>>(0);

    for (int i = 0; i < paths.size(); ++i) {
      if (stopToken.stop_requested()) {
        break;
      }

      QString rawPath = paths[i];
      QString normPath = rawPath;
      if (!normPath.startsWith(u'/')) normPath.prepend(u'/');

      bool isDir = normPath.endsWith(u'/');
      QString fileName = QFileInfo(normPath).fileName();

      QMetaObject::invokeMethod(this, [this, fileName, i]() {
        m_currentFileName = fileName;
        m_processedFiles = i;
        emit progressChanged();
      }, Qt::QueuedConnection);

      auto progressCb = [this, lastDispatch, accumulatedBytes, totalBytesToExtract](const SeJob &job) {
        auto now = std::chrono::duration_cast<std::chrono::milliseconds>(
                       std::chrono::steady_clock::now().time_since_epoch())
                       .count();
        int64_t last = lastDispatch->load(std::memory_order_relaxed);
        if (job.percentage == 100 || (now - last >= 40)) {
          lastDispatch->store(now, std::memory_order_relaxed);
          uint64_t currentFileBytes = job.processedBytes;
          uint64_t totalCur = accumulatedBytes + currentFileBytes;

          QMetaObject::invokeMethod(this, [this, job, totalCur, totalBytesToExtract]() {
            m_fileProgress = static_cast<qreal>(job.percentage) / 100.0;
            m_totalProcessedBytes = totalCur;
            m_totalCompressedBytes = job.compressedBytes;
            if (totalBytesToExtract > 0) {
              m_overallProgress = qBound(0.0, static_cast<qreal>(totalCur) / static_cast<qreal>(totalBytesToExtract), 1.0);
            }
            emit progressChanged();
          }, Qt::QueuedConnection);
        }
      };

      auto entryOpt = m_archive->GetTOC().GetEntry(normPath.toStdU16String());
      uint64_t entrySize = entryOpt ? entryOpt->uncompressed_size : 0;

      auto res = isDir
                     ? m_archive->ExtractDirectorySync(normPath.toStdU16String(),
                                                       cleanOut.toStdU16String(),
                                                       progressCb, stopToken, pauseToken)
                     : m_archive->ExtractFileSync(normPath.toStdU16String(),
                                                  cleanOut.toStdU16String(),
                                                  progressCb, stopToken, pauseToken);

      if (stopToken.stop_requested()) {
        break;
      }

      if (res) {
        extractedCount++;
        accumulatedBytes += entrySize;
      } else {
        failedCount++;
        lastError = QString::fromLocal8Bit(res.error().message().c_str());
      }

      QMetaObject::invokeMethod(this, [this, nextIdx = i + 1, totalCur = accumulatedBytes, totalBytesToExtract]() {
        m_processedFiles = nextIdx;
        m_fileProgress = 1.0;
        if (totalBytesToExtract > 0) {
          m_overallProgress = qBound(0.0, static_cast<qreal>(totalCur) / static_cast<qreal>(totalBytesToExtract), 1.0);
        } else if (m_totalFiles > 0) {
          m_overallProgress = static_cast<qreal>(nextIdx) / static_cast<qreal>(m_totalFiles);
        }
        emit progressChanged();
      }, Qt::QueuedConnection);
    }

    if (stopToken.stop_requested()) {
      QMetaObject::invokeMethod(this, [this]() {
        m_currentTask.reset();
        setBusy(false);
        resetProgress();
        emit isPausedChanged(false);
        emit operationCompleted(QStringLiteral("Recovery Extraction"), false,
                                QStringLiteral("Operation was canceled"));
      }, Qt::QueuedConnection);
      return;
    }

    QMetaObject::invokeMethod(this, [this, extractedCount, failedCount, lastError]() {
      m_currentTask.reset();
      setBusy(false);
      emit isPausedChanged(false);
      if (failedCount == 0) {
        m_overallProgress = 1.0;
        m_fileProgress = 1.0;
        emit progressChanged();
        emit operationCompleted(QStringLiteral("Recovery Extraction"), true,
                                QStringLiteral("Extraction completed successfully."));
      } else {
        QString msg = QStringLiteral("%1 of %2 files extracted with errors: %3")
                          .arg(failedCount)
                          .arg(extractedCount + failedCount)
                          .arg(lastError);
        emit operationCompleted(QStringLiteral("Recovery Extraction"), false, msg);
        emit errorOccurred(QStringLiteral("Extraction Warning"), msg);
      }
    }, Qt::QueuedConnection);
  });

  auto taskHandle = std::make_shared<SeTaskHandle<bool>>(
      std::move(workerThread), std::move(future), pauseState);
  m_currentTask = taskHandle;
  emit isPausedChanged(false);

  return true;
}

bool ArchiveRecoveryInterface::testRecoveryItem(const QString &archiveRelativePath) {
  return testRecoveryBatch(QStringList() << archiveRelativePath);
}

bool ArchiveRecoveryInterface::testRecoveryBatch(const QStringList &archiveRelativePaths) {
  if (!m_archive) {
    emit errorOccurred(QStringLiteral("Test Error"), QStringLiteral("No recovery archive loaded."));
    return false;
  }

  if (archiveRelativePaths.isEmpty()) {
    emit errorOccurred(QStringLiteral("Test Error"), QStringLiteral("No files specified for CRC testing."));
    return false;
  }

  // Calculate total bytes to verify
  uint64_t totalBytesToTest = 0;
  for (const QString &rawPath : archiveRelativePaths) {
    QString normPath = rawPath;
    if (!normPath.startsWith(u'/')) normPath.prepend(u'/');
    auto entryOpt = m_archive->GetTOC().GetEntry(normPath.toStdU16String());
    if (entryOpt) {
      totalBytesToTest += entryOpt->uncompressed_size;
    }
  }

  m_stopSource = std::stop_source();
  std::stop_token stopToken = m_stopSource.get_token();
  auto pauseState = std::make_shared<SePauseState>();
  SePauseToken pauseToken(pauseState);

  auto promise = std::make_shared<std::promise<expected<bool, error_code>>>();
  auto future = promise->get_future().share();

  setBusy(true);
  m_currentOperationName = QStringLiteral("Recovery CRC Check");
  m_processedFiles = 0;
  m_totalFiles = archiveRelativePaths.size();
  m_totalBytes = totalBytesToTest;
  m_totalProcessedBytes = 0;
  m_totalCompressedBytes = 0;
  m_overallProgress = 0.0;
  m_fileProgress = 0.0;
  emit progressChanged();

  std::jthread workerThread([this, paths = archiveRelativePaths, totalBytesToTest,
                             stopToken, pauseToken, promise]() {
    int passed = 0;
    int failed = 0;
    int missing = 0;
    int truncated = 0;
    uint64_t accumulatedBytes = 0;

    auto lastProgressDispatchMs = std::make_shared<std::atomic<int64_t>>(0);
    auto lastBatchDispatchTime = std::chrono::steady_clock::now();

    for (int i = 0; i < paths.size(); ++i) {
      if (stopToken.stop_requested()) {
        break;
      }

      QString rawPath = paths[i];
      QString normPath = rawPath;
      if (!normPath.startsWith(u'/')) normPath.prepend(u'/');

      QString fileName = QFileInfo(normPath).fileName();

      auto entryOpt = m_archive->GetTOC().GetEntry(normPath.toStdU16String());
      if (!entryOpt) {
        failed++;
        missing++;
        continue;
      }

      const auto &entry = *entryOpt;
      if (entry.recoveryState == EntryRecoveryState::NotFound) {
        failed++;
        missing++;
        continue;
      }

      auto progressCb = [this, lastProgressDispatchMs, accumulatedBytes, totalBytesToTest](const SeJob &job) {
        auto now = std::chrono::duration_cast<std::chrono::milliseconds>(
                       std::chrono::steady_clock::now().time_since_epoch())
                       .count();
        int64_t last = lastProgressDispatchMs->load(std::memory_order_relaxed);
        if (now - last >= 40) {
          lastProgressDispatchMs->store(now, std::memory_order_relaxed);
          uint64_t currentFileBytes = job.processedBytes;
          uint64_t totalCur = accumulatedBytes + currentFileBytes;

          QMetaObject::invokeMethod(this, [this, pct = job.percentage, totalCur, totalBytesToTest]() {
            m_fileProgress = static_cast<qreal>(pct) / 100.0;
            m_totalProcessedBytes = totalCur;
            if (totalBytesToTest > 0) {
              m_overallProgress = qBound(0.0, static_cast<qreal>(totalCur) / static_cast<qreal>(totalBytesToTest), 1.0);
            }
            emit progressChanged();
          }, Qt::QueuedConnection);
        }
      };

      // Perform fast in-memory streaming decryption, decompression, and CRC calculation directly from archive stream
      auto testRes = m_archive->TestFileSync(normPath.toStdU16String(),
                                             progressCb, stopToken, pauseToken);

      if (stopToken.stop_requested()) {
        break;
      }

      if (testRes) {
        passed++;
        accumulatedBytes += entry.uncompressed_size;
      } else {
        failed++;
        truncated++;
      }

      auto now = std::chrono::steady_clock::now();
      auto elapsedMs = std::chrono::duration_cast<std::chrono::milliseconds>(now - lastBatchDispatchTime).count();
      bool isLastFile = (i == paths.size() - 1) || stopToken.stop_requested();

      if (isLastFile || elapsedMs >= 40) {
        lastBatchDispatchTime = now;
        QMetaObject::invokeMethod(this, [this, fileName, nextIdx = i + 1, totalCur = accumulatedBytes, totalBytesToTest]() {
          m_currentFileName = fileName;
          m_processedFiles = nextIdx;
          m_fileProgress = 1.0;
          m_totalProcessedBytes = totalCur;
          if (totalBytesToTest > 0) {
            m_overallProgress = qBound(0.0, static_cast<qreal>(totalCur) / static_cast<qreal>(totalBytesToTest), 1.0);
          } else if (m_totalFiles > 0) {
            m_overallProgress = static_cast<qreal>(nextIdx) / static_cast<qreal>(m_totalFiles);
          }
          emit progressChanged();
        }, Qt::QueuedConnection);
      }
    }

    if (stopToken.stop_requested()) {
      QMetaObject::invokeMethod(this, [this]() {
        m_currentTask.reset();
        setBusy(false);
        resetProgress();
        emit isPausedChanged(false);
        emit operationCompleted(QStringLiteral("Recovery CRC Check"), false,
                                QStringLiteral("Operation was canceled"));
      }, Qt::QueuedConnection);
      return;
    }

    QMetaObject::invokeMethod(this, [this, passed, failed, missing, truncated, total = paths.size()]() {
      m_currentTask.reset();
      setBusy(false);
      emit isPausedChanged(false);

      if (failed == 0) {
        m_overallProgress = 1.0;
        m_fileProgress = 1.0;
        emit progressChanged();
        QString okMsg = (total == 1)
                            ? QStringLiteral("CRC-32 checksum matched perfectly. File is intact.")
                            : QStringLiteral("All %1 selected files passed CRC-32 integrity validation without errors.").arg(passed);
        emit operationCompleted(QStringLiteral("Recovery CRC Check"), true, okMsg);
      } else {
        QString errorSummary = QStringLiteral("CRC verification completed:\n\n"
                                              "• %1 file(s) PASSED (CRC-32 matched)\n")
                                   .arg(passed);
        if (truncated > 0) {
          errorSummary += QStringLiteral("• %1 file(s) FAILED / TRUNCATED (CRC mismatch)\n").arg(truncated);
        }
        if (missing > 0) {
          errorSummary += QStringLiteral("• %1 file(s) NOT FOUND (missing payload stream)").arg(missing);
        }
        emit operationCompleted(QStringLiteral("Recovery CRC Check"), false, errorSummary);
        emit errorOccurred(QStringLiteral("Integrity Anomalies Detected"), errorSummary);
      }
    }, Qt::QueuedConnection);
  });

  auto taskHandle = std::make_shared<SeTaskHandle<bool>>(
      std::move(workerThread), std::move(future), pauseState);
  m_currentTask = taskHandle;
  emit isPausedChanged(false);

  return true;
}

void ArchiveRecoveryInterface::cancelCurrentOperation() {
  m_stopSource.request_stop();
  if (m_currentTask) {
    m_currentTask->request_stop();
  }
}

void ArchiveRecoveryInterface::pauseCurrentOperation() {
  setOperationPaused(true);
}

void ArchiveRecoveryInterface::resumeCurrentOperation() {
  setOperationPaused(false);
}

void ArchiveRecoveryInterface::togglePauseCurrentOperation() {
  if (m_currentTask) {
    bool isPausedNow = m_currentTask->toggle_pause();
    emit isPausedChanged(isPausedNow);
  }
}

void ArchiveRecoveryInterface::setOperationPaused(bool paused) {
  if (m_currentTask) {
    if (paused) {
      m_currentTask->pause();
    } else {
      m_currentTask->resume();
    }
    emit isPausedChanged(paused);
  }
}
