#pragma once
#include <QJSEngine>
#include <QMimeData>
#include <QMetaObject>
#include <QPainter>
#include <QPainterPath>
#include <QPixmap>
#include <QStorageInfo>
#include <QTemporaryDir>
#include <QUrl>

class DelayedExtractMimeData : public QMimeData {

public:
    DelayedExtractMimeData(ArchiveInterface* iface,
        const QStringList& archivePaths,
        const QString& displayName,
        bool isFolder)
        : m_iface(iface),
        m_archivePaths(archivePaths),
        m_displayName(displayName),
        m_isFolder(isFolder) {
    }

    QStringList formats() const override {
        QStringList f = QMimeData::formats();
        if (!f.contains(QStringLiteral("text/uri-list"))) {
            f.append(QStringLiteral("text/uri-list"));
        }
        return f;
    }

    bool hasFormat(const QString& mimetype) const override {
        if (mimetype == QStringLiteral("text/uri-list")) {
            return true;
        }
        return QMimeData::hasFormat(mimetype);
    }

protected:
    QVariant retrieveData(const QString& mimetype, QMetaType preferredType) const override {
        if (mimetype == QStringLiteral("text/uri-list")) {
            if (!m_extracted) {
                performExtraction();
            }
            return QVariant::fromValue(m_stagedUrls);
        }
        return QMimeData::retrieveData(mimetype, preferredType);
    }

private:
    void performExtraction() const {
        if (m_extracted) return;
        m_extracted = true;

        if (!m_iface || !m_iface->m_archive) return;

        struct ExtractedItemInfo {
            QString normPath;
            QString itemFileName;
            bool isDir;
            qulonglong uncompressedSize;
        };

        std::vector<ExtractedItemInfo> items;
        QStringList jobFilePaths;
        qulonglong totalBytes = 0;

        const auto& entries = m_iface->m_archive->GetTOC().GetEntries();

        for (int i = 0; i < m_archivePaths.size(); ++i) {
            QString normPath = m_archivePaths.at(i);
            if (!normPath.startsWith(u'/')) {
                normPath.prepend(u'/');
            }

            auto entryOpt = m_iface->m_archive->GetTOC().GetEntry(normPath.toStdU16String());
            bool itemIsDir = m_isFolder || normPath.endsWith(u'/') || (entryOpt && entryOpt->isDirectory());

            QString itemFileName;
            if (m_archivePaths.size() == 1 && !m_displayName.isEmpty()) {
                itemFileName = m_displayName;
            }
            else {
                QString stripped = normPath;
                if (stripped.endsWith(u'/') && stripped.length() > 1) {
                    stripped.chop(1);
                }
                itemFileName = stripped.section(u'/', -1);
            }
            if (itemFileName.isEmpty()) {
                itemFileName = QStringLiteral("Item_%1").arg(i + 1);
            }

            qulonglong sz = (entryOpt ? entryOpt->uncompressed_size : 0);
            items.push_back({ normPath, itemFileName, itemIsDir, sz });

            if (itemIsDir) {
                QString prefix = normPath;
                if (!prefix.endsWith(u'/')) prefix.append(u'/');
                for (const auto& e : entries) {
                    if (e.path == u"/") continue;
                    if (!e.isDirectory()) {
                        QString ePath = QString::fromStdU16String(e.path);
                        if (ePath.startsWith(prefix)) {
                            jobFilePaths.append(ePath);
                            totalBytes += e.uncompressed_size;
                        }
                    }
                }
            }
            else {
                jobFilePaths.append(normPath);
                totalBytes += sz;
            }
        }

        if (jobFilePaths.isEmpty() && !items.empty()) {
            jobFilePaths.append(items.front().normPath);
        }

        m_iface->setBusy(true);
        m_iface->m_totalFiles = static_cast<int>(jobFilePaths.size());
        m_iface->m_processedFiles = 0;
        m_iface->m_extractTotalBytes = totalBytes;
        m_iface->m_extractProcessedBytes = 0;
        m_iface->m_extractCompressedBytes = 0;
        m_iface->m_overallProgress = 0.0;
        m_iface->m_fileProgress = 0.0;
        m_iface->m_currentOperationName = QStringLiteral("Extracting: ") + (m_displayName.isEmpty() ? (items.empty() ? QStringLiteral("Export") : items.front().itemFileName) : m_displayName);
        m_iface->m_currentFileName = m_displayName;
        m_iface->setStatusMessage(QStringLiteral("Extracting for export..."));

        if (m_iface->m_jobModel) {
            m_iface->m_jobModel->setExtractJobs(jobFilePaths);
        }

        emit m_iface->dragStagingStarted(m_displayName);
        emit m_iface->progressChanged();
        QCoreApplication::processEvents(QEventLoop::ExcludeUserInputEvents, 20);

        QString stagingBaseDir = QDir::tempPath() + QStringLiteral("/SecDet_Drag_") +
            QString::number(QCoreApplication::applicationPid()) + QStringLiteral("_") +
            QString::number(QDateTime::currentMSecsSinceEpoch());
        QDir().mkpath(stagingBaseDir);

        auto extractCb = [this, totalAllBytes = totalBytes](const SeJob& job) {
            QString jobFile = QString::fromStdU16String(job.GetFileName());
            if (!jobFile.isEmpty()) {
                m_iface->m_currentFileName = jobFile.section(u'/', -1);
            }
            m_iface->m_fileProgress = static_cast<qreal>(job.percentage) / 100.0;
            m_iface->m_extractProcessedBytes = job.processedBytes;
            m_iface->m_extractTotalBytes = (job.totalBytes > 0) ? job.totalBytes : totalAllBytes;
            m_iface->m_extractCompressedBytes = job.compressedBytes;

            if (m_iface->m_jobModel && m_iface->m_jobModel->count() > 0) {
                m_iface->m_jobModel->updateJob(job);
                m_iface->m_overallProgress = m_iface->m_jobModel->overallProgress();
                m_iface->m_processedFiles = m_iface->m_jobModel->finishedCount();
            }
            else {
                m_iface->m_overallProgress = m_iface->m_fileProgress;
            }

            emit m_iface->progressChanged();
            QCoreApplication::processEvents(QEventLoop::ExcludeUserInputEvents, 10);
            };

        for (const auto& item : items) {
            QString stagedItemPath = stagingBaseDir + QStringLiteral("/") + item.itemFileName;
            if (item.isDir) {
                auto res = m_iface->m_archive->ExtractDirectorySync(item.normPath.toStdU16String(), stagingBaseDir.toStdU16String(), extractCb);
                if (!res) {
                    emit m_iface->dragStagingCompleted();
                    m_iface->setBusy(false);
                    emit m_iface->operationCompleted(QStringLiteral("Drag Export"), false, QString::fromLocal8Bit(res.error().message().c_str()));
                    return;
                }
            }
            else {
                auto res = m_iface->m_archive->ExtractFileSync(item.normPath.toStdU16String(), stagingBaseDir.toStdU16String(), extractCb);
                if (!res) {
                    emit m_iface->dragStagingCompleted();
                    m_iface->setBusy(false);
                    emit m_iface->operationCompleted(QStringLiteral("Drag Export"), false, QString::fromLocal8Bit(res.error().message().c_str()));
                    return;
                }
            }
            if (QFile::exists(stagedItemPath)) {
                m_stagedUrls.append(QUrl::fromLocalFile(stagedItemPath));
            }
        }

        m_iface->m_overallProgress = 1.0;
        m_iface->m_fileProgress = 1.0;
        m_iface->m_processedFiles = m_iface->m_totalFiles;
        emit m_iface->progressChanged();
        m_iface->setBusy(false);
        emit m_iface->dragStagingCompleted();
        emit m_iface->operationCompleted(QStringLiteral("Drag Export"), true, QStringLiteral("Export completed successfully"));
        QCoreApplication::processEvents(QEventLoop::ExcludeUserInputEvents, 20);
    }

    ArchiveInterface* m_iface;
    QStringList m_archivePaths;
    QString m_displayName;
    bool m_isFolder;
    mutable bool m_extracted = false;
    mutable QList<QUrl> m_stagedUrls;
};