#include "SeFileEntryObject.h"

#include <QFileInfo>

SeFileEntryObject::SeFileEntryObject(QObject *parent)
    : QObject(parent) {}

SeFileEntryObject::SeFileEntryObject(const SeArchiveEntry &entry, QObject *parent)
    : QObject(parent),
      m_uncompressedSize(entry.uncompressed_size),
      m_compressedSize(entry.compressed_size),
      m_crc32(entry.crc32),
      m_attributes(entry.attributes),
      m_offset(entry.offset),
      m_isPending(false) {

    m_path = QString::fromStdU16String(entry.path);
    m_isFolder = entry.isDirectory();

    // Determine display name
    QString cleanPath = m_path;
    while (cleanPath.endsWith(u'/') || cleanPath.endsWith(u'\\')) {
        cleanPath.chop(1);
    }
    int lastSlash = std::max(cleanPath.lastIndexOf(u'/'), cleanPath.lastIndexOf(u'\\'));
    if (lastSlash >= 0) {
        m_name = cleanPath.mid(lastSlash + 1);
    } else {
        m_name = cleanPath;
    }
    if (m_name.isEmpty()) {
        m_name = "/";
    }
}

SeFileEntryObject::SeFileEntryObject(const QString &name, const QString &path, bool isFolder,
                                     qulonglong uncompressedSize, qulonglong compressedSize,
                                     bool isPending, QObject *parent)
    : QObject(parent),
      m_name(name),
      m_path(path),
      m_isFolder(isFolder),
      m_uncompressedSize(uncompressedSize),
      m_compressedSize(compressedSize),
      m_isPending(isPending) {}

QString SeFileEntryObject::formattedRealSize() const {
    if (m_isFolder) {
        return QStringLiteral("-");
    }
    return formatBytes(m_uncompressedSize);
}

QString SeFileEntryObject::formattedCompressedSize() const {
    if (m_isPending) {
        return QStringLiteral("Staged");
    }
    if (m_isFolder) {
        return QStringLiteral("-");
    }
    return formatBytes(m_compressedSize);
}

QString SeFileEntryObject::ratio() const {
    if (m_isPending) {
        return QStringLiteral("Pending");
    }
    if (m_isFolder) {
        return QStringLiteral("-");
    }
    if (m_uncompressedSize == 0) {
        return QStringLiteral("-");
    }
    if (m_compressedSize >= m_uncompressedSize) {
        return QStringLiteral("0%");
    }
    double savings = (1.0 - (static_cast<double>(m_compressedSize) / static_cast<double>(m_uncompressedSize))) * 100.0;
    return QString::number(qRound(savings)) + QStringLiteral("%");
}

void SeFileEntryObject::setPending(bool pending) {
    if (m_isPending != pending) {
        m_isPending = pending;
        emit entryChanged();
    }
}

void SeFileEntryObject::setChildren(const QVariantList &children) {
    m_children = children;
    emit childrenChanged();
}

void SeFileEntryObject::addChild(const QVariantMap &child) {
    m_children.append(child);
    emit childrenChanged();
}

QVariantMap SeFileEntryObject::toVariantMap() const {
    QVariantMap map;
    map[QStringLiteral("name")] = m_name;
    map[QStringLiteral("filePath")] = m_path;
    map[QStringLiteral("isFolder")] = m_isFolder;
    map[QStringLiteral("expanded")] = true;
    map[QStringLiteral("pending")] = m_isPending;
    map[QStringLiteral("realSize")] = formattedRealSize();
    map[QStringLiteral("compressedSize")] = formattedCompressedSize();
    map[QStringLiteral("ratio")] = ratio();
    map[QStringLiteral("crc32")] = QStringLiteral("0x%1").arg(m_crc32, 8, 16, QLatin1Char('0')).toUpper();
    map[QStringLiteral("children")] = m_children;
    return map;
}

QString SeFileEntryObject::formatBytes(qulonglong bytes) {
    if (bytes < 1024) {
        return QString::number(bytes) + QStringLiteral(" B");
    }
    double kb = static_cast<double>(bytes) / 1024.0;
    if (kb < 1024.0) {
        return QString::number(kb, 'f', 1) + QStringLiteral(" KB");
    }
    double mb = kb / 1024.0;
    if (mb < 1024.0) {
        return QString::number(mb, 'f', 1) + QStringLiteral(" MB");
    }
    double gb = mb / 1024.0;
    return QString::number(gb, 'f', 2) + QStringLiteral(" GB");
}
