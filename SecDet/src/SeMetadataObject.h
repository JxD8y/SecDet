#pragma once

#include <QObject>
#include <QString>
#include <QVariantMap>

#include <libsecdet/SeMetadata.h>

class SeMetadataObject : public QObject {
    Q_OBJECT

    Q_PROPERTY(int version READ version NOTIFY metadataChanged)
    Q_PROPERTY(int compressionLevel READ compressionLevel WRITE setCompressionLevel NOTIFY metadataChanged)
    Q_PROPERTY(QString compressionPresetName READ compressionPresetName NOTIFY metadataChanged)
    Q_PROPERTY(bool preserveMetadata READ preserveMetadata WRITE setPreserveMetadata NOTIFY metadataChanged)
    Q_PROPERTY(qulonglong tocOffset READ tocOffset NOTIFY metadataChanged)
    Q_PROPERTY(QString archiveFileName READ archiveFileName NOTIFY metadataChanged)
    Q_PROPERTY(int fileCount READ fileCount NOTIFY statsChanged)
    Q_PROPERTY(int folderCount READ folderCount NOTIFY statsChanged)
    Q_PROPERTY(qulonglong totalRealSize READ totalRealSize NOTIFY statsChanged)
    Q_PROPERTY(qulonglong totalCompressedSize READ totalCompressedSize NOTIFY statsChanged)
    Q_PROPERTY(QString formattedTotalRealSize READ formattedTotalRealSize NOTIFY statsChanged)
    Q_PROPERTY(QString formattedTotalCompressedSize READ formattedTotalCompressedSize NOTIFY statsChanged)
    Q_PROPERTY(QString overallRatio READ overallRatio NOTIFY statsChanged)

public:
    explicit SeMetadataObject(QObject *parent = nullptr);
    explicit SeMetadataObject(const SeMetadata &metadata, QObject *parent = nullptr);

    [[nodiscard]] int version() const { return m_version; }
    [[nodiscard]] int compressionLevel() const { return m_compressionLevel; }
    [[nodiscard]] QString compressionPresetName() const;
    [[nodiscard]] bool preserveMetadata() const { return m_preserveMetadata; }
    [[nodiscard]] qulonglong tocOffset() const { return m_tocOffset; }
    [[nodiscard]] QString archiveFileName() const { return m_archiveFileName; }

    [[nodiscard]] int fileCount() const { return m_fileCount; }
    [[nodiscard]] int folderCount() const { return m_folderCount; }
    [[nodiscard]] qulonglong totalRealSize() const { return m_totalRealSize; }
    [[nodiscard]] qulonglong totalCompressedSize() const { return m_totalCompressedSize; }
    [[nodiscard]] QString formattedTotalRealSize() const;
    [[nodiscard]] QString formattedTotalCompressedSize() const;
    [[nodiscard]] QString overallRatio() const;

    void updateFromSeMetadata(const SeMetadata &metadata);
    void updateStats(int fileCount, int folderCount, qulonglong totalRealSize, qulonglong totalCompressedSize);
    void setArchiveFileName(const QString &fileName);

public slots:
    void setCompressionLevel(int level);
    void setPreserveMetadata(bool preserve);

signals:
    void metadataChanged();
    void statsChanged();
    void compressionLevelModified(int level);
    void preserveMetadataModified(bool preserve);

private:
    int m_version = 1;
    int m_compressionLevel = 2; // 1 = Fast, 2 = Balanced, 3 = Ultra
    bool m_preserveMetadata = true;
    qulonglong m_tocOffset = 0;
    QString m_archiveFileName;

    int m_fileCount = 0;
    int m_folderCount = 0;
    qulonglong m_totalRealSize = 0;
    qulonglong m_totalCompressedSize = 0;
};
