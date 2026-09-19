#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QFileInfo>
#include <QVariantList>
#include <QVariantMap>

#include <atomic>
#include <memory>
#include <stop_token>

#include <libsecdet/SeArchive.h>
#include <libsecdet/SeTaskHandle.h>

class ArchiveRecoveryInterface : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool hasArchive READ hasArchive NOTIFY recoveryStatusChanged)
    Q_PROPERTY(bool hasRecoveryArchive READ hasArchive NOTIFY recoveryStatusChanged)
    Q_PROPERTY(QString archiveFilePath READ archiveFilePath NOTIFY recoveryStatusChanged)
    Q_PROPERTY(QString recoveryFilePath READ archiveFilePath NOTIFY recoveryStatusChanged)
    Q_PROPERTY(QString archiveFileName READ archiveFileName NOTIFY recoveryStatusChanged)
    Q_PROPERTY(QString recoveryFileName READ archiveFileName NOTIFY recoveryStatusChanged)
    Q_PROPERTY(bool isKeyRegistered READ isKeyRegistered NOTIFY recoveryKeyStatusChanged)
    Q_PROPERTY(bool isRecoveryKeyRegistered READ isKeyRegistered NOTIFY recoveryKeyStatusChanged)
    Q_PROPERTY(bool isLoading READ isLoading NOTIFY recoveryStatusChanged)
    Q_PROPERTY(bool isRecovering READ isLoading NOTIFY recoveryStatusChanged)

    Q_PROPERTY(QString metadataHealthState READ metadataHealthState NOTIFY recoveryStatusChanged)
    Q_PROPERTY(QString recoveryMetadataHealthState READ metadataHealthState NOTIFY recoveryStatusChanged)
    Q_PROPERTY(QString metadataDetails READ metadataDetails NOTIFY recoveryStatusChanged)
    Q_PROPERTY(QString recoveryMetadataDetails READ metadataDetails NOTIFY recoveryStatusChanged)
    Q_PROPERTY(bool isMetadataHealthy READ isMetadataHealthy NOTIFY recoveryStatusChanged)
    Q_PROPERTY(bool isRecoveryMetadataHealthy READ isMetadataHealthy NOTIFY recoveryStatusChanged)

    Q_PROPERTY(QString tocHealthState READ tocHealthState NOTIFY recoveryStatusChanged)
    Q_PROPERTY(QString recoveryTocHealthState READ tocHealthState NOTIFY recoveryStatusChanged)
    Q_PROPERTY(QString tocDetails READ tocDetails NOTIFY recoveryStatusChanged)
    Q_PROPERTY(QString recoveryTocDetails READ tocDetails NOTIFY recoveryStatusChanged)
    Q_PROPERTY(bool isTocHealthy READ isTocHealthy NOTIFY recoveryStatusChanged)
    Q_PROPERTY(bool isRecoveryTocHealthy READ isTocHealthy NOTIFY recoveryStatusChanged)

    Q_PROPERTY(int okCount READ okCount NOTIFY recoveryStatusChanged)
    Q_PROPERTY(int foundOkCount READ foundOkCount NOTIFY recoveryStatusChanged)
    Q_PROPERTY(int truncatedCount READ truncatedCount NOTIFY recoveryStatusChanged)
    Q_PROPERTY(int notFoundCount READ notFoundCount NOTIFY recoveryStatusChanged)

    Q_PROPERTY(QVariantList recoveryItems READ recoveryItems NOTIFY recoveryItemsChanged)

    // Progress & Worker State Properties (for ProgressWindow)
    Q_PROPERTY(bool isBusy READ isBusy NOTIFY isBusyChanged)
    Q_PROPERTY(bool isPaused READ isPaused NOTIFY isPausedChanged)
    Q_PROPERTY(qreal overallProgress READ overallProgress NOTIFY progressChanged)
    Q_PROPERTY(qreal fileProgress READ fileProgress NOTIFY progressChanged)
    Q_PROPERTY(QString currentOperationName READ currentOperationName NOTIFY progressChanged)
    Q_PROPERTY(QString currentFileName READ currentFileName NOTIFY progressChanged)
    Q_PROPERTY(int processedFiles READ processedFiles NOTIFY progressChanged)
    Q_PROPERTY(int totalFiles READ totalFiles NOTIFY progressChanged)
    Q_PROPERTY(qulonglong totalProcessedBytes READ totalProcessedBytes NOTIFY progressChanged)
    Q_PROPERTY(qulonglong totalCompressedBytes READ totalCompressedBytes NOTIFY progressChanged)
    Q_PROPERTY(qulonglong totalBytes READ totalBytes NOTIFY progressChanged)
    Q_PROPERTY(qulonglong totalArchiveSize READ totalArchiveSize NOTIFY progressChanged)

public:
    explicit ArchiveRecoveryInterface(QObject *parent = nullptr);
    ~ArchiveRecoveryInterface() override;

    [[nodiscard]] bool hasArchive() const { return m_archive != nullptr; }
    [[nodiscard]] QString archiveFilePath() const { return m_archivePath; }
    [[nodiscard]] QString archiveFileName() const {
        if (m_archivePath.isEmpty()) return QStringLiteral("No Archive");
        return QFileInfo(m_archivePath).fileName();
    }
    [[nodiscard]] bool isKeyRegistered() const {
        if (m_archive) return m_archive->IsKeyPresent();
        return m_isKeyRegistered;
    }
    [[nodiscard]] bool isLoading() const { return m_isLoading; }

    [[nodiscard]] QString metadataHealthState() const { return m_metadataHealthState; }
    [[nodiscard]] QString metadataDetails() const { return m_metadataDetails; }
    [[nodiscard]] bool isMetadataHealthy() const { return m_isMetadataHealthy; }

    [[nodiscard]] QString tocHealthState() const { return m_tocHealthState; }
    [[nodiscard]] QString tocDetails() const { return m_tocDetails; }
    [[nodiscard]] bool isTocHealthy() const { return m_isTocHealthy; }

    [[nodiscard]] int okCount() const { return m_okCount; }
    [[nodiscard]] int foundOkCount() const { return m_foundOkCount; }
    [[nodiscard]] int truncatedCount() const { return m_truncatedCount; }
    [[nodiscard]] int notFoundCount() const { return m_notFoundCount; }

    [[nodiscard]] QVariantList recoveryItems() const { return m_recoveryItems; }

    [[nodiscard]] bool isBusy() const { return m_isBusy; }
    [[nodiscard]] bool isPaused() const {
        if (m_currentTask) return m_currentTask->is_paused();
        return false;
    }
    [[nodiscard]] qreal overallProgress() const { return m_overallProgress; }
    [[nodiscard]] qreal fileProgress() const { return m_fileProgress; }
    [[nodiscard]] QString currentOperationName() const { return m_currentOperationName; }
    [[nodiscard]] QString currentFileName() const { return m_currentFileName; }
    [[nodiscard]] int processedFiles() const { return m_processedFiles; }
    [[nodiscard]] int totalFiles() const { return m_totalFiles; }
    [[nodiscard]] qulonglong totalProcessedBytes() const { return m_totalProcessedBytes; }
    [[nodiscard]] qulonglong totalCompressedBytes() const { return m_totalCompressedBytes; }
    [[nodiscard]] qulonglong totalBytes() const { return m_totalBytes; }
    [[nodiscard]] qulonglong totalArchiveSize() const { return m_totalArchiveSize; }

    // QML Invocable Methods
    Q_INVOKABLE bool loadArchive(const QString &filePath, const QString &password = QString());
    Q_INVOKABLE void unloadArchive();
    Q_INVOKABLE bool registerKey(const QString &password);

    Q_INVOKABLE bool extractRecoveryItem(const QString &archiveRelativePath, const QString &outputDir);
    Q_INVOKABLE bool extractRecoveryBatch(const QStringList &archiveRelativePaths, const QString &outputDir);

    Q_INVOKABLE bool testRecoveryItem(const QString &archiveRelativePath);
    Q_INVOKABLE bool testRecoveryBatch(const QStringList &archiveRelativePaths);

    Q_INVOKABLE void cancelCurrentOperation();
    Q_INVOKABLE void pauseCurrentOperation();
    Q_INVOKABLE void resumeCurrentOperation();
    Q_INVOKABLE void togglePauseCurrentOperation();
    Q_INVOKABLE void setOperationPaused(bool paused);

signals:
    void archiveLoadedChanged(bool loaded);
    void recoveryStatusChanged();
    void recoveryItemsChanged();
    void recoveryKeyStatusChanged(bool registered);
    void progressChanged();
    void isPausedChanged(bool isPaused);
    void isBusyChanged(bool isBusy);
    void operationCompleted(const QString &operationName, bool success, const QString &message);
    void errorOccurred(const QString &title, const QString &message);
    void recoveryCompleted(bool success, const QString &message);

private:
    void setBusy(bool busy);
    void resetProgress();

    std::unique_ptr<SeArchive> m_archive;
    QString m_archivePath;
    bool m_isKeyRegistered = false;
    bool m_isLoading = false;

    QString m_metadataHealthState = QStringLiteral("Unknown");
    QString m_metadataDetails;
    bool m_isMetadataHealthy = false;

    QString m_tocHealthState = QStringLiteral("Unknown");
    QString m_tocDetails;
    bool m_isTocHealthy = false;

    int m_okCount = 0;
    int m_foundOkCount = 0;
    int m_truncatedCount = 0;
    int m_notFoundCount = 0;

    QVariantList m_recoveryItems;

    // Background operation progress & task management
    bool m_isBusy = false;
    qreal m_overallProgress = 0.0;
    qreal m_fileProgress = 0.0;
    QString m_currentOperationName;
    QString m_currentFileName;
    int m_processedFiles = 0;
    int m_totalFiles = 0;
    qulonglong m_totalProcessedBytes = 0;
    qulonglong m_totalCompressedBytes = 0;
    qulonglong m_totalBytes = 0;
    qulonglong m_totalArchiveSize = 0;

    std::stop_source m_stopSource;
    std::shared_ptr<SeTaskHandleBase> m_currentTask;
};
