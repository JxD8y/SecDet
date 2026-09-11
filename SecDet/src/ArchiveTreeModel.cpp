#include "ArchiveTreeModel.h"
#include "SeFileEntryObject.h"
#include <QColor>
#include <QFileInfo>
#include <algorithm>
#include <map>
#include <unordered_map>
#include <unordered_set>

ArchiveTreeModel::ArchiveTreeModel(QObject *parent)
    : QAbstractListModel(parent),
      m_rootNode(std::make_unique<TreeNode>()) {
    m_rootNode->name = QStringLiteral("/");
    m_rootNode->fullPath = QStringLiteral("/");
    m_rootNode->isFolder = true;
    m_rootNode->isExpanded = true;
    m_rootNode->depth = -1;
}

int ArchiveTreeModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return static_cast<int>(m_visibleNodes.size());
}

QVariant ArchiveTreeModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= static_cast<int>(m_visibleNodes.size())) {
        return {};
    }

    const auto *node = m_visibleNodes[index.row()];
    switch (role) {
    case NameRole:
    case Qt::DisplayRole:
        return node->name;
    case FilePathRole:
        return node->fullPath;
    case IsFolderRole:
        return node->isFolder;
    case DepthRole:
        return node->depth;
    case ExpandedRole:
        return node->isExpanded;
    case HasChildrenRole:
        return node->hasChildren();
    case PendingRole:
        return node->isPending;
    case ParentNameRole:
        return node->parentName;
    case CompressedSizeRole:
        if (node->isPending) return QStringLiteral("Staged");
        if (node->isFolder) return QStringLiteral("-");
        return formatSize(node->compressedSize);
    case RealSizeRole:
        if (node->isFolder) return QStringLiteral("-");
        return formatSize(node->realSize);
    case RatioRole:
        if (node->isPending) return QStringLiteral("Pending");
        if (node->isFolder) return QStringLiteral("-");
        if (node->realSize > 0) {
            if (node->compressedSize >= node->realSize) {
                return QStringLiteral("0%");
            }
            double savings = (1.0 - (static_cast<double>(node->compressedSize) / static_cast<double>(node->realSize))) * 100.0;
            return QString::number(qRound(savings)) + QStringLiteral("%");
        }
        return QStringLiteral("-");
    case CrcRole:
        if (node->isFolder || node->isPending) return QStringLiteral("-");
        return QString::asprintf("0x%08X", node->crc32);
    case KeyStatusRole:
        if (node->isFolder) return QStringLiteral("");
        if (node->isPending) return QStringLiteral("unlocked");
        return node->isUnlocked ? QStringLiteral("unlocked") : QStringLiteral("locked");
    case IsUnlockedRole:
        if (node->isFolder || node->isPending) return true;
        return node->isUnlocked;
    case HealthStatusRole:
        if (node->isFolder || node->isPending) return 0;
        return node->healthStatus;
    default:
        return {};
    }
}

QHash<int, QByteArray> ArchiveTreeModel::roleNames() const {
    QHash<int, QByteArray> roles;
    roles[NameRole] = "name";
    roles[FilePathRole] = "filePath";
    roles[IsFolderRole] = "isFolder";
    roles[DepthRole] = "depth";
    roles[ExpandedRole] = "expanded";
    roles[HasChildrenRole] = "hasChildren";
    roles[PendingRole] = "pending";
    roles[CompressedSizeRole] = "compressedSize";
    roles[RealSizeRole] = "realSize";
    roles[RatioRole] = "ratio";
    roles[ParentNameRole] = "parentName";
    roles[CrcRole] = "crc";
    roles[KeyStatusRole] = "keyStatus";
    roles[IsUnlockedRole] = "isUnlocked";
    roles[HealthStatusRole] = "healthStatus";
    return roles;
}

QString ArchiveTreeModel::formatSize(qulonglong bytes) {
    return SeFileEntryObject::formatBytes(bytes);
}

void ArchiveTreeModel::clear() {
    beginResetModel();
    m_healthStatusByPath.clear();
    m_rootNode = std::make_unique<TreeNode>();
    m_rootNode->name = QStringLiteral("/");
    m_rootNode->fullPath = QStringLiteral("/");
    m_rootNode->isFolder = true;
    m_rootNode->isExpanded = true;
    m_rootNode->depth = -1;
    m_visibleNodes.clear();
    m_nodeByPath.clear();

    m_fileCount = 0;
    m_folderCount = 0;
    m_totalRealSize = 0;
    m_totalCompressedSize = 0;
    endResetModel();

    emit countChanged();
    emit statsChanged();
}

void ArchiveTreeModel::buildTree(std::span<const SeArchiveEntry> entries,
                                 const std::vector<PendingItem> &pendingItems,
                                 const std::vector<StagedMoveItem> &moveItems,
                                 const std::vector<QString> &removePaths,
                                 const QString &archiveName) {
    std::unordered_set<QString> previouslyExpanded;
    std::unordered_set<QString> previouslyUnlocked;
    if (m_rootNode) {
        std::function<void(TreeNode*)> collectState = [&](TreeNode *node) {
            if (!node) return;
            if (node->isFolder && node->isExpanded && node != m_rootNode.get()) {
                previouslyExpanded.insert(node->fullPath);
            }
            if (!node->isFolder) {
                if (node->isUnlocked) {
                    previouslyUnlocked.insert(node->fullPath);
                }
                if (node->healthStatus != 0) {
                    m_healthStatusByPath[node->fullPath] = node->healthStatus;
                }
            }
            for (const auto &child : node->children) {
                collectState(child.get());
            }
        };
        collectState(m_rootNode.get());
    }

    beginResetModel();
    m_rootNode = std::make_unique<TreeNode>();
    m_rootNode->name = archiveName.isEmpty() ? QStringLiteral("/") : archiveName;
    m_rootNode->fullPath = QStringLiteral("/");
    m_rootNode->isFolder = true;
    m_rootNode->isExpanded = true;
    m_rootNode->depth = -1;
    m_visibleNodes.clear();
    m_nodeByPath.clear();
    m_nodeByPath[QStringLiteral("/")] = m_rootNode.get();

    m_fileCount = 0;
    m_folderCount = 0;
    m_totalRealSize = 0;
    m_totalCompressedSize = 0;

    std::unordered_map<QString, TreeNode*> dirMap;
    dirMap[QStringLiteral("/")] = m_rootNode.get();

    auto findOrCreateChild = [&](TreeNode *parent, QStringView partName, bool isDir) -> TreeNode* {
        if (partName.isEmpty()) return parent;

        QString targetPath;
        if (parent->fullPath.isEmpty() || parent->fullPath == QStringLiteral("/")) {
            targetPath = QStringLiteral("/") + partName;
        } else if (parent->fullPath.endsWith(u'/')) {
            targetPath = parent->fullPath + partName;
        } else {
            targetPath = parent->fullPath + QStringLiteral("/") + partName;
        }
        if (isDir && !targetPath.endsWith(u'/')) {
            targetPath += QStringLiteral("/");
        }

        if (isDir) {
            auto it = dirMap.find(targetPath);
            if (it != dirMap.end()) {
                it->second->isFolder = true;
                return it->second;
            }
        }

        auto newNode = std::make_unique<TreeNode>();
        newNode->name = partName.toString();
        newNode->isFolder = isDir;
        newNode->parent = parent;
        newNode->parentName = parent->name;
        newNode->depth = parent->depth + 1;
        // Folders initially start collapsed so user can see the full archive root;
        // preserve expanded state only if the folder was already expanded by user.
        newNode->isExpanded = isDir ? (previouslyExpanded.find(targetPath) != previouslyExpanded.end()) : false;
        newNode->isUnlocked = !isDir && (previouslyUnlocked.find(targetPath) != previouslyUnlocked.end());
        newNode->fullPath = targetPath;

        TreeNode *ptr = newNode.get();
        if (isDir) {
            dirMap[targetPath] = ptr;
        }
        m_nodeByPath[targetPath] = ptr;
        if (targetPath.endsWith(u'/') && targetPath.length() > 1) {
            m_nodeByPath[targetPath.left(targetPath.length() - 1)] = ptr;
        } else if (!targetPath.endsWith(u'/')) {
            m_nodeByPath[targetPath + u'/'] = ptr;
        }
        parent->children.push_back(std::move(newNode));
        return ptr;
    };

    // 1. Process TOC Entries (accounting for queued remove and move jobs)
    std::unordered_set<QString> removeExact;
    std::vector<QString> removePrefixes;
    removeExact.reserve(removePaths.size());
    for (const auto &rp : removePaths) {
        removeExact.insert(rp);
        if (rp.endsWith(u'/')) {
            removePrefixes.push_back(rp);
        } else {
            removePrefixes.push_back(rp + u'/');
        }
    }

    for (const auto &entry : entries) {
        QString fullPath = QString::fromStdU16String(entry.path);
        if (fullPath.isEmpty() || fullPath == QStringLiteral("/")) continue;

        // Check if this entry or any parent folder is queued for removal
        if (removeExact.find(fullPath) != removeExact.end()) {
            continue;
        }
        bool isRemoved = false;
        for (const auto &prefix : removePrefixes) {
            if (fullPath.startsWith(prefix)) {
                isRemoved = true;
                break;
            }
        }
        if (isRemoved) {
            continue;
        }

        bool isDir = entry.isDirectory();
        if (isDir) {
            m_folderCount++;
        } else {
            m_fileCount++;
            m_totalRealSize += entry.uncompressed_size;
            m_totalCompressedSize += entry.compressed_size;
        }

        // Check if this entry was moved in queued jobs
        QString effectivePath = fullPath;
        bool isStagedMove = false;
        for (const auto &mi : moveItems) {
            if (!mi.isDirectory && effectivePath == mi.srcPath) {
                QString fn = QFileInfo(effectivePath).fileName();
                effectivePath = mi.dstDirPath + fn;
                isStagedMove = true;
                break;
            } else if (mi.isDirectory && (effectivePath == mi.srcPath || effectivePath.startsWith(mi.srcPath))) {
                QString rel = effectivePath.mid(mi.srcPath.length());
                QString dirName = QFileInfo(mi.srcPath.left(mi.srcPath.length() - 1)).fileName();
                effectivePath = mi.dstDirPath + dirName + QStringLiteral("/") + rel;
                isStagedMove = true;
                break;
            }
        }

        QString cleanPath = effectivePath;
        cleanPath.replace(u'\\', u'/');
        while (cleanPath.startsWith(u'/')) cleanPath = cleanPath.mid(1);
        while (cleanPath.endsWith(u'/')) cleanPath.chop(1);

        std::vector<QStringView> parts;
        parts.reserve(8);
        for (auto part : QStringView(cleanPath).tokenize(u'/')) {
            parts.push_back(part);
        }
        TreeNode *current = m_rootNode.get();

        for (size_t i = 0; i < parts.size(); ++i) {
            const QStringView &part = parts[i];
            if (part.isEmpty()) continue;
            bool isLast = (i == parts.size() - 1);
            bool partIsDir = !isLast || isDir;

            current = findOrCreateChild(current, part, partIsDir);
            if (isStagedMove) {
                current->isPending = true;
            }
            if (isLast && !isDir) {
                current->realSize = entry.uncompressed_size;
                current->compressedSize = entry.compressed_size;
                current->crc32 = entry.crc32;
                auto hIt = m_healthStatusByPath.find(current->fullPath);
                if (hIt != m_healthStatusByPath.end()) {
                    current->healthStatus = hIt->second;
                }
            }
        }
    }

    // 2. Process Staged Pending Items
    for (const auto &pending : pendingItems) {
        bool isRemoved = false;
        for (const auto &rp : removePaths) {
            if (pending.archiveRelPath == rp ||
                (rp.endsWith(u'/') && pending.archiveRelPath.startsWith(rp)) ||
                (!rp.endsWith(u'/') && pending.archiveRelPath.startsWith(rp + u'/'))) {
                isRemoved = true;
                break;
            }
        }
        if (isRemoved) continue;

        QString cleanPath = pending.archiveRelPath;
        cleanPath.replace(u'\\', u'/');
        while (cleanPath.startsWith(u'/')) cleanPath = cleanPath.mid(1);
        while (cleanPath.endsWith(u'/')) cleanPath.chop(1);

        std::vector<QStringView> parts;
        parts.reserve(8);
        for (auto part : QStringView(cleanPath).tokenize(u'/')) {
            parts.push_back(part);
        }
        TreeNode *current = m_rootNode.get();

        for (size_t i = 0; i < parts.size(); ++i) {
            const QStringView &part = parts[i];
            if (part.isEmpty()) continue;
            bool isLast = (i == parts.size() - 1);
            bool partIsDir = !isLast || pending.isDirectory;

            current = findOrCreateChild(current, part, partIsDir);
            current->isPending = true;
            if (isLast) {
                current->realSize = pending.size;
                if (pending.isDirectory) {
                    m_folderCount++;
                } else {
                    m_fileCount++;
                    m_totalRealSize += pending.size;
                }
            }
        }
    }

    // Sort children: directories first, then files, alphabetically
    std::function<void(TreeNode*)> sortTree = [&](TreeNode *node) {
        std::sort(node->children.begin(), node->children.end(), [](const auto &a, const auto &b) {
            if (a->isFolder != b->isFolder) {
                return a->isFolder; // Folders come first
            }
            return a->name.compare(b->name, Qt::CaseInsensitive) < 0;
        });
        for (const auto &child : node->children) {
            sortTree(child.get());
        }
    };
    // Aggregate cumulative folder sizes bottom-up
    calculateCumulativeFolderSizes(m_rootNode.get());

    sortTree(m_rootNode.get());

    // Flatten all currently expanded visible nodes
    flattenVisibleTree(m_rootNode.get());

    endResetModel();
    emit countChanged();
    emit statsChanged();
}

void ArchiveTreeModel::flattenVisibleTree(TreeNode *node) {
    if (!node) return;
    for (const auto &child : node->children) {
        m_visibleNodes.push_back(child.get());
        if (child->isFolder && child->isExpanded) {
            flattenVisibleTree(child.get());
        }
    }
}

void ArchiveTreeModel::collectVisibleDescendants(TreeNode *node, std::vector<TreeNode*> &outList) {
    if (!node) return;
    for (const auto &child : node->children) {
        outList.push_back(child.get());
        if (child->isFolder && child->isExpanded) {
            collectVisibleDescendants(child.get(), outList);
        }
    }
}

void ArchiveTreeModel::toggleExpand(int row) {
    if (row < 0 || row >= static_cast<int>(m_visibleNodes.size())) return;

    TreeNode *node = m_visibleNodes[row];
    if (!node || !node->isFolder) return;

    if (node->isExpanded) {
        // Collapse: remove all currently visible descendants
        std::vector<TreeNode*> descendants;
        collectVisibleDescendants(node, descendants);
        int removeCount = static_cast<int>(descendants.size());

        if (removeCount > 0) {
            beginRemoveRows(QModelIndex(), row + 1, row + removeCount);
            m_visibleNodes.erase(m_visibleNodes.begin() + row + 1, m_visibleNodes.begin() + row + 1 + removeCount);
            node->isExpanded = false;
            endRemoveRows();
        } else {
            node->isExpanded = false;
        }
        emit dataChanged(createIndex(row, 0), createIndex(row, 0), {ExpandedRole});
        emit countChanged();
    } else {
        // Expand: insert all visible descendants
        node->isExpanded = true;
        std::vector<TreeNode*> descendants;
        collectVisibleDescendants(node, descendants);
        int insertCount = static_cast<int>(descendants.size());

        if (insertCount > 0) {
            beginInsertRows(QModelIndex(), row + 1, row + insertCount);
            m_visibleNodes.insert(m_visibleNodes.begin() + row + 1, descendants.begin(), descendants.end());
            endInsertRows();
        }
        emit dataChanged(createIndex(row, 0), createIndex(row, 0), {ExpandedRole});
        emit countChanged();
    }
}

void ArchiveTreeModel::expandAll() {
    beginResetModel();
    std::function<void(TreeNode*)> setExp = [&](TreeNode *n) {
        if (!n) return;
        n->isExpanded = true;
        for (const auto &c : n->children) setExp(c.get());
    };
    setExp(m_rootNode.get());
    m_visibleNodes.clear();
    flattenVisibleTree(m_rootNode.get());
    endResetModel();
    emit countChanged();
}

void ArchiveTreeModel::collapseAll() {
    beginResetModel();
    std::function<void(TreeNode*)> setCol = [&](TreeNode *n) {
        if (!n) return;
        if (n != m_rootNode.get()) n->isExpanded = false;
        for (const auto &c : n->children) setCol(c.get());
    };
    setCol(m_rootNode.get());
    m_visibleNodes.clear();
    flattenVisibleTree(m_rootNode.get());
    endResetModel();
    emit countChanged();
}

bool ArchiveTreeModel::isFolderDescendant(const QString &parentName, const QString &targetName) const {
    if (!m_rootNode || parentName.isEmpty() || targetName.isEmpty() || parentName == targetName) {
        return false;
    }

    // Direct path check if full paths are passed
    if (parentName.startsWith(u'/') && targetName.startsWith(u'/')) {
        QString p = parentName.endsWith(u'/') ? parentName : (parentName + u'/');
        QString t = targetName.endsWith(u'/') ? targetName : (targetName + u'/');
        return t.startsWith(p);
    }

    std::function<const TreeNode*(const TreeNode*, const QString&)> findNode =
        [&](const TreeNode *curr, const QString &name) -> const TreeNode* {
            if (!curr) return nullptr;
            if (curr->name == name || curr->fullPath == name) return curr;
            for (const auto &child : curr->children) {
                if (const TreeNode *res = findNode(child.get(), name)) return res;
            }
            return nullptr;
        };

    const TreeNode *targetNode = findNode(m_rootNode.get(), targetName);
    if (!targetNode) return false;

    const TreeNode *p = targetNode->parent;
    while (p && p != m_rootNode.get()) {
        if (p->name == parentName || p->fullPath == parentName) return true;
        p = p->parent;
    }
    return false;
}

QVariantMap ArchiveTreeModel::getNodeData(int row) const {
    if (row < 0 || row >= static_cast<int>(m_visibleNodes.size())) {
        return {};
    }
    const TreeNode *node = m_visibleNodes[row];
    QVariantMap map;
    map[QStringLiteral("name")] = node->name;
    map[QStringLiteral("filePath")] = node->fullPath;
    map[QStringLiteral("isFolder")] = node->isFolder;
    map[QStringLiteral("depth")] = node->depth;
    map[QStringLiteral("expanded")] = node->isExpanded;
    map[QStringLiteral("hasChildren")] = node->hasChildren();
    map[QStringLiteral("pending")] = node->isPending;
    map[QStringLiteral("parentFolderName")] = node->parentName;

    if (node->isPending) {
        map[QStringLiteral("compressedSize")] = QStringLiteral("Staged");
        map[QStringLiteral("realSize")] = node->isFolder ? QStringLiteral("-") : formatSize(node->realSize);
        map[QStringLiteral("ratio")] = QStringLiteral("Pending");
    } else if (node->isFolder) {
        map[QStringLiteral("compressedSize")] = QStringLiteral("-");
        map[QStringLiteral("realSize")] = QStringLiteral("-");
        map[QStringLiteral("ratio")] = QStringLiteral("-");
    } else {
        map[QStringLiteral("compressedSize")] = formatSize(node->compressedSize);
        map[QStringLiteral("realSize")] = formatSize(node->realSize);
        if (node->realSize > 0) {
            if (node->compressedSize >= node->realSize) {
                map[QStringLiteral("ratio")] = QStringLiteral("0%");
            } else {
                double savings = (1.0 - (static_cast<double>(node->compressedSize) / static_cast<double>(node->realSize))) * 100.0;
                map[QStringLiteral("ratio")] = QString::number(qRound(savings)) + QStringLiteral("%");
            }
        } else {
            map[QStringLiteral("ratio")] = QStringLiteral("-");
        }
    }

    map[QStringLiteral("crc")] = (node->isFolder || node->isPending) ? QStringLiteral("-") : QString::asprintf("0x%08X", node->crc32);
    map[QStringLiteral("keyStatus")] = node->isFolder ? QStringLiteral("") : (node->isPending ? QStringLiteral("unlocked") : (node->isUnlocked ? QStringLiteral("unlocked") : QStringLiteral("locked")));
    map[QStringLiteral("isUnlocked")] = (node->isFolder || node->isPending) ? true : node->isUnlocked;
    map[QStringLiteral("healthStatus")] = (node->isFolder || node->isPending) ? 0 : node->healthStatus;

    return map;
}

int ArchiveTreeModel::findRowByName(const QString &name) const {
    for (size_t i = 0; i < m_visibleNodes.size(); ++i) {
        if (m_visibleNodes[i]->name == name) {
            return static_cast<int>(i);
        }
    }
    return -1;
}

int ArchiveTreeModel::ensurePathVisible(const QString &archiveRelPath) {
    if (archiveRelPath.isEmpty()) return -1;
    QString normPath = archiveRelPath.trimmed();
    if (!normPath.startsWith(u'/')) normPath.prepend(u'/');

    TreeNode *targetNode = nullptr;
    auto it = m_nodeByPath.find(normPath);
    if (it != m_nodeByPath.end()) {
        targetNode = it->second;
    } else if (normPath.endsWith(u'/') && normPath.length() > 1) {
        auto it2 = m_nodeByPath.find(normPath.left(normPath.length() - 1));
        if (it2 != m_nodeByPath.end()) targetNode = it2->second;
    } else if (!normPath.endsWith(u'/')) {
        auto it2 = m_nodeByPath.find(normPath + u'/');
        if (it2 != m_nodeByPath.end()) targetNode = it2->second;
    }

    if (!targetNode || targetNode == m_rootNode.get()) return -1;

    bool neededExpansion = false;
    if (targetNode->isFolder && !targetNode->isExpanded) {
        targetNode->isExpanded = true;
        neededExpansion = true;
    }

    TreeNode *curr = targetNode->parent;
    while (curr && curr != m_rootNode.get()) {
        if (!curr->isExpanded) {
            curr->isExpanded = true;
            neededExpansion = true;
        }
        curr = curr->parent;
    }

    if (neededExpansion) {
        beginResetModel();
        m_visibleNodes.clear();
        flattenVisibleTree(m_rootNode.get());
        endResetModel();
        emit countChanged();
    }

    for (size_t i = 0; i < m_visibleNodes.size(); ++i) {
        if (m_visibleNodes[i] == targetNode) {
            return static_cast<int>(i);
        }
    }
    return -1;
}

void ArchiveTreeModel::updateLockStatus(const QHash<QString, bool> &statusMap) {
    if (statusMap.isEmpty()) return;

    std::function<void(TreeNode*)> updateNode = [&](TreeNode *node) {
        if (!node) return;
        if (!node->isFolder) {
            auto it = statusMap.find(node->fullPath);
            node->isUnlocked = (it != statusMap.end()) ? it.value() : false;
        }
        for (const auto &child : node->children) {
            updateNode(child.get());
        }
    };
    updateNode(m_rootNode.get());

    if (!m_visibleNodes.empty()) {
        emit dataChanged(createIndex(0, 0),
                         createIndex(static_cast<int>(m_visibleNodes.size()) - 1, 0),
                         {KeyStatusRole, IsUnlockedRole});
    }
}

void ArchiveTreeModel::updateLockStatus(const std::unordered_map<QString, bool> &statusMap) {
    if (statusMap.empty()) return;

    std::function<void(TreeNode*)> updateNode = [&](TreeNode *node) {
        if (!node) return;
        if (!node->isFolder) {
            auto it = statusMap.find(node->fullPath);
            node->isUnlocked = (it != statusMap.end()) ? it->second : false;
        }
        for (const auto &child : node->children) {
            updateNode(child.get());
        }
    };
    updateNode(m_rootNode.get());

    if (!m_visibleNodes.empty()) {
        emit dataChanged(createIndex(0, 0),
                         createIndex(static_cast<int>(m_visibleNodes.size()) - 1, 0),
                         {KeyStatusRole, IsUnlockedRole});
    }
}

bool ArchiveTreeModel::markItemCommitted(const QString &archiveRelPath, qulonglong compressedSize, quint32 crc32) {
    if (!m_rootNode) return false;

    QString normPath = archiveRelPath;
    normPath.replace(u'\\', u'/');
    if (!normPath.startsWith(u'/')) {
        normPath.prepend(u'/');
    }

    TreeNode *targetNode = nullptr;
    auto it = m_nodeByPath.find(normPath);
    if (it != m_nodeByPath.end()) {
        targetNode = it->second;
    } else {
        QString alt = normPath.endsWith(u'/') ? normPath.left(normPath.length() - 1) : (normPath + u'/');
        auto altIt = m_nodeByPath.find(alt);
        if (altIt != m_nodeByPath.end()) {
            targetNode = altIt->second;
        }
    }

    if (!targetNode) return false;

    if (targetNode->isPending) {
        targetNode->isPending = false;
        targetNode->compressedSize = compressedSize;
        if (crc32 != 0) {
            targetNode->crc32 = crc32;
        }
        targetNode->isUnlocked = true;
        m_totalCompressedSize += compressedSize;
    } else {
        if (crc32 != 0) {
            targetNode->crc32 = crc32;
        }
        if (compressedSize > 0) {
            targetNode->compressedSize = compressedSize;
        }
    }

    // Check parent folders: fast check on immediate children
    TreeNode *p = targetNode->parent;
    while (p && p != m_rootNode.get()) {
        bool anyPending = false;
        for (const auto &c : p->children) {
            if (c->isPending) {
                anyPending = true;
                break;
            }
        }
        if (!anyPending) {
            p->isPending = false;
        }
        p = p->parent;
    }

    // Find row in m_visibleNodes to emit dataChanged for target node
    for (size_t i = 0; i < m_visibleNodes.size(); ++i) {
        if (m_visibleNodes[i] == targetNode) {
            QModelIndex idx = createIndex(static_cast<int>(i), 0);
            emit dataChanged(idx, idx, {PendingRole, CompressedSizeRole, CrcRole, RatioRole, IsUnlockedRole, KeyStatusRole});
            break;
        }
    }

    return true;
}

bool ArchiveTreeModel::isPathOrDescendantsLocked(const QString &archiveRelPath) const {
    if (!m_rootNode) return false;

    QString normPath = archiveRelPath;
    normPath.replace(u'\\', u'/');
    if (!normPath.startsWith(u'/')) {
        normPath.prepend(u'/');
    }

    bool isRoot = (normPath == QStringLiteral("/") || archiveRelPath.trimmed().isEmpty());

    bool foundLocked = false;
    std::function<void(const TreeNode*)> checkLocked = [&](const TreeNode *node) {
        if (!node || foundLocked) return;

        if (!node->isFolder) {
            if (!node->isPending && !node->isUnlocked) {
                foundLocked = true;
                return;
            }
        }

        for (const auto &child : node->children) {
            checkLocked(child.get());
        }
    };

    if (isRoot) {
        checkLocked(m_rootNode.get());
        return foundLocked;
    }

    QString folderPrefix = normPath;
    if (!folderPrefix.endsWith(u'/')) {
        folderPrefix += u'/';
    }

    const TreeNode *targetNode = nullptr;
    std::function<void(const TreeNode*)> findNode = [&](const TreeNode *node) {
        if (!node || targetNode) return;
        if (node->fullPath == normPath || node->fullPath == folderPrefix) {
            targetNode = node;
            return;
        }
        for (const auto &child : node->children) {
            findNode(child.get());
        }
    };
    findNode(m_rootNode.get());

    if (targetNode) {
        checkLocked(targetNode);
    } else {
        std::function<void(const TreeNode*)> checkPrefix = [&](const TreeNode *node) {
            if (!node || foundLocked) return;
            if (!node->isFolder && (node->fullPath.startsWith(folderPrefix) || node->fullPath == normPath)) {
                if (!node->isPending && !node->isUnlocked) {
                    foundLocked = true;
                    return;
                }
            }
            for (const auto &child : node->children) {
                checkPrefix(child.get());
            }
        };
        checkPrefix(m_rootNode.get());
    }

    return foundLocked;
}

void ArchiveTreeModel::setFileHealthStatus(const QString &filePath, int status) {
    QString normPath = filePath;
    normPath.replace(u'\\', u'/');
    if (!normPath.startsWith(u'/')) {
        normPath.prepend(u'/');
    }

    m_healthStatusByPath[normPath] = status;

    TreeNode *targetNode = nullptr;
    auto it = m_nodeByPath.find(normPath);
    if (it != m_nodeByPath.end()) {
        targetNode = it->second;
    }

    if (targetNode) {
        targetNode->healthStatus = status;
        for (size_t i = 0; i < m_visibleNodes.size(); ++i) {
            if (m_visibleNodes[i] == targetNode) {
                QModelIndex idx = createIndex(static_cast<int>(i), 0);
                emit dataChanged(idx, idx, {HealthStatusRole});
                break;
            }
        }
    }
}

int ArchiveTreeModel::getFileHealthStatus(const QString &filePath) const {
    QString normPath = filePath;
    normPath.replace(u'\\', u'/');
    if (!normPath.startsWith(u'/')) {
        normPath.prepend(u'/');
    }
    auto it = m_healthStatusByPath.find(normPath);
    if (it != m_healthStatusByPath.end()) {
        return it->second;
    }
    return 0;
}

void ArchiveTreeModel::calculateCumulativeFolderSizes(TreeNode *node) {
    if (!node) return;
    if (node->isFolder) {
        node->realSize = 0;
        node->compressedSize = 0;
    }
    for (const auto &child : node->children) {
        calculateCumulativeFolderSizes(child.get());
        if (node->isFolder) {
            node->realSize += child->realSize;
            node->compressedSize += child->compressedSize;
        }
    }
}

QVariantMap ArchiveTreeModel::getSunburstData(const QString &folderPath) const {
    QVariantMap result;
    if (!m_rootNode) {
        return result;
    }

    static const QStringList kPalette = {
        QStringLiteral("#D4AF37"), // SecDet Gold Primary
        QStringLiteral("#00D2FF"), // Electric Cyan
        QStringLiteral("#10B981"), // Tech Emerald
        QStringLiteral("#8B5CF6"), // Electric Violet
        QStringLiteral("#F59E0B"), // Imperial Amber
        QStringLiteral("#F43F5E"), // Rose Neon
        QStringLiteral("#38BDF8"), // Sky Blue
        QStringLiteral("#EC4899"), // Neon Pink
        QStringLiteral("#14B8A6"), // Teal
        QStringLiteral("#A855F7")  // Purple
    };

    QString normPath = folderPath.trimmed();
    if (normPath.isEmpty()) {
        normPath = QStringLiteral("/");
    }

    TreeNode *activeNode = nullptr;
    auto it = m_nodeByPath.find(normPath);
    if (it != m_nodeByPath.end()) {
        activeNode = it->second;
    } else {
        if (normPath.endsWith(u'/') && normPath.length() > 1) {
            auto it2 = m_nodeByPath.find(normPath.left(normPath.length() - 1));
            if (it2 != m_nodeByPath.end()) activeNode = it2->second;
        } else if (!normPath.endsWith(u'/')) {
            auto it2 = m_nodeByPath.find(normPath + u'/');
            if (it2 != m_nodeByPath.end()) activeNode = it2->second;
        }
    }
    if (!activeNode) {
        activeNode = m_rootNode.get();
    }

    // Breadcrumbs
    QVariantList breadcrumbs;
    TreeNode *curr = activeNode;
    std::vector<TreeNode*> chain;
    while (curr) {
        chain.push_back(curr);
        curr = curr->parent;
    }
    std::reverse(chain.begin(), chain.end());
    for (TreeNode *n : chain) {
        QVariantMap b;
        b[QStringLiteral("name")] = (n == m_rootNode.get() || n->fullPath == QStringLiteral("/")) ? QStringLiteral("Root") : n->name;
        b[QStringLiteral("path")] = n->fullPath;
        breadcrumbs.append(b);
    }
    result[QStringLiteral("breadcrumbs")] = breadcrumbs;

    // Subtree file/folder count
    int subFileCount = 0;
    int subFolderCount = 0;
    std::function<void(TreeNode*)> countSubtree = [&](TreeNode *n) {
        for (const auto &ch : n->children) {
            if (ch->isFolder) {
                subFolderCount++;
            } else {
                subFileCount++;
            }
            countSubtree(ch.get());
        }
    };
    countSubtree(activeNode);

    qulonglong totalSize = activeNode->realSize;
    qulonglong totalComp = activeNode->compressedSize;
    double hubSavings = 0.0;
    if (totalSize > 0 && totalComp < totalSize) {
        hubSavings = (1.0 - (static_cast<double>(totalComp) / static_cast<double>(totalSize))) * 100.0;
    }

    QVariantMap hub;
    hub[QStringLiteral("name")] = (activeNode == m_rootNode.get() || activeNode->fullPath == QStringLiteral("/")) ? QStringLiteral("Root Archive") : activeNode->name;
    hub[QStringLiteral("path")] = activeNode->fullPath;
    hub[QStringLiteral("isFolder")] = activeNode->isFolder;
    hub[QStringLiteral("parentPath")] = activeNode->parent ? activeNode->parent->fullPath : QStringLiteral("");
    hub[QStringLiteral("realSize")] = static_cast<qulonglong>(totalSize);
    hub[QStringLiteral("compressedSize")] = static_cast<qulonglong>(totalComp);
    hub[QStringLiteral("formattedSize")] = formatSize(totalSize);
    hub[QStringLiteral("formattedCompSize")] = formatSize(totalComp);
    hub[QStringLiteral("savings")] = hubSavings;
    hub[QStringLiteral("fileCount")] = subFileCount;
    hub[QStringLiteral("folderCount")] = subFolderCount;
    result[QStringLiteral("hub")] = hub;

    if (activeNode->children.empty()) {
        result[QStringLiteral("ring1")] = QVariantList();
        result[QStringLiteral("ring2")] = QVariantList();
        result[QStringLiteral("hasChildren")] = false;
        return result;
    }

    // Sort active node children descending by realSize
    std::vector<TreeNode*> r1Children;
    r1Children.reserve(activeNode->children.size());
    for (const auto &ch : activeNode->children) {
        r1Children.push_back(ch.get());
    }
    std::sort(r1Children.begin(), r1Children.end(), [](TreeNode *a, TreeNode *b) {
        if (a->realSize != b->realSize) return a->realSize > b->realSize;
        return a->name < b->name;
    });

    // Ring 1 angle distribution with min sweep threshold (2.5 degrees)
    const double kMinSweep = 2.5;
    qulonglong otherSize = 0;
    qulonglong otherComp = 0;
    int otherCount = 0;
    std::vector<TreeNode*> dedicatedR1;

    for (TreeNode *ch : r1Children) {
        double rawSweep = totalSize > 0 ? (static_cast<double>(ch->realSize) / static_cast<double>(totalSize)) * 360.0 : (360.0 / r1Children.size());
        if (rawSweep >= kMinSweep || r1Children.size() <= 8) {
            dedicatedR1.push_back(ch);
        } else {
            otherSize += ch->realSize;
            otherComp += ch->compressedSize;
            otherCount++;
        }
    }

    QVariantList ring1List;
    QVariantList ring2List;
    double currentAngle = 0.0;
    int colorIdx = 0;

    for (size_t i = 0; i < dedicatedR1.size(); ++i) {
        TreeNode *ch = dedicatedR1[i];
        double sweep = totalSize > 0 ? (static_cast<double>(ch->realSize) / static_cast<double>(totalSize)) * 360.0 : (360.0 / (dedicatedR1.size() + (otherCount > 0 ? 1 : 0)));
        if (sweep < 0.1) sweep = 0.1;

        double startA = currentAngle;
        double endA = currentAngle + sweep;
        currentAngle = endA;

        QString itemColor = kPalette[colorIdx % kPalette.size()];
        colorIdx++;

        double itemRatio = 0.0;
        if (ch->realSize > 0 && ch->compressedSize < ch->realSize) {
            itemRatio = (1.0 - (static_cast<double>(ch->compressedSize) / static_cast<double>(ch->realSize))) * 100.0;
        }

        // Subtree count
        int chFiles = 0;
        int chFolders = 0;
        if (ch->isFolder) {
            std::function<void(TreeNode*)> subCount = [&](TreeNode *n) {
                for (const auto &c : n->children) {
                    if (c->isFolder) chFolders++;
                    else chFiles++;
                    subCount(c.get());
                }
            };
            subCount(ch);
        }

        QVariantMap r1Item;
        r1Item[QStringLiteral("name")] = ch->name;
        r1Item[QStringLiteral("path")] = ch->fullPath;
        r1Item[QStringLiteral("isFolder")] = ch->isFolder;
        r1Item[QStringLiteral("realSize")] = static_cast<qulonglong>(ch->realSize);
        r1Item[QStringLiteral("compressedSize")] = static_cast<qulonglong>(ch->compressedSize);
        r1Item[QStringLiteral("formattedSize")] = formatSize(ch->realSize);
        r1Item[QStringLiteral("formattedCompSize")] = formatSize(ch->compressedSize);
        r1Item[QStringLiteral("savings")] = itemRatio;
        r1Item[QStringLiteral("sharePercent")] = totalSize > 0 ? (static_cast<double>(ch->realSize) / static_cast<double>(totalSize)) * 100.0 : (100.0 / r1Children.size());
        r1Item[QStringLiteral("crc32")] = ch->isFolder ? QStringLiteral("N/A") : QString::asprintf("0x%08X", ch->crc32);
        r1Item[QStringLiteral("fileCount")] = ch->isFolder ? chFiles : 1;
        r1Item[QStringLiteral("folderCount")] = chFolders;
        r1Item[QStringLiteral("startAngle")] = startA;
        r1Item[QStringLiteral("endAngle")] = endA;
        r1Item[QStringLiteral("sweepAngle")] = sweep;
        r1Item[QStringLiteral("color")] = itemColor;
        r1Item[QStringLiteral("isOther")] = false;
        ring1List.append(r1Item);

        // Ring 2: Children of this Ring 1 folder
        if (ch->isFolder && !ch->children.empty()) {
            std::vector<TreeNode*> r2Children;
            r2Children.reserve(ch->children.size());
            for (const auto &gCh : ch->children) {
                r2Children.push_back(gCh.get());
            }
            std::sort(r2Children.begin(), r2Children.end(), [](TreeNode *a, TreeNode *b) {
                if (a->realSize != b->realSize) return a->realSize > b->realSize;
                return a->name < b->name;
            });

            qulonglong parentSize = ch->realSize;
            double parentSweep = sweep;
            double r2CurrentAngle = startA;

            qulonglong r2OtherSize = 0;
            qulonglong r2OtherComp = 0;
            int r2OtherCount = 0;
            std::vector<TreeNode*> dedicatedR2;

            for (TreeNode *gCh : r2Children) {
                double rawR2Sweep = parentSize > 0 ? (static_cast<double>(gCh->realSize) / static_cast<double>(parentSize)) * parentSweep : (parentSweep / r2Children.size());
                if (rawR2Sweep >= kMinSweep || r2Children.size() <= 4) {
                    dedicatedR2.push_back(gCh);
                } else {
                    r2OtherSize += gCh->realSize;
                    r2OtherComp += gCh->compressedSize;
                    r2OtherCount++;
                }
            }

            QColor baseCol(itemColor);
            for (size_t k = 0; k < dedicatedR2.size(); ++k) {
                TreeNode *gCh = dedicatedR2[k];
                double gSweep = parentSize > 0 ? (static_cast<double>(gCh->realSize) / static_cast<double>(parentSize)) * parentSweep : (parentSweep / (dedicatedR2.size() + (r2OtherCount > 0 ? 1 : 0)));
                if (gSweep < 0.1) gSweep = 0.1;

                double gStart = r2CurrentAngle;
                double gEnd = r2CurrentAngle + gSweep;
                r2CurrentAngle = gEnd;

                // Create lighter / harmonizing tint from parent color
                QColor gColor = baseCol.lighter(108 + (k % 4) * 12);

                double gRatio = 0.0;
                if (gCh->realSize > 0 && gCh->compressedSize < gCh->realSize) {
                    gRatio = (1.0 - (static_cast<double>(gCh->compressedSize) / static_cast<double>(gCh->realSize))) * 100.0;
                }

                QVariantMap r2Item;
                r2Item[QStringLiteral("name")] = gCh->name;
                r2Item[QStringLiteral("path")] = gCh->fullPath;
                r2Item[QStringLiteral("isFolder")] = gCh->isFolder;
                r2Item[QStringLiteral("realSize")] = static_cast<qulonglong>(gCh->realSize);
                r2Item[QStringLiteral("compressedSize")] = static_cast<qulonglong>(gCh->compressedSize);
                r2Item[QStringLiteral("formattedSize")] = formatSize(gCh->realSize);
                r2Item[QStringLiteral("formattedCompSize")] = formatSize(gCh->compressedSize);
                r2Item[QStringLiteral("savings")] = gRatio;
                r2Item[QStringLiteral("sharePercent")] = totalSize > 0 ? (static_cast<double>(gCh->realSize) / static_cast<double>(totalSize)) * 100.0 : 0.0;
                r2Item[QStringLiteral("crc32")] = gCh->isFolder ? QStringLiteral("N/A") : QString::asprintf("0x%08X", gCh->crc32);
                r2Item[QStringLiteral("startAngle")] = gStart;
                r2Item[QStringLiteral("endAngle")] = gEnd;
                r2Item[QStringLiteral("sweepAngle")] = gSweep;
                r2Item[QStringLiteral("color")] = gColor.name();
                r2Item[QStringLiteral("isOther")] = false;
                ring2List.append(r2Item);
            }

            if (r2OtherCount > 0 && r2CurrentAngle < endA) {
                double gSweep = endA - r2CurrentAngle;
                QVariantMap r2Other;
                r2Other[QStringLiteral("name")] = QStringLiteral("Other (%1 items)").arg(r2OtherCount);
                r2Other[QStringLiteral("path")] = ch->fullPath + QStringLiteral(" [other]");
                r2Other[QStringLiteral("isFolder")] = false;
                r2Other[QStringLiteral("realSize")] = static_cast<qulonglong>(r2OtherSize);
                r2Other[QStringLiteral("compressedSize")] = static_cast<qulonglong>(r2OtherComp);
                r2Other[QStringLiteral("formattedSize")] = formatSize(r2OtherSize);
                r2Other[QStringLiteral("formattedCompSize")] = formatSize(r2OtherComp);
                r2Other[QStringLiteral("savings")] = 0.0;
                r2Other[QStringLiteral("sharePercent")] = totalSize > 0 ? (static_cast<double>(r2OtherSize) / static_cast<double>(totalSize)) * 100.0 : 0.0;
                r2Other[QStringLiteral("crc32")] = QStringLiteral("N/A");
                r2Other[QStringLiteral("startAngle")] = r2CurrentAngle;
                r2Other[QStringLiteral("endAngle")] = endA;
                r2Other[QStringLiteral("sweepAngle")] = gSweep;
                r2Other[QStringLiteral("color")] = QStringLiteral("#64748B"); // Slate gray
                r2Other[QStringLiteral("isOther")] = true;
                ring2List.append(r2Other);
            }
        }
    }

    // Append Ring 1 "Other" sector if needed
    if (otherCount > 0 && currentAngle < 360.0) {
        double sweep = 360.0 - currentAngle;
        double startA = currentAngle;
        double endA = 360.0;

        double otherRatio = 0.0;
        if (otherSize > 0 && otherComp < otherSize) {
            otherRatio = (1.0 - (static_cast<double>(otherComp) / static_cast<double>(otherSize))) * 100.0;
        }

        QVariantMap r1Other;
        r1Other[QStringLiteral("name")] = QStringLiteral("Other (%1 items)").arg(otherCount);
        r1Other[QStringLiteral("path")] = activeNode->fullPath + (activeNode->fullPath.endsWith(u'/') ? QStringLiteral("") : QStringLiteral("/")) + QStringLiteral("[other]");
        r1Other[QStringLiteral("isFolder")] = false;
        r1Other[QStringLiteral("realSize")] = static_cast<qulonglong>(otherSize);
        r1Other[QStringLiteral("compressedSize")] = static_cast<qulonglong>(otherComp);
        r1Other[QStringLiteral("formattedSize")] = formatSize(otherSize);
        r1Other[QStringLiteral("formattedCompSize")] = formatSize(otherComp);
        r1Other[QStringLiteral("savings")] = otherRatio;
        r1Other[QStringLiteral("sharePercent")] = totalSize > 0 ? (static_cast<double>(otherSize) / static_cast<double>(totalSize)) * 100.0 : 0.0;
        r1Other[QStringLiteral("crc32")] = QStringLiteral("N/A");
        r1Other[QStringLiteral("fileCount")] = otherCount;
        r1Other[QStringLiteral("folderCount")] = 0;
        r1Other[QStringLiteral("startAngle")] = startA;
        r1Other[QStringLiteral("endAngle")] = endA;
        r1Other[QStringLiteral("sweepAngle")] = sweep;
        r1Other[QStringLiteral("color")] = QStringLiteral("#64748B"); // Slate gray
        r1Other[QStringLiteral("isOther")] = true;
        ring1List.append(r1Other);
    }

    result[QStringLiteral("ring1")] = ring1List;
    result[QStringLiteral("ring2")] = ring2List;
    result[QStringLiteral("hasChildren")] = true;
    return result;
}


