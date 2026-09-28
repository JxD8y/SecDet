#include "SeJobModel.h"
#include "SeFileEntryObject.h"
#include <QFileInfo>
#include <algorithm>

SeJobModel::SeJobModel(QObject *parent)
    : QAbstractListModel(parent) {
}

int SeJobModel::toSourceIndex(int displayIndex) const {
    if (m_displayToSource.empty() || displayIndex < 0 || displayIndex >= static_cast<int>(m_displayToSource.size())) {
        return displayIndex;
    }
    return m_displayToSource[displayIndex];
}

int SeJobModel::toDisplayIndex(int sourceIndex) const {
    if (m_sourceToDisplay.empty() || sourceIndex < 0 || sourceIndex >= static_cast<int>(m_sourceToDisplay.size())) {
        return sourceIndex;
    }
    return m_sourceToDisplay[sourceIndex];
}

int SeJobModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return static_cast<int>(m_jobs.size());
}

QVariant SeJobModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= static_cast<int>(m_jobs.size())) {
        return {};
    }

    int srcRow = toSourceIndex(index.row());
    if (srcRow < 0 || srcRow >= static_cast<int>(m_jobs.size())) {
        return {};
    }

    const auto &job = m_jobs[srcRow];
    switch (role) {
    case NameRole:
        return job.name;
    case StateRole:
        return job.state;
    case ProgressRole:
        return job.progress;
    case DetailRole:
        return job.detail;
    case IdRole:
        return job.id;
    case JobIndexRole:
        return srcRow;
    case FileNameRole:
        return job.fileName;
    case Qt::DisplayRole:
        return job.name;
    default:
        return {};
    }
}

QHash<int, QByteArray> SeJobModel::roleNames() const {
    QHash<int, QByteArray> roles;
    roles[NameRole] = "name";
    roles[StateRole] = "state";
    roles[ProgressRole] = "progress";
    roles[DetailRole] = "detail";
    roles[IdRole] = "id";
    roles[JobIndexRole] = "jobIndex";
    roles[FileNameRole] = "fileName";
    return roles;
}

QString SeJobModel::statusToStateString(JobStatus status) {
    switch (status) {
    case JobStatus::Idle:     return QStringLiteral("idle");
    case JobStatus::Pending:  return QStringLiteral("pending");
    case JobStatus::Running:  return QStringLiteral("running");
    case JobStatus::Paused:   return QStringLiteral("paused");
    case JobStatus::Finished: return QStringLiteral("finished");
    case JobStatus::Aborted:  return QStringLiteral("aborted");
    case JobStatus::Failed:   return QStringLiteral("failed");
    default:                  return QStringLiteral("idle");
    }
}

static QString jobTypeToString(JobType type) {
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

static QString compressionLevelToName(int level) {
    switch (level) {
    case 1:  return QStringLiteral("Fast (Store)");
    case 2:  return QStringLiteral("Balanced");
    case 3:  return QStringLiteral("Ultra");
    default: return QStringLiteral("Level %1").arg(level);
    }
}

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

void SeJobModel::indexJobFile(const QString &path, size_t index) {
    if (path.isEmpty()) return;
    m_fileToIndex[path] = index;
    QString norm = path;
    norm.replace(u'\\', u'/');
    m_fileToIndex[norm] = index;
    if (norm.startsWith(u'/')) {
        m_fileToIndex[norm.mid(1)] = index;
    } else {
        m_fileToIndex[QStringLiteral("/") + norm] = index;
    }
    QString baseName = QFileInfo(norm).fileName();
    if (!baseName.isEmpty()) {
        m_fileToIndex[baseName] = index;
    }
}

int SeJobModel::findJobIndex(int id, const QString &fileName) const {
    if (id > 0) {
        auto it = m_idToIndex.find(id);
        if (it != m_idToIndex.end()) {
            return static_cast<int>(it->second);
        }
    }

    if (!fileName.isEmpty()) {
        auto it = m_fileToIndex.find(fileName);
        if (it != m_fileToIndex.end()) {
            return static_cast<int>(it->second);
        }

        QString norm = fileName;
        norm.replace(u'\\', u'/');
        it = m_fileToIndex.find(norm);
        if (it != m_fileToIndex.end()) {
            return static_cast<int>(it->second);
        }

        if (norm.startsWith(u'/')) {
            it = m_fileToIndex.find(norm.mid(1));
            if (it != m_fileToIndex.end()) return static_cast<int>(it->second);
        } else {
            it = m_fileToIndex.find(QStringLiteral("/") + norm);
            if (it != m_fileToIndex.end()) return static_cast<int>(it->second);
        }

        QString baseName = QFileInfo(norm).fileName();
        if (!baseName.isEmpty()) {
            it = m_fileToIndex.find(baseName);
            if (it != m_fileToIndex.end()) {
                return static_cast<int>(it->second);
            }
        }
    }

    if (id > 0) {
        for (size_t r = 0; r < m_jobs.size(); ++r) {
            if (m_jobs[r].id == id) {
                return static_cast<int>(r);
            }
        }
    }

    if (m_jobs.size() == 1) {
        return 0;
    }

    if (m_runningJobIndex >= 0 && m_runningJobIndex < static_cast<int>(m_jobs.size())) {
        return m_runningJobIndex;
    }

    for (size_t r = 0; r < m_jobs.size(); ++r) {
        if (m_jobs[r].state == QStringLiteral("running") ||
            m_jobs[r].state == QStringLiteral("pending") ||
            m_jobs[r].state == QStringLiteral("idle")) {
            return static_cast<int>(r);
        }
    }

    return -1;
}

void SeJobModel::setJobs(const std::vector<SeJob> &jobs) {
    beginResetModel();
    m_jobs.clear();
    m_displayToSource.clear();
    m_sourceToDisplay.clear();
    m_idToIndex.clear();
    m_fileToIndex.clear();

    m_jobs.reserve(jobs.size());
    for (size_t i = 0; i < jobs.size(); ++i) {
        const auto &j = jobs[i];
        JobData data;
        data.id = j.GetId();
        QString rawFileName = QString::fromStdU16String(j.GetFileName());
        data.fileName = rawFileName;
        data.state = statusToStateString(j.GetStatus());
        // Clean up any stale running state from prior canceled or interrupted executions
        if (data.state == QStringLiteral("running")) {
            data.state = QStringLiteral("aborted");
            data.detail = QStringLiteral("Cancelled");
        }
        data.progress = static_cast<qreal>(j.percentage) / 100.0;

        QString typeName = jobTypeToString(j.GetJobType());
        if (j.GetJobType() == JobType::CompressionLevelChange) {
            int lvl = !rawFileName.isEmpty() ? (rawFileName[0].unicode() - u'0') : 0;
            QString lvlName = compressionLevelToName(lvl);
            data.name = QStringLiteral("Change Compression: %1").arg(lvlName);
            data.fileName = lvlName;
        } else {
            QString baseName = extractBaseFileName(data.fileName);
            if (!baseName.isEmpty()) {
                data.name = QStringLiteral("%1 %2").arg(typeName, baseName);
            } else {
                data.name = typeName;
            }
        }

        data.processedBytes = j.processedBytes;
        data.compressedBytes = j.compressedBytes;
        data.totalBytes = j.totalBytes;

        if (j.totalBytes > 0) {
            data.detail = QStringLiteral("%1 / %2 (%3%)")
                .arg(SeFileEntryObject::formatBytes(j.processedBytes))
                .arg(SeFileEntryObject::formatBytes(j.totalBytes))
                .arg(j.percentage);
        } else if (j.percentage > 0) {
            data.detail = QStringLiteral("%1% completed").arg(j.percentage);
        } else if (data.detail.isEmpty()) {
            data.detail = QStringLiteral("Queued");
        }

        m_jobs.push_back(data);
        if (data.id > 0) {
            m_idToIndex[data.id] = i;
        }
        indexJobFile(rawFileName, i);
        if (!data.fileName.isEmpty() && data.fileName != rawFileName) {
            indexJobFile(data.fileName, i);
        }
    }
    endResetModel();

    recalculateAggregates();
    rebuildDisplayMapping();
    emit countChanged();
}

void SeJobModel::setTestJobs(const QStringList &filePaths) {
    beginResetModel();
    m_jobs.clear();
    m_displayToSource.clear();
    m_sourceToDisplay.clear();
    m_idToIndex.clear();
    m_fileToIndex.clear();
    m_jobs.reserve(filePaths.size());

    for (int i = 0; i < filePaths.size(); ++i) {
        JobData data;
        data.id = i + 1;
        const QString &fPath = filePaths[i];
        QString fName = QFileInfo(fPath).fileName();
        data.name = QStringLiteral("Test %1").arg(fName);
        data.fileName = fPath;
        data.state = QStringLiteral("pending");
        data.progress = 0.0;
        data.detail = QStringLiteral("Queued");
        data.totalBytes = 0;
        data.processedBytes = 0;
        data.compressedBytes = 0;

        m_jobs.push_back(data);
        m_idToIndex[data.id] = i;
        indexJobFile(data.fileName, i);
    }

    endResetModel();
    recalculateAggregates();
    rebuildDisplayMapping();
    emit countChanged();
}

void SeJobModel::setExtractJobs(const QStringList &filePaths, qulonglong totalBytes) {
    beginResetModel();
    m_jobs.clear();
    m_displayToSource.clear();
    m_sourceToDisplay.clear();
    m_idToIndex.clear();
    m_fileToIndex.clear();
    m_jobs.reserve(filePaths.size());

    for (int i = 0; i < filePaths.size(); ++i) {
        JobData data;
        data.id = i + 1;
        const QString &fPath = filePaths[i];

        QString cleanPath = fPath;
        while (cleanPath.endsWith(u'/') && cleanPath.length() > 1) {
            cleanPath.chop(1);
        }
        QString fName = (cleanPath == u"/") ? QStringLiteral("All files") : QFileInfo(cleanPath).fileName();
        if (fName.isEmpty()) fName = fPath;

        data.name = QStringLiteral("Extract %1").arg(fName);
        data.fileName = fPath;
        data.state = QStringLiteral("pending");
        data.progress = 0.0;
        data.detail = QStringLiteral("Queued");
        data.totalBytes = (filePaths.size() == 1 && totalBytes > 0) ? totalBytes : 0;
        data.processedBytes = 0;
        data.compressedBytes = 0;

        m_jobs.push_back(data);
        m_idToIndex[data.id] = i;
        indexJobFile(data.fileName, i);
        if (cleanPath != fPath) {
            indexJobFile(cleanPath, i);
        }
    }

    endResetModel();
    recalculateAggregates();
    rebuildDisplayMapping();
    emit countChanged();
}

void SeJobModel::updateJob(const SeJob &job) {
    int jobId = job.GetId();
    QString fileName = QString::fromStdU16String(job.GetFileName());
    qreal progress = static_cast<qreal>(job.percentage) / 100.0;

    QString detail;
    if (job.totalBytes > 0) {
        detail = QStringLiteral("%1 / %2 (%3%)")
            .arg(SeFileEntryObject::formatBytes(job.processedBytes))
            .arg(SeFileEntryObject::formatBytes(job.totalBytes))
            .arg(job.percentage);
    } else {
        detail = QStringLiteral("%1% completed").arg(job.percentage);
    }

    updateJobProgress(jobId, fileName, job.GetStatus(), progress, detail,
                      job.processedBytes, job.compressedBytes, job.totalBytes);
}

void SeJobModel::updateJobsBatch(const std::vector<SeJob> &batch) {
    if (batch.empty()) return;

    int minRow = -1;
    int maxRow = -1;
    bool anyProgressChanged = false;
    bool anyBytesChanged = false;
    bool anyStateChanged = false;
    bool anyFailedTransition = false;
    std::vector<int> changedRows;

    for (const auto &job : batch) {
        int id = job.GetId();
        QString fileName = QString::fromStdU16String(job.GetFileName());
        int targetRow = findJobIndex(id, fileName);

        if (targetRow < 0 || targetRow >= static_cast<int>(m_jobs.size())) {
            continue;
        }

        auto &j = m_jobs[targetRow];
        QString oldState = j.state;
        qreal oldProgress = j.progress;
        qulonglong oldProcessed = j.processedBytes;
        qulonglong oldCompressed = j.compressedBytes;
        qulonglong oldTotal = j.totalBytes;

        JobStatus status = job.GetStatus();
        QString newState = statusToStateString(status);
        qreal progress = static_cast<qreal>(job.percentage) / 100.0;
        qreal clampedProgress = std::clamp(progress, 0.0, 1.0);
        qulonglong processedBytes = job.processedBytes;
        qulonglong compressedBytes = job.compressedBytes;
        qulonglong totalBytes = job.totalBytes;

        QString detail;
        if (job.totalBytes > 0) {
            detail = QStringLiteral("%1 / %2 (%3%)")
                .arg(SeFileEntryObject::formatBytes(job.processedBytes))
                .arg(SeFileEntryObject::formatBytes(job.totalBytes))
                .arg(job.percentage);
        } else if (job.percentage > 0) {
            detail = QStringLiteral("%1% completed").arg(job.percentage);
        }

        QString currentFileName = QString::fromStdU16String(job.GetFileName());
        bool fileNameChanged = (!currentFileName.isEmpty() && j.fileName != currentFileName);

        bool stateChanged = (oldState != newState);
        bool progressChanged = std::abs(oldProgress - clampedProgress) > 0.001;
        bool bytesChanged = (oldProcessed != processedBytes || oldCompressed != compressedBytes || (totalBytes > 0 && oldTotal != totalBytes));
        bool detailChanged = (!detail.isEmpty() && j.detail != detail);

        if (!stateChanged && !progressChanged && !bytesChanged && !detailChanged && !fileNameChanged) {
            continue;
        }

        if (fileNameChanged) {
            j.fileName = currentFileName;
        }

        j.state = newState;
        j.progress = clampedProgress;
        j.processedBytes = processedBytes;
        j.compressedBytes = compressedBytes;
        if (totalBytes > 0) {
            j.totalBytes = totalBytes;
        }
        if (!detail.isEmpty()) {
            j.detail = detail;
        }

        if (minRow < 0 || targetRow < minRow) minRow = targetRow;
        if (maxRow < 0 || targetRow > maxRow) maxRow = targetRow;
        changedRows.push_back(targetRow);

        if (progressChanged) {
            m_progressSum += (clampedProgress - oldProgress);
            if (m_progressSum < 0.0) m_progressSum = 0.0;
            anyProgressChanged = true;
        }

        if (bytesChanged) {
            m_totalProcessedBytes += (j.processedBytes - oldProcessed);
            m_totalCompressedBytes += (j.compressedBytes - oldCompressed);
            if (totalBytes > 0) {
                m_totalBytes += (j.totalBytes - oldTotal);
            }
            anyBytesChanged = true;
        }

        if (stateChanged) {
            anyStateChanged = true;
            if ((oldState == QStringLiteral("failed") && newState != QStringLiteral("failed")) ||
                (oldState != QStringLiteral("failed") && newState == QStringLiteral("failed"))) {
                anyFailedTransition = true;
            }

            auto decCount = [&](const QString &s) {
                if (s == QStringLiteral("running")) m_runningCount = std::max(0, m_runningCount - 1);
                else if (s == QStringLiteral("finished") || s == QStringLiteral("done"))
                {
                    m_finishedCount = std::max(0, m_finishedCount - 1);
                }
                else if (s == QStringLiteral("failed")) m_failedCount = std::max(0, m_failedCount - 1);
                else if (s == QStringLiteral("paused")) m_pausedCount = std::max(0, m_pausedCount - 1);
                else if (s == QStringLiteral("aborted")) m_abortedCount = std::max(0, m_abortedCount - 1);
            };
            auto incCount = [&](const QString &s) {
                if (s == QStringLiteral("running")) m_runningCount++;
                else if (s == QStringLiteral("finished") || s == QStringLiteral("done")) {
                    m_finishedCount++;
                }
                else if (s == QStringLiteral("failed")) m_failedCount++;
                else if (s == QStringLiteral("paused")) m_pausedCount++;
                else if (s == QStringLiteral("aborted")) m_abortedCount++;
            };
            decCount(oldState);
            incCount(newState);

            if (newState == QStringLiteral("running")) {
                m_runningJobIndex = targetRow;
            } else if (m_runningJobIndex == targetRow) {
                int nextRunning = -1;
                if (targetRow + 1 < static_cast<int>(m_jobs.size()) && m_jobs[targetRow + 1].state == QStringLiteral("running")) {
                    nextRunning = targetRow + 1;
                }
                m_runningJobIndex = nextRunning;
            }

            if (newState == QStringLiteral("failed")) {
                if (m_failedJobIndex < 0 || targetRow < m_failedJobIndex) {
                    m_failedJobIndex = targetRow;
                }
            }
        }
    }

    if (anyFailedTransition) {
        rebuildDisplayMapping();
    } else if (!changedRows.empty()) {
        if (m_sourceToDisplay.empty()) {
            if (minRow >= 0 && maxRow >= 0) {
                emit dataChanged(createIndex(minRow, 0), createIndex(maxRow, 0), {StateRole, ProgressRole, DetailRole, FileNameRole});
            }
        } else {
            for (int r : changedRows) {
                int dispRow = toDisplayIndex(r);
                emit dataChanged(createIndex(dispRow, 0), createIndex(dispRow, 0), {StateRole, ProgressRole, DetailRole, FileNameRole});
            }
        }
    }

    if (anyProgressChanged && !m_jobs.empty()) {
        qreal newOverall = m_progressSum / static_cast<qreal>(m_jobs.size());
        if (std::abs(m_overallProgress - newOverall) > 0.005 || (newOverall >= 0.999 && m_overallProgress < 0.999)) {
            m_overallProgress = newOverall;
            emit overallProgressChanged();
        }
    }

    if (anyBytesChanged) {
        emit this->progressChanged();
    }

    if (anyStateChanged) {
        emit countsChanged();
        emit runningJobIndexChanged(m_runningJobIndex >= 0 ? toDisplayIndex(m_runningJobIndex) : -1);
        emit failedJobIndexChanged(m_failedCount > 0 ? 0 : -1);

        QString newOverallState = QStringLiteral("idle");
        if (m_failedCount > 0) newOverallState = QStringLiteral("failed");
        else if (m_abortedCount > 0) newOverallState = QStringLiteral("aborted");
        else if (m_runningCount > 0) newOverallState = QStringLiteral("running");
        else if (m_pausedCount > 0) newOverallState = QStringLiteral("paused");
        else if (m_finishedCount == static_cast<int>(m_jobs.size()) && !m_jobs.empty()) newOverallState = QStringLiteral("finished");
        else if (m_runningCount == 0 && m_finishedCount > 0) newOverallState = QStringLiteral("finished");

        if (m_overallState != newOverallState) {
            m_overallState = newOverallState;
            emit overallStateChanged();
        }
    }
}

void SeJobModel::updateJobProgress(int id, const QString &fileName, JobStatus status, qreal progress, const QString &detail,
                                   qulonglong processedBytes, qulonglong compressedBytes, qulonglong totalBytes) {
    int targetRow = findJobIndex(id, fileName);

    if (targetRow < 0 || targetRow >= static_cast<int>(m_jobs.size())) {
        return;
    }

    auto &j = m_jobs[targetRow];
    QString oldState = j.state;
    qreal oldProgress = j.progress;
    qulonglong oldProcessed = j.processedBytes;
    qulonglong oldCompressed = j.compressedBytes;
    qulonglong oldTotal = j.totalBytes;

    QString newState = statusToStateString(status);
    qreal clampedProgress = std::clamp(progress, 0.0, 1.0);
    bool stateChanged = (oldState != newState);
    bool progressChanged = std::abs(oldProgress - clampedProgress) > 0.001;
    bool bytesChanged = (oldProcessed != processedBytes || oldCompressed != compressedBytes || (totalBytes > 0 && oldTotal != totalBytes));
    bool detailChanged = (!detail.isEmpty() && j.detail != detail);
    bool fileNameChanged = (!fileName.isEmpty() && j.fileName != fileName);

    if (!stateChanged && !progressChanged && !bytesChanged && !detailChanged && !fileNameChanged) {
        return;
    }

    if (fileNameChanged) {
        j.fileName = fileName;
    }

    j.state = newState;
    j.progress = clampedProgress;
    j.processedBytes = processedBytes;
    j.compressedBytes = compressedBytes;
    if (totalBytes > 0) {
        j.totalBytes = totalBytes;
    }
    if (!detail.isEmpty()) {
        j.detail = detail;
    }

    bool isFailedTransition = stateChanged && ((oldState == QStringLiteral("failed") && newState != QStringLiteral("failed")) ||
                                              (oldState != QStringLiteral("failed") && newState == QStringLiteral("failed")));

    if (isFailedTransition) {
        rebuildDisplayMapping();
    } else {
        int dispRow = toDisplayIndex(targetRow);
        QModelIndex idx = createIndex(dispRow, 0);
        emit dataChanged(idx, idx, {StateRole, ProgressRole, DetailRole, FileNameRole});
    }

    if (progressChanged) {
        m_progressSum += (clampedProgress - oldProgress);
        if (m_progressSum < 0.0) m_progressSum = 0.0;
        if (!m_jobs.empty()) {
            qreal newOverall = m_progressSum / static_cast<qreal>(m_jobs.size());
            if (std::abs(m_overallProgress - newOverall) > 0.005 || (newOverall >= 0.999 && m_overallProgress < 0.999)) {
                m_overallProgress = newOverall;
                emit overallProgressChanged();
            }
        }
    }

    if (bytesChanged) {
        m_totalProcessedBytes += (j.processedBytes - oldProcessed);
        m_totalCompressedBytes += (j.compressedBytes - oldCompressed);
        if (totalBytes > 0) {
            m_totalBytes += (j.totalBytes - oldTotal);
        }
        emit this->progressChanged();
    }

    if (stateChanged) {
        auto decCount = [&](const QString &s) {
            if (s == QStringLiteral("running")) m_runningCount = std::max(0, m_runningCount - 1);
            else if (s == QStringLiteral("finished") || s == QStringLiteral("done")) m_finishedCount = std::max(0, m_finishedCount - 1);
            else if (s == QStringLiteral("failed")) m_failedCount = std::max(0, m_failedCount - 1);
            else if (s == QStringLiteral("paused")) m_pausedCount = std::max(0, m_pausedCount - 1);
            else if (s == QStringLiteral("aborted")) m_abortedCount = std::max(0, m_abortedCount - 1);
        };
        auto incCount = [&](const QString &s) {
            if (s == QStringLiteral("running")) m_runningCount++;
            else if (s == QStringLiteral("finished") || s == QStringLiteral("done")) m_finishedCount++;
            else if (s == QStringLiteral("failed")) m_failedCount++;
            else if (s == QStringLiteral("paused")) m_pausedCount++;
            else if (s == QStringLiteral("aborted")) m_abortedCount++;
        };
        decCount(oldState);
        incCount(newState);
        emit countsChanged();

        // Update running job index (single head executing)
        if (newState == QStringLiteral("running")) {
            if (m_runningJobIndex != targetRow) {
                m_runningJobIndex = targetRow;
                emit runningJobIndexChanged(m_runningJobIndex);
            }
        } else if (m_runningJobIndex == targetRow) {
            // Target row stopped running; check if next job is already running
            int nextRunning = -1;
            if (targetRow + 1 < static_cast<int>(m_jobs.size()) && m_jobs[targetRow + 1].state == QStringLiteral("running")) {
                nextRunning = targetRow + 1;
            }
            if (m_runningJobIndex != nextRunning) {
                m_runningJobIndex = nextRunning;
                emit runningJobIndexChanged(m_runningJobIndex);
            }
        }

        if (newState == QStringLiteral("failed")) {
            if (m_failedJobIndex < 0 || targetRow < m_failedJobIndex) {
                m_failedJobIndex = targetRow;
                emit failedJobIndexChanged(m_failedJobIndex);
            }
        }

        // Update overallState
        QString newOverallState = QStringLiteral("idle");
        if (m_failedCount > 0) newOverallState = QStringLiteral("failed");
        else if (m_abortedCount > 0) newOverallState = QStringLiteral("aborted");
        else if (m_runningCount > 0) newOverallState = QStringLiteral("running");
        else if (m_pausedCount > 0) newOverallState = QStringLiteral("paused");
        else if (m_finishedCount == static_cast<int>(m_jobs.size()) && !m_jobs.empty()) newOverallState = QStringLiteral("finished");
        else if (m_runningCount == 0 && m_finishedCount > 0) newOverallState = QStringLiteral("finished");

        if (m_overallState != newOverallState) {
            m_overallState = newOverallState;
            emit overallStateChanged();
        }
    }
}

void SeJobModel::recalculateAggregates() {
    if (m_jobs.empty()) {
        m_progressSum = 0.0;
        if (m_overallProgress != 0.0) { m_overallProgress = 0.0; emit overallProgressChanged(); }
        if (m_overallState != QStringLiteral("idle")) { m_overallState = QStringLiteral("idle"); emit overallStateChanged(); }
        if (m_runningCount != 0 || m_finishedCount != 0 || m_failedCount != 0 || m_pausedCount != 0 || m_abortedCount != 0) {
            m_runningCount = 0; m_finishedCount = 0; m_failedCount = 0; m_pausedCount = 0; m_abortedCount = 0; emit countsChanged();
        }
        if (m_runningJobIndex != -1) { m_runningJobIndex = -1; emit runningJobIndexChanged(-1); }
        if (m_failedJobIndex != -1) { m_failedJobIndex = -1; emit failedJobIndexChanged(-1); }
        if (m_totalProcessedBytes != 0 || m_totalCompressedBytes != 0 || m_totalBytes != 0) {
            m_totalProcessedBytes = 0; m_totalCompressedBytes = 0; m_totalBytes = 0; emit progressChanged();
        }
        return;
    }

    qreal sum = 0.0;
    int running = 0;
    int finished = 0;
    int failed = 0;
    int paused = 0;
    int aborted = 0;
    int firstRunning = -1;
    int firstFailed = -1;
    qulonglong totProc = 0;
    qulonglong totComp = 0;
    qulonglong totBytes = 0;

    for (size_t i = 0; i < m_jobs.size(); ++i) {
        const auto &j = m_jobs[i];
        sum += j.progress;
        totProc += j.processedBytes;
        totComp += j.compressedBytes;
        totBytes += j.totalBytes;
        if (j.state == QStringLiteral("running")) {
            running++;
            if (firstRunning < 0) firstRunning = static_cast<int>(i);
        } else if (j.state == QStringLiteral("finished") || j.state == QStringLiteral("done")) {
            finished++;
        } else if (j.state == QStringLiteral("failed")) {
            failed++;
            if (firstFailed < 0) firstFailed = static_cast<int>(i);
        } else if (j.state == QStringLiteral("paused")) {
            paused++;
        } else if (j.state == QStringLiteral("aborted")) {
            aborted++;
        }
    }

    m_progressSum = sum;

    if (m_totalProcessedBytes != totProc || m_totalCompressedBytes != totComp || m_totalBytes != totBytes) {
        m_totalProcessedBytes = totProc;
        m_totalCompressedBytes = totComp;
        m_totalBytes = totBytes;
        emit progressChanged();
    }

    qreal newOverall = sum / static_cast<qreal>(m_jobs.size());
    if (std::abs(m_overallProgress - newOverall) > 0.005 || (newOverall >= 0.999 && m_overallProgress < 0.999)) {
        m_overallProgress = newOverall;
        emit overallProgressChanged();
    }

    QString newState = QStringLiteral("idle");
    if (failed > 0) newState = QStringLiteral("failed");
    else if (aborted > 0) newState = QStringLiteral("aborted");
    else if (running > 0) newState = QStringLiteral("running");
    else if (paused > 0) newState = QStringLiteral("paused");
    else if (finished == static_cast<int>(m_jobs.size())) newState = QStringLiteral("finished");
    else if (running == 0 && finished > 0) newState = QStringLiteral("finished");

    if (m_overallState != newState) {
        m_overallState = newState;
        emit overallStateChanged();
    }

    if (m_runningCount != running || m_finishedCount != finished || m_failedCount != failed ||
        m_pausedCount != paused || m_abortedCount != aborted) {
        m_runningCount = running;
        m_finishedCount = finished;
        m_failedCount = failed;
        m_pausedCount = paused;
        m_abortedCount = aborted;
        emit countsChanged();
    }

    int dispFirstRunning = (firstRunning >= 0) ? toDisplayIndex(firstRunning) : -1;
    int dispFirstFailed = (failed > 0) ? 0 : -1;

    if (m_runningJobIndex != dispFirstRunning) {
        m_runningJobIndex = dispFirstRunning;
        emit runningJobIndexChanged(m_runningJobIndex);
    }
    if (m_failedJobIndex != dispFirstFailed) {
        m_failedJobIndex = dispFirstFailed;
        emit failedJobIndexChanged(m_failedJobIndex);
    }
}

void SeJobModel::rebuildDisplayMapping() {
    if (m_failedCount == 0) {
        if (!m_displayToSource.empty()) {
            beginResetModel();
            m_displayToSource.clear();
            m_sourceToDisplay.clear();
            endResetModel();
        }
        return;
    }

    size_t total = m_jobs.size();
    std::vector<int> newDisplayToSource(total);
    std::vector<int> newSourceToDisplay(total);

    int pos = 0;
    // 1. Put all failed jobs at the very top of the list
    for (size_t i = 0; i < total; ++i) {
        if (m_jobs[i].state == QStringLiteral("failed")) {
            newDisplayToSource[pos] = static_cast<int>(i);
            newSourceToDisplay[i] = pos;
            pos++;
        }
    }
    // 2. Follow with all other jobs in their original sequence
    for (size_t i = 0; i < total; ++i) {
        if (m_jobs[i].state != QStringLiteral("failed")) {
            newDisplayToSource[pos] = static_cast<int>(i);
            newSourceToDisplay[i] = pos;
            pos++;
        }
    }

    beginResetModel();
    m_displayToSource = std::move(newDisplayToSource);
    m_sourceToDisplay = std::move(newSourceToDisplay);
    endResetModel();
}

void SeJobModel::clearJobs() {
    clear();
}

void SeJobModel::abortRunningJobs() {
    bool anyChanged = false;
    for (size_t i = 0; i < m_jobs.size(); ++i) {
        if (m_jobs[i].state == QStringLiteral("running")) {
            m_jobs[i].state = QStringLiteral("aborted");
            m_jobs[i].detail = QStringLiteral("Cancelled");
            anyChanged = true;
        }
    }

    m_runningCount = 0;
    m_runningJobIndex = -1;

    if (anyChanged) {
        recalculateAggregates();
        rebuildDisplayMapping();
        emit dataChanged(createIndex(0, 0), createIndex(static_cast<int>(m_jobs.size()) - 1, 0), {StateRole, DetailRole});
    } else {
        recalculateAggregates();
    }
}

QVariantMap SeJobModel::get(int index) const {
    int srcRow = toSourceIndex(index);
    if (srcRow < 0 || srcRow >= static_cast<int>(m_jobs.size())) {
        return {};
    }
    const auto &j = m_jobs[srcRow];
    QVariantMap map;
    map[QStringLiteral("name")] = j.name;
    map[QStringLiteral("state")] = j.state;
    map[QStringLiteral("progress")] = j.progress;
    map[QStringLiteral("detail")] = j.detail;
    map[QStringLiteral("id")] = j.id;
    map[QStringLiteral("jobIndex")] = srcRow;
    map[QStringLiteral("fileName")] = j.fileName;
    return map;
}

void SeJobModel::setProperty(int index, const QString &property, const QVariant &value) {
    int srcRow = toSourceIndex(index);
    if (srcRow < 0 || srcRow >= static_cast<int>(m_jobs.size())) {
        return;
    }
    auto &j = m_jobs[srcRow];
    QList<int> roles;

    if (property == QStringLiteral("state")) {
        j.state = value.toString();
        roles.append(StateRole);
    } else if (property == QStringLiteral("progress")) {
        j.progress = value.toReal();
        roles.append(ProgressRole);
    } else if (property == QStringLiteral("detail")) {
        j.detail = value.toString();
        roles.append(DetailRole);
    } else if (property == QStringLiteral("name")) {
        j.name = value.toString();
        roles.append(NameRole);
    }

    if (!roles.isEmpty()) {
        int dispRow = toDisplayIndex(srcRow);
        QModelIndex idx = createIndex(dispRow, 0);
        emit dataChanged(idx, idx, roles);
        recalculateAggregates();
        if (property == QStringLiteral("state")) {
            rebuildDisplayMapping();
        }
    }
}

void SeJobModel::append(const QVariantMap &item) {
    int newRow = static_cast<int>(m_jobs.size());
    beginInsertRows(QModelIndex(), newRow, newRow);

    JobData data;
    data.name = item.value(QStringLiteral("name")).toString();
    data.state = item.value(QStringLiteral("state"), QStringLiteral("pending")).toString();
    data.progress = item.value(QStringLiteral("progress"), 0.0).toReal();
    data.detail = item.value(QStringLiteral("detail")).toString();
    data.id = item.value(QStringLiteral("id"), newRow + 1).toInt();

    m_jobs.push_back(data);
    if (data.id > 0) m_idToIndex[data.id] = newRow;
    endInsertRows();

    recalculateAggregates();
    rebuildDisplayMapping();
    emit countChanged();
}

void SeJobModel::remove(int index) {
    int srcRow = toSourceIndex(index);
    if (srcRow < 0 || srcRow >= static_cast<int>(m_jobs.size())) return;

    beginRemoveRows(QModelIndex(), index, index);
    m_jobs.erase(m_jobs.begin() + srcRow);

    // Rebuild index maps
    m_idToIndex.clear();
    m_fileToIndex.clear();
    for (size_t i = 0; i < m_jobs.size(); ++i) {
        if (m_jobs[i].id > 0) m_idToIndex[m_jobs[i].id] = i;
        if (!m_jobs[i].fileName.isEmpty()) m_fileToIndex[m_jobs[i].fileName] = i;
    }
    endRemoveRows();

    recalculateAggregates();
    rebuildDisplayMapping();
    emit countChanged();
}

void SeJobModel::removeCompletedJobs() {
    // Logic removed: completed jobs are preserved in job list
}

void SeJobModel::clear() {
    beginResetModel();
    m_jobs.clear();
    m_displayToSource.clear();
    m_sourceToDisplay.clear();
    m_idToIndex.clear();
    m_fileToIndex.clear();
    endResetModel();

    recalculateAggregates();
    emit countChanged();
}
