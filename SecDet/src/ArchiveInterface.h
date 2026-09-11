#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QFileInfo>
#include <QVariant>
#include <QVariantList>
#include <QVariantMap>
#include <QHash>
#include <QJSValue>

#include <atomic>
#include <memory>
#include <vector>

#include "SeFileEntryObject.h"
#include "SeJobObject.h"
#include "SeMetadataObject.h"
#include "SeJobModel.h"
#include "ArchiveTreeModel.h"

#include <libsecdet/SeArchive.h>

class ArchiveInterface : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool hasArchive READ hasArchive NOTIFY archiveLoadedChanged)
    Q_PROPERTY(QString archiveFilePath READ archiveFilePath NOTIFY archiveLoadedChanged)
    Q_PROPERTY(QString archiveFileName READ archiveFileName NOTIFY archiveLoadedChanged)
    Q_PROPERTY(bool isKeyRegistered READ isKeyRegistered NOTIFY keyStatusChanged)
    Q_PROPERTY(ArchiveTreeModel* treeModel READ treeModel CONSTANT)
    Q_PROPERTY(SeJobModel* jobModel READ jobModel CONSTANT)
    Q_PROPERTY(QVariantList archiveTree READ archiveTree NOTIFY archiveTreeChanged)
    Q_PROPERTY(QVariantList jobs READ jobs NOTIFY jobsChanged)
    Q_PROPERTY(int pendingJobCount READ pendingJobCount NOTIFY jobsChanged)
    Q_PROPERTY(bool hasUncommittedChanges READ hasUncommittedChanges NOTIFY jobsChanged)
    Q_PROPERTY(SeMetadataObject* metadata READ metadata CONSTANT)
    Q_PROPERTY(bool isBusy READ isBusy NOTIFY isBusyChanged)
    Q_PROPERTY(bool isLoadingArchive READ isLoadingArchive NOTIFY isLoadingArchiveChanged)
    Q_PROPERTY(bool isOptimizing READ isOptimizing NOTIFY isOptimizingChanged)
    Q_PROPERTY(bool isCommitting READ isCommitting NOTIFY isCommittingChanged)
    Q_PROPERTY(bool isAddingFiles READ isAddingFiles NOTIFY isAddingFilesChanged)
    Q_PROPERTY(int indexedFolders READ indexedFolders NOTIFY indexingCountersChanged)
    Q_PROPERTY(int indexedFiles READ indexedFiles NOTIFY indexingCountersChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusMessageChanged)
    Q_PROPERTY(qreal overallProgress READ overallProgress NOTIFY progressChanged)
    Q_PROPERTY(qreal fileProgress READ fileProgress NOTIFY progressChanged)
    Q_PROPERTY(QString currentOperationName READ currentOperationName NOTIFY progressChanged)
    Q_PROPERTY(QString currentFileName READ currentFileName NOTIFY progressChanged)
    Q_PROPERTY(int processedFiles READ processedFiles NOTIFY progressChanged)
    Q_PROPERTY(int totalFiles READ totalFiles NOTIFY progressChanged)
    Q_PROPERTY(qulonglong totalProcessedBytes READ totalProcessedBytes NOTIFY progressChanged)
    Q_PROPERTY(qulonglong totalCompressedBytes READ totalCompressedBytes NOTIFY progressChanged)
    Q_PROPERTY(qulonglong totalBytes READ totalBytes NOTIFY progressChanged)
    Q_PROPERTY(QVariantList entropyRegions READ entropyRegions NOTIFY entropyRegionsChanged)
    Q_PROPERTY(bool isCalculatingEntropy READ isCalculatingEntropy NOTIFY entropyCalculationChanged)
    Q_PROPERTY(qreal averageEntropy READ averageEntropy NOTIFY entropyRegionsChanged)
    Q_PROPERTY(qulonglong totalArchiveSize READ totalArchiveSize NOTIFY entropyRegionsChanged)
    Q_PROPERTY(bool isPaused READ isPaused NOTIFY isPausedChanged)
    Q_PROPERTY(bool isRecovering READ isRecovering NOTIFY recoveryStatusChanged)
    Q_PROPERTY(bool hasRecoveryArchive READ hasRecoveryArchive NOTIFY recoveryStatusChanged)
    Q_PROPERTY(QString recoveryFilePath READ recoveryFilePath NOTIFY recoveryStatusChanged)
    Q_PROPERTY(QString recoveryFileName READ recoveryFileName NOTIFY recoveryStatusChanged)
    Q_PROPERTY(QString recoveryMetadataHealthState READ recoveryMetadataHealthState NOTIFY recoveryStatusChanged)
    Q_PROPERTY(QString recoveryMetadataDetails READ recoveryMetadataDetails NOTIFY recoveryStatusChanged)
    Q_PROPERTY(bool isRecoveryMetadataHealthy READ isRecoveryMetadataHealthy NOTIFY recoveryStatusChanged)
    Q_PROPERTY(QString recoveryTocHealthState READ recoveryTocHealthState NOTIFY recoveryStatusChanged)
    Q_PROPERTY(QString recoveryTocDetails READ recoveryTocDetails NOTIFY recoveryStatusChanged)
    Q_PROPERTY(bool isRecoveryTocHealthy READ isRecoveryTocHealthy NOTIFY recoveryStatusChanged)
    Q_PROPERTY(QVariantList recoveryItems READ recoveryItems NOTIFY recoveryItemsChanged)
    Q_PROPERTY(bool isRecoveryKeyRegistered READ isRecoveryKeyRegistered NOTIFY recoveryKeyStatusChanged)
    Q_PROPERTY(QString lastAttemptedArchivePath READ lastAttemptedArchivePath NOTIFY lastAttemptedArchivePathChanged)

public:
    explicit ArchiveInterface(QObject *parent = nullptr);
    ~ArchiveInterface() override;

    [[nodiscard]] bool hasArchive() const { return m_archive != nullptr; }
    [[nodiscard]] QString archiveFilePath() const { return m_archivePath; }
    [[nodiscard]] QString lastAttemptedArchivePath() const { return m_lastAttemptedArchivePath; }
    [[nodiscard]] QString archiveFileName() const;
    [[nodiscard]] bool isPaused() const {
        if (m_currentTask) {
            return m_currentTask->is_paused();
        }
        return false;
    }
    [[nodiscard]] bool isKeyRegistered() const {
        if (m_archive) {
            return m_archive->IsKeyPresent();
        }
        return m_isKeyRegistered;
    }
    [[nodiscard]] ArchiveTreeModel* treeModel() const { return m_treeModel; }
    [[nodiscard]] SeJobModel* jobModel() const { return m_jobModel; }
    [[nodiscard]] QVariantList archiveTree() const { return m_archiveTree; }
    [[nodiscard]] QVariantList jobs() const { return m_jobsList; }
    [[nodiscard]] int pendingJobCount() const;
    [[nodiscard]] bool hasUncommittedChanges() const;
    [[nodiscard]] SeMetadataObject* metadata() const { return m_metadata; }
    [[nodiscard]] bool isBusy() const { return m_isBusy; }
    [[nodiscard]] bool isLoadingArchive() const { return m_isLoadingArchive; }
    [[nodiscard]] bool isOptimizing() const { return m_isOptimizing; }
    [[nodiscard]] bool isCommitting() const { return m_isCommitting; }
    [[nodiscard]] bool isAddingFiles() const { return m_isAddingFiles; }
    [[nodiscard]] int indexedFolders() const { return m_indexedFolders; }
    [[nodiscard]] int indexedFiles() const { return m_indexedFiles; }
    [[nodiscard]] QString statusMessage() const { return m_statusMessage; }
    [[nodiscard]] qreal overallProgress() const { return m_overallProgress; }
    [[nodiscard]] qreal fileProgress() const { return m_fileProgress; }
    [[nodiscard]] QString currentOperationName() const { return m_currentOperationName; }
    [[nodiscard]] QString currentFileName() const { return m_currentFileName; }
    [[nodiscard]] int processedFiles() const { return (m_jobModel && m_jobModel->count() > 0) ? m_jobModel->finishedCount() : m_processedFiles; }
    [[nodiscard]] int totalFiles() const { return (m_jobModel && m_jobModel->count() > 0) ? m_jobModel->count() : m_totalFiles; }
    [[nodiscard]] qulonglong totalProcessedBytes() const {
        if (m_isCommitting && m_jobModel && m_jobModel->totalProcessedBytes() > 0) return m_jobModel->totalProcessedBytes();
        if (m_extractProcessedBytes > 0) return m_extractProcessedBytes;
        if (m_jobModel && m_jobModel->totalProcessedBytes() > 0) return m_jobModel->totalProcessedBytes();
        return 0;
    }
    [[nodiscard]] qulonglong totalCompressedBytes() const {
        if (m_isCommitting && m_jobModel && m_jobModel->totalCompressedBytes() > 0) return m_jobModel->totalCompressedBytes();
        if (m_extractCompressedBytes > 0) return m_extractCompressedBytes;
        if (m_jobModel && m_jobModel->totalCompressedBytes() > 0) return m_jobModel->totalCompressedBytes();
        return 0;
    }
    [[nodiscard]] qulonglong totalBytes() const {
        if (m_isCommitting && m_jobModel && m_jobModel->totalBytes() > 0) return m_jobModel->totalBytes();
        if (m_extractTotalBytes > 0) return m_extractTotalBytes;
        if (m_jobModel && m_jobModel->totalBytes() > 0) return m_jobModel->totalBytes();
        return 0;
    }
    [[nodiscard]] QVariantList entropyRegions() const { return m_entropyRegions; }
    [[nodiscard]] bool isCalculatingEntropy() const { return m_isCalculatingEntropy; }
    [[nodiscard]] qreal averageEntropy() const { return m_averageEntropy; }
    [[nodiscard]] qulonglong totalArchiveSize() const { return m_totalArchiveSize; }

    [[nodiscard]] bool isRecovering() const { return m_isRecovering; }
    [[nodiscard]] bool hasRecoveryArchive() const { return m_recoveryArchive != nullptr; }
    [[nodiscard]] QString recoveryFilePath() const { return m_recoveryFilePath; }
    [[nodiscard]] QString recoveryFileName() const {
        if (m_recoveryFilePath.isEmpty()) return QStringLiteral("No Archive");
        return QFileInfo(m_recoveryFilePath).fileName();
    }
    [[nodiscard]] QString recoveryMetadataHealthState() const { return m_recoveryMetadataHealthState; }
    [[nodiscard]] QString recoveryMetadataDetails() const { return m_recoveryMetadataDetails; }
    [[nodiscard]] bool isRecoveryMetadataHealthy() const { return m_isRecoveryMetadataHealthy; }
    [[nodiscard]] QString recoveryTocHealthState() const { return m_recoveryTocHealthState; }
    [[nodiscard]] QString recoveryTocDetails() const { return m_recoveryTocDetails; }
    [[nodiscard]] bool isRecoveryTocHealthy() const { return m_isRecoveryTocHealthy; }
    [[nodiscard]] QVariantList recoveryItems() const { return m_recoveryItems; }
    [[nodiscard]] bool isRecoveryKeyRegistered() const {
        if (m_recoveryArchive) {
            return m_recoveryArchive->IsKeyPresent();
        }
        return m_isRecoveryKeyRegistered;
    }

    // QML Invocable Methods
    Q_INVOKABLE bool createEmptyFile(const QString &filePath);
    Q_INVOKABLE bool createArchive(const QString &filePath, const QString &password,
                                   int compressionLevel, bool preserveMetadata,
                                   const QStringList &initialFiles = QStringList());

    Q_INVOKABLE bool loadArchive(const QString &filePath, const QString &password = QString(),
                                 const QStringList &initialFilesToStage = QStringList());
    Q_INVOKABLE void closeArchive();

    Q_INVOKABLE bool registerKey(const QString &password);

    Q_INVOKABLE bool addFilesToArchive(const QStringList &fileUrls, const QString &targetArchiveFolder = QStringLiteral("/"));
    Q_INVOKABLE void scanFolderAsync(const QString &folderUrl, const QJSValue &callback);
    Q_INVOKABLE bool removeArchiveItem(const QString &archiveRelativePath, bool isDirectory);
    Q_INVOKABLE bool moveArchiveItem(const QString &sourceRelativePath, const QString &destRelativePath, bool isDirectory);

    Q_INVOKABLE bool saveChanges();
    Q_INVOKABLE bool saveArchive();
    Q_INVOKABLE void optimizeJobsAsync();
    Q_INVOKABLE void syncJobsList();

    Q_INVOKABLE bool extractItem(const QString &archiveRelativePath, const QString &outputDir);
    Q_INVOKABLE bool extractAll(const QString &outputDir);
    Q_INVOKABLE bool startNativeDrag(const QVariant &pathsOrPath, const QString &displayName = QString(), bool isFolder = false);

    Q_INVOKABLE bool removeJob(int jobId, int modelIndex = -1);
    Q_INVOKABLE bool retryJob(int jobId, int modelIndex = -1);

    Q_INVOKABLE void cancelCurrentOperation();
    Q_INVOKABLE void pauseCurrentOperation();
    Q_INVOKABLE void resumeCurrentOperation();
    Q_INVOKABLE void togglePauseCurrentOperation();
    Q_INVOKABLE void setOperationPaused(bool paused);

    Q_INVOKABLE void setCompressionLevel(int level);
    Q_INVOKABLE bool addCompressionLevelJob(int level);
    Q_INVOKABLE void setPreserveMetadata(bool preserve);

    Q_INVOKABLE void refreshArchiveView();
    Q_INVOKABLE void calculateEntropy();
    Q_INVOKABLE QVariantMap getSunburstData(const QString &folderPath = QStringLiteral("/")) const;

    Q_INVOKABLE bool isItemLocked(const QString &archiveRelativePath) const;
    Q_INVOKABLE bool testKeyForPath(const QString &archiveRelativePath, const QString &password);
    Q_INVOKABLE bool testFile(const QString &archiveRelativePath);
    Q_INVOKABLE bool testArchive();

    // Recovery Invocable Methods
    Q_INVOKABLE bool recoverArchive(const QString &filePath, const QString &password = QString());
    Q_INVOKABLE void unloadRecoveryArchive();
    Q_INVOKABLE bool registerRecoveryKey(const QString &password);
    Q_INVOKABLE bool extractRecoveryItem(const QString &archiveRelativePath, const QString &outputDir);
    Q_INVOKABLE bool extractRecoveryBatch(const QStringList &archiveRelativePaths, const QString &outputDir);
    Q_INVOKABLE QVariantMap testRecoveryItem(const QString &archiveRelativePath);
    Q_INVOKABLE QVariantMap testRecoveryBatch(const QStringList &archiveRelativePaths);

signals:
    void archiveLoadedChanged(bool loaded);
    void archiveTreeChanged();
    void jobsChanged();
    void keyStatusChanged(bool registered);
    void isBusyChanged(bool isBusy);
    void isLoadingArchiveChanged(bool isLoading);
    void isOptimizingChanged(bool isOptimizing);
    void isCommittingChanged(bool isCommitting);
    void isAddingFilesChanged(bool isAdding);
    void indexingCountersChanged();
    void statusMessageChanged(const QString &message);
    void progressChanged();
    void passwordRequired(const QString &archivePath);
    void operationCompleted(const QString &operationName, bool success, const QString &message);
    void errorOccurred(const QString &title, const QString &message);
    void entropyRegionsChanged();
    void entropyCalculationChanged();
    void extractionCryptoMismatch(const QString &failedPath, const QString &destDir);
    void optimizationCompleted(const QVariantList &deletedJobIds);
    void isPausedChanged(bool isPaused);
    void dragStagingStarted(const QString &itemName);
    void dragStagingCompleted();
    void recoveryStatusChanged();
    void recoveryItemsChanged();
    void recoveryKeyStatusChanged(bool registered);
    void lastAttemptedArchivePathChanged();
    void recoveryCompleted(bool success, const QString &message);

private slots:
    void onJobProgressUpdated(const SeJob &job);
    void onJobsBatchProgressUpdated(const std::vector<SeJob> &batch);
    void onSaveCompleted(bool success, const QString &errorMsg);
    void onExtractCompleted(bool success, const QString &errorMsg, bool isCryptoFail = false, const QString &failedPath = QString());

private:
    friend class DelayedExtractMimeData;

    void setBusy(bool busy);
    void setStatusMessage(const QString &message);
    void buildArchiveTree();
    void updateFileMapRegions();
    void testArchiveEntriesKey(const std::string &password);

    struct PendingStagedItem {
        QString localDiskPath;
        QString archiveRelPath;
        QString name;
        bool isDirectory = false;
        qulonglong size = 0;
    };

    std::unique_ptr<SeArchive> m_archive;
    QString m_archivePath;
    bool m_isKeyRegistered = false;
    bool m_isBusy = false;
    bool m_isLoadingArchive = false;
    bool m_isOptimizing = false;
    bool m_isCommitting = false;
    bool m_isAddingFiles = false;
    int m_indexedFolders = 0;
    int m_indexedFiles = 0;
    QString m_statusMessage = QStringLiteral("Ready");

    qreal m_overallProgress = 0.0;
    qreal m_fileProgress = 0.0;
    QString m_currentOperationName;
    QString m_currentFileName;
    int m_processedFiles = 0;
    int m_totalFiles = 0;
    qulonglong m_extractTotalBytes = 0;
    qulonglong m_extractProcessedBytes = 0;
    qulonglong m_extractCompressedBytes = 0;

    QVariantList m_entropyRegions;
    bool m_isCalculatingEntropy = false;
    qreal m_averageEntropy = 0.0;
    qulonglong m_totalArchiveSize = 0;
    std::atomic<uint64_t> m_fileMapCalcGeneration{0};

    SeMetadataObject *m_metadata = nullptr;
    ArchiveTreeModel *m_treeModel = nullptr;
    SeJobModel *m_jobModel = nullptr;
    QVariantList m_archiveTree;
    QVariantList m_jobsList;
    QHash<QString, PendingStagedItem> m_stagedPendingItems;
    QString m_lastExtractOutputDir;
    QString m_lastExtractRelPath;

    std::stop_source m_stopSource;
    std::shared_ptr<SeTaskHandleBase> m_currentTask;

    // Recovery subsystem state
    std::unique_ptr<SeArchive> m_recoveryArchive;
    QString m_recoveryFilePath;
    QString m_recoveryMetadataHealthState = QStringLiteral("Unknown");
    QString m_recoveryMetadataDetails;
    bool m_isRecoveryMetadataHealthy = false;
    QString m_recoveryTocHealthState = QStringLiteral("Unknown");
    QString m_recoveryTocDetails;
    bool m_isRecoveryTocHealthy = false;
    QVariantList m_recoveryItems;
    bool m_isRecovering = false;
    bool m_isRecoveryKeyRegistered = false;
    QString m_lastAttemptedArchivePath;

    void populateRecoveryItemsFromArchive();
};
