#pragma once

#include <QAbstractListModel>
#include <QString>
#include <QVariantMap>
#include <vector>
#include <memory>
#include <span>
#include <libsecdet/SeTOC.h>

class ArchiveTreeModel : public QAbstractListModel {
    Q_OBJECT

    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(int fileCount READ fileCount NOTIFY statsChanged)
    Q_PROPERTY(int folderCount READ folderCount NOTIFY statsChanged)
    Q_PROPERTY(qulonglong totalRealSize READ totalRealSize NOTIFY statsChanged)
    Q_PROPERTY(qulonglong totalCompressedSize READ totalCompressedSize NOTIFY statsChanged)

public:
    enum TreeRoles {
        NameRole = Qt::UserRole + 1,
        FilePathRole,
        IsFolderRole,
        DepthRole,
        ExpandedRole,
        HasChildrenRole,
        PendingRole,
        CompressedSizeRole,
        RealSizeRole,
        RatioRole,
        ParentNameRole,
        CrcRole,
        KeyStatusRole,
        IsUnlockedRole,
        HealthStatusRole
    };
    Q_ENUM(TreeRoles)

    struct PendingItem {
        QString localDiskPath;
        QString archiveRelPath;
        QString name;
        bool isDirectory = false;
        qulonglong size = 0;
    };

    struct StagedMoveItem {
        QString srcPath;
        QString dstDirPath;
        bool isDirectory = false;
    };

    struct TreeNode {
        QString name;
        QString fullPath;
        QString parentName;
        bool isFolder = false;
        bool isPending = false;
        bool isExpanded = false;
        int depth = 0;
        qulonglong realSize = 0;
        qulonglong compressedSize = 0;
        quint32 crc32 = 0;
        bool isUnlocked = false;
        int healthStatus = 0; // 0: untested, 1: ok, 2: failed

        TreeNode *parent = nullptr;
        std::vector<std::unique_ptr<TreeNode>> children;

        [[nodiscard]] bool hasChildren() const { return !children.empty(); }
    };

    explicit ArchiveTreeModel(QObject *parent = nullptr);
    ~ArchiveTreeModel() override = default;

    [[nodiscard]] int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    [[nodiscard]] QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    [[nodiscard]] QHash<int, QByteArray> roleNames() const override;

    [[nodiscard]] int count() const { return static_cast<int>(m_visibleNodes.size()); }
    [[nodiscard]] int fileCount() const { return m_fileCount; }
    [[nodiscard]] int folderCount() const { return m_folderCount; }
    [[nodiscard]] qulonglong totalRealSize() const { return m_totalRealSize; }
    [[nodiscard]] qulonglong totalCompressedSize() const { return m_totalCompressedSize; }

    void buildTree(std::span<const SeArchiveEntry> entries,
                   const std::vector<PendingItem> &pendingItems,
                   const std::vector<StagedMoveItem> &moveItems,
                   const std::vector<QString> &removePaths,
                   const QString &archiveName);
    void buildTree(std::span<const SeArchiveEntry> entries,
                   const std::vector<PendingItem> &pendingItems,
                   const std::vector<StagedMoveItem> &moveItems,
                   const QString &archiveName) {
        buildTree(entries, pendingItems, moveItems, {}, archiveName);
    }
    void buildTree(std::span<const SeArchiveEntry> entries,
                   const std::vector<PendingItem> &pendingItems,
                   const QString &archiveName) {
        buildTree(entries, pendingItems, {}, {}, archiveName);
    }
    void clear();

    // QML Invocable methods
    Q_INVOKABLE void toggleExpand(int row);
    Q_INVOKABLE void expandAll();
    Q_INVOKABLE void collapseAll();
    Q_INVOKABLE bool isFolderDescendant(const QString &parentName, const QString &targetName) const;
    Q_INVOKABLE QVariantMap getNodeData(int row) const;
    Q_INVOKABLE int findRowByName(const QString &name) const;
    Q_INVOKABLE int ensurePathVisible(const QString &archiveRelPath);
    Q_INVOKABLE void updateLockStatus(const QHash<QString, bool> &statusMap);
    void updateLockStatus(const std::unordered_map<QString, bool> &statusMap);
    Q_INVOKABLE bool isPathOrDescendantsLocked(const QString &archiveRelPath) const;
    bool markItemCommitted(const QString &archiveRelPath, qulonglong compressedSize, quint32 crc32);
    Q_INVOKABLE void setFileHealthStatus(const QString &filePath, int status);
    Q_INVOKABLE int getFileHealthStatus(const QString &filePath) const;
    Q_INVOKABLE QVariantMap getSunburstData(const QString &folderPath = QStringLiteral("/")) const;

signals:
    void countChanged();
    void statsChanged();

private:
    void calculateCumulativeFolderSizes(TreeNode *node);
    void flattenVisibleTree(TreeNode *node);
    void collectVisibleDescendants(TreeNode *node, std::vector<TreeNode*> &outList);
    static QString formatSize(qulonglong bytes);

    std::unique_ptr<TreeNode> m_rootNode;
    std::vector<TreeNode*> m_visibleNodes;
    std::unordered_map<QString, TreeNode*> m_nodeByPath;
    std::unordered_map<QString, int> m_healthStatusByPath;

    int m_fileCount = 0;
    int m_folderCount = 0;
    qulonglong m_totalRealSize = 0;
    qulonglong m_totalCompressedSize = 0;
};
