#pragma once

#include <QAbstractListModel>
#include <QString>
#include <QVariantMap>
#include <vector>
#include <unordered_map>
#include <libsecdet/SeJob.h>

class SeJobModel : public QAbstractListModel {
    Q_OBJECT

    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(qreal overallProgress READ overallProgress NOTIFY overallProgressChanged)
    Q_PROPERTY(QString overallState READ overallState NOTIFY overallStateChanged)
    Q_PROPERTY(int runningCount READ runningCount NOTIFY countsChanged)
    Q_PROPERTY(int finishedCount READ finishedCount NOTIFY countsChanged)
    Q_PROPERTY(int failedCount READ failedCount NOTIFY countsChanged)
    Q_PROPERTY(int runningJobIndex READ runningJobIndex NOTIFY runningJobIndexChanged)
    Q_PROPERTY(int failedJobIndex READ failedJobIndex NOTIFY failedJobIndexChanged)
    Q_PROPERTY(qulonglong totalProcessedBytes READ totalProcessedBytes NOTIFY progressChanged)
    Q_PROPERTY(qulonglong totalCompressedBytes READ totalCompressedBytes NOTIFY progressChanged)
    Q_PROPERTY(qulonglong totalBytes READ totalBytes NOTIFY progressChanged)

public:
    enum JobRoles {
        NameRole = Qt::UserRole + 1,
        StateRole,
        ProgressRole,
        DetailRole,
        IdRole,
        JobIndexRole,
        FileNameRole
    };
    Q_ENUM(JobRoles)

    struct JobData {
        int id = 0;
        QString name;
        QString fileName;
        QString state = QStringLiteral("idle"); // idle, pending, running, paused, aborted, failed, finished
        qreal progress = 0.0;
        qulonglong processedBytes = 0;
        qulonglong compressedBytes = 0;
        qulonglong totalBytes = 0;
        QString detail;
    };

    explicit SeJobModel(QObject *parent = nullptr);
    ~SeJobModel() override = default;

    [[nodiscard]] int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    [[nodiscard]] QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    [[nodiscard]] QHash<int, QByteArray> roleNames() const override;

    [[nodiscard]] int count() const { return static_cast<int>(m_jobs.size()); }
    [[nodiscard]] qreal overallProgress() const { return m_overallProgress; }
    [[nodiscard]] QString overallState() const { return m_overallState; }
    [[nodiscard]] int runningCount() const { return m_runningCount; }
    [[nodiscard]] int finishedCount() const { return m_finishedCount; }
    [[nodiscard]] int failedCount() const { return m_failedCount; }
    [[nodiscard]] int runningJobIndex() const { return m_runningJobIndex; }
    [[nodiscard]] int failedJobIndex() const { return m_failedJobIndex; }
    [[nodiscard]] qulonglong totalProcessedBytes() const { return m_totalProcessedBytes; }
    [[nodiscard]] qulonglong totalCompressedBytes() const { return m_totalCompressedBytes; }
    [[nodiscard]] qulonglong totalBytes() const { return m_totalBytes; }

    void setJobs(const std::vector<SeJob> &jobs);
    void setTestJobs(const QStringList &filePaths);
    void setExtractJobs(const QStringList &filePaths);
    void updateJob(const SeJob &job);
    void updateJobsBatch(const std::vector<SeJob> &batch);
    void updateJobProgress(int id, const QString &fileName, JobStatus status, qreal progress, const QString &detail,
                           qulonglong processedBytes = 0, qulonglong compressedBytes = 0, qulonglong totalBytes = 0);
    void clearJobs();
    void abortRunningJobs();

    // QML Invocable helper methods
    Q_INVOKABLE QVariantMap get(int index) const;
    Q_INVOKABLE void setProperty(int index, const QString &property, const QVariant &value);
    Q_INVOKABLE void append(const QVariantMap &item);
    Q_INVOKABLE void remove(int index);
    Q_INVOKABLE void removeCompletedJobs();
    Q_INVOKABLE void clear();

    [[nodiscard]] int toSourceIndex(int displayIndex) const;
    [[nodiscard]] int toDisplayIndex(int sourceIndex) const;

signals:
    void countChanged();
    void overallProgressChanged();
    void overallStateChanged();
    void countsChanged();
    void progressChanged();
    void runningJobIndexChanged(int index);
    void failedJobIndexChanged(int index);

private:
    void recalculateAggregates();
    void rebuildDisplayMapping();
    static QString statusToStateString(JobStatus status);
    [[nodiscard]] int findJobIndex(int id, const QString &fileName) const;
    void indexJobFile(const QString &path, size_t index);

    std::vector<JobData> m_jobs;
    std::vector<int> m_displayToSource;
    std::vector<int> m_sourceToDisplay;
    std::unordered_map<int, size_t> m_idToIndex;
    std::unordered_map<QString, size_t> m_fileToIndex;

    qreal m_overallProgress = 0.0;
    qreal m_progressSum = 0.0;
    QString m_overallState = QStringLiteral("idle");
    int m_runningCount = 0;
    int m_finishedCount = 0;
    int m_failedCount = 0;
    int m_pausedCount = 0;
    int m_abortedCount = 0;
    int m_runningJobIndex = -1;
    int m_failedJobIndex = -1;
    qulonglong m_totalProcessedBytes = 0;
    qulonglong m_totalCompressedBytes = 0;
    qulonglong m_totalBytes = 0;
};
