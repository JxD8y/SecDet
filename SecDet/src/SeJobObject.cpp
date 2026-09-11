#include "SeJobObject.h"
#include "SeFileEntryObject.h"

static QString extractBaseFileName(const QString &rawPath) {
    QString path = rawPath;
    while (path.endsWith(u'/') || path.endsWith(u'\\')) {
        path.chop(1);
    }
    int lastSlash = std::max(path.lastIndexOf(u'/'), path.lastIndexOf(u'\\'));
    if (lastSlash >= 0) {
        return path.mid(lastSlash + 1);
    }
    return path;
}

SeJobObject::SeJobObject(QObject *parent)
    : QObject(parent) {}

static QString compressionLevelToName(int level) {
    switch (level) {
    case 1:  return QStringLiteral("Fast (Store)");
    case 2:  return QStringLiteral("Balanced");
    case 3:  return QStringLiteral("Ultra");
    default: return QStringLiteral("Level %1").arg(level);
    }
}

SeJobObject::SeJobObject(const SeJob &job, QObject *parent)
    : QObject(parent),
      m_id(job.GetId()),
      m_status(statusToString(job.GetStatus())),
      m_percentage(job.percentage),
      m_processedBytes(job.processedBytes),
      m_compressedBytes(job.compressedBytes),
      m_totalBytes(job.totalBytes) {

    m_fileName = QString::fromStdU16String(job.GetFileName());
    m_typeName = typeToString(job.GetJobType());
    if (job.GetJobType() == JobType::CompressionLevelChange) {
        int lvl = !m_fileName.isEmpty() ? (m_fileName[0].unicode() - u'0') : 0;
        m_fileName = compressionLevelToName(lvl);
    }

    if (m_totalBytes > 0) {
        m_detail = QStringLiteral("%1 / %2 (%3%)")
            .arg(SeFileEntryObject::formatBytes(m_processedBytes))
            .arg(SeFileEntryObject::formatBytes(m_totalBytes))
            .arg(m_percentage);
    } else {
        m_detail = QStringLiteral("%1% completed").arg(m_percentage);
    }
}

SeJobObject::SeJobObject(int id, const QString &typeName, const QString &fileName,
                         const QString &status, int percentage, QObject *parent)
    : QObject(parent),
      m_id(id),
      m_typeName(typeName),
      m_fileName(fileName),
      m_status(status),
      m_percentage(percentage) {
    m_detail = QStringLiteral("%1% completed").arg(m_percentage);
}

QString SeJobObject::name() const {
    if (m_typeName == QStringLiteral("Compression")) {
        return QStringLiteral("Change Compression: %1").arg(m_fileName);
    }
    QString baseName = extractBaseFileName(m_fileName);
    QString type = m_typeName.isEmpty() ? QStringLiteral("Job") : m_typeName;
    if (!baseName.isEmpty()) {
        return QStringLiteral("%1 %2").arg(type, baseName);
    }
    return type;
}

void SeJobObject::updateFromSeJob(const SeJob &job) {
    m_id = job.GetId();
    m_fileName = QString::fromStdU16String(job.GetFileName());
    m_typeName = typeToString(job.GetJobType());
    if (job.GetJobType() == JobType::CompressionLevelChange) {
        int lvl = !m_fileName.isEmpty() ? (m_fileName[0].unicode() - u'0') : 0;
        m_fileName = compressionLevelToName(lvl);
    }
    m_status = statusToString(job.GetStatus());
    m_percentage = job.percentage;
    m_processedBytes = job.processedBytes;
    m_compressedBytes = job.compressedBytes;
    m_totalBytes = job.totalBytes;

    if (m_totalBytes > 0) {
        m_detail = QStringLiteral("%1 / %2 (%3%)")
            .arg(SeFileEntryObject::formatBytes(m_processedBytes))
            .arg(SeFileEntryObject::formatBytes(m_totalBytes))
            .arg(m_percentage);
    } else {
        m_detail = QStringLiteral("%1% completed").arg(m_percentage);
    }

    emit jobChanged();
}

void SeJobObject::setStatus(const QString &status) {
    if (m_status != status) {
        m_status = status;
        emit jobChanged();
    }
}

void SeJobObject::setProgress(int percentage, qulonglong processedBytes, qulonglong totalBytes, qulonglong compressedBytes) {
    m_percentage = percentage;
    m_processedBytes = processedBytes;
    m_totalBytes = totalBytes;
    m_compressedBytes = compressedBytes;
    if (m_totalBytes > 0) {
        m_detail = QStringLiteral("%1 / %2 (%3%)")
            .arg(SeFileEntryObject::formatBytes(m_processedBytes))
            .arg(SeFileEntryObject::formatBytes(m_totalBytes))
            .arg(m_percentage);
    } else {
        m_detail = QStringLiteral("%1% completed").arg(m_percentage);
    }
    emit jobChanged();
}

void SeJobObject::setDetail(const QString &detail) {
    if (m_detail != detail) {
        m_detail = detail;
        emit jobChanged();
    }
}

QVariantMap SeJobObject::toVariantMap() const {
    QVariantMap map;
    map[QStringLiteral("id")] = m_id;
    map[QStringLiteral("name")] = name();
    map[QStringLiteral("typeName")] = m_typeName;
    map[QStringLiteral("fileName")] = m_fileName;
    map[QStringLiteral("filePath")] = m_filePath;
    map[QStringLiteral("state")] = m_status;
    map[QStringLiteral("status")] = m_status;
    map[QStringLiteral("percentage")] = m_percentage;
    map[QStringLiteral("progress")] = progress();
    map[QStringLiteral("processedBytes")] = m_processedBytes;
    map[QStringLiteral("compressedBytes")] = m_compressedBytes;
    map[QStringLiteral("totalBytes")] = m_totalBytes;
    map[QStringLiteral("detail")] = m_detail;
    return map;
}

QString SeJobObject::statusToString(JobStatus status) {
    switch (status) {
        case JobStatus::Idle:     return QStringLiteral("idle");
        case JobStatus::Pending:  return QStringLiteral("pending");
        case JobStatus::Running:  return QStringLiteral("running");
        case JobStatus::Finished: return QStringLiteral("finished");
        case JobStatus::Aborted:  return QStringLiteral("aborted");
        case JobStatus::Failed:   return QStringLiteral("failed");
        default:                  return QStringLiteral("idle");
    }
}

QString SeJobObject::typeToString(JobType type) {
    switch (type) {
        case JobType::AddFile:                return QStringLiteral("Add");
        case JobType::RemoveFile:             return QStringLiteral("Remove");
        case JobType::CreateArchiveDirectory: return QStringLiteral("Add Dir");
        case JobType::DeleteDirectory:        return QStringLiteral("Remove Dir");
        case JobType::MoveArchiveFile:        return QStringLiteral("Move");
        case JobType::MoveDirectory:          return QStringLiteral("Move Dir");
        case JobType::CompressionLevelChange: return QStringLiteral("Compression");
        case JobType::TestFile:               return QStringLiteral("Test");
        case JobType::ExtractFile:            return QStringLiteral("Extract");
        case JobType::ExtractDirectory:       return QStringLiteral("Extract Dir");
        case JobType::AddDirectory:           return QStringLiteral("Add Dir");
        default:                              return QStringLiteral("Job");
    }
}
