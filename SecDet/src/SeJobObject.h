#pragma once

#include <QObject>
#include <QString>
#include <QVariantMap>

#include <libsecdet/SeJob.h>

class SeJobObject : public QObject {
    Q_OBJECT

    Q_PROPERTY(int id READ id NOTIFY jobChanged)
    Q_PROPERTY(QString typeName READ typeName NOTIFY jobChanged)
    Q_PROPERTY(QString fileName READ fileName NOTIFY jobChanged)
    Q_PROPERTY(QString filePath READ filePath NOTIFY jobChanged)
    Q_PROPERTY(QString status READ status NOTIFY jobChanged)
    Q_PROPERTY(QString state READ status NOTIFY jobChanged)
    Q_PROPERTY(int percentage READ percentage NOTIFY jobChanged)
    Q_PROPERTY(qreal progress READ progress NOTIFY jobChanged)
    Q_PROPERTY(qulonglong processedBytes READ processedBytes NOTIFY jobChanged)
    Q_PROPERTY(qulonglong compressedBytes READ compressedBytes NOTIFY jobChanged)
    Q_PROPERTY(qulonglong totalBytes READ totalBytes NOTIFY jobChanged)
    Q_PROPERTY(QString detail READ detail NOTIFY jobChanged)
    Q_PROPERTY(QString name READ name NOTIFY jobChanged)

public:
    explicit SeJobObject(QObject *parent = nullptr);
    explicit SeJobObject(const SeJob &job, QObject *parent = nullptr);
    SeJobObject(int id, const QString &typeName, const QString &fileName,
                const QString &status, int percentage, QObject *parent = nullptr);

    [[nodiscard]] int id() const { return m_id; }
    [[nodiscard]] QString typeName() const { return m_typeName; }
    [[nodiscard]] QString fileName() const { return m_fileName; }
    [[nodiscard]] QString filePath() const { return m_filePath; }
    [[nodiscard]] QString status() const { return m_status; }
    [[nodiscard]] int percentage() const { return m_percentage; }
    [[nodiscard]] qreal progress() const { return static_cast<qreal>(m_percentage) / 100.0; }
    [[nodiscard]] qulonglong processedBytes() const { return m_processedBytes; }
    [[nodiscard]] qulonglong compressedBytes() const { return m_compressedBytes; }
    [[nodiscard]] qulonglong totalBytes() const { return m_totalBytes; }
    [[nodiscard]] QString detail() const { return m_detail; }
    [[nodiscard]] QString name() const;

    void updateFromSeJob(const SeJob &job);

    void setStatus(const QString &status);
    void setProgress(int percentage, qulonglong processedBytes = 0, qulonglong totalBytes = 0, qulonglong compressedBytes = 0);
    void setDetail(const QString &detail);

    [[nodiscard]] QVariantMap toVariantMap() const;

    static QString statusToString(JobStatus status);
    static QString typeToString(JobType type);

signals:
    void jobChanged();

private:
    int m_id = 0;
    QString m_typeName;
    QString m_fileName;
    QString m_filePath;
    QString m_status = QStringLiteral("idle");
    int m_percentage = 0;
    qulonglong m_processedBytes = 0;
    qulonglong m_compressedBytes = 0;
    qulonglong m_totalBytes = 0;
    QString m_detail;
};
