#include "SeMetadataObject.h"
#include "SeFileEntryObject.h"

SeMetadataObject::SeMetadataObject(QObject *parent)
    : QObject(parent) {}

SeMetadataObject::SeMetadataObject(const SeMetadata &metadata, QObject *parent)
    : QObject(parent) {
    updateFromSeMetadata(metadata);
}

QString SeMetadataObject::compressionPresetName() const {
    switch (m_compressionLevel) {
        case 1:  return QStringLiteral("Fast (Store)");
        case 2:  return QStringLiteral("Balanced (Deflate)");
        case 3:  return QStringLiteral("Ultra (LZMA2/Zstd)");
        default: return QStringLiteral("Balanced");
    }
}

QString SeMetadataObject::formattedTotalRealSize() const {
    return SeFileEntryObject::formatBytes(m_totalRealSize);
}

QString SeMetadataObject::formattedTotalCompressedSize() const {
    return SeFileEntryObject::formatBytes(m_totalCompressedSize);
}

QString SeMetadataObject::overallRatio() const {
    if (m_totalRealSize == 0) {
        return QStringLiteral("-");
    }
    if (m_totalCompressedSize >= m_totalRealSize) {
        return QStringLiteral("0%");
    }
    double savings = (1.0 - (static_cast<double>(m_totalCompressedSize) / static_cast<double>(m_totalRealSize))) * 100.0;
    return QString::number(qRound(savings)) + QStringLiteral("%");
}

void SeMetadataObject::updateFromSeMetadata(const SeMetadata &metadata) {
    auto &nonConstMeta = const_cast<SeMetadata&>(metadata);
    m_compressionLevel = nonConstMeta.GetCompressionLevel();
    m_preserveMetadata = nonConstMeta.GetPreserveMetadata();
    m_version = 1;
    emit metadataChanged();
}

void SeMetadataObject::updateStats(int fileCount, int folderCount, qulonglong totalRealSize, qulonglong totalCompressedSize) {
    m_fileCount = fileCount;
    m_folderCount = folderCount;
    m_totalRealSize = totalRealSize;
    m_totalCompressedSize = totalCompressedSize;
    emit statsChanged();
}

void SeMetadataObject::setArchiveFileName(const QString &fileName) {
    if (m_archiveFileName != fileName) {
        m_archiveFileName = fileName;
        emit metadataChanged();
    }
}

void SeMetadataObject::setCompressionLevel(int level) {
    if (level < 1 || level > 3) {
        return;
    }
    if (m_compressionLevel != level) {
        m_compressionLevel = level;
        emit metadataChanged();
        emit compressionLevelModified(level);
    }
}

void SeMetadataObject::setPreserveMetadata(bool preserve) {
    if (m_preserveMetadata != preserve) {
        m_preserveMetadata = preserve;
        emit metadataChanged();
        emit preserveMetadataModified(preserve);
    }
}
