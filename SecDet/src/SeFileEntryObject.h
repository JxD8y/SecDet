#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

#include <libsecdet/SeTOC.h>

class SeFileEntryObject : public QObject {
    Q_OBJECT

    Q_PROPERTY(QString name READ name NOTIFY entryChanged)
    Q_PROPERTY(QString path READ path NOTIFY entryChanged)
    Q_PROPERTY(bool isFolder READ isFolder NOTIFY entryChanged)
    Q_PROPERTY(qulonglong uncompressedSize READ uncompressedSize NOTIFY entryChanged)
    Q_PROPERTY(qulonglong compressedSize READ compressedSize NOTIFY entryChanged)
    Q_PROPERTY(QString formattedRealSize READ formattedRealSize NOTIFY entryChanged)
    Q_PROPERTY(QString formattedCompressedSize READ formattedCompressedSize NOTIFY entryChanged)
    Q_PROPERTY(QString ratio READ ratio NOTIFY entryChanged)
    Q_PROPERTY(quint32 crc32 READ crc32 NOTIFY entryChanged)
    Q_PROPERTY(quint32 attributes READ attributes NOTIFY entryChanged)
    Q_PROPERTY(qulonglong offset READ offset NOTIFY entryChanged)
    Q_PROPERTY(bool isPending READ isPending WRITE setPending NOTIFY entryChanged)
    Q_PROPERTY(QVariantList children READ children NOTIFY childrenChanged)

public:
    explicit SeFileEntryObject(QObject *parent = nullptr);
    explicit SeFileEntryObject(const SeArchiveEntry &entry, QObject *parent = nullptr);
    SeFileEntryObject(const QString &name, const QString &path, bool isFolder,
                      qulonglong uncompressedSize, qulonglong compressedSize,
                      bool isPending = false, QObject *parent = nullptr);

    [[nodiscard]] QString name() const { return m_name; }
    [[nodiscard]] QString path() const { return m_path; }
    [[nodiscard]] bool isFolder() const { return m_isFolder; }
    [[nodiscard]] qulonglong uncompressedSize() const { return m_uncompressedSize; }
    [[nodiscard]] qulonglong compressedSize() const { return m_compressedSize; }
    [[nodiscard]] QString formattedRealSize() const;
    [[nodiscard]] QString formattedCompressedSize() const;
    [[nodiscard]] QString ratio() const;
    [[nodiscard]] quint32 crc32() const { return m_crc32; }
    [[nodiscard]] quint32 attributes() const { return m_attributes; }
    [[nodiscard]] qulonglong offset() const { return m_offset; }
    [[nodiscard]] bool isPending() const { return m_isPending; }
    [[nodiscard]] QVariantList children() const { return m_children; }

    void setPending(bool pending);
    void setChildren(const QVariantList &children);
    void addChild(const QVariantMap &child);

    [[nodiscard]] QVariantMap toVariantMap() const;

    static QString formatBytes(qulonglong bytes);

signals:
    void entryChanged();
    void childrenChanged();

private:
    QString m_name;
    QString m_path;
    bool m_isFolder = false;
    qulonglong m_uncompressedSize = 0;
    qulonglong m_compressedSize = 0;
    quint32 m_crc32 = 0;
    quint32 m_attributes = 0;
    qulonglong m_offset = 0;
    bool m_isPending = false;
    QVariantList m_children;
};
