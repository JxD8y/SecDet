#ifdef _WIN32
#ifndef NOMINMAX
#define NOMINMAX
#endif
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shlobj.h>
#include <exdisp.h>
#include <shlwapi.h>
#pragma comment(lib, "Shlwapi.lib")
#endif

#include "ArchiveInterface.h"

#include <QCoreApplication>
#include <QDir>
#include <QDrag>
#include <QFileInfo>
#include <QFontDatabase>
#include <QFontMetrics>
#include <QGuiApplication>
#include <QJSEngine>
#include <QMimeData>
#include <QMetaObject>
#include <QDateTime>
#include <QFile>
#include <QPainter>
#include <QPainterPath>
#include <QPixmap>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QTemporaryDir>
#include <QUrl>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <limits>
#include <optional>
#include <thread>
#include <unordered_map>
#include <unordered_set>

#include <libsecdet/SeCRC32.h>
#include <libsecdet/SeMetadata.h>

ArchiveInterface::ArchiveInterface(QObject *parent): QObject(parent),m_metadata(new SeMetadataObject(this)),
                                                                    m_treeModel(new ArchiveTreeModel(this)),
                                                                    m_jobModel(new SeJobModel(this))
{

    connect(m_jobModel, &SeJobModel::progressChanged, this, &ArchiveInterface::progressChanged);

    connect(m_jobModel, &SeJobModel::overallProgressChanged, this, [this]() {
        if (!m_isTestingArchive) {
            m_overallProgress = m_jobModel->overallProgress();
            emit progressChanged();
        }
    });
}

ArchiveInterface::~ArchiveInterface() = default;

int ArchiveInterface::pendingJobCount() const {
    if (m_jobModel && m_jobModel->count() > 0) {
        return m_jobModel->count();
    }
    return static_cast<int>(m_jobsList.size());
}

bool ArchiveInterface::hasUncommittedChanges() const {
    if (pendingJobCount() > 0) {
        return true;
    }
    if (!m_stagedPendingItems.empty()) {
        return true;
    }
    if (m_archive && !m_archive->GetJobs().empty()) {
        return true;
    }
    return false;
}

QString ArchiveInterface::archiveFileName() const {
    if (m_archivePath.isEmpty()) {
        return QStringLiteral("No Archive");
    }
    return QFileInfo(m_archivePath).fileName();
}

void ArchiveInterface::setBusy(bool busy) {
    if (m_isBusy != busy) {
        m_isBusy = busy;
        emit isBusyChanged(busy);
    }
}

void ArchiveInterface::setStatusMessage(const QString &message) {
    if (m_statusMessage != message) {
        m_statusMessage = message;
        emit statusMessageChanged(message);
    }
}

bool ArchiveInterface::createEmptyFile(const QString &filePath) {
    if (filePath.isEmpty()) {
        return false;
    }
    QString cleanPath = filePath;
    if (cleanPath.startsWith(QStringLiteral("file:///"))) {
        cleanPath = QUrl(cleanPath).toLocalFile();
    } else if (cleanPath.startsWith(QStringLiteral("file://"))) {
        cleanPath = cleanPath.mid(7);
    }
    if (!cleanPath.endsWith(QStringLiteral(".sda"), Qt::CaseInsensitive)) {
        cleanPath += QStringLiteral(".sda");
    }

    QFileInfo fi(cleanPath);
    cleanPath = fi.absoluteFilePath();

    std::filesystem::path fsPath(cleanPath.toStdWString());
    try {
        if (fsPath.has_parent_path()) {
            std::error_code ec;
            std::filesystem::create_directories(fsPath.parent_path(), ec);
        }
        std::ofstream ofs(fsPath, std::ios::binary | std::ios::trunc);
        if (!ofs.is_open()) {
            return false;
        }
        ofs.close();
        return true;
    } catch (...) {
        return false;
    }
}

bool ArchiveInterface::createArchive(const QString &filePath,const QString &password,int compressionLevel,bool preserveMetadata,const QStringList &initialFiles) {
    if (filePath.isEmpty()) {
        setStatusMessage( QStringLiteral("Archive creation failed: empty path specified."));
        emit errorOccurred(QStringLiteral("Create Archive Error"), QStringLiteral("Please specify an archive file path."));
        return false;
    }

    QString cleanPath = filePath;
    if (cleanPath.startsWith(QStringLiteral("file:///"))) { // Open file dialog is QML object and returns qurl ready strings
        cleanPath = QUrl(cleanPath).toLocalFile();
    } else if (cleanPath.startsWith(QStringLiteral("file://"))) {
        cleanPath = cleanPath.mid(7);
    }

    if (!cleanPath.endsWith(QStringLiteral(".sda"), Qt::CaseInsensitive)) {
        cleanPath += QStringLiteral(".sda");
    }

    QFileInfo fi(cleanPath);
    cleanPath = fi.absoluteFilePath();

    if (!createEmptyFile(cleanPath)) {
        QString errMsg = QStringLiteral("Could not create archive file on disk: ") + cleanPath;
        setStatusMessage(errMsg);
        emit errorOccurred(QStringLiteral("File Error"), errMsg);
        return false;
    }

    uint16_t compLvl = static_cast<uint16_t>(std::clamp(compressionLevel, 1, 3));
    auto arcRes = SeArchive::CreateArchive(1, compLvl, preserveMetadata,cleanPath.toStdU16String(), password.toStdString());

    if (!arcRes) {
        QString errMsg = QString::fromLocal8Bit(arcRes.error().message().c_str());
        setStatusMessage(QStringLiteral("SeArchive creation failed: ") + errMsg);
        emit errorOccurred(QStringLiteral("Archive Creation Failed"), errMsg);
        return false;
    }

    auto tempArchive = std::make_unique<SeArchive>(std::move(*arcRes));

    auto saveRes = tempArchive->SaveChangesSync(nullptr, std::stop_token());
    if (!saveRes) {
        QString errMsg = QString::fromLocal8Bit(saveRes.error().message().c_str());
        setStatusMessage(QStringLiteral("Failed to save archive metadata: ") + errMsg);
        emit errorOccurred(QStringLiteral("Save Archive Failed"), errMsg);
        return false;
    }
    tempArchive.reset();

    return loadArchive(cleanPath, password, initialFiles);
}

bool ArchiveInterface::loadArchive(const QString &filePath,const QString &password,const QStringList &initialFilesToStage) {

    m_stopSource.request_stop();
    m_stopSource = std::stop_source(); // Stop source is global , doing this to stop any ongoing operation

    QString cleanPath = filePath;
    if (cleanPath.startsWith(QStringLiteral("file:///"))) {
        cleanPath = QUrl(cleanPath).toLocalFile();
    } else if (cleanPath.startsWith(QStringLiteral("file://"))) {
        cleanPath = cleanPath.mid(7);
    }

    cleanPath = QUrl::fromPercentEncoding(cleanPath.toUtf8());

    QFileInfo fi(cleanPath);
    if (!fi.exists() || !fi.isFile()) {
        QString errMsg = QStringLiteral("Archive file not found:\n%1").arg(cleanPath);
        setStatusMessage(errMsg);
        emit errorOccurred(QStringLiteral("Open Archive Failed"), errMsg);
        return false;
    }

    if (!cleanPath.endsWith(QStringLiteral(".sda"), Qt::CaseInsensitive)) {
        QString errMsg = QStringLiteral("The selected file '%1' is not a sda formated file.").arg(fi.fileName());
        setStatusMessage(errMsg);
        emit errorOccurred(QStringLiteral("Invalid file"), errMsg);
        return false;
    }

    //m_lastAttemptedArchivePath = cleanPath;
    //emit lastAttemptedArchivePathChanged();

    setBusy(true);
    m_isLoadingArchive = true;
    emit isLoadingArchiveChanged(true);
    setStatusMessage(QStringLiteral("Opening archive: ") + fi.fileName() + QStringLiteral("..."));

    // ENTROPY CONCEPT IS REMOVED

    std::stop_token stopToken = m_stopSource.get_token();

    std::thread([this, cleanPath, password, initialFilesToStage, stopToken]() {
        // Archive loader worker

        if (stopToken.stop_requested())
            return;

        auto arcRes = SeArchive::LoadArchiveFile(cleanPath.toStdU16String());
        if (stopToken.stop_requested())
            return;

        if (!arcRes) {
            auto err = arcRes.error();
            QString errMsg = QString::fromLocal8Bit(err.message().c_str());
            QString errTitle = QStringLiteral("Load Error");

            if (err == SeError::InvalidTOCMagic || err == SeError::NoTOCFound || err == SeError::BufferUnderflow || err == SeError::BufferStringOverflow) {
                errTitle = QStringLiteral("Invalid TOC");
            }

            QMetaObject::invokeMethod( // XThread calling ui
                this,
                [this, errTitle, errMsg]() {
                    m_isLoadingArchive = false;
                    emit isLoadingArchiveChanged(false);
                    setBusy(false);
                    setStatusMessage(QStringLiteral("Cannot open archive: ") + errMsg);
                    emit errorOccurred(errTitle, errMsg);
                },
                Qt::QueuedConnection);
            return;
        }

        auto loadedArchive = std::make_unique<SeArchive>(std::move(*arcRes));

        bool isKeyRegistered = false;
        if (!password.isEmpty()) {
            auto keyRes = loadedArchive->RegisterKey(password.toStdString());
            isKeyRegistered = keyRes.has_value();
        } else {
            isKeyRegistered = loadedArchive->IsKeyPresent();
        }

        if (stopToken.stop_requested())
            return;

        QMetaObject::invokeMethod(
            this,
            [this, cleanPath, password, initialFilesToStage,
                arc = std::move(loadedArchive), isKeyRegistered]() mutable {
                m_archive = std::move(arc);
                m_archivePath = cleanPath;
                m_metadata->updateFromSeMetadata(m_archive->GetMetadata());
                m_metadata->setArchiveFileName(cleanPath);
                m_isKeyRegistered = isKeyRegistered;
                emit keyStatusChanged(m_isKeyRegistered);

                m_stagedPendingItems.clear();
                refreshArchiveView();

                // REPLACED WITH PVV

                m_isLoadingArchive = false;
                emit isLoadingArchiveChanged(false);
                setBusy(false);
                setStatusMessage(QStringLiteral("Loaded archive: ") + archiveFileName());
                emit archiveLoadedChanged(true);

                if (!initialFilesToStage.isEmpty()) {
                    this->addFilesToArchive(initialFilesToStage, QStringLiteral("/"));
                }
            },
            Qt::QueuedConnection);
    }).detach();

    return true;
}

void ArchiveInterface::closeArchive() {
    //m_fileMapCalcGeneration.fetch_add(1);
    m_stopSource.request_stop();
    m_stopSource = std::stop_source();

    m_isLoadingArchive = false;
    emit isLoadingArchiveChanged(false);
    m_isOptimizing = false;
    emit isOptimizingChanged(false);
    m_isCommitting = false;
    emit isCommittingChanged(false);
    m_isAddingFiles = false;
    emit isAddingFilesChanged(false);
    m_indexedFolders = 0;
    m_indexedFiles = 0;
    emit indexingCountersChanged();

    m_archive = nullptr;
    m_archivePath.clear();
    m_isKeyRegistered = false;
    if (m_treeModel)
    m_treeModel->clear();
    if (m_jobModel)
    m_jobModel->clear();
    m_archiveTree.clear();
    m_jobsList.clear();
    m_stagedPendingItems.clear();


    emit archiveLoadedChanged(false);
    emit keyStatusChanged(false);
    emit archiveTreeChanged();
    emit jobsChanged();
    setStatusMessage(QStringLiteral("No Archive Open"));
}

bool ArchiveInterface::registerKey(const QString &password) {
    if (!m_archive) {
        setStatusMessage(QStringLiteral("No active archive to register key."));
        return false;
    }

    std::string passStr = password.toStdString();
    auto keyRes = m_archive->RegisterKey(passStr);
    if (!keyRes) {
        QString errMsg = QString::fromLocal8Bit(keyRes.error().message().c_str());
        setStatusMessage(QStringLiteral("Key registration failed: ") + errMsg);
        emit errorOccurred(QStringLiteral("Key Registration Failed"), errMsg);
        m_isKeyRegistered = false;
        emit keyStatusChanged(false);
        return false;
    }

    m_isKeyRegistered = true;
    emit keyStatusChanged(true);

    return true;
}

bool ArchiveInterface::addFilesToArchive(const QStringList &fileUrls, const QString &targetArchiveFolder) {
    if (!m_archive) {
        setStatusMessage(QStringLiteral("Cannot add files: no open archive."));
        return false;
    }

    if (!m_isKeyRegistered && !m_archive->IsKeyPresent()) {
        emit passwordRequired(m_archivePath);
        return false;
    }

    QString normTargetDir = targetArchiveFolder;
    if (!normTargetDir.startsWith(u'/'))
        normTargetDir.prepend(u'/');

    if (!normTargetDir.endsWith(u'/'))
        normTargetDir.append(u'/');

    m_indexedFolders = 0;
    m_indexedFiles = 0;
    emit indexingCountersChanged();

    m_isAddingFiles = true;
    emit isAddingFilesChanged(true);
    setStatusMessage(QStringLiteral("Indexing is in progress..."));

    std::thread([this, fileUrls, normTargetDir]() {

        std::vector<PendingStagedItem> newPendingItems;
        int stagedCount = 0;
        int totalFoldersIndexed = 0;
        int totalFilesIndexed = 0;
        auto lastUiPostTime = std::chrono::steady_clock::now();

        for (const QString &rawUrl : fileUrls) { 
            QString localPath = rawUrl;

            if (localPath.startsWith(QStringLiteral("file:///"))) {
                localPath = QUrl(localPath).toLocalFile();
            }
            else if (localPath.startsWith(QStringLiteral("file://"))) {
                localPath = localPath.mid(7);
            }
            localPath = QUrl::fromPercentEncoding(localPath.toUtf8());

            QFileInfo fi(localPath);
            if (!fi.exists()) {
                continue;
            }

            if (!m_archive)
                break;

            if (fi.isDir()) {
            int baseFolders = totalFoldersIndexed;
            int baseFiles = totalFilesIndexed;

            auto progressCb = [&](size_t fCount, size_t dCount) {
                totalFoldersIndexed = baseFolders + static_cast<int>(dCount);
                totalFilesIndexed = baseFiles + static_cast<int>(fCount);

                auto now = std::chrono::steady_clock::now();
                if (std::chrono::duration_cast<std::chrono::milliseconds>(now - lastUiPostTime).count() >= 40) {
                lastUiPostTime = now;
                QMetaObject::invokeMethod(
                    this,
                    [this, d = totalFoldersIndexed, f = totalFilesIndexed]() {
                        m_indexedFolders = d;
                        m_indexedFiles = f;
                        emit indexingCountersChanged();
                    },
                    Qt::QueuedConnection);
                }
            };

            auto res = m_archive->AddDirectoryWithDetails(localPath.toStdU16String(),
                                                            normTargetDir.toStdU16String(),
                                                            progressCb);
            if (res) {
                for (const auto &discovered : *res) {
                    PendingStagedItem item;
                    item.localDiskPath = QString::fromStdU16String(discovered.diskPath);
                    item.name = QString::fromStdU16String(discovered.name);
                    item.archiveRelPath = QString::fromStdU16String(discovered.archiveRelPath);
                    item.isDirectory = discovered.isDirectory;
                    item.size = discovered.size;
                    newPendingItems.push_back(std::move(item));
                    stagedCount++;
                }
            } else {
                QString errMsg =
                    QString::fromLocal8Bit(res.error().message().c_str());
                QMetaObject::invokeMethod(
                    this,
                    [this, errMsg]() {
                    emit errorOccurred(QStringLiteral("Add Directory Failed"),
                                        errMsg);
                    },
                    Qt::QueuedConnection);
            }
            } 
            else {
                QString destRelPath = normTargetDir + fi.fileName();
                auto res = m_archive->AddFile(destRelPath.toStdU16String(),localPath.toStdU16String());

                if (res) {
                    PendingStagedItem item;
                    item.localDiskPath = localPath;
                    item.name = fi.fileName();
                    item.archiveRelPath = destRelPath;
                    item.isDirectory = false;
                    item.size = static_cast<qulonglong>(fi.size());
                    newPendingItems.push_back(item);
                    stagedCount++;
                    totalFilesIndexed++;

                    auto now = std::chrono::steady_clock::now();
                    if (std::chrono::duration_cast<std::chrono::milliseconds>(now - lastUiPostTime).count() >= 40) {
                    lastUiPostTime = now;

                    QMetaObject::invokeMethod(this,
                        [this, d = totalFoldersIndexed, f = totalFilesIndexed]() {
                            m_indexedFolders = d;
                            m_indexedFiles = f;
                            emit indexingCountersChanged();
                        },
                        Qt::QueuedConnection);
                    }
                } 
                else {
                    QString errMsg =
                        QString::fromLocal8Bit(res.error().message().c_str());
                    QMetaObject::invokeMethod(this,
                        [this, errMsg]() {
                            emit errorOccurred(QStringLiteral("Add File Failed"), errMsg);
                        },
                        Qt::QueuedConnection);
                }
            }
        }

        QMetaObject::invokeMethod(this,[this, d = totalFoldersIndexed, f = totalFilesIndexed]() {
                m_indexedFolders = d;
                m_indexedFiles = f;
                emit indexingCountersChanged();
            },
            Qt::QueuedConnection);

        std::this_thread::sleep_for(std::chrono::milliseconds(600)); // delay beofore closing indexing popup

        QMetaObject::invokeMethod(this,
            [this, items = std::move(newPendingItems), stagedCount]() mutable {
                for (auto &it : items) { // Possible UI chocking point
                    m_stagedPendingItems.insert(it.archiveRelPath, std::move(it));
                }
                m_isAddingFiles = false;
                emit isAddingFilesChanged(false);
                syncJobsList();
                buildArchiveTree();
                setStatusMessage(QStringLiteral("Added %1 item(s) to archive (Staged for commit)").arg(stagedCount));
            },
            Qt::QueuedConnection);
    }).detach();

    return true;
}

void ArchiveInterface::scanFolderAsync(const QString &folderUrl, const QJSValue &callback) {
    QString localPath = folderUrl;
    if (localPath.startsWith(QStringLiteral("file:///"))) {
        localPath = QUrl(localPath).toLocalFile();
    } else if (localPath.startsWith(QStringLiteral("file://"))) {
        localPath = localPath.mid(7);
    }
    localPath = QUrl::fromPercentEncoding(localPath.toUtf8());

    QJSValue cbCopy = callback;

    std::thread([this, localPath, cb = cbCopy]() mutable {
        QFileInfo fi(localPath);
        if (!fi.exists()) {
            return;
        }

        if (fi.isFile()) { // Using QVariant for file tree source is memory consuming
            QVariantMap fileNode;
            fileNode[QStringLiteral("name")] = fi.fileName();
            fileNode[QStringLiteral("filePath")] = fi.absoluteFilePath();
            fileNode[QStringLiteral("isFolder")] = false;
            fileNode[QStringLiteral("realSize")] = SeFileEntryObject::formatBytes(fi.size());
            fileNode[QStringLiteral("children")] = QVariantList();

            QMetaObject::invokeMethod(this,
                [this, cb, fileNode]() mutable {
                if (cb.isCallable()) {
                    QJSEngine *engine = qjsEngine(this);
                    if (engine) {
                        QJSValue arg = engine->toScriptValue(fileNode);
                        cb.call(QJSValueList{arg});
                    }
                }
                },
                Qt::QueuedConnection);
            return;
        }

        if (!fi.isDir()) {
            return;
        }

        std::function<QVariantMap(const QFileInfo &)> scanDirRecursive = [&](const QFileInfo &dirFi) -> QVariantMap
        {
            QVariantMap node;
            node[QStringLiteral("name")] = dirFi.fileName();
            node[QStringLiteral("filePath")] = dirFi.absoluteFilePath();
            node[QStringLiteral("isFolder")] = true;
            node[QStringLiteral("expanded")] = false;
            node[QStringLiteral("realSize")] = QStringLiteral("-");

            QDir dir(dirFi.absoluteFilePath());
            QFileInfoList entries =
                dir.entryInfoList(QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot,
                                QDir::DirsFirst | QDir::Name);
            QVariantList children;
            for (const auto &entry : entries) {
            if (entry.isDir()) {
                children.append(scanDirRecursive(entry));
            } else {
                QVariantMap fileNode;
                fileNode[QStringLiteral("name")] = entry.fileName();
                fileNode[QStringLiteral("filePath")] = entry.absoluteFilePath();
                fileNode[QStringLiteral("isFolder")] = false;
                fileNode[QStringLiteral("realSize")] =
                    SeFileEntryObject::formatBytes(entry.size());
                fileNode[QStringLiteral("children")] = QVariantList();
                children.append(fileNode);
            }
            }
            node[QStringLiteral("children")] = children;
            return node;
        };

        QVariantMap result = scanDirRecursive(fi);

        QMetaObject::invokeMethod(
            this,
            [this, cb, result]() mutable {
                if (cb.isCallable()) {
                    QJSEngine *engine = qjsEngine(this);
                    if (engine) {
                        QJSValue arg = engine->toScriptValue(result);
                        cb.call(QJSValueList{arg});
                    }
                }
            },
            Qt::QueuedConnection);
    }).detach();
}

bool ArchiveInterface::removeArchiveItem(const QString &archiveRelativePath, bool isDirectory) {
    if (!m_archive)
        return false;

    QString normPath = archiveRelativePath;
    normPath.replace(u'\\', u'/');

    while (normPath.contains(QStringLiteral("//"))) {
        normPath.replace(QStringLiteral("//"), QStringLiteral("/"));
    }

    if (!normPath.startsWith(u'/')) {
        normPath.prepend(u'/');
    }

    QString pathWithSlash = normPath.endsWith(u'/') ? normPath : (normPath + u'/');
    QString pathNoSlash = (normPath.length() > 1 && normPath.endsWith(u'/'))
                            ? normPath.left(normPath.length() - 1)
                            : normPath;

    // Determine if target is a directory
    bool isDir = isDirectory || normPath.endsWith(u'/');
    if (!isDir) {
        auto it1 = m_stagedPendingItems.constFind(pathWithSlash);
        if (it1 != m_stagedPendingItems.constEnd() && it1->isDirectory) {
            isDir = true;
        }
        else {
            auto it2 = m_stagedPendingItems.constFind(pathNoSlash);
            if (it2 != m_stagedPendingItems.constEnd() && it2->isDirectory) {
                isDir = true;
            }
        }
    }

    std::vector<int> jobIdsToRemove;
    if (!isDir && m_archive) {
        std::u16string u16Slash = pathWithSlash.toStdU16String();
        std::u16string u16NoSlash = pathNoSlash.toStdU16String();
        for (const auto &job : m_archive->GetJobs()) {
            if (job.GetJobType() == JobType::CreateArchiveDirectory ||
                job.GetJobType() == JobType::AddDirectory ||
                job.GetJobType() == JobType::DeleteDirectory ||
                job.GetJobType() == JobType::MoveDirectory)
            {

                if (job.GetFileName() == u16Slash || job.GetFileName() == u16NoSlash) { // BUG: Seams like job.FileName can have two type of URL
                    isDir = true;
                    break;
                }
            }
        }
    }

    if (!isDir && m_archive) {
        std::u16string u16Slash = pathWithSlash.toStdU16String();
        std::u16string u16NoSlash = pathNoSlash.toStdU16String();
        if (m_archive->GetTOC().IsDirectory(u16Slash) || m_archive->GetTOC().IsDirectory(u16NoSlash)) {
            isDir = true;
        }
    }

    std::u16string u16Slash = pathWithSlash.toStdU16String();
    std::u16string u16NoSlash = pathNoSlash.toStdU16String();

    // 1. Identify all matching jobs to remove in m_archive->GetJobs()
    
    for (const auto &job : m_archive->GetJobs()) {
        std::u16string jobFile = job.GetFileName();
        bool match = false;
        if (isDir) {
            if (jobFile == u16Slash || jobFile == u16NoSlash) {
                match = true;
            }
            else if (jobFile.starts_with(u16Slash)) {
                match = true;
            }
            else if (job.GetJobType() == JobType::CreateArchiveDirectory || job.GetJobType() == JobType::AddDirectory) {
                std::u16string jobDirWithSlash = jobFile;
                if (!jobDirWithSlash.empty() && jobDirWithSlash.back() != u'/') {
                    jobDirWithSlash.push_back(u'/');
                }
                if (jobDirWithSlash == u16Slash || jobDirWithSlash.starts_with(u16Slash)) {
                    match = true;
                }
            }
            if (job.GetJobType() == JobType::MoveArchiveFile || job.GetJobType() == JobType::MoveDirectory) {
                std::u16string jobDst = job.GetFilePath();
                if (jobDst.starts_with(u16Slash)) {
                    match = true;
                }
            }
        } else {
            if (jobFile == u16NoSlash || jobFile == u16Slash) {
                match = true;
            }
        }

        if (match) {
            jobIdsToRemove.push_back(job.GetId());
        }
    }

    std::vector<QString> stagedToRemove;
    for (auto it = m_stagedPendingItems.constBegin(); it != m_stagedPendingItems.constEnd(); ++it) { // Pending path check
        const QString &sPath = it.key();
        if (sPath == pathWithSlash || sPath == pathNoSlash) {
            stagedToRemove.push_back(it.value().archiveRelPath);
        } 
        else if (isDir && (sPath.startsWith(pathWithSlash) || (!sPath.endsWith(u'/') && (sPath + u'/').startsWith(pathWithSlash)))) {
            stagedToRemove.push_back(it.value().archiveRelPath);
        }
    }

    for (const auto &p : stagedToRemove) {
        std::u16string u16p = p.toStdU16String();
        for (const auto &job : m_archive->GetJobs()) {
            if (job.GetFileName() == u16p) {
                if (std::find(jobIdsToRemove.begin(), jobIdsToRemove.end(), job.GetId()) == jobIdsToRemove.end()) {
                    jobIdsToRemove.push_back(job.GetId());
                }
            }
        }
    }

    for (int id : jobIdsToRemove) {
        (void)m_archive->RemoveJob(id);
    }

    for (const auto &p : stagedToRemove) {
        m_stagedPendingItems.remove(p);
    }

    bool existsInToc = m_archive->GetTOC().CheckPath(u16Slash) || m_archive->GetTOC().CheckPath(u16NoSlash);

    bool wasPending = (!jobIdsToRemove.empty()) || (!stagedToRemove.empty());

    if (existsInToc) { // Add a delete job
        if (isDir) {
            auto res = m_archive->DeleteDirectory(u16Slash);
            if (!res) {
            QString errMsg = QString::fromLocal8Bit(res.error().message().c_str());
            setStatusMessage(QStringLiteral("Failed to remove directory: ") + errMsg);
            emit errorOccurred(QStringLiteral("Delete Directory Failed"), errMsg);
            return false;
            }
        } else {
            auto res = m_archive->RemoveFile(u16NoSlash);
            if (!res) {
            QString errMsg = QString::fromLocal8Bit(res.error().message().c_str());
            setStatusMessage(QStringLiteral("Failed to remove file: ") + errMsg);
            emit errorOccurred(QStringLiteral("Remove File Failed"), errMsg);
            return false;
            }
        }
        syncJobsList();
        buildArchiveTree();
        setStatusMessage(QStringLiteral("Removed '%1' (Staged for commit)").arg(archiveRelativePath));
        return true;
    }

    if (wasPending) {
        syncJobsList();
        buildArchiveTree();
        setStatusMessage(QStringLiteral("Discarded staged item '%1'").arg(archiveRelativePath));
        return true;
    }

    syncJobsList();
    buildArchiveTree();
    setStatusMessage(QStringLiteral("Item '%1' not found in archive.").arg(archiveRelativePath));
    return false;
}

bool ArchiveInterface::moveArchiveItem(const QString &sourceRelativePath, const QString &destRelativePath, bool isDirectory) {
    if (!m_archive)
        return false;

    QString normSrc = sourceRelativePath;

    if (!normSrc.startsWith(u'/'))
        normSrc.prepend(u'/');

    QString normDst = destRelativePath;
    if (!normDst.startsWith(u'/'))
        normDst.prepend(u'/');

    if (!normDst.endsWith(u'/'))
        normDst.append(u'/'); // Destination must always be a directory


    bool foundInStaged = false;
    std::vector<QString> keysToUpdate;
    for (auto it = m_stagedPendingItems.constBegin(); it != m_stagedPendingItems.constEnd(); ++it) {
        if (it.key() == normSrc || (isDirectory && it.key().startsWith(normSrc))) {
            keysToUpdate.push_back(it.key());
        }
    }

    for (const auto &oldKey : keysToUpdate) {
        PendingStagedItem staged = m_stagedPendingItems.take(oldKey);
        QString oldRelPath = staged.archiveRelPath;
        if (staged.archiveRelPath == normSrc) {
            QString fn = staged.name;
            staged.archiveRelPath =
                normDst + fn +
                (staged.isDirectory ? QStringLiteral("/") : QStringLiteral(""));
        }
        else if (isDirectory && staged.archiveRelPath.startsWith(normSrc)) {
            QString relPart = staged.archiveRelPath.mid(normSrc.length());
            QString dirName = QFileInfo(normSrc.endsWith(u'/')
                                            ? normSrc.left(normSrc.length() - 1)
                                            : normSrc)
                                .fileName();
            staged.archiveRelPath =
                normDst + dirName + QStringLiteral("/") + relPart;
        }

        // Update matching job in m_archive if any
        std::u16string u16Old = oldRelPath.toStdU16String();
        for (const auto &job : m_archive->GetJobs()) {
            if (job.GetFileName() == u16Old) {
                (void)m_archive->RemoveJob(job.GetId());
                if (!staged.isDirectory && !staged.localDiskPath.isEmpty()) {
                    (void)m_archive->AddFile(staged.archiveRelPath.toStdU16String(),staged.localDiskPath.toStdU16String());
                }
                break;
            }
        }
        m_stagedPendingItems.insert(staged.archiveRelPath, std::move(staged));
        foundInStaged = true;
    }
    if (foundInStaged) {
        syncJobsList();
        buildArchiveTree();
        setStatusMessage(QStringLiteral("Moved staged item '%1' to '%2'")
                                .arg(sourceRelativePath, destRelativePath));
        return true;
    }

    if (isDirectory) {
        if (!normSrc.endsWith(u'/'))
            normSrc.append(u'/');

        auto res = m_archive->MoveDirectory(normSrc.toStdU16String(),
                                            normDst.toStdU16String());
        if (!res) {
            QString errMsg = QString::fromLocal8Bit(res.error().message().c_str());
            setStatusMessage(QStringLiteral("Failed to move directory: ") + errMsg);
            emit errorOccurred(QStringLiteral("Move Directory Failed"), errMsg);
            return false;
        }
    }
    else {
        if (normSrc.endsWith(u'/'))
            normSrc.chop(1);
        auto res = m_archive->MoveArchiveFile(normSrc.toStdU16String(),
                                                normDst.toStdU16String());
        if (!res) {
            QString errMsg = QString::fromLocal8Bit(res.error().message().c_str());
            setStatusMessage(QStringLiteral("Failed to move file: ") + errMsg);
            emit errorOccurred(QStringLiteral("Move File Failed"), errMsg);
            return false;
        }
    }

    syncJobsList();
    buildArchiveTree();
    setStatusMessage(QStringLiteral("Moved '%1' to '%2' (Staged for commit)").arg(sourceRelativePath, destRelativePath));
    return true;
}

bool ArchiveInterface::saveChanges() {
    if (!m_archive) {
        setStatusMessage(QStringLiteral("No archive open to save."));
        return false;
    }

    if (!m_isKeyRegistered && !m_archive->IsKeyPresent()) {
        emit passwordRequired(m_archivePath);
        return false;
    }

    m_stopSource = std::stop_source();
    m_lastExtractOutputDir.clear();
    m_lastExtractRelPath.clear();

    // Synchronize jobs model with the post-optimization queue so that
    // execution proceeds strictly according to the clean, ordered queue
    syncJobsList();

    setBusy(true);
    m_isCommitting = true;
    emit isCommittingChanged(true);
    m_currentOperationName = QStringLiteral("Writing Archive Changes");
    setStatusMessage(QStringLiteral("Saving changes to archive..."));
    m_overallProgress = 0.0;
    m_fileProgress = 0.0;
    emit progressChanged();

    struct BatchState {
        std::mutex mtx;
        std::vector<SeJob> pending;
        int64_t lastDispatchMs = 0;
    };

    auto batchState = std::make_shared<BatchState>();

    auto flushBatch = [this, batchState](bool /*force*/) {
        std::vector<SeJob> toSend;
        {
            std::lock_guard<std::mutex> lock(batchState->mtx);
            if (!batchState->pending.empty()) {
                toSend.swap(batchState->pending);
                batchState->lastDispatchMs = std::chrono::duration_cast<std::chrono::milliseconds>(
                                std::chrono::steady_clock::now().time_since_epoch())
                                .count();
            }
        }
        if (!toSend.empty()) {
        QMetaObject::invokeMethod(
            this,
            [this, batch = std::move(toSend)]() {
                this->onJobsBatchProgressUpdated(batch);
            },
            Qt::QueuedConnection);
        }
    };

    auto callback = [batchState, flushBatch](const SeJob &job) {
        {
            std::lock_guard<std::mutex> lock(batchState->mtx);
            batchState->pending.push_back(job);
        }// End of critical section
        flushBatch(false);
    };

    auto taskHandle = std::make_shared<SeTaskHandle<void>>(m_archive->SaveChangesAsync(callback));
    m_currentTask = taskHandle;
    emit isPausedChanged(false);

    std::thread([this, taskHandle, flushBatch]() {
        auto res = taskHandle->get();

        // Flush unposted jobs
        flushBatch(true);

        QMetaObject::invokeMethod(
            this,
            [this, success = res.has_value(),
                errMsg =
                    res ? QString()
                        : QString::fromLocal8Bit(res.error().message().c_str())]() {
                this->onSaveCompleted(success, errMsg);
            },
            Qt::QueuedConnection);
    }).detach();

    return true;
}

bool ArchiveInterface::saveArchive() { return saveChanges(); }

void ArchiveInterface::optimizeJobsAsync() {
    if (!m_archive) {
        setStatusMessage(QStringLiteral("No archive open to optimize."));
        emit optimizationCompleted(QVariantList());
        return;
    }

    if (!m_isKeyRegistered && !m_archive->IsKeyPresent()) {
        emit passwordRequired(m_archivePath);
        return;
    }

    if (m_isOptimizing || m_isCommitting) {
        return;
    }

    m_isOptimizing = true;
    emit isOptimizingChanged(true);
    setStatusMessage(QStringLiteral("Optimizing archive jobs queue..."));

    std::thread([this]() {
        auto deletedIds = m_archive->optimizeJobs();

        QVariantList qDeletedIds;
        qDeletedIds.reserve(static_cast<qsizetype>(deletedIds.size()));
        for (int id : deletedIds) {
            qDeletedIds.append(id);
        }

        QMetaObject::invokeMethod(
            this,
            [this, qDeletedIds]() {
                m_isOptimizing = false;
                emit isOptimizingChanged(false);
                setStatusMessage(QStringLiteral("Job queue optimization completed."));
                emit optimizationCompleted(qDeletedIds);
            },
            Qt::QueuedConnection);
    }).detach();
}

bool ArchiveInterface::extractItem(const QString &archiveRelativePath,const QString &outputDir) {
    if (!m_archive)
        return false;

    if (!m_isKeyRegistered && !m_archive->IsKeyPresent()) {
        emit passwordRequired(m_archivePath);
        return false;
    }

    QString cleanOut = outputDir;
    if (cleanOut.startsWith(QStringLiteral("file:///"))) {
        cleanOut = QUrl(cleanOut).toLocalFile();
    }
    else if (cleanOut.startsWith(QStringLiteral("file://"))) {
        cleanOut = cleanOut.mid(7);
    }

    QString normPath = archiveRelativePath;
    if (!normPath.startsWith(u'/'))
        normPath.prepend(u'/');

    bool isDir = normPath.endsWith(u'/');
    if (!isDir && m_archive) {
        auto u16p = normPath.toStdU16String();
        if (m_archive->GetTOC().IsDirectory(u16p) || m_archive->GetTOC().IsDirectory(u16p + u'/')) {
            isDir = true;
            normPath.append(u'/');
        }
    }

    m_stopSource = std::stop_source();
    m_lastExtractOutputDir = cleanOut;
    m_lastExtractRelPath = normPath;

    setBusy(true);
    m_currentOperationName = QStringLiteral("Extracting: ") + normPath;
    setStatusMessage(QStringLiteral("Extracting item..."));
    m_overallProgress = 0.0;
    m_fileProgress = 0.0;
    m_processedFiles = 0;
    m_totalFiles = 1;
    m_extractTotalBytes = 0;
    m_extractProcessedBytes = 0;
    m_extractCompressedBytes = 0;

    if (m_archive) {
        qulonglong extBytes = 0;
        int extFileCount = 0;
        const auto &entries = m_archive->GetTOC().GetEntries();

        for (const auto &e : entries) {
            if (e.path == u"/") continue;
            if (!e.isDirectory()) {
                QString ep = QString::fromStdU16String(e.path);
                if (normPath == u"/" || ep.startsWith(normPath)) {
                    extBytes += e.uncompressed_size;
                    extFileCount++;
                }
            }
        }
        m_extractTotalBytes = extBytes;
        if (m_jobModel) {
            m_jobModel->setExtractJobs({ normPath }, extBytes);
        }
    }
    emit progressChanged();

    auto callback = [this](const SeJob &job) {
        QMetaObject::invokeMethod(
            this, [this, job]() { this->onJobProgressUpdated(job); },
            Qt::QueuedConnection);
    };

    std::shared_ptr<SeTaskHandle<size_t>> taskHandle;
    if (isDir) {
        taskHandle = std::make_shared<SeTaskHandle<size_t>>(
            m_archive->ExtractDirectoryAsync(normPath.toStdU16String(), cleanOut.toStdU16String(), callback));
    } 
    else {
        taskHandle = std::make_shared<SeTaskHandle<size_t>>(m_archive->ExtractFileAsync(normPath.toStdU16String(),cleanOut.toStdU16String(), callback));
    }
    m_currentTask = taskHandle;
    emit isPausedChanged(false);

    std::thread([this, taskHandle, normPath]() {
        auto res = taskHandle->get();
        bool isCryptoFail = (!res && res.error() == SeError::CRYPTOGenericFailure);
        QMetaObject::invokeMethod(
            this,
            [this, success = res.has_value(), isCryptoFail, normPath,
            errMsg =
                res ? QString()
                    : QString::fromLocal8Bit(res.error().message().c_str())]() {
            this->onExtractCompleted(success, errMsg, isCryptoFail, normPath);
            },
            Qt::QueuedConnection);
    }).detach();

    return true;
}

bool ArchiveInterface::extractAll(const QString &outputDir) {
  return extractItem(QStringLiteral("/"), outputDir);
}

#ifdef Q_OS_WIN
static QString getExplorerOrDesktopPathAtPoint(POINT pt) {
    HWND hwnd = WindowFromPoint(pt);
    if (!hwnd) return QStandardPaths::writableLocation(QStandardPaths::DesktopLocation);

    HWND rootHwnd = GetAncestor(hwnd, GA_ROOT);
    HWND targetHwnd = rootHwnd ? rootHwnd : hwnd;

    // If released over SecDet's own window, don't trigger external drop
    DWORD pid = 0;
    GetWindowThreadProcessId(targetHwnd, &pid);
    if (pid == GetCurrentProcessId()) {
        return QString();
    }

    WCHAR className[256] = {0};
    GetClassNameW(targetHwnd, className, 255);

    // Desktop check
    if (wcscmp(className, L"Progman") == 0 || wcscmp(className, L"WorkerW") == 0) {
        return QStandardPaths::writableLocation(QStandardPaths::DesktopLocation);
    }

    // Explorer window check
    HWND cur = hwnd;
    HWND explorerHwnd = nullptr;
    while (cur) {
        GetClassNameW(cur, className, 255);
        if (wcscmp(className, L"CabinetWClass") == 0 || wcscmp(className, L"ExploreWClass") == 0) {
            explorerHwnd = cur;
            break;
        }
        cur = GetParent(cur);
    }
    if (!explorerHwnd && rootHwnd) {
        GetClassNameW(rootHwnd, className, 255);
        if (wcscmp(className, L"CabinetWClass") == 0 || wcscmp(className, L"ExploreWClass") == 0) {
            explorerHwnd = rootHwnd;
        }
    }

    if (explorerHwnd) {
        IShellWindows* pShellWindows = nullptr;
        if (SUCCEEDED(CoCreateInstance(CLSID_ShellWindows, NULL, CLSCTX_ALL, IID_IShellWindows, (void**)&pShellWindows)) && pShellWindows) {
            long count = 0;
            pShellWindows->get_Count(&count);
            for (long i = 0; i < count; ++i) {
                VARIANT v;
                VariantInit(&v);
                v.vt = VT_I4;
                v.lVal = i;
                IDispatch* pDisp = nullptr;
                if (SUCCEEDED(pShellWindows->Item(v, &pDisp)) && pDisp) {
                    IWebBrowserApp* pBrowser = nullptr;
                    if (SUCCEEDED(pDisp->QueryInterface(IID_IWebBrowserApp, (void**)&pBrowser)) && pBrowser) {
                        HWND bHwnd = nullptr;
                        pBrowser->get_HWND((SHANDLE_PTR*)&bHwnd);
                        if (bHwnd == explorerHwnd) {
                            BSTR url = nullptr;
                            pBrowser->get_LocationURL(&url);
                            if (url) {
                                QString qurl = QString::fromWCharArray(url);
                                SysFreeString(url);
                                pBrowser->Release();
                                pDisp->Release();
                                pShellWindows->Release();
                                if (qurl.startsWith(QStringLiteral("file:///"))) {
                                    return QUrl(qurl).toLocalFile();
                                }
                            }
                        }
                        pBrowser->Release();
                    }
                    pDisp->Release();
                }
            }
            pShellWindows->Release();
        }
    }

    return QStandardPaths::writableLocation(QStandardPaths::DesktopLocation);
}
#endif

// ─── Native OS File Drag ─────────────────────────────────────────────────────

void ArchiveInterface::startNativeFileDrag(const QString &archiveRelativePath,
                                           const QString &displayName,
                                           bool isFolder) {
    if (!m_archive) return;

    if (!m_isKeyRegistered && !m_archive->IsKeyPresent()) {
        emit passwordRequired(m_archivePath);
        return;
    }

    QString normPath = archiveRelativePath;
    if (!normPath.startsWith(u'/')) normPath.prepend(u'/');
    if (isFolder && !normPath.endsWith(u'/')) normPath.append(u'/');

    QString primaryName = displayName;
    if (primaryName.isEmpty()) {
        QString stripped = normPath;
        if (stripped.endsWith(u'/') && stripped.length() > 1) stripped.chop(1);
        primaryName = stripped.section(u'/', -1);
    }
    if (primaryName.isEmpty()) primaryName = QStringLiteral("Item");

    // Clean, normal drag overlay badge
    QFont font(QStringLiteral("Segoe UI"));
    font.setPixelSize(12);
    font.setWeight(QFont::Medium);
    QFontMetrics fm(font);
    int textWidth = fm.horizontalAdvance(primaryName);
    int pixmapWidth = 32 + textWidth + 20;
    int pixmapHeight = 34;

    QPixmap dragPixmap(pixmapWidth, pixmapHeight);
    dragPixmap.fill(Qt::transparent);
    {
        QPainter painter(&dragPixmap);
        painter.setRenderHint(QPainter::Antialiasing);

        QPainterPath path;
        path.addRoundedRect(QRectF(1, 1, pixmapWidth - 2, pixmapHeight - 2), 6, 6);

        painter.fillPath(path, QColor(24, 28, 36, 235));
        painter.setPen(QPen(QColor(218, 165, 32), 1.5));
        painter.drawPath(path);

        painter.setPen(QColor(255, 255, 255));
        painter.setFont(font);
        painter.drawText(QRect(12, 0, pixmapWidth - 16, pixmapHeight),
                         Qt::AlignVCenter | Qt::AlignLeft,
                         (isFolder ? QStringLiteral("📁 ") : QStringLiteral("📄 ")) + primaryName);
    }

    QMimeData *mimeData = new QMimeData();
    mimeData->setData(QStringLiteral("application/x-secdet-export"), normPath.toUtf8());
    mimeData->setText(primaryName);

    QDrag *drag = new QDrag(this);
    drag->setMimeData(mimeData);
    drag->setPixmap(dragPixmap);
    drag->setHotSpot(QPoint(16, pixmapHeight / 2));

    setStatusMessage(QStringLiteral("Dragging '%1' outside window — release to extract").arg(primaryName));

    // Execute native OS drag loop
    Qt::DropAction action = drag->exec(Qt::CopyAction | Qt::MoveAction, Qt::CopyAction);
    Q_UNUSED(action);
    drag->deleteLater();

    // When dropped outside application window
#ifdef Q_OS_WIN
    POINT pt;
    GetCursorPos(&pt);
    QString dropTarget = getExplorerOrDesktopPathAtPoint(pt);
    if (!dropTarget.isEmpty()) {
        setStatusMessage(QStringLiteral("Extracting '%1' to '%2'...").arg(primaryName, dropTarget));
        emit nativeDragDropped(normPath, dropTarget);
    }
#else
    QString dropTarget = QStandardPaths::writableLocation(QStandardPaths::DesktopLocation);
    emit nativeDragDropped(normPath, dropTarget);
#endif
}



bool ArchiveInterface::removeJob(int jobId, int modelIndex) {
    if (!m_archive)
        return false;

    QString targetPath;
    bool isDirJob = false;
    std::vector<int> childJobIds;

    for (const auto &j : m_archive->GetJobs()) {
        if (j.GetId() == jobId) {
            targetPath = QString::fromStdU16String(j.GetFileName());

            if (j.GetJobType() == JobType::CreateArchiveDirectory ||
                j.GetJobType() == JobType::AddDirectory ||
                j.GetJobType() == JobType::DeleteDirectory ||
                j.GetJobType() == JobType::MoveDirectory)
            {
                isDirJob = true;
            }
            break;
        }
    }

    if (jobId > 0) {
        (void)m_archive->RemoveJob(jobId);
    }

    if (isDirJob && !targetPath.isEmpty()) {
        QString dirSlash = targetPath.endsWith(u'/') ? targetPath : (targetPath + u'/');
        std::u16string u16DirSlash = dirSlash.toStdU16String();
        for (const auto &j : m_archive->GetJobs()) {
            if (j.GetFileName().starts_with(u16DirSlash)) {
            childJobIds.push_back(j.GetId());
            }
        }
        for (int childId : childJobIds) {
            (void)m_archive->RemoveJob(childId);
        }
    }

    // Clean up m_stagedPendingItems by path match, NOT by modelIndex!
    if (!targetPath.isEmpty()) {
    QString targetSlash = targetPath.endsWith(u'/') ? targetPath : (targetPath + u'/');
    QString targetNoSlash = (targetPath.length() > 1 && targetPath.endsWith(u'/')) ? targetPath.left(targetPath.length() - 1) : targetPath;

    if (!isDirJob) {
        m_stagedPendingItems.remove(targetSlash);
        m_stagedPendingItems.remove(targetNoSlash);
    }
    else {
        std::vector<QString> toRem;
        for (auto it = m_stagedPendingItems.constBegin(); it != m_stagedPendingItems.constEnd(); ++it) {
            const QString &sPath = it.key();
            if (sPath == targetSlash || sPath == targetNoSlash ||
                sPath.startsWith(targetSlash) ||
                (!sPath.endsWith(u'/') && (sPath + u'/').startsWith(targetSlash))) {
                toRem.push_back(sPath);
            }
        }
        for (const auto &k : toRem) {
            m_stagedPendingItems.remove(k);
        }
    }
    }

    if (m_jobModel) {
        if (modelIndex >= 0 && modelIndex < m_jobModel->count()) {
            m_jobModel->remove(modelIndex);
        } else if (jobId > 0) {
            for (int i = 0; i < m_jobModel->count(); ++i) {
                if (m_jobModel->get(i).value(QStringLiteral("id")).toInt() == jobId) {
                    m_jobModel->remove(i);
                    break;
                }
            }
        }
        for (int cid : childJobIds) {
            for (int i = 0; i < m_jobModel->count(); ++i) {
                if (m_jobModel->get(i).value(QStringLiteral("id")).toInt() == cid) {
                    m_jobModel->remove(i);
                    break;
                }
            }
        }
    }

    syncJobsList();
    buildArchiveTree();
    setStatusMessage(QStringLiteral("Removed job from queue."));
    return true;
}

bool ArchiveInterface::retryJob(int jobId, int modelIndex) {
    m_stopSource = std::stop_source();

    if (m_archive) {
        if (!m_isKeyRegistered && !m_archive->IsKeyPresent()) {
            emit passwordRequired(m_archivePath);
            return false;
        }
        (void)m_archive->ResetJob(jobId);
    }

    if (m_jobModel) {
        if (modelIndex >= 0 && modelIndex < m_jobModel->count()) {
            m_jobModel->setProperty(modelIndex, QStringLiteral("state"),
                                    QStringLiteral("pending"));
            m_jobModel->setProperty(modelIndex, QStringLiteral("progress"), 0.0);
            m_jobModel->setProperty(modelIndex, QStringLiteral("detail"),
                                    QStringLiteral("Queued for retry"));
        }
        for (int i = 0; i < m_jobModel->count(); ++i) {
            QString st = m_jobModel->get(i).value(QStringLiteral("state")).toString();
            if (st == QStringLiteral("failed") || st == QStringLiteral("aborted")) {
            m_jobModel->setProperty(i, QStringLiteral("state"),
                                    QStringLiteral("pending"));
            m_jobModel->setProperty(i, QStringLiteral("progress"), 0.0);
            m_jobModel->setProperty(i, QStringLiteral("detail"),
                                    QStringLiteral("Queued"));
            }
        }
    }

    if (!m_lastExtractOutputDir.isEmpty()) {
        setStatusMessage(QStringLiteral("Retrying extraction..."));
        return extractItem(m_lastExtractRelPath, m_lastExtractOutputDir);
    } else {
        setStatusMessage(QStringLiteral("Retrying archive operations..."));
        return saveChanges();
    }
}

void ArchiveInterface::cancelCurrentOperation() {
    m_stopSource.request_stop();
    if (m_currentTask) {
        m_currentTask->cancel();
    }

    m_currentOperationName = QStringLiteral("Cancelling operation...");
    setStatusMessage(QStringLiteral("Cancelling operation..."));
    if (m_jobModel) {
        m_jobModel->abortRunningJobs();
    }
    emit progressChanged();
}

void ArchiveInterface::pauseCurrentOperation() {
    if (m_currentTask) {
        m_currentTask->pause();
        emit isPausedChanged(true);
    }
}

void ArchiveInterface::resumeCurrentOperation() {
    if (m_currentTask) {
        m_currentTask->resume();
        emit isPausedChanged(false);
    }
}

void ArchiveInterface::togglePauseCurrentOperation() {
    if (m_currentTask) {
        bool paused = m_currentTask->toggle_pause();
        emit isPausedChanged(paused);
    }
}

void ArchiveInterface::setOperationPaused(bool paused) {
    if (m_currentTask) {
        if (paused) {
            m_currentTask->pause();
        } else {
            m_currentTask->resume();
        }
        emit isPausedChanged(m_currentTask->is_paused());
    }
}

bool ArchiveInterface::addCompressionLevelJob(int level) {
    if (level < 1 || level > 3) {
        qWarning() << "addCompressionLevelJob: invalid compression level" << level;
        return false;
    }
    if (!m_archive) {
        setStatusMessage(QStringLiteral("No archive open to set compression level."));
        return false;
    }
    if (isBusy()) {
        emit errorOccurred(QStringLiteral("Busy"), QStringLiteral("Another operation is already in progress."));
        return false;
    }

    auto res = m_archive->ChangeCompressionLevel(static_cast<uint32_t>(level));
    if (!res) {
        emit errorOccurred(QStringLiteral("Job Error"), QStringLiteral("Could not queue compression level change."));
        return false;
    }

    m_metadata->setCompressionLevel(level);
    syncJobsList();
    emit jobsChanged();

    QString lvlName = (level == 1) ? QStringLiteral("Fast")
                    : (level == 2) ? QStringLiteral("Balanced")
                    : QStringLiteral("Ultra");

    setStatusMessage(QStringLiteral("Queued compression level change to %1.").arg(lvlName));
    return true;
}

void ArchiveInterface::setCompressionLevel(int level) {
    if (level < 1 || level > 3) {
        return;
    }
    if (m_archive) {
        addCompressionLevelJob(level);
    } else {
        m_metadata->setCompressionLevel(level);
    }
}

void ArchiveInterface::setPreserveMetadata(bool preserve) {
    if (m_archive) {
        m_archive->SetPreserveMetadata(preserve);
    }
    m_metadata->setPreserveMetadata(preserve);
}

void ArchiveInterface::refreshArchiveView() {
    if (m_archive) {
        m_metadata->updateFromSeMetadata(m_archive->GetMetadata());
    }
    buildArchiveTree();
    syncJobsList();
}

void ArchiveInterface::onJobProgressUpdated(const SeJob &job) {
    if (m_stopSource.stop_requested()) {
        if (m_jobModel) {
            m_jobModel->abortRunningJobs();
        }
        return;
    }

    if (job.GetJobType() != JobType::CompressionLevelChange) {   
        m_currentFileName = QString::fromStdU16String(job.GetFileName());
    }
    else {
        int lvl = !job.GetFileName().empty() ? (job.GetFileName()[0] - u'0') : 0;
        m_currentFileName = (lvl == 1) ? QStringLiteral("Fast (Store)")
            : (lvl == 2) ? QStringLiteral("Balanced")
            : (lvl == 3) ? QStringLiteral("Ultra")
            : QStringLiteral("Level %1").arg(lvl);
    }

    if (job.GetJobType() == JobType::ExtractDirectory ||
        job.GetJobType() == JobType::AddDirectory ||
        job.GetJobType() == JobType::ExtractFile ||
        job.GetJobType() == JobType::TestFile)
    {
        m_extractTotalBytes = job.totalBytes;
        m_extractProcessedBytes = job.processedBytes;
        m_extractCompressedBytes = job.compressedBytes;
        //m_overallProgress = job.totalBytes > 0.0 ? static_cast<double>(job.processedBytes) / job.totalBytes : 0.0;
        m_fileProgress = job.percentage / 100.0;

        if (m_jobModel && m_jobModel->count() > 0) {
            m_jobModel->updateJob(job);
            m_overallProgress = m_jobModel->overallProgress();
            m_processedFiles = m_jobModel->finishedCount();
            m_totalFiles = m_jobModel->count();
        }
    } 
    else {
        m_fileProgress = static_cast<qreal>(job.percentage) / 100.0;
        if (m_jobModel && m_jobModel->count() > 0) {
            m_jobModel->updateJob(job);
            m_overallProgress = m_jobModel->overallProgress();
            m_processedFiles = m_jobModel->finishedCount();
            m_totalFiles = m_jobModel->count();
        } else {
            m_overallProgress = m_fileProgress;
            m_extractTotalBytes = job.totalBytes;
            m_extractProcessedBytes = job.processedBytes;
            m_extractCompressedBytes = job.compressedBytes;
        }
    }

    // Defer ArchiveTreeModel updates during commit to avoid freezing the UI thread with linear scans.
    // Tree is rebuilt cleanly in onSaveCompleted() -> refreshArchiveView().
    if (!m_isCommitting && job.GetStatus() == JobStatus::Finished &&
        (job.GetJobType() == JobType::AddFile ||
        job.GetJobType() == JobType::CreateArchiveDirectory ||
        job.GetJobType() == JobType::AddDirectory))
    {
        QString relPath = QString::fromStdU16String(job.GetFileName());
        if (!relPath.startsWith(u'/')) {
            relPath.prepend(u'/');
        }

        QString relSlash = relPath.endsWith(u'/') ? relPath : (relPath + u'/');
        QString relNoSlash = (relPath.length() > 1 && relPath.endsWith(u'/')) ? relPath.left(relPath.length() - 1) : relPath;

        if (!m_stagedPendingItems.isEmpty()) { // remove from pending items
            if (!m_stagedPendingItems.remove(relPath)) {
                if (!m_stagedPendingItems.remove(relSlash)) {
                    m_stagedPendingItems.remove(relNoSlash);
                }
            }
        }

        quint32 crc32 = job.crc32;
        if (m_treeModel) {
            m_treeModel->markItemCommitted(relPath, static_cast<qulonglong>(job.compressedBytes), crc32);
        }
    }

    emit progressChanged();
}

void ArchiveInterface::onJobsBatchProgressUpdated(const std::vector<SeJob> &batch) {
    if (batch.empty())
        return;

    if (m_stopSource.stop_requested()) {
        if (m_jobModel) {
            m_jobModel->abortRunningJobs();
        }
        return;
    }

    // Prioritize active running job in the batch if present, otherwise take the last job
    const SeJob *activeJob = nullptr;
    for (auto it = batch.rbegin(); it != batch.rend(); ++it) {
        if (it->GetStatus() == JobStatus::Running || it->GetStatus() == JobStatus::Pending) {
            activeJob = &(*it);
            break;
        }
    }

    auto &lastJob = const_cast<SeJob&>((activeJob != nullptr) ? (*activeJob) : batch.back());

    if (lastJob.GetJobType() != JobType::CompressionLevelChange) {
        m_currentFileName = QString::fromStdU16String(lastJob.GetFileName());
    }
    else {
        int lvl = !lastJob.GetFileName().empty() ? (lastJob.GetFileName()[0] - u'0') : 0;
        m_currentFileName = (lvl == 1) ? QStringLiteral("Fast")
                            : (lvl == 2) ? QStringLiteral("Balanced")
                            : (lvl == 3) ? QStringLiteral("Ultra")
                            : QStringLiteral("Level %1").arg(lvl);
    }

    if (lastJob.GetJobType() == JobType::ExtractDirectory ||
        lastJob.GetJobType() == JobType::AddDirectory ||
        lastJob.GetJobType() == JobType::ExtractFile ||
        lastJob.GetJobType() == JobType::TestFile)
    {
        m_extractTotalBytes = lastJob.totalBytes;
        m_extractProcessedBytes = lastJob.processedBytes;
        m_extractCompressedBytes = lastJob.compressedBytes;
        //m_overallProgress = lastJob.totalBytes > 0.0 ? static_cast<double>(lastJob.processedBytes) / lastJob.totalBytes : 0.0;
        m_fileProgress = lastJob.percentage / 100.0;

        if (m_jobModel && m_jobModel->count() > 0) {
            m_jobModel->updateJobsBatch(batch);
            m_overallProgress = m_jobModel->overallProgress();
            m_processedFiles = m_jobModel->finishedCount();
            m_totalFiles = m_jobModel->count();
        }

    }
    else {
        m_fileProgress = static_cast<qreal>(lastJob.percentage) / 100.0;
        if (m_jobModel && m_jobModel->count() > 0) {
            m_jobModel->updateJobsBatch(batch);
            m_overallProgress = m_jobModel->overallProgress();
            m_processedFiles = m_jobModel->finishedCount();
            m_totalFiles = m_jobModel->count();
        }
        else {
            m_overallProgress = m_fileProgress;
            m_extractTotalBytes = lastJob.totalBytes;
            m_extractProcessedBytes = lastJob.processedBytes;
            m_extractCompressedBytes = lastJob.compressedBytes;
        }
    }

    emit progressChanged();
}

void ArchiveInterface::onSaveCompleted(bool success, const QString &errorMsg) {
    m_currentTask.reset();
    emit isPausedChanged(false);
    setBusy(false);
    m_isCommitting = false;
    emit isCommittingChanged(false);
    m_stopSource = std::stop_source();

    bool isCancelled = errorMsg.contains(QStringLiteral("cancel"), Qt::CaseInsensitive);

    if (success) {
        m_stagedPendingItems.clear();
        m_overallProgress = 1.0;
        m_fileProgress = 1.0;
        setStatusMessage(QStringLiteral("All changes saved successfully."));
        refreshArchiveView();
        emit operationCompleted(QStringLiteral("Save Changes"), true,QStringLiteral("Archive updated."));
    } 
    else if (isCancelled) {
        setStatusMessage(QStringLiteral("Save changes cancelled."));
        if (m_jobModel) {
            m_jobModel->abortRunningJobs();
        }
        refreshArchiveView();
        emit operationCompleted(QStringLiteral("Save Changes"), false, QStringLiteral("Operation was canceled"));
    }
    else {
        setStatusMessage(QStringLiteral("Save failed: ") + errorMsg);
        refreshArchiveView();
        emit errorOccurred(QStringLiteral("Save Changes Error"), errorMsg);
        emit operationCompleted(QStringLiteral("Save Changes"), false, errorMsg);
    }

    emit progressChanged();
}

void ArchiveInterface::onExtractCompleted(bool success,const QString &errorMsg,bool isCryptoFail,const QString &failedPath) {
    m_currentTask.reset();
    emit isPausedChanged(false);
    setBusy(false);
    m_stopSource = std::stop_source();

    bool isCancelled = errorMsg.contains(QStringLiteral("cancel"), Qt::CaseInsensitive);

    if (success) {
        m_overallProgress = 1.0;
        m_fileProgress = 1.0;
        if (m_jobModel) {
            for (int i = 0; i < m_jobModel->count(); ++i) {
                QString st = m_jobModel->get(i).value(QStringLiteral("state")).toString();
                if (st == QStringLiteral("running") || st == QStringLiteral("pending")) {
                    m_jobModel->setProperty(i, QStringLiteral("state"), QStringLiteral("finished"));
                    m_jobModel->setProperty(i, QStringLiteral("progress"), 1.0);
                    m_jobModel->setProperty(i, QStringLiteral("detail"), QStringLiteral("Finished"));
                }
            }
        }
        setStatusMessage(QStringLiteral("Extraction completed successfully."));
        emit operationCompleted(QStringLiteral("Extraction"), true, QStringLiteral("Files extracted to destination."));
    } 
    else if (isCancelled) {
        setStatusMessage(QStringLiteral("Extraction cancelled."));
        if (m_jobModel) {
            m_jobModel->abortRunningJobs();
        }
        syncJobsList();
        emit operationCompleted(QStringLiteral("Extraction"), false, QStringLiteral("Operation was canceled"));
    }
    else if (isCryptoFail) {
        setStatusMessage(QStringLiteral("Extraction paused: Key mismatch on encrypted file."));
        emit extractionCryptoMismatch(failedPath.isEmpty() ? m_lastExtractRelPath : failedPath, m_lastExtractOutputDir);
    } 
    else {
        setStatusMessage(QStringLiteral("Extraction failed: ") + errorMsg);
        emit errorOccurred(QStringLiteral("Extraction Error"), errorMsg);
        emit operationCompleted(QStringLiteral("Extraction"), false, errorMsg);
    }

    emit progressChanged();
}

void ArchiveInterface::syncJobsList() {
    m_jobsList.clear();

    if (!m_archive) {
        if (m_jobModel)
            m_jobModel->clear();
        emit jobsChanged();
        return;
    }

    const auto &jobs = m_archive->GetJobs();
    if (m_jobModel) {
        m_jobModel->setJobs(jobs);
    }

    // Only populate legacy QVariantList for small batches (<= 200 items).
    // Large batches rely exclusively on the high-performance virtualized jobModel
    // to avoid freezing the UI thread with hundreds of thousands of QVariantMap allocations.
    if (jobs.size() <= 200) { // Job count is normaly below 200 now since we modified addDirectory to have its own job type
        for (const auto &job : jobs) {
            SeJobObject jobObj(job);
            m_jobsList.append(jobObj.toVariantMap());
        }
    }

    emit jobsChanged();
}

void ArchiveInterface::buildArchiveTree() {
    m_archiveTree.clear();

    if (!m_archive) {
        if (m_treeModel)
            m_treeModel->clear();
        m_metadata->updateStats(0, 0, 0, 0);
        emit archiveTreeChanged();
        return;
    }

    std::vector<ArchiveTreeModel::PendingItem> pending;
    pending.reserve(m_stagedPendingItems.size());
    for (auto it = m_stagedPendingItems.constBegin(); it != m_stagedPendingItems.constEnd(); ++it) {
        const auto &item = it.value();
        ArchiveTreeModel::PendingItem p;
        p.localDiskPath = item.localDiskPath;
        p.archiveRelPath = item.archiveRelPath;
        p.name = item.name;
        p.isDirectory = item.isDirectory;
        p.size = item.size;
        pending.push_back(std::move(p));
    }

    std::vector<QString> removePaths;
    std::vector<ArchiveTreeModel::StagedMoveItem> moveItems;
    if (m_archive) {
        for (const auto &job : m_archive->GetJobs()) {
            if (job.GetJobType() == JobType::RemoveFile || job.GetJobType() == JobType::DeleteDirectory) {
                removePaths.push_back(QString::fromStdU16String(job.GetFileName()));
            } 
            else if (job.GetJobType() == JobType::MoveArchiveFile || job.GetJobType() == JobType::MoveDirectory) {
                ArchiveTreeModel::StagedMoveItem mi;
                mi.srcPath = QString::fromStdU16String(job.GetFileName());
                mi.dstDirPath = QString::fromStdU16String(job.GetFilePath());
                mi.isDirectory = (job.GetJobType() == JobType::MoveDirectory);
                moveItems.push_back(mi);
            }
        }
    }

    if (m_treeModel) {
    m_treeModel->buildTree(m_archive->GetTOC().GetEntries(), pending, moveItems, removePaths, archiveFileName());
    m_metadata->updateStats(
        m_treeModel->fileCount(), m_treeModel->folderCount(),
        m_treeModel->totalRealSize(), m_treeModel->totalCompressedSize());
    }

    //updateFileMapRegions();

    emit archiveTreeChanged();
}

/*void ArchiveInterface::updateFileMapRegions() {
  if (!m_archive || m_archivePath.isEmpty()) {
    m_fileMapCalcGeneration.fetch_add(1);
    m_entropyRegions.clear();
    m_averageEntropy = 0.0;
    m_totalArchiveSize = 0;
    m_isCalculatingEntropy = false;
    emit entropyCalculationChanged();
    emit entropyRegionsChanged();
    return;
  }

  uint64_t currentGen = m_fileMapCalcGeneration.fetch_add(1) + 1;
  m_isCalculatingEntropy = true;
  emit entropyCalculationChanged();

  uint64_t tocOffset = m_archive->GetMetadata().GetTOCOffset();
  uint64_t currentDiskSize = 0;
  QFileInfo fi(m_archivePath);
  if (fi.exists()) {
    currentDiskSize = static_cast<uint64_t>(fi.size());
  }

  uint64_t metaOffset = 0;
  uint64_t metaSize = static_cast<uint64_t>(SE_METADATA_SIZE);

  // Pre-filter removed items into fast lookups in O(Jobs) time
  std::unordered_set<QString> removedExact;
  std::vector<QString> removedDirs;
  for (const auto &job : m_archive->GetJobs()) {
    if (job.GetJobType() == JobType::RemoveFile ||
        job.GetJobType() == JobType::DeleteDirectory) {
      QString rp = QString::fromStdU16String(job.GetFileName());
      removedExact.insert(rp);
      if (rp.endsWith(u'/')) {
        removedDirs.push_back(rp);
      } else {
        removedDirs.push_back(rp + u'/');
      }
    }
  }

  // Snapshot TOC entries span to pass to worker thread
  auto entriesSpan = m_archive->GetTOC().GetEntries();
  std::vector<SeArchiveEntry> entriesCopy(entriesSpan.begin(), entriesSpan.end());

  // Snapshot staged pending items
  std::vector<PendingStagedItem> stagedItems;
  stagedItems.reserve(m_stagedPendingItems.size());
  for (auto it = m_stagedPendingItems.constBegin();
       it != m_stagedPendingItems.constEnd(); ++it) {
    stagedItems.push_back(it.value());
  }

  std::thread([this, currentGen, tocOffset, currentDiskSize, metaOffset, metaSize,
               removedExact = std::move(removedExact),
               removedDirs = std::move(removedDirs),
               entriesCopy = std::move(entriesCopy),
               stagedItems = std::move(stagedItems)]() mutable {
    if (currentGen != m_fileMapCalcGeneration.load()) {
      return;
    }

    // Distinguishable palette ensuring adjacent blocks never share the same color
    static const QStringList kPalette = {
        QStringLiteral("#D4AF37"), // Gold Primary
        QStringLiteral("#00D2FF"), // Electric Cyan
        QStringLiteral("#10B981"), // Tech Emerald
        QStringLiteral("#8B5CF6"), // Electric Violet
        QStringLiteral("#F59E0B")  // Imperial Amber
    };

    struct EntryMeta {
      QString path;
      QString name;
      uint64_t offset = 0;
      uint64_t diskSize = 0;
      uint64_t compressedSize = 0;
      uint64_t uncompressedSize = 0;
      uint32_t crc32 = 0;
      bool isPending = false;
    };

    std::vector<EntryMeta> fileEntries;
    fileEntries.reserve(entriesCopy.size() + stagedItems.size());
    for (const auto &entry : entriesCopy) {
      if (entry.isDirectory()) {
        continue;
      }
      QString entryPath = QString::fromStdU16String(entry.path);
      if (removedExact.find(entryPath) != removedExact.end()) {
        continue;
      }
      bool isRemoved = false;
      for (const auto &dir : removedDirs) {
        if (entryPath.startsWith(dir)) {
          isRemoved = true;
          break;
        }
      }
      if (isRemoved) {
        continue;
      }

      EntryMeta em;
      em.path = entryPath;
      em.name =
          QString::fromStdU16String(SeTableOfContent::GetFileName(entry.path));
      if (em.name.isEmpty()) {
        em.name = em.path;
      }
      em.offset = entry.offset;
      em.diskSize = entry.GetDiskSize();
      em.compressedSize = entry.compressed_size;
      em.uncompressedSize = entry.uncompressed_size;
      em.crc32 = entry.crc32;
      em.isPending = false;
      fileEntries.push_back(std::move(em));
    }

    uint64_t nextPendingOffset =
        currentDiskSize > 0 ? currentDiskSize : (metaSize + 1);
    for (const auto &p : stagedItems) {
      if (p.isDirectory)
        continue;
      EntryMeta em;
      em.path = p.archiveRelPath;
      em.name = p.name;
      em.offset = nextPendingOffset;
      em.diskSize = p.size;
      em.compressedSize = p.size;
      em.uncompressedSize = p.size;
      em.crc32 = 0;
      em.isPending = true;
      nextPendingOffset += em.diskSize;
      fileEntries.push_back(std::move(em));
    }

    if (currentGen != m_fileMapCalcGeneration.load()) {
      return;
    }

    // Sort files by archive offset to preserve sequential layout
    std::sort(fileEntries.begin(), fileEntries.end(),
              [](const EntryMeta &a, const EntryMeta &b) {
                if (a.isPending != b.isPending)
                  return !a.isPending; // committed first
                return a.offset < b.offset;
              });

    if (currentGen != m_fileMapCalcGeneration.load()) {
      return;
    }

    QVariantList computedList;
    uint64_t totalRealBytes = 0;
    uint64_t totalCompBytes = 0;
    int colorIdx = 0;

    // 1. Metadata bytes at start of file
    QVariantMap metaMap;
    metaMap[QStringLiteral("name")] = QStringLiteral("Archive Metadata");
    metaMap[QStringLiteral("path")] = QStringLiteral("/__metadata__");
    metaMap[QStringLiteral("type")] = QStringLiteral("metadata");
    metaMap[QStringLiteral("startOffset")] = static_cast<qulonglong>(metaOffset);
    metaMap[QStringLiteral("endOffset")] =
        static_cast<qulonglong>(metaOffset + metaSize);
    metaMap[QStringLiteral("size")] = static_cast<qulonglong>(metaSize);
    metaMap[QStringLiteral("compressedSize")] = static_cast<qulonglong>(metaSize);
    metaMap[QStringLiteral("uncompressedSize")] =
        static_cast<qulonglong>(metaSize);
    metaMap[QStringLiteral("crc32")] = QStringLiteral("0x00000000");
    metaMap[QStringLiteral("ratio")] = 0.0;
    metaMap[QStringLiteral("savingsPercent")] = 0.0;
    metaMap[QStringLiteral("entropy")] = 0.0;
    metaMap[QStringLiteral("itemCount")] = 1;
    metaMap[QStringLiteral("color")] = kPalette[colorIdx % kPalette.size()];
    colorIdx++;
    computedList.append(metaMap);

    // 2. Dynamic clustering of small files to prevent UI lag on 1,000+ files
    uint64_t totalFileBytes = 0;
    for (const auto &em : fileEntries) {
      totalFileBytes += em.diskSize;
      totalRealBytes += em.uncompressedSize;
      totalCompBytes += em.compressedSize;
    }

    const size_t totalFileCount = fileEntries.size();
    const size_t kTargetBoxes = 35;
    const uint64_t targetSlice =
        (totalFileCount > kTargetBoxes && totalFileBytes > 0)
            ? (totalFileBytes / kTargetBoxes)
            : 0;
    const uint64_t largeFileThreshold =
        (targetSlice > 0)
            ? std::max<uint64_t>(64ULL * 1024ULL,
                                 static_cast<uint64_t>(targetSlice * 1.5))
            : 0;

    struct ClusteredBox {
      QString name;
      QString path;
      QString type;
      uint64_t startOffset = 0;
      uint64_t endOffset = 0;
      uint64_t diskSize = 0;
      uint64_t compressedSize = 0;
      uint64_t uncompressedSize = 0;
      uint32_t crc32 = 0;
      double ratio = 0.0;
      int itemCount = 1;
      bool isPending = false;
    };

    std::vector<ClusteredBox> clusteredBoxes;
    std::optional<ClusteredBox> currentCluster;

    auto flushCluster = [&]() {
      if (!currentCluster.has_value())
        return;
      auto &c = *currentCluster;
      if (c.itemCount > 1) {
        c.name = QString::asprintf("(offset 0x%08llX to 0x%08llX)",
                                   static_cast<unsigned long long>(c.startOffset),
                                   static_cast<unsigned long long>(c.endOffset));
        c.path = QStringLiteral("[%1 files merged]").arg(c.itemCount);
        c.type = c.isPending ? QStringLiteral("staged_cluster")
                             : QStringLiteral("cluster");
        c.crc32 = 0;
      }
      if (c.uncompressedSize > 0 && c.compressedSize < c.uncompressedSize) {
        c.ratio = (1.0 - static_cast<double>(c.compressedSize) /
                             static_cast<double>(c.uncompressedSize)) *
                  100.0;
      } else {
        c.ratio = 0.0;
      }
      clusteredBoxes.push_back(std::move(c));
      currentCluster.reset();
    };

    for (const auto &em : fileEntries) {
      double fileRatio = 0.0;
      if (em.uncompressedSize > 0 && em.compressedSize < em.uncompressedSize) {
        fileRatio = (1.0 - static_cast<double>(em.compressedSize) /
                               static_cast<double>(em.uncompressedSize)) *
                    100.0;
      }

      bool isLargeFile =
          (largeFileThreshold > 0 && em.diskSize >= largeFileThreshold);

      if (isLargeFile) {
        flushCluster();

        ClusteredBox largeBox;
        largeBox.name = em.name;
        largeBox.path = em.path;
        largeBox.type =
            em.isPending ? QStringLiteral("staged") : QStringLiteral("file");
        largeBox.startOffset = em.offset;
        largeBox.endOffset = em.offset + em.diskSize;
        largeBox.diskSize = em.diskSize;
        largeBox.compressedSize = em.compressedSize;
        largeBox.uncompressedSize = em.uncompressedSize;
        largeBox.crc32 = em.crc32;
        largeBox.ratio = fileRatio;
        largeBox.itemCount = 1;
        largeBox.isPending = em.isPending;
        clusteredBoxes.push_back(std::move(largeBox));
      } else if (totalFileCount <= 35) {
        ClusteredBox singleBox;
        singleBox.name = em.name;
        singleBox.path = em.path;
        singleBox.type =
            em.isPending ? QStringLiteral("staged") : QStringLiteral("file");
        singleBox.startOffset = em.offset;
        singleBox.endOffset = em.offset + em.diskSize;
        singleBox.diskSize = em.diskSize;
        singleBox.compressedSize = em.compressedSize;
        singleBox.uncompressedSize = em.uncompressedSize;
        singleBox.crc32 = em.crc32;
        singleBox.ratio = fileRatio;
        singleBox.itemCount = 1;
        singleBox.isPending = em.isPending;
        clusteredBoxes.push_back(std::move(singleBox));
      } else {
        if (!currentCluster.has_value()) {
          ClusteredBox newC;
          newC.name = em.name;
          newC.path = em.path;
          newC.type =
              em.isPending ? QStringLiteral("staged") : QStringLiteral("file");
          newC.startOffset = em.offset;
          newC.endOffset = em.offset + em.diskSize;
          newC.diskSize = em.diskSize;
          newC.compressedSize = em.compressedSize;
          newC.uncompressedSize = em.uncompressedSize;
          newC.crc32 = em.crc32;
          newC.ratio = fileRatio;
          newC.itemCount = 1;
          newC.isPending = em.isPending;
          currentCluster = newC;
        } else {
          bool samePendingState = (em.isPending == currentCluster->isPending);
          bool sizeLimitReached =
              (targetSlice > 0 && currentCluster->diskSize >= targetSlice);
          bool countLimitReached = (currentCluster->itemCount >= 200);

          if (samePendingState && !sizeLimitReached && !countLimitReached) {
            currentCluster->endOffset = em.offset + em.diskSize;
            currentCluster->diskSize += em.diskSize;
            currentCluster->compressedSize += em.compressedSize;
            currentCluster->uncompressedSize += em.uncompressedSize;
            currentCluster->itemCount++;
          } else {
            flushCluster();

            ClusteredBox newC;
            newC.name = em.name;
            newC.path = em.path;
            newC.type =
                em.isPending ? QStringLiteral("staged") : QStringLiteral("file");
            newC.startOffset = em.offset;
            newC.endOffset = em.offset + em.diskSize;
            newC.diskSize = em.diskSize;
            newC.compressedSize = em.compressedSize;
            newC.uncompressedSize = em.uncompressedSize;
            newC.crc32 = em.crc32;
            newC.ratio = fileRatio;
            newC.itemCount = 1;
            newC.isPending = em.isPending;
            currentCluster = newC;
          }
        }
      }
    }

    flushCluster();

    // Secondary Safeguard: enforce strict cap of <= 45 total boxes
    while (clusteredBoxes.size() > 45) {
      size_t bestIdx = 0;
      uint64_t minCombinedSize = std::numeric_limits<uint64_t>::max();
      for (size_t i = 0; i + 1 < clusteredBoxes.size(); ++i) {
        if (clusteredBoxes[i].isPending == clusteredBoxes[i + 1].isPending) {
          uint64_t comb =
              clusteredBoxes[i].diskSize + clusteredBoxes[i + 1].diskSize;
          if (comb < minCombinedSize) {
            minCombinedSize = comb;
            bestIdx = i;
          }
        }
      }
      if (minCombinedSize == std::numeric_limits<uint64_t>::max())
        break;

      auto &first = clusteredBoxes[bestIdx];
      const auto &second = clusteredBoxes[bestIdx + 1];
      first.endOffset = second.endOffset;
      first.diskSize += second.diskSize;
      first.compressedSize += second.compressedSize;
      first.uncompressedSize += second.uncompressedSize;
      first.itemCount += second.itemCount;
      first.name =
          QString::asprintf("(offset 0x%08llX to 0x%08llX)",
                            static_cast<unsigned long long>(first.startOffset),
                            static_cast<unsigned long long>(first.endOffset));
      first.path = QStringLiteral("[%1 files merged]").arg(first.itemCount);
      first.type = first.isPending ? QStringLiteral("staged_cluster")
                                   : QStringLiteral("cluster");
      first.crc32 = 0;
      if (first.uncompressedSize > 0 &&
          first.compressedSize < first.uncompressedSize) {
        first.ratio = (1.0 - static_cast<double>(first.compressedSize) /
                                 static_cast<double>(first.uncompressedSize)) *
                      100.0;
      } else {
        first.ratio = 0.0;
      }
      clusteredBoxes.erase(clusteredBoxes.begin() + bestIdx + 1);
    }

    for (const auto &box : clusteredBoxes) {
      QVariantMap fileMap;
      fileMap[QStringLiteral("name")] = box.name;
      fileMap[QStringLiteral("path")] = box.path;
      fileMap[QStringLiteral("type")] = box.type;
      fileMap[QStringLiteral("startOffset")] =
          static_cast<qulonglong>(box.startOffset);
      fileMap[QStringLiteral("endOffset")] =
          static_cast<qulonglong>(box.endOffset);
      fileMap[QStringLiteral("size")] = static_cast<qulonglong>(box.diskSize);
      fileMap[QStringLiteral("compressedSize")] =
          static_cast<qulonglong>(box.compressedSize);
      fileMap[QStringLiteral("uncompressedSize")] =
          static_cast<qulonglong>(box.uncompressedSize);
      fileMap[QStringLiteral("crc32")] =
          (box.itemCount > 1) ? QStringLiteral("N/A (Cluster)")
                              : QString::asprintf("0x%08X", box.crc32);
      fileMap[QStringLiteral("ratio")] = box.ratio;
      fileMap[QStringLiteral("savingsPercent")] = box.ratio;
      fileMap[QStringLiteral("entropy")] = (box.ratio / 100.0) * 8.0;
      fileMap[QStringLiteral("itemCount")] = box.itemCount;
      fileMap[QStringLiteral("color")] = kPalette[colorIdx % kPalette.size()];
      colorIdx++;

      computedList.append(fileMap);
    }

    // 3. TOC at end of file
    if (currentDiskSize > tocOffset && tocOffset > 0) {
      uint64_t tocSize = currentDiskSize - tocOffset;
      QVariantMap tocMap;
      tocMap[QStringLiteral("name")] = QStringLiteral("Table of Contents (TOC)");
      tocMap[QStringLiteral("path")] = QStringLiteral("/__toc__");
      tocMap[QStringLiteral("type")] = QStringLiteral("toc");
      tocMap[QStringLiteral("startOffset")] = static_cast<qulonglong>(tocOffset);
      tocMap[QStringLiteral("endOffset")] =
          static_cast<qulonglong>(currentDiskSize);
      tocMap[QStringLiteral("size")] = static_cast<qulonglong>(tocSize);
      tocMap[QStringLiteral("compressedSize")] = static_cast<qulonglong>(tocSize);
      tocMap[QStringLiteral("uncompressedSize")] =
          static_cast<qulonglong>(tocSize);
      tocMap[QStringLiteral("crc32")] = QStringLiteral("0x00000000");
      tocMap[QStringLiteral("ratio")] = 0.0;
      tocMap[QStringLiteral("savingsPercent")] = 0.0;
      tocMap[QStringLiteral("entropy")] = 0.0;
      tocMap[QStringLiteral("itemCount")] = 1;
      tocMap[QStringLiteral("color")] = kPalette[colorIdx % kPalette.size()];
      colorIdx++;
      computedList.append(tocMap);
    }

    double overallSavings = 0.0;
    if (totalRealBytes > 0 && totalCompBytes < totalRealBytes) {
      overallSavings = (1.0 - static_cast<double>(totalCompBytes) /
                                  static_cast<double>(totalRealBytes)) *
                       100.0;
    }
    uint64_t totalArchiveSize =
        currentDiskSize > 0 ? currentDiskSize : (metaSize + totalCompBytes);

    if (currentGen != m_fileMapCalcGeneration.load()) {
      return;
    }

    QMetaObject::invokeMethod(
        this,
        [this, currentGen, computedList = std::move(computedList),
         overallSavings, totalArchiveSize]() mutable {
          if (currentGen != m_fileMapCalcGeneration.load() || !m_archive ||
              m_archivePath.isEmpty()) {
            return;
          }
          m_entropyRegions = std::move(computedList);
          m_averageEntropy = overallSavings;
          m_totalArchiveSize = totalArchiveSize;
          m_isCalculatingEntropy = false;
          emit entropyCalculationChanged();
          emit entropyRegionsChanged();
        },
        Qt::QueuedConnection);
  }).detach();
}*/

/*void ArchiveInterface::calculateEntropy() {

  if (!m_archive || m_archivePath.isEmpty()) {
    m_entropyRegions.clear();
    m_averageEntropy = 0.0;
    m_totalArchiveSize = 0;
    m_isCalculatingEntropy = false;
    emit entropyCalculationChanged();
    emit entropyRegionsChanged();
    return;
  }

  m_isCalculatingEntropy = true;
  emit entropyCalculationChanged();

  QString filePath = m_archivePath;
  uint64_t tocOffset = m_archive->GetMetadata().GetTOCOffset();

  struct EntryMeta {
    QString path;
    QString name;
    uint64_t offset = 0;
    uint64_t diskSize = 0;
    uint64_t compressedSize = 0;
    uint64_t uncompressedSize = 0;
    uint32_t crc32 = 0;
  };

  std::vector<EntryMeta> fileEntries;
  for (const auto &entry : m_archive->GetTOC().GetEntries()) {
    if (entry.isDirectory()) continue;
    EntryMeta em;
    em.path = QString::fromStdU16String(entry.path);
    em.name =
  QString::fromStdU16String(SeTableOfContent::GetFileName(entry.path)); if
  (em.name.isEmpty()) em.name = em.path; em.offset = entry.offset; em.diskSize =
  entry.GetDiskSize(); em.compressedSize = entry.compressed_size;
    em.uncompressedSize = entry.uncompressed_size;
    em.crc32 = entry.crc32;
    fileEntries.push_back(em);
  }

  std::sort(fileEntries.begin(), fileEntries.end(), [](const EntryMeta &a, const
  EntryMeta &b) { return a.offset < b.offset;
  });

  std::stop_token stopToken = m_stopSource.get_token();

  std::thread([this, filePath, tocOffset, fileEntries = std::move(fileEntries),
  stopToken]() { std::ifstream
  fileStream(std::filesystem::path(filePath.toStdWString()), std::ios::binary |
  std::ios::ate); if (!fileStream.is_open()) { QMetaObject::invokeMethod(this,
  [this]() { m_isCalculatingEntropy = false; emit entropyCalculationChanged();
      }, Qt::QueuedConnection);
      return;
    }

    uint64_t totalFileSize = static_cast<uint64_t>(fileStream.tellg());
    fileStream.seekg(0, std::ios::beg);

    auto readMetrics = [&](uint64_t offset, uint64_t length, double &outEntropy,
  uint32_t &outCrc) { outEntropy = 0.0; outCrc = 0; if (length == 0 || offset >=
  totalFileSize || stopToken.stop_requested()) return; uint64_t actualLen =
  std::min(length, totalFileSize - offset);
      fileStream.seekg(static_cast<std::streamoff>(offset), std::ios::beg);

      std::array<uint64_t, 256> freq{};
      freq.fill(0);
      uint32_t runningCrc = CRC32C_INIT;

      constexpr size_t kBufSize = 65536;
      std::vector<uint8_t> buffer(kBufSize);
      uint64_t remaining = actualLen;

      while (remaining > 0 && fileStream.good() && !stopToken.stop_requested())
  { size_t toRead = static_cast<size_t>(std::min<uint64_t>(remaining,
  kBufSize)); fileStream.read(reinterpret_cast<char *>(buffer.data()), toRead);
        std::streamsize bytesRead = fileStream.gcount();
        if (bytesRead <= 0) break;

        for (std::streamsize i = 0; i < bytesRead; ++i) freq[buffer[i]]++;
        runningCrc = crc32c_update(runningCrc, buffer.data(),
  static_cast<size_t>(bytesRead)); remaining -=
  static_cast<uint64_t>(bytesRead);
      }

      if (stopToken.stop_requested()) return;
      outCrc = crc32c_finalize(runningCrc);

      if (actualLen > 0) {
        double invTotal = 1.0 / static_cast<double>(actualLen);
        double h = 0.0;
        for (uint64_t c : freq) {
          if (c > 0) {
            double p = static_cast<double>(c) * invTotal;
            h -= p * std::log2(p);
          }
        }
        outEntropy = std::clamp(h, 0.0, 8.0);
      }
    };
    ...
  }).detach();

  // Update file map regions instantly from in-memory TOC
  //updateFileMapRegions();
}*/

QVariantMap ArchiveInterface::getSunburstData(const QString &folderPath) const {
    if (!m_treeModel) {
    return {};
    }
    return m_treeModel->getSunburstData(folderPath);
}

bool ArchiveInterface::isItemLocked(const QString &archiveRelativePath) const {
    if (!m_treeModel)
        return false;
    return m_treeModel->isPathOrDescendantsLocked(archiveRelativePath);
}

/*bool ArchiveInterface::testKeyForPath(const QString& archiveRelativePath,
                                      const QString &password) {
  if (!m_archive)
    return false;
  std::string passStr = password.toStdString();
  QString normPath = archiveRelativePath;
  if (!normPath.startsWith(u'/'))
    normPath.prepend(u'/');

  bool isFolder = normPath.endsWith(u'/') || normPath == QStringLiteral("/");
  const auto &entries = m_archive->GetTOC().GetEntries();
  bool anyMatched = false;
  bool anyTested = false;
  for (const auto &entry : entries) {
    if (entry.isDirectory())
      continue;
    QString qPath = QString::fromStdU16String(entry.path);
    if (!qPath.startsWith(u'/'))
      qPath.prepend(u'/');

    bool shouldTest = isFolder ? (normPath == QStringLiteral("/") || qPath.startsWith(normPath))
                               : (qPath == normPath);
    if (shouldTest) {
      anyTested = true;
      auto res = m_archive->TestKeySync(entry, passStr);
      if (res && *res) {
        anyMatched = true;
      }
    }
  }
  return anyTested ? anyMatched : true;
}*/

bool ArchiveInterface::testFile(const QString &archiveRelativePath) {
    if (!m_archive) {
        emit errorOccurred(QStringLiteral("No Archive Open"), QStringLiteral("Please open an archive before testing files."));
        return false;
    }

    QString normPath = archiveRelativePath;
    normPath.replace(u'\\', u'/');
    if (!normPath.startsWith(u'/')) {
        normPath.prepend(u'/');
    }

    if (normPath.endsWith(u'/') || normPath == QStringLiteral("/")) {
        emit errorOccurred(QStringLiteral("Invalid Target"), QStringLiteral("Directories cannot be tested directly."));
        return false;
    }

    if (!m_isKeyRegistered && !m_archive->IsKeyPresent()) {
        emit passwordRequired(m_archivePath);
        return false;
    }

    auto _entry = m_archive->GetTOC().GetEntry(normPath.toStdU16String());
    if (!_entry) {
        emit errorOccurred(QStringLiteral("File Not Found"), QStringLiteral("File '%1' was not found in the archive.").arg(normPath));
        return false;
    }
    const auto entry = *_entry;
    if (entry.isDirectory()) {
        emit errorOccurred(QStringLiteral("Invalid Target"), QStringLiteral("Directories cannot be tested directly."));
        return false;
    }

    // Check available disk space in temporary directory before extraction
    QString tempBasePath = QDir::tempPath();
    QStorageInfo storage(tempBasePath);
    qint64 availableBytes = storage.bytesAvailable();
    if (availableBytes >= 0 && entry.uncompressed_size > static_cast<uint64_t>(availableBytes)) {
        emit errorOccurred(QStringLiteral("Insufficient Space"),
                            QStringLiteral("Not enough free disk space in temporary directory to test file '%1'.\nRequired: %2\nAvailable: %3")
                                .arg(normPath, SeFileEntryObject::formatBytes(entry.uncompressed_size), SeFileEntryObject::formatBytes(availableBytes)));
        return false;
    }

    m_stopSource = std::stop_source();
    setBusy(true);
    QString fileName = QFileInfo(normPath).fileName();
    m_currentOperationName = QStringLiteral("Testing file ") + fileName;
    m_currentFileName = fileName;
    setStatusMessage(QStringLiteral("Testing file %1...").arg(normPath));
    
    m_overallProgress = 0.0;
    m_fileProgress = 0.0;
    m_totalFiles = 1;
    m_processedFiles = 0;
    m_extractTotalBytes = entry.uncompressed_size;
    m_extractProcessedBytes = 0;
    m_extractCompressedBytes = 0;

    if (m_jobModel) {
        m_jobModel->clear();
    }
    emit progressChanged();

    std::stop_token stopToken = m_stopSource.get_token();
    auto pauseState = std::make_shared<SePauseState>();
    SePauseToken pauseToken(pauseState);

    auto promise = std::make_shared<std::promise<expected<bool, error_code>>>();
    auto future = promise->get_future().share();

    std::jthread workerThread([this, normPath, entry, stopToken, pauseToken]() {
        QTemporaryDir tempDir;

        if (!tempDir.isValid()) {
            QMetaObject::invokeMethod(this, [this]() {
                m_currentTask.reset();
                emit isPausedChanged(false);
                setBusy(false);
                emit errorOccurred(QStringLiteral("Temp Directory Error"), QStringLiteral("Failed to create temporary directory for testing."));
                emit operationCompleted(QStringLiteral("Test File"), false, QStringLiteral("Failed to create temporary directory"));
                emit progressChanged();

            }, Qt::QueuedConnection);
            return;
        }

        QString tempDirPath = tempDir.path();
        auto lastDispatch = std::make_shared<std::atomic<int64_t>>(0);
        auto callback = [this, lastDispatch](const SeJob &job) {
            auto now = std::chrono::duration_cast<std::chrono::milliseconds>(
                            std::chrono::steady_clock::now().time_since_epoch())
                            .count();
            int64_t last = lastDispatch->load(std::memory_order_relaxed);
            if (job.percentage == 100 || (now - last >= 40)) {
                lastDispatch->store(now, std::memory_order_relaxed);
                QMetaObject::invokeMethod(this, [this, job]() {
                    this->onJobProgressUpdated(job);
                }, Qt::QueuedConnection);
            }
        };

        auto extractRes = m_archive->ExtractFileSync(normPath.toStdU16String(), tempDirPath.toStdU16String(), callback, stopToken, pauseToken);
        if (stopToken.stop_requested() || m_stopSource.stop_requested() || (!extractRes && extractRes.error() == SeError::OperationCanceled)) {
            tempDir.remove();

            QMetaObject::invokeMethod(this, [this]() {
                m_currentTask.reset();
                emit isPausedChanged(false);
                setBusy(false);
                m_currentOperationName.clear();
                m_currentFileName.clear();
                m_overallProgress = 0.0;
                m_fileProgress = 0.0;
                setStatusMessage(QStringLiteral("Testing cancelled."));
                syncJobsList();
                emit operationCompleted(QStringLiteral("Test File"), false, QStringLiteral("Operation was canceled"));
                emit progressChanged();
            }, Qt::QueuedConnection);
            return;
        }

        if (!extractRes) {
            tempDir.remove();
            QString errMsg = QString::fromLocal8Bit(extractRes.error().message().c_str());
            QMetaObject::invokeMethod(this, [this, normPath, errMsg]() {
            m_currentTask.reset();
            emit isPausedChanged(false);
            setBusy(false);
            if (m_treeModel) {
                m_treeModel->setFileHealthStatus(normPath, 2);
            }
            setStatusMessage(QStringLiteral("Testing failed: ") + errMsg);
            emit errorOccurred(QStringLiteral("Health Test Failed"), errMsg);
            emit operationCompleted(QStringLiteral("Test File"), false, errMsg);
            emit progressChanged();
            }, Qt::QueuedConnection);
            return;
        }

        // Now calculate CRC32 of extracted file on disk
        QString fileName = QFileInfo(normPath).fileName();
        QString extractedFilePath = QDir(tempDirPath).filePath(fileName);

        uint32_t computedCrc = CRC32C_INIT;
        bool readOk = true;
        {
            QFile extractedFile(extractedFilePath); // TODO: use QFile::map instead of read
            if (extractedFile.open(QIODevice::ReadOnly)) {
                constexpr qint64 bufSize = 65536;
                QByteArray buffer;
                buffer.resize(bufSize);
                while (!extractedFile.atEnd()) {
                    if (pauseToken.wait_if_paused(stopToken)) {
                        readOk = false;
                        break;
                    }
                    if (stopToken.stop_requested() || m_stopSource.stop_requested()) {
                        readOk = false;
                        break;
                    }
                    qint64 bytesRead = extractedFile.read(buffer.data(), bufSize);
                    if (bytesRead > 0) {
                    computedCrc = crc32c_update(computedCrc, buffer.constData(), static_cast<size_t>(bytesRead));
                    }
                    else if (bytesRead < 0) {
                        readOk = false;
                        break;
                    }
                }
                extractedFile.close();
            }
            else {
                readOk = false;
            }
        }
        computedCrc = crc32c_finalize(computedCrc);

        tempDir.remove();

        if (stopToken.stop_requested() || m_stopSource.stop_requested()) {
            QMetaObject::invokeMethod(this, [this]() {
                m_currentTask.reset();
                emit isPausedChanged(false);
                setBusy(false);
                m_currentOperationName.clear();
                m_currentFileName.clear();
                m_overallProgress = 0.0;
                m_fileProgress = 0.0;
                setStatusMessage(QStringLiteral("Testing cancelled."));
                syncJobsList();
                emit operationCompleted(QStringLiteral("Test File"), false, QStringLiteral("Operation was canceled"));
                emit progressChanged();
            }, Qt::QueuedConnection);
            return;
        }

        if (!readOk) {
            QMetaObject::invokeMethod(this, [this, normPath]() {
            m_currentTask.reset();
            emit isPausedChanged(false);
            setBusy(false);
            if (m_treeModel) {
                m_treeModel->setFileHealthStatus(normPath, 2);
            }
            setStatusMessage(QStringLiteral("Failed to read extracted file."));
            emit operationCompleted(QStringLiteral("Test File"), false, QStringLiteral("Failed to read extracted file"));
            emit progressChanged();
            }, Qt::QueuedConnection);
            return;
        }

        bool match = (computedCrc == entry.crc32);
        QMetaObject::invokeMethod(this, [this, normPath, match, computedCrc, expectedCrc = entry.crc32]() {
            m_currentTask.reset();
            emit isPausedChanged(false);
            setBusy(false);
            if (match) {
            m_overallProgress = 1.0;
            m_fileProgress = 1.0;
            if (m_treeModel) {
                m_treeModel->setFileHealthStatus(normPath, 1);
            }
            setStatusMessage(QStringLiteral("File is OK! CRC32 verified: 0x%1").arg(computedCrc, 8, 16, QLatin1Char('0')).toUpper());
            emit operationCompleted(QStringLiteral("Test File"), true, QStringLiteral("File is OK"));
            } 
            else {
                if (m_treeModel) {
                    m_treeModel->setFileHealthStatus(normPath, 2);
                }
                QString errMsg = QStringLiteral("CRC32 mismatch! Expected 0x%1, got 0x%2")
                                        .arg(expectedCrc, 8, 16, QLatin1Char('0'))
                                        .arg(computedCrc, 8, 16, QLatin1Char('0'))
                                        .toUpper();
                setStatusMessage(errMsg);
                emit errorOccurred(QStringLiteral("Health Test Failed"), errMsg);
                emit operationCompleted(QStringLiteral("Test File"), false, errMsg);
            }
            emit progressChanged();
        }, Qt::QueuedConnection);
    });

    auto taskHandle = std::make_shared<SeTaskHandle<bool>>(std::move(workerThread), std::move(future), pauseState);
    m_currentTask = taskHandle;
    emit isPausedChanged(false);

    return true;
}

bool ArchiveInterface::testArchive() {
    if (!m_archive) {
        emit errorOccurred(QStringLiteral("No Archive"), QStringLiteral("No archive is currently open."));
        return false;
    }

    if (!m_isKeyRegistered && !m_archive->IsKeyPresent()) {
        emit passwordRequired(m_archivePath);
        return false;
    }

    if (isBusy()) {
        emit errorOccurred(QStringLiteral("Busy"), QStringLiteral("Another operation is already in progress."));
        return false;
    }

    m_stopSource = std::stop_source();
    setBusy(true);
    m_isTestingArchive = true;
    m_currentOperationName = QStringLiteral("Testing archive integrity...");
    m_currentFileName = QString();
    setStatusMessage(QStringLiteral("Preparing archive integrity test..."));
    m_overallProgress = 0.0;
    m_fileProgress = 0.0;
    m_totalFiles = 0;
    m_processedFiles = 0;
    m_extractTotalBytes = 0;
    m_extractProcessedBytes = 0;
    m_extractCompressedBytes = 0;

    if (m_jobModel) {
        m_jobModel->clear();
    }
    emit progressChanged();

    std::stop_token stopToken = m_stopSource.get_token();
    auto pauseState = std::make_shared<SePauseState>();
    SePauseToken pauseToken(pauseState);


    struct TestedFileResult {
        QString normPath;
        int jobIdx;
        bool ok;
    };

    auto promise = std::make_shared<std::promise<expected<bool, error_code>>>();
    auto future = promise->get_future().share();

    // Run the entire test workflow in a managed jthread task
    std::jthread workerThread([this, stopToken, pauseToken]() {
        const auto &entries = m_archive->GetTOC().GetEntries();
        std::vector<SeArchiveEntry> filesToTest;
        filesToTest.reserve(entries.size());
        uint64_t totalBytesAll = 0;
        uint64_t maxFileSize = 0;
        QStringList filePathsList;
        filePathsList.reserve(static_cast<int>(entries.size()));

        for (const auto &entry : entries) {
            if (!entry.isDirectory()) {
                filesToTest.push_back(entry);
                totalBytesAll += entry.uncompressed_size;
                if (entry.uncompressed_size > maxFileSize) {
                    maxFileSize = entry.uncompressed_size;
                }
                QString normPath = QString::fromStdU16String(entry.path);
                if (!normPath.startsWith(u'/')) {
                    normPath.prepend(u'/');
                }
                filePathsList.append(normPath);
            }
        }

        int totalFiles = static_cast<int>(filesToTest.size());

        if (totalFiles == 0) {
            QMetaObject::invokeMethod(this, [this]() {
            m_isTestingArchive = false;
            m_currentTask.reset();
            emit isPausedChanged(false);
            setBusy(false);
            m_currentOperationName.clear();
            m_currentFileName.clear();
            setStatusMessage(QStringLiteral("Archive contains no files to test."));
            syncJobsList();
            emit operationCompleted(QStringLiteral("Test Archive"), true, QStringLiteral("File is OK"));
            emit progressChanged();
            }, Qt::QueuedConnection);
            return;
        }

        QString tempBasePath = QDir::tempPath();
        QStorageInfo storage(tempBasePath);
        qint64 availableBytes = storage.bytesAvailable();
        if (availableBytes >= 0 && maxFileSize > static_cast<uint64_t>(availableBytes)) {

            QMetaObject::invokeMethod(this, [this, maxFileSize, availableBytes]() {
                m_isTestingArchive = false;
                m_currentTask.reset();
                emit isPausedChanged(false);
                setBusy(false);
                m_currentOperationName.clear();
                m_currentFileName.clear();
                syncJobsList();
                emit errorOccurred(QStringLiteral("Insufficient Space"),
                                    QStringLiteral("Not enough free disk space in temporary directory to test archive files.\nRequired: %1\nAvailable: %2")
                                        .arg(SeFileEntryObject::formatBytes(maxFileSize), SeFileEntryObject::formatBytes(availableBytes)));
                emit operationCompleted(QStringLiteral("Test Archive"), false, QStringLiteral("Insufficient temporary disk space"));
                emit progressChanged();
            }, Qt::QueuedConnection);
            return;
        }

        // Batch initialize the job model on the main thread in a single O(N) model reset
        QMetaObject::invokeMethod(this, [this, filePathsList, totalFiles, totalBytesAll]() {
            m_totalFiles = totalFiles;
            m_extractTotalBytes = totalBytesAll;
            setStatusMessage(QStringLiteral("Testing %1 archive files...").arg(totalFiles));
            if (m_jobModel) {
                m_jobModel->setTestJobs(filePathsList);
            }
            emit progressChanged();
        }, Qt::QueuedConnection);

        QTemporaryDir tempDir;
        if (!tempDir.isValid()) {
            QMetaObject::invokeMethod(this, [this]() {
                m_isTestingArchive = false;
                m_currentTask.reset();
                emit isPausedChanged(false);
                setBusy(false);
                m_currentOperationName.clear();
                m_currentFileName.clear();
                syncJobsList();
                emit errorOccurred(QStringLiteral("Temp Directory Error"), QStringLiteral("Failed to create temporary directory for testing."));
                emit operationCompleted(QStringLiteral("Test Archive"), false, QStringLiteral("Failed to create temporary directory"));
                emit progressChanged();
            }, Qt::QueuedConnection);
            return;
        }

        QString tempDirPath = tempDir.path();
        int processedCount = 0;
        int failedCount = 0;
        uint64_t accumulatedProcessedBytes = 0;

        std::vector<TestedFileResult> pendingResults;
        pendingResults.reserve(64);
        auto lastProgressDispatchMs = std::make_shared<std::atomic<int64_t>>(0);
        auto lastBatchDispatchTime = std::chrono::steady_clock::now();

        for (int fileIdx = 0; fileIdx < totalFiles; ++fileIdx) { // Main file iter loop
            if (pauseToken.wait_if_paused(stopToken) || stopToken.stop_requested() || m_stopSource.stop_requested() ) {
                break;
            }

            const auto &entry = filesToTest[fileIdx];
            const QString &normPath = filePathsList[fileIdx];
            QString fileName = QFileInfo(normPath).fileName();

            // avoid double file extraction
            QString extractedFilePath = QDir(tempDirPath).filePath(fileName);
            if (QFile::exists(extractedFilePath)) {
                QFile::remove(extractedFilePath);
            }

            QMetaObject::invokeMethod(this, [this, fileIdx, totalFiles, fileName, normPath]() {
                m_currentOperationName = QStringLiteral("Testing archive (%1/%2)").arg(fileIdx + 1).arg(totalFiles);
                m_currentFileName = fileName;
                setStatusMessage(QStringLiteral("Testing (%1/%2): %3...").arg(fileIdx + 1).arg(totalFiles).arg(normPath));
                m_fileProgress = 0.0;
                if (m_jobModel) {
                    m_jobModel->updateJobProgress(fileIdx + 1, QString(), JobStatus::Running, 0.0,
                                                QStringLiteral("Testing..."));
                }
                emit progressChanged();
            }, Qt::QueuedConnection);

            uint64_t fileEntrySize = entry.uncompressed_size;
            auto callback = [this, fileIdx, fileName, accumulatedProcessedBytes,
                                        totalBytesAll, fileEntrySize, lastProgressDispatchMs](const SeJob &job) {

                auto now = std::chrono::duration_cast<std::chrono::milliseconds>(
                                std::chrono::steady_clock::now().time_since_epoch())
                                .count();
                int64_t last = lastProgressDispatchMs->load(std::memory_order_relaxed);
                if (now - last >= 40) {
                    lastProgressDispatchMs->store(now, std::memory_order_relaxed);
                    QMetaObject::invokeMethod(this, [this, fileIdx, fileName, pct = job.percentage, fileProcessed = job.processedBytes, fileEntrySize, curBytes = accumulatedProcessedBytes + job.processedBytes, totalBytesAll]() {
                        m_currentFileName = fileName;
                        m_fileProgress = static_cast<qreal>(pct) / 100.0;
                        if (totalBytesAll > 0) {
                            qreal p = static_cast<qreal>(curBytes) / static_cast<qreal>(totalBytesAll);
                            if (p > m_overallProgress) {
                                m_overallProgress = p;
                            }
                        }
                        if (curBytes > m_extractProcessedBytes) {
                            m_extractProcessedBytes = curBytes;
                        }
                        m_extractTotalBytes = totalBytesAll;
                        if (m_jobModel) {
                            m_jobModel->updateJobProgress(fileIdx + 1, QString(), JobStatus::Running, m_fileProgress,
                                                        QStringLiteral("%1% completed").arg(pct),
                                                        fileProcessed, 0, fileEntrySize);
                        }
                        emit progressChanged();
                    }, Qt::QueuedConnection);
                }
            };

            auto extractRes = m_archive->ExtractFileSync(normPath.toStdU16String(), tempDirPath.toStdU16String(), callback, stopToken, pauseToken);

            if (stopToken.stop_requested() || m_stopSource.stop_requested() || (!extractRes && extractRes.error() == SeError::OperationCanceled)) {
                if (QFile::exists(extractedFilePath)) {
                    QFile::remove(extractedFilePath);
                }
                break;
            }

            bool ok = false;
            if (extractRes) {
            uint32_t computedCrc = CRC32C_INIT;
            bool readOk = true;
            {
                QFile extractedFile(extractedFilePath); // Again i have to use qfile map here!
                if (extractedFile.open(QIODevice::ReadOnly)) {
                constexpr qint64 bufSize = 65536;
                QByteArray buffer;
                buffer.resize(bufSize);
                while (!extractedFile.atEnd()) {
                    if (pauseToken.wait_if_paused(stopToken)) {
                    readOk = false;
                    break;
                    }
                    if (stopToken.stop_requested() || m_stopSource.stop_requested()) {
                    readOk = false;
                    break;
                    }
                    qint64 bytesRead = extractedFile.read(buffer.data(), bufSize);
                    if (bytesRead > 0) {
                    computedCrc = crc32c_update(computedCrc, buffer.constData(), static_cast<size_t>(bytesRead));
                    } else if (bytesRead < 0) {
                    readOk = false;
                    break;
                    }
                }
                extractedFile.close();
                } else {
                    readOk = false;
                }
            }
            computedCrc = crc32c_finalize(computedCrc);

                if (readOk && (computedCrc == entry.crc32)) {
                    ok = true;
                }
            }

            if (QFile::exists(extractedFilePath)) {
                QFile::remove(extractedFilePath);
            }

            if (stopToken.stop_requested() || m_stopSource.stop_requested()) {
                    break;
            }

            accumulatedProcessedBytes += entry.uncompressed_size;
            processedCount++;
            if (!ok) {
                failedCount++;
            }

            pendingResults.push_back({normPath, fileIdx + 1, ok});

            auto now = std::chrono::steady_clock::now();
            auto elapsedMs = std::chrono::duration_cast<std::chrono::milliseconds>(now - lastBatchDispatchTime).count();
            bool isLastFile = (fileIdx == totalFiles - 1) || stopToken.stop_requested() || m_stopSource.stop_requested();

            if (isLastFile || elapsedMs >= 40 || pendingResults.size() >= 50) {
                lastBatchDispatchTime = now;
                auto batch = std::move(pendingResults);
                pendingResults.clear();

                QMetaObject::invokeMethod(this, [this, batch = std::move(batch), normPath, fileName, fileIdx, isLastFile, processedCount, totalFiles, accumulatedProcessedBytes, totalBytesAll]() {
                    if (m_treeModel) {
                    for (const auto &item : batch) {
                        m_treeModel->setFileHealthStatus(item.normPath, item.ok ? 1 : 2);
                    }
                    }
                    if (m_jobModel) {
                    for (const auto &item : batch) {
                        m_jobModel->updateJobProgress(item.jobIdx, QString(), item.ok ? JobStatus::Finished : JobStatus::Failed, 1.0,
                                                    item.ok ? QStringLiteral("Verified OK") : QStringLiteral("Corrupt / CRC mismatch"));
                    }
                    }
                    m_currentOperationName = QStringLiteral("Testing archive (%1/%2)").arg(fileIdx + 1).arg(totalFiles);
                    m_currentFileName = fileName;
                    setStatusMessage(QStringLiteral("Testing (%1/%2): %3...").arg(fileIdx + 1).arg(totalFiles).arg(normPath));
                    m_processedFiles = processedCount;
                    if (isLastFile) {
                        m_fileProgress = 1.0;
                    }
                    if (accumulatedProcessedBytes > m_extractProcessedBytes) {
                        m_extractProcessedBytes = accumulatedProcessedBytes;
                    }
                    m_extractTotalBytes = totalBytesAll;
                    if (totalBytesAll > 0) {
                        qreal p = static_cast<qreal>(accumulatedProcessedBytes) / static_cast<qreal>(totalBytesAll);
                        if (p > m_overallProgress) {
                            m_overallProgress = p;
                        }
                    } else {
                        qreal p = static_cast<qreal>(processedCount) / static_cast<qreal>(totalFiles);
                        if (p > m_overallProgress) {
                            m_overallProgress = p;
                        }
                    }
                    emit progressChanged();
                }, Qt::QueuedConnection);
            }
        }

        tempDir.remove();

        QMetaObject::invokeMethod(this, [this, failedCount, processedCount, totalFiles]() {
            m_isTestingArchive = false;
            m_currentTask.reset();
            emit isPausedChanged(false);
            setBusy(false);
            m_currentOperationName.clear();
            m_currentFileName.clear();
            if (m_stopSource.stop_requested()) {
            m_overallProgress = 0.0;
            m_fileProgress = 0.0;
            setStatusMessage(QStringLiteral("Archive test cancelled (%1 of %2 files tested).").arg(processedCount).arg(totalFiles));
            if (m_jobModel) {
                m_jobModel->abortRunningJobs();
            }
            syncJobsList();
            emit operationCompleted(QStringLiteral("Test Archive"), false, QStringLiteral("Operation was canceled"));
            } else if (failedCount == 0) {
            m_overallProgress = 1.0;
            m_fileProgress = 1.0;
            setStatusMessage(QStringLiteral("All %1 files verified successfully! Archive is healthy.").arg(totalFiles));
            emit operationCompleted(QStringLiteral("Test Archive"), true, QStringLiteral("File is OK"));
            } else {
            QString errMsg = QStringLiteral("%1 of %2 files failed integrity test!").arg(failedCount).arg(totalFiles);
            setStatusMessage(errMsg);
            emit errorOccurred(QStringLiteral("Archive Integrity Error"), errMsg);
            emit operationCompleted(QStringLiteral("Test Archive"), false, errMsg);
            }
            emit progressChanged();
        }, Qt::QueuedConnection);
    });

    auto taskHandle = std::make_shared<SeTaskHandle<bool>>(
        std::move(workerThread), std::move(future), pauseState);
    m_currentTask = taskHandle;
    emit isPausedChanged(false);

    return true;
}

/*void ArchiveInterface::populateRecoveryItemsFromArchive() {
  m_recoveryItems.clear();
  if (!m_recoveryArchive) {
    emit recoveryItemsChanged();
    return;
  }

  const auto &entries = m_recoveryArchive->GetTOC().GetEntries();
  uint64_t totalRealBytes = 0;
  for (const auto &e : entries) {
    if (e.path == u"/") continue;
    totalRealBytes += e.uncompressed_size;
  }

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
        break;
      case EntryRecoveryState::FoundOk:
        stateStr = QStringLiteral("Found OK");
        break;
      case EntryRecoveryState::FoundTruncated:
        stateStr = QStringLiteral("Found Truncated");
        break;
      case EntryRecoveryState::NotFound:
        stateStr = QStringLiteral("Not Found");
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

    m_recoveryItems.append(itemMap);
  }

  emit recoveryItemsChanged();
}

bool ArchiveInterface::recoverArchive(const QString &filePath, const QString &password) {
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
    emit errorOccurred(QStringLiteral("Recovery Error"), QStringLiteral("File does not exist or is not a regular file."));
    return false;
  }

  m_isRecovering = true;
  m_recoveryFilePath = cleanPath;
  emit recoveryStatusChanged();

  std::thread([this, cleanPath, password]() {
    auto result = SeArchive::RecoverArchiveSync(cleanPath.toStdU16String());

    QMetaObject::invokeMethod(this, [this, res = std::move(result), cleanPath, password]() mutable {
      m_isRecovering = false;
      if (!res) {
        m_recoveryArchive.reset();
        m_recoveryItems.clear();
        m_isRecoveryMetadataHealthy = false;
        m_recoveryMetadataHealthState = QStringLiteral("Corrupted / Unreadable");

        QString errorTitle = QStringLiteral("Critical Crypto Data Missing");
        QString errorDetail;
        if (res.error() == SeError::RequiredFieldMissing ||
            res.error() == SeError::InvalidMetadataMagic ||
            res.error() == std::errc::invalid_argument) {
          errorDetail = QStringLiteral("Cannot open archive for recovery: Critical cryptographic parameters (Salt or Password Verification Value) are damaged or unreadable in the metadata header.\n\nWithout valid Salt and PVV, cryptographic derivation and decryption cannot take place.");
        } else {
          errorTitle = QStringLiteral("Recovery Analysis Failed");
          errorDetail = QStringLiteral("Failed to open archive for recovery: ") + QString::fromLocal8Bit(res.error().message().c_str());
        }

        m_recoveryMetadataDetails = errorDetail;
        m_isRecoveryTocHealthy = false;
        m_recoveryTocHealthState = QStringLiteral("Unavailable");
        m_recoveryTocDetails = QStringLiteral("Cannot reconstruct Table of Contents without valid cryptographic metadata.");
        emit recoveryStatusChanged();
        emit recoveryItemsChanged();
        emit recoveryCompleted(false, errorDetail);
        emit errorOccurred(errorTitle, errorDetail);
        return;
      }

      m_recoveryArchive = std::make_unique<SeArchive>(std::move(*res));
      if (!password.isEmpty()) {
        (void)m_recoveryArchive->RegisterKey(password.toStdString());
      }
      m_isRecoveryKeyRegistered = m_recoveryArchive->IsKeyPresent();

      // Formulate diagnostic properties from archive health
      QString metaHealthStr = QString::fromStdString(m_recoveryArchive->GetMetadataHealth());
      m_isRecoveryMetadataHealthy = !metaHealthStr.contains(QStringLiteral("Corrupt"), Qt::CaseInsensitive) && !metaHealthStr.contains(QStringLiteral("Invalid"), Qt::CaseInsensitive);
      m_recoveryMetadataHealthState = m_isRecoveryMetadataHealthy ? QStringLiteral("Healthy (Valid Header)") : QStringLiteral("Corrupted / Damaged");
      m_recoveryMetadataDetails = metaHealthStr;

      QString tocHealthStr = QString::fromStdString(m_recoveryArchive->GetTOCHealth());
      m_isRecoveryTocHealthy = !tocHealthStr.contains(QStringLiteral("Truncated"), Qt::CaseInsensitive) && !tocHealthStr.contains(QStringLiteral("Damaged"), Qt::CaseInsensitive) && !tocHealthStr.contains(QStringLiteral("Corrupt"), Qt::CaseInsensitive);
      m_recoveryTocHealthState = m_isRecoveryTocHealthy ? QStringLiteral("Valid (Full TOC)") : QStringLiteral("Truncated / Reconstructed");
      m_recoveryTocDetails = tocHealthStr;

      populateRecoveryItemsFromArchive();

      emit recoveryStatusChanged();
      emit recoveryKeyStatusChanged(m_isRecoveryKeyRegistered);
      emit recoveryCompleted(true, QStringLiteral("Archive recovery analysis completed successfully."));
    }, Qt::QueuedConnection);
  }).detach();

  return true;
}

void ArchiveInterface::unloadRecoveryArchive() {
  m_recoveryArchive.reset();
  m_recoveryFilePath.clear();
  m_recoveryMetadataHealthState = QStringLiteral("Unknown");
  m_recoveryMetadataDetails.clear();
  m_isRecoveryMetadataHealthy = false;
  m_recoveryTocHealthState = QStringLiteral("Unknown");
  m_recoveryTocDetails.clear();
  m_isRecoveryTocHealthy = false;
  m_recoveryItems.clear();
  m_isRecovering = false;
  m_isRecoveryKeyRegistered = false;
  emit recoveryStatusChanged();
  emit recoveryItemsChanged();
  emit recoveryKeyStatusChanged(false);
}

bool ArchiveInterface::registerRecoveryKey(const QString &password) {
  if (!m_recoveryArchive) return false;
  auto res = m_recoveryArchive->RegisterKey(password.toStdString());
  if (res) {
    m_isRecoveryKeyRegistered = true;
    emit recoveryKeyStatusChanged(true);
    return true;
  }
  return false;
}

bool ArchiveInterface::extractRecoveryItem(const QString &archiveRelativePath, const QString &outputDir) {
  return extractRecoveryBatch(QStringList() << archiveRelativePath, outputDir);
}

bool ArchiveInterface::extractRecoveryBatch(const QStringList &archiveRelativePaths, const QString &outputDir) {
  if (!m_recoveryArchive) {
    emit errorOccurred(QStringLiteral("Extraction Error"), QStringLiteral("No recovery archive loaded."));
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

  setBusy(true);
  setStatusMessage(QStringLiteral("Extracting recovered files..."));

  std::thread([this, paths = archiveRelativePaths, cleanOut]() {
    int extractedCount = 0;
    int failedCount = 0;
    QString lastError;

    for (const QString &rawPath : paths) {
      QString normPath = rawPath;
      if (!normPath.startsWith(u'/')) normPath.prepend(u'/');

      bool isDir = normPath.endsWith(u'/');
      auto res = isDir
          ? m_recoveryArchive->ExtractDirectorySync(normPath.toStdU16String(), cleanOut.toStdU16String(), nullptr)
          : m_recoveryArchive->ExtractFileSync(normPath.toStdU16String(), cleanOut.toStdU16String(), nullptr);

      if (res) {
        extractedCount++;
      } else {
        failedCount++;
        lastError = QString::fromLocal8Bit(res.error().message().c_str());
      }
    }

    QMetaObject::invokeMethod(this, [this, extractedCount, failedCount, lastError]() {
      setBusy(false);
      if (failedCount == 0) {
        setStatusMessage(QStringLiteral("Extracted %1 recovered files successfully.").arg(extractedCount));
        emit operationCompleted(QStringLiteral("Recovery Extraction"), true, QStringLiteral("Extraction completed successfully."));
      } else {
        QString msg = QStringLiteral("%1 of %2 files extracted with errors: %3").arg(failedCount).arg(extractedCount + failedCount).arg(lastError);
        setStatusMessage(msg);
        emit operationCompleted(QStringLiteral("Recovery Extraction"), false, msg);
        emit errorOccurred(QStringLiteral("Extraction Warning"), msg);
      }
    }, Qt::QueuedConnection);
  }).detach();

  return true;
}

QVariantMap ArchiveInterface::testRecoveryItem(const QString &archiveRelativePath) {
  QVariantMap result;
  if (!m_recoveryArchive) {
    result[QStringLiteral("success")] = false;
    result[QStringLiteral("message")] = QStringLiteral("No recovery archive loaded.");
    return result;
  }

  QString normPath = archiveRelativePath;
  if (!normPath.startsWith(u'/')) normPath.prepend(u'/');

  auto entryRes = m_recoveryArchive->GetTOC().GetEntry(normPath.toStdU16String());
  if (!entryRes) {
    result[QStringLiteral("success")] = false;
    result[QStringLiteral("path")] = normPath;
    result[QStringLiteral("message")] = QStringLiteral("Entry not found in recovery archive.");
    return result;
  }

  const auto &entry = *entryRes;
  result[QStringLiteral("path")] = normPath;
  result[QStringLiteral("name")] = QFileInfo(normPath).fileName();
  result[QStringLiteral("expectedCrc")] = QString::asprintf("0x%08X", entry.crc32);

  if (entry.recoveryState == EntryRecoveryState::NotFound) {
    result[QStringLiteral("success")] = false;
    result[QStringLiteral("computedCrc")] = QStringLiteral("N/A");
    result[QStringLiteral("message")] = QStringLiteral("Payload stream not found in archive data.");
    return result;
  }

  QTemporaryDir tempDir;
  if (!tempDir.isValid()) {
    result[QStringLiteral("success")] = false;
    result[QStringLiteral("message")] = QStringLiteral("Could not create temporary directory for test.");
    return result;
  }

  auto extractRes = m_recoveryArchive->ExtractFileSync(normPath.toStdU16String(), tempDir.path().toStdU16String(), nullptr);
  if (!extractRes) {
    result[QStringLiteral("success")] = false;
    result[QStringLiteral("computedCrc")] = QStringLiteral("N/A");
    result[QStringLiteral("message")] = QStringLiteral("Extraction failed: ") + QString::fromLocal8Bit(extractRes.error().message().c_str());
    return result;
  }

  QString extractedFilePath = QDir(tempDir.path()).filePath(QFileInfo(normPath).fileName());
  QFile file(extractedFilePath);
  if (!file.open(QIODevice::ReadOnly)) {
    result[QStringLiteral("success")] = false;
    result[QStringLiteral("message")] = QStringLiteral("Failed to read extracted test file.");
    return result;
  }

  uint32_t computedCrc = CRC32C_INIT;
  constexpr qint64 bufSize = 65536;
  QByteArray buffer;
  buffer.resize(bufSize);
  while (!file.atEnd()) {
    qint64 bytesRead = file.read(buffer.data(), bufSize);
    if (bytesRead > 0) {
      computedCrc = crc32c_update(computedCrc, buffer.constData(), static_cast<size_t>(bytesRead));
    }
  }
  computedCrc = crc32c_finalize(computedCrc);
  file.close();
  QFile::remove(extractedFilePath);

  result[QStringLiteral("computedCrc")] = QString::asprintf("0x%08X", computedCrc);
  bool matches = (computedCrc == entry.crc32);
  result[QStringLiteral("success")] = matches;
  if (matches) {
    result[QStringLiteral("message")] = QStringLiteral("CRC-32 checksum matched perfectly.");
  } else {
    result[QStringLiteral("message")] = QString::asprintf("CRC-32 mismatch (computed: 0x%08X, expected: 0x%08X)", computedCrc, entry.crc32);
  }

  return result;
}

QVariantMap ArchiveInterface::testRecoveryBatch(const QStringList &archiveRelativePaths) {
  QVariantMap batchResult;
  int passed = 0;
  int failed = 0;
  int missing = 0;
  int truncated = 0;
  QVariantList details;

  for (const QString &path : archiveRelativePaths) {
    QVariantMap res = testRecoveryItem(path);
    details.append(res);
    if (res[QStringLiteral("success")].toBool()) {
      passed++;
    } else {
      failed++;
      QString msg = res[QStringLiteral("message")].toString();
      if (msg.contains(QStringLiteral("not found"), Qt::CaseInsensitive)) {
        missing++;
      } else {
        truncated++;
      }
    }
  }

  batchResult[QStringLiteral("total")] = archiveRelativePaths.size();
  batchResult[QStringLiteral("passed")] = passed;
  batchResult[QStringLiteral("failed")] = failed;
  batchResult[QStringLiteral("missing")] = missing;
  batchResult[QStringLiteral("truncated")] = truncated;
  batchResult[QStringLiteral("results")] = details;
  return batchResult;
}
*/