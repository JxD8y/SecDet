import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import QtQuick.Dialogs
import UI

Window {
    id: window
    width: 1040
    height: 800
    minimumWidth: 720
    minimumHeight: 680
    visible: true
    title: (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.hasArchive) ? ("SecDet - " + archiveInterface.archiveFileName) : "SecDet - No Archive is open"
    color: Colors.bgMain

    onClosing: function (close) {
        if (window.forceClose) {
            close.accepted = true;
            return;
        }
        close.accepted = false;
        window.handleWindowCloseRequest();
    }

    FontLoader {
        id: materialIcons
        source: "Fonts/MaterialIconsRound-Regular.otf"
    }

    component IslandButton: Item {
        id: iconBtn
        property string iconText: ""
        property string labelText: ""
        property color accentColor: Colors.goldPrimary
        property bool highlighted: false
        property bool activeState: false
        property color activeBgColor: "transparent"
        property color activeBorderColor: "transparent"
        property bool showIndicatorDot: false
        property color indicatorColor: Colors.indicatorGreen
        signal clicked

        implicitWidth: 62
        implicitHeight: 50
        opacity: enabled ? 1.0 : 0.38

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }

        Rectangle {
            id: hoverBg
            anchors.fill: parent
            radius: 8
            color: !iconBtn.enabled ? "transparent" : mouseArea.containsPress ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.08)) : mouseArea.containsMouse ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.04)) : iconBtn.activeState ? iconBtn.activeBgColor : iconBtn.highlighted ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.04)) : "transparent"

            border.color: (!iconBtn.enabled) ? "transparent" : iconBtn.activeState ? iconBtn.activeBorderColor : (mouseArea.containsMouse || iconBtn.highlighted) ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.10)) : "transparent"
            border.width: iconBtn.activeState ? 1.5 : 1

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
            Behavior on border.color {
                ColorAnimation {
                    duration: 150
                }
            }
        }

        ColumnLayout {
            id: btnCol
            anchors.centerIn: parent
            spacing: 3

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: iconBtn.iconText
                font.family: materialIcons.name
                font.pixelSize: 24
                color: (!iconBtn.enabled) ? Colors.textMuted : mouseArea.containsMouse ? (iconBtn.accentColor === Colors.textMuted ? Colors.textMain : iconBtn.accentColor) : iconBtn.accentColor

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: iconBtn.labelText
                font.family: Colors.fontFamily
                font.pixelSize: 11
                font.weight: iconBtn.activeState ? Font.DemiBold : Font.Medium
                color: (!iconBtn.enabled) ? Colors.textMuted : iconBtn.activeState ? iconBtn.accentColor : mouseArea.containsMouse ? Colors.textMain : Colors.textMuted

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }
        }

        // active indicator dot
        Rectangle {
            visible: iconBtn.showIndicatorDot
            width: 7
            height: 7
            radius: 3.5
            color: iconBtn.indicatorColor
            anchors.top: parent.top
            anchors.topMargin: 5
            anchors.right: parent.right
            anchors.rightMargin: 6

            Rectangle {
                anchors.centerIn: parent
                width: 13
                height: 13
                radius: 6.5
                color: "transparent"
                border.color: iconBtn.indicatorColor
                border.width: 1
                opacity: 0.6
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            enabled: iconBtn.enabled
            hoverEnabled: iconBtn.enabled
            cursorShape: iconBtn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (iconBtn.enabled) {
                    iconBtn.clicked();
                }
            }
            scale: containsPress ? 0.95 : 1.0
            Behavior on scale {
                NumberAnimation {
                    duration: 100
                }
            }
        }
    }

    component ThemeToggle: Rectangle {
        id: themeToggleRoot
        implicitWidth: 72
        implicitHeight: 32
        radius: 16
        color: Colors.bgElevated
        border.color: themeToggleMouse.containsMouse ? Colors.goldBorderHi : Colors.goldBorder
        border.width: 1

        Behavior on color {
            ColorAnimation {
                duration: 200
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: 200
            }
        }

        Rectangle {
            id: togglePill
            width: 30
            height: 26
            radius: 13
            anchors.verticalCenter: parent.verticalCenter
            x: Colors.isDarkMode ? parent.width - width - 3 : 3
            color: Colors.isDarkMode ? Colors.bgSurface : Colors.goldPrimary
            border.color: Colors.goldBorderHi
            border.width: 1

            Behavior on x {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 200
                }
            }

            // Active Icon inside pill
            Text {
                anchors.centerIn: parent
                text: Colors.isDarkMode ? "nightlight" : "\ue518"
                font.family: materialIcons.name
                font.pixelSize: 14
                color: Colors.isDarkMode ? Colors.goldPrimary : Colors.textOnGold

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 0

            Text {
                text: "\ue518" // sun
                font.family: materialIcons.name
                font.pixelSize: 13
                color: !Colors.isDarkMode ? Colors.textOnGold : Colors.textMuted
                opacity: Colors.isDarkMode ? 0.6 : 0.0
                Layout.alignment: Qt.AlignVCenter
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: "nightlight" // moon
                font.family: materialIcons.name
                font.pixelSize: 13
                color: Colors.isDarkMode ? Colors.goldPrimary : Colors.textMuted
                opacity: !Colors.isDarkMode ? 0.6 : 0.0
                Layout.alignment: Qt.AlignVCenter
            }
        }

        MouseArea {
            id: themeToggleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Colors.toggleTheme()
            scale: containsPress ? 0.95 : 1.0
            Behavior on scale {
                NumberAnimation {
                    duration: 100
                }
            }
        }
    }

    // ── Drag State Machine ──────────────────────────────────────────────────
    // External drag:  drag outside window → async extraction → OS QDrag::exec()
    // Internal drag:  drag inside window  → DropArea → moveArchiveItem job

    signal pendingFilesAdded(var pendingEvent)
    signal pendingCommitted(var commitEvent)
    signal itemMoved(var moveEvent)

    property var lastTreeAction: null

    // ── File Tree Drag State ──────────────────────────────────────────────────
    property bool isTreeDragActive: false
    property var draggedTreeItem: null
    property string dragTargetDir: ""
    property string dragTargetName: ""
    property string dragOverlayText: ""
    property bool dragOverlayValid: false
    property real dragOverlayX: 0
    property real dragOverlayY: 0


    // Status Objects
    QtObject {
        id: statusText
        property string text: (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.hasArchive) ? ("Ready • " + archiveInterface.archiveFileName + " loaded") : "Ready • No archive loaded"
    }

    QtObject {
        id: pBar
        property real value: 0.0
    }

    readonly property bool hasArchive: typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.hasArchive
    property var archiveTreeData: []
    property var selectedTreeItem: null
    property var selectedItemMap: ({})
    property int selectedCount: 0

    readonly property int colCompressedWidth: 95
    readonly property int colRealWidth: 95
    readonly property int colRatioWidth: 60
    readonly property int colCrcWidth: 95

    property string mainTreeFindQuery: ""

    Shortcut {
        sequence: "Ctrl+F"
        enabled: (!recoveryPageLoader.visible) && (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.hasArchive)
        onActivated: {
            if (treeFindBar) {
                treeFindBar.openFind();
            }
        }
    }

    function isItemSelected(itemPathOrName) {
        if (!itemPathOrName)
            return false;
        return selectedItemMap[itemPathOrName] !== undefined;
    }

    function selectItem(itemData, isCtrl) {
        if (!itemData)
            return;
        let key = itemData.filePath || itemData.path || itemData.name;
        if (!key)
            return;

        let map = isCtrl ? Object.assign({}, selectedItemMap) : {};
        if (isCtrl && map[key] !== undefined) {
            delete map[key];
            let keys = Object.keys(map);
            selectedTreeItem = (keys.length > 0) ? map[keys[keys.length - 1]] : null;
        } else {
            map[key] = itemData;
            selectedTreeItem = itemData;
        }
        selectedItemMap = map;
        selectedCount = Object.keys(map).length;
        if (selectedCount > 1) {
            statusText.text = selectedCount + " items selected";
        } else if (selectedCount === 1) {
            statusText.text = "Selected: " + (selectedTreeItem ? selectedTreeItem.name : key);
        } else {
            statusText.text = "Ready";
        }

        // File map sync
        if (infoPageLoader.visible && infoPageLoader.item && !window.isSyncingFromInfoPage) {
            let itemPath = itemData.filePath || itemData.path || ("/" + itemData.name);
            let isFolder = Boolean(itemData.isFolder);
            infoPageLoader.item.navigateToItem(itemPath, isFolder);
        }
    }

    property bool isSyncingFromInfoPage: false

    function navigateToFileTreePath(targetPath) {
        if (!targetPath || typeof archiveInterface === "undefined" || !archiveInterface || !archiveInterface.treeModel)
            return;
        isSyncingFromInfoPage = true;
        if (targetPath === "/" || targetPath === "") {
            window.clearSelection();
            mainTreeListView.positionViewAtBeginning();
            isSyncingFromInfoPage = false;
            return;
        }
        let row = archiveInterface.treeModel.ensurePathVisible(targetPath);
        if (row >= 0) {
            let nodeData = archiveInterface.treeModel.getNodeData(row);
            window.selectItem(nodeData, false);
            mainTreeListView.positionViewAtIndex(row, ListView.Center);
        }
        isSyncingFromInfoPage = false;
    }

    function clearSelection() {
        if (selectedCount > 0 || selectedTreeItem !== null) {
            selectedItemMap = ({});
            selectedTreeItem = null;
            selectedCount = 0;
            statusText.text = "Ready";
        }
    }

    function getSelectedItemsList() {
        let list = [];
        for (let k in selectedItemMap) {
            if (selectedItemMap.hasOwnProperty(k)) {
                list.push(selectedItemMap[k]);
            }
        }
        return list;
    }

    // Tree Model Actions
    // Super memory inefficient !
    function addPendingItems(urls, targetFolder) {
        let targetDirPath = "/";
        let targetDisplayName = "root (/)";
        if (typeof targetFolder === "string") {
            targetDirPath = targetFolder;
            targetDisplayName = targetFolder;
        } else if (targetFolder && (targetFolder.path || targetFolder.filePath || targetFolder.name)) {
            targetDirPath = targetFolder.path || targetFolder.filePath || ("/" + targetFolder.name + "/");
            targetDisplayName = targetFolder.name || targetDirPath;
        }
        if (!targetDirPath.startsWith("/"))
            targetDirPath = "/" + targetDirPath;
        if (!targetDirPath.endsWith("/"))
            targetDirPath = targetDirPath + "/";

        if (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.hasArchive) {
            let fileList = [];
            for (let i = 0; i < urls.length; ++i)
                fileList.push(urls[i].toString());
            window.ensureKeyRegistered(function () {
                archiveInterface.addFilesToArchive(fileList, targetDirPath);
            });
            return;
        }

        let newItems = [];
        for (let i = 0; i < urls.length; ++i) {
            let rawUrl = urls[i].toString();
            let fullPath = rawUrl;
            if (fullPath.startsWith("file:///")) {
                if (fullPath.length >= 10 && fullPath.charAt(9) === ':')
                    fullPath = fullPath.substring(8);
                else
                    fullPath = fullPath.substring(7);
            } else if (fullPath.startsWith("file://"))
                fullPath = fullPath.substring(7);
            fullPath = decodeURIComponent(fullPath);
            let name = fullPath.split("/").pop().split("\\").pop();
            let isDir = !name.includes(".");

            let itemObj = {
                name: name,
                filePath: fullPath,
                isFolder: isDir,
                expanded: false,
                pending: true,
                realSize: isDir ? "-" : "164 KB",
                compressedSize: "Staged",
                ratio: "Pending",
                children: isDir ? [
                    {
                        name: "child_preview.dat",
                        isFolder: false,
                        realSize: "64 KB",
                        compressedSize: "Staged",
                        ratio: "Pending",
                        pending: true
                    }
                ] : []
            };
            newItems.push(itemObj);
        }

        let cloned = JSON.parse(JSON.stringify(archiveTreeData));
        if (targetFolder && targetFolder.children) {
            function insertIntoTarget(nodes, targetName) {
                for (let k = 0; k < nodes.length; ++k) {
                    if (nodes[k].name === targetName && nodes[k].isFolder) {
                        nodes[k].children = (nodes[k].children || []).concat(newItems);
                        return true;
                    }
                    if (nodes[k].children && insertIntoTarget(nodes[k].children, targetName))
                        return true;
                }
                return false;
            }
            if (!insertIntoTarget(cloned, targetFolder.name)) {
                if (cloned.length > 0 && cloned[0].children)
                    cloned[0].children = cloned[0].children.concat(newItems);
                else
                    cloned = cloned.concat(newItems);
            }
        } else if (cloned.length > 0 && cloned[0].isFolder) {
            cloned[0].children = (cloned[0].children || []).concat(newItems);
        } else {
            cloned = cloned.concat(newItems);
        }
        archiveTreeData = cloned;

        let pendingEvt = {
            action: "ADD_PENDING_ITEMS",
            count: newItems.length,
            items: newItems,
            timestamp: new Date().toISOString()
        };
        lastTreeAction = pendingEvt;
        pendingFilesAdded(pendingEvt);
        statusText.text = "Added " + newItems.length + " pending item(s) to archive (Staged for commit)";
    }

    function commitPendingItem(nodeName) {
        if (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.hasArchive) {
            window.startCommitWorkflow();
            return;
        }

        let cloned = JSON.parse(JSON.stringify(archiveTreeData));
        let found = false;

        function commitRecursive(nodes) {
            for (let i = 0; i < nodes.length; ++i) {
                if (nodes[i].name === nodeName) {
                    nodes[i].pending = false;
                    nodes[i].compressedSize = "16 KB";
                    nodes[i].ratio = "42%";
                    if (nodes[i].children) {
                        for (let c = 0; c < nodes[i].children.length; ++c) {
                            nodes[i].children[c].pending = false;
                            nodes[i].children[c].compressedSize = "6 KB";
                            nodes[i].children[c].ratio = "38%";
                        }
                    }
                    found = true;
                    return true;
                }
                if (nodes[i].children && commitRecursive(nodes[i].children))
                    return true;
            }
            return false;
        }
        commitRecursive(cloned);
        if (found) {
            archiveTreeData = cloned;
            let commitEvent = {
                action: "COMMIT_PENDING",
                itemName: nodeName,
                timestamp: new Date().toISOString()
            };
            lastTreeAction = commitEvent;
            pendingCommitted(commitEvent);
            statusText.text = "Committed '" + nodeName + "' to archive";
        }
    }

    function removeTreeItem(itemPath, isFolder) {
        if (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.hasArchive) {
            archiveInterface.removeArchiveItem(itemPath, isFolder || false);
            return;
        }

        let cloned = JSON.parse(JSON.stringify(archiveTreeData));
        function removeRecursive(nodes) {
            for (let i = 0; i < nodes.length; ++i) {
                if (nodes[i].filePath === itemPath || nodes[i].name === itemPath) {
                    nodes.splice(i, 1);
                    return true;
                }
                if (nodes[i].children && removeRecursive(nodes[i].children))
                    return true;
            }
            return false;
        }
        if (removeRecursive(cloned)) {
            archiveTreeData = cloned;
            statusText.text = "Removed '" + itemPath + "' from archive";
        }
    }

    function executeMoveItem(itemData, srcParent, targetFolderName, targetFolderPath) {
        if (!itemData || !targetFolderName || targetFolderName === srcParent || itemData.name === targetFolderName) {
            return;
        }

        let targetDirPath = targetFolderPath || ("/" + targetFolderName + "/");
        if (!targetDirPath.startsWith("/"))
            targetDirPath = "/" + targetDirPath;
        if (!targetDirPath.endsWith("/"))
            targetDirPath = targetDirPath + "/";

        let sourcePath = itemData.filePath || ("/" + (srcParent ? srcParent + "/" : "") + itemData.name);
        if (!sourcePath.startsWith("/"))
            sourcePath = "/" + sourcePath;

        if (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.hasArchive) {
            archiveInterface.moveArchiveItem(sourcePath, targetDirPath, itemData.isFolder);
            return;
        }

        if (itemData.isFolder && isFolderDescendant(sourcePath, targetDirPath)) {
            statusText.text = "Cannot move folder '" + itemData.name + "' into its own subfolder";
            return;
        }

        let cloned = JSON.parse(JSON.stringify(archiveTreeData));
        let extractedItem = null;

        function removeTarget(nodes) {
            for (let i = 0; i < nodes.length; ++i) {
                if (nodes[i].name === itemData.name) {
                    extractedItem = nodes.splice(i, 1)[0];
                    return true;
                }
                if (nodes[i].children && removeTarget(nodes[i].children))
                    return true;
            }
            return false;
        }

        removeTarget(cloned);
        if (!extractedItem)
            return;

        let inserted = false;
        function insertTarget(nodes) {
            for (let i = 0; i < nodes.length; ++i) {
                if ((nodes[i].filePath === targetDirPath || nodes[i].name === targetFolderName) && nodes[i].isFolder) {
                    if (!nodes[i].children)
                        nodes[i].children = [];
                    extractedItem.filePath = targetDirPath + extractedItem.name + (extractedItem.isFolder ? "/" : "");
                    nodes[i].children.push(extractedItem);
                    nodes[i].expanded = true;
                    inserted = true;
                    return true;
                }
                if (nodes[i].children && insertTarget(nodes[i].children))
                    return true;
            }
            return false;
        }

        insertTarget(cloned);

        if (inserted) {
            archiveTreeData = cloned;

            let moveDetails = {
                action: "ITEM_MOVED",
                item: {
                    name: itemData.name,
                    isFolder: itemData.isFolder,
                    realSize: itemData.realSize,
                    compressedSize: itemData.compressedSize,
                    ratio: itemData.ratio
                },
                fromFolder: srcParent !== "" ? srcParent : "ROOT",
                toFolder: targetFolderName,
                sourcePath: sourcePath,
                destinationPath: targetDirPath + itemData.name,
                timestamp: new Date().toISOString()
            };

            lastTreeAction = moveDetails;
            itemMoved(moveDetails);
            console.log("[SecDet Clean Interface] Item Moved:", JSON.stringify(moveDetails, null, 2));
            statusText.text = "Moved '" + itemData.name + "' into folder '" + targetFolderName + "'";
        }
    }

    function isFolderDescendant(parentName, checkName) {
        if (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.treeModel) {
            return archiveInterface.treeModel.isFolderDescendant(parentName, checkName);
        }
        return false;
    }




    component ContextMenuItem: Rectangle {
        id: cmiRoot
        property string text: ""
        property string iconText: ""
        property color accentColor: Colors.textMain
        signal clicked

        Layout.fillWidth: true
        height: 28
        radius: 4
        color: cmiMouse.containsMouse ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05)) : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: 100
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 8

            Text {
                text: cmiRoot.iconText
                font.family: materialIcons.name
                font.pixelSize: 14
                color: cmiRoot.accentColor === Colors.textMain ? Colors.textMuted : cmiRoot.accentColor
            }

            Text {
                text: cmiRoot.text
                font.family: Colors.fontFamily
                font.pixelSize: 11
                font.weight: Font.Medium
                color: cmiRoot.accentColor
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: cmiMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cmiRoot.clicked()
        }
    }

    Popup {
        id: treeContextMenu
        width: 220
        padding: 6
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property var targetItem: null
        property string parentFolderName: ""
        property bool isTargetPending: false
        property bool isBlankArea: false

        background: Rectangle {
            color: Colors.bgElevated
            radius: 8
            border.color: Colors.goldBorderHi
            border.width: 1

            Rectangle {
                anchors.fill: parent
                anchors.margins: -1
                radius: 9
                color: "transparent"
                border.color: Colors.shadowColor
                border.width: 1
                z: -1
            }
        }

        contentItem: ColumnLayout {
            spacing: 2
            width: parent.width

            // Header indicating target
            Rectangle {
                Layout.fillWidth: true
                height: 24
                radius: 4
                color: Colors.bgHover
                visible: !treeContextMenu.isBlankArea

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6

                    Text {
                        text: treeContextMenu.targetItem && treeContextMenu.targetItem.isFolder ? "\ue2c8" : "\ue873"
                        font.family: materialIcons.name
                        font.pixelSize: 12
                        color: Colors.goldPrimary
                    }

                    Text {
                        text: treeContextMenu.targetItem ? treeContextMenu.targetItem.name : ""
                        font.family: Colors.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: Colors.textMain
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        visible: treeContextMenu.isTargetPending
                        width: 48
                        height: 14
                        radius: 3
                        color: Colors.goldLight
                        border.color: Colors.goldBorder
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "PENDING"
                            font.family: Colors.fontFamily
                            font.pixelSize: 8
                            font.weight: Font.Bold
                            color: Colors.goldPrimary
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.divider
                visible: !treeContextMenu.isBlankArea
            }

            // ACTION: Discard Pending (Only for Pending files, not folders)
            ContextMenuItem {
                text: "Discard / Remove Pending"
                iconText: "\ue5cd"
                accentColor: "#e05353"
                visible: treeContextMenu.isTargetPending && treeContextMenu.targetItem && !treeContextMenu.targetItem.isFolder
                onClicked: {
                    let target = treeContextMenu.targetItem;
                    treeContextMenu.close();
                    if (target) {
                        removeTreeItem(target.filePath || target.name, target.isFolder || false);
                    }
                }
            }

            // ACTION: Extract (Committed files or folders)
            ContextMenuItem {
                text: "Extract to Folder..."
                iconText: "unarchive"
                visible: !treeContextMenu.isBlankArea && !treeContextMenu.isTargetPending
                onClicked: {
                    let target = treeContextMenu.targetItem;
                    treeContextMenu.close();
                    window.ensureKeyRegistered(function () {
                        window.pendingExtractTarget = target;
                        extractFolderDialog.open();
                    });
                }
            }

            ContextMenuItem {
                text: "Test File"
                iconText: "\ue86c"
                visible: !treeContextMenu.isBlankArea && (!treeContextMenu.targetItem || !treeContextMenu.targetItem.isFolder) && !treeContextMenu.isTargetPending
                onClicked: {
                    let target = treeContextMenu.targetItem;
                    treeContextMenu.close();
                    if (target) {
                        launchTestFile(target);
                    }
                }
            }

            // ACTION: Add Files to Folder (Folders)
            ContextMenuItem {
                text: "Add Files to Folder..."
                iconText: "\ue145"
                visible: !treeContextMenu.isBlankArea && (treeContextMenu.targetItem && treeContextMenu.targetItem.isFolder)
                onClicked: {
                    let target = treeContextMenu.targetItem;
                    treeContextMenu.close();
                    window.pendingAddTargetFolder = target;
                    addFilesDialog.open();
                }
            }

            // ACTION: New Subfolder
            ContextMenuItem {
                text: "New Subfolder"
                iconText: "\ue2cc"
                visible: !treeContextMenu.isBlankArea && (treeContextMenu.targetItem && treeContextMenu.targetItem.isFolder)
                onClicked: {
                    treeContextMenu.close();
                    addPendingItems(["file:///New_Subfolder"], treeContextMenu.targetItem);
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.divider
                visible: !treeContextMenu.isBlankArea
            }

            // ACTION: Delete from Archive (Committed items)
            ContextMenuItem {
                text: "Delete from Archive"
                iconText: "\ue872"
                accentColor: "#e05353"
                visible: !treeContextMenu.isBlankArea && !treeContextMenu.isTargetPending
                onClicked: {
                    let target = treeContextMenu.targetItem;
                    treeContextMenu.close();
                    if (target) {
                        removeTreeItem(target.filePath || target.name, target.isFolder || false);
                    }
                }
            }

            // --- Blank Area Actions ---
            ContextMenuItem {
                text: "Add Files"
                iconText: "\ue145"
                visible: treeContextMenu.isBlankArea
                onClicked: {
                    treeContextMenu.close();
                    window.pendingAddTargetFolder = "/";
                    addFilesDialog.open();
                }
            }
        }
    }

    FileDialog {
        id: openArchiveDialog
        title: "Open SecDet"
        nameFilters: ["SecDet Archive (*.sda)", "All Files (*.*)"]
        onAccepted: {
            if (typeof archiveInterface !== "undefined" && archiveInterface) {
                let rawUrl = selectedFile.toString();
                let clean = rawUrl;
                if (clean.startsWith("file:///")) {
                    if (clean.length >= 10 && clean.charAt(9) === ':')
                        clean = clean.substring(8);
                    else
                        clean = clean.substring(7);
                } else if (clean.startsWith("file://")) {
                    clean = clean.substring(7);
                }
                clean = decodeURIComponent(clean);
                if (!clean.toLowerCase().endsWith(".sda")) {
                    let fiName = clean.split("/").pop().split("\\").pop();
                    errorDialog.showError("Invalid Archive File", "The file '" + fiName + "' is not a valid SecDet Archive (.sda).\nPlease select a file with the .sda extension.");
                    return;
                }
                window.lastLoadingArchivePath = clean;
                window.isUserLoadingArchive = true;
                archiveInterface.loadArchive(rawUrl);
            }
        }
    }

    property string lastLoadingArchivePath: ""
    property bool isUserLoadingArchive: false

    function openRecoveryWithFile(filePath) {
        if (!filePath || filePath.length === 0) return;
        if (infoPageLoader.visible) {
            infoPageLoader.visible = false;
        }
        recoveryPageLoader.visible = true;
        if (recoveryPageLoader.item) {
            recoveryPageLoader.item.loadArchive(filePath);
        } else {
            let conn = function () {
                recoveryPageLoader.loaded.disconnect(conn);
                if (recoveryPageLoader.item) {
                    recoveryPageLoader.item.loadArchive(filePath);
                }
            };
            recoveryPageLoader.loaded.connect(conn);
        }
    }

    property var pendingExtractTarget: null
    property bool pendingCloseAfterCommit: false
    property var pendingPostUnlockAction: null
    property var pendingAddTargetFolder: null

    property bool forceClose: false
    property bool pendingExitApp: false
    property bool pendingExitAfterOperationCancel: false
    property bool pendingExitAfterCommit: false

    function isOperationRunning() {
        if (typeof archiveInterface === "undefined" || !archiveInterface) {
            return false;
        }
        if (archiveInterface.isBusy || archiveInterface.isCommitting || archiveInterface.isOptimizing || archiveInterface.isLoadingArchive || archiveInterface.isAddingFiles) {
            return true;
        }
        if (typeof progressWindow !== "undefined" && progressWindow && progressWindow.visible && !progressWindow.isOperationDone) {
            return true;
        }
        return false;
    }

    function exitApplication() {
        window.forceClose = true;
        if (typeof progressWindow !== "undefined" && progressWindow) {
            progressWindow.close();
        }
        window.close();
        Qt.quit();
    }

    function finalizeExitAfterOperation() {
        if (!window.pendingExitAfterOperationCancel) {
            return;
        }
        window.pendingExitAfterOperationCancel = false;
        forceExitTimer.stop();
        closingPendingDialog.close();
        window.closeArchiveDirectly();
        window.exitApplication();
    }

    function handleWindowCloseRequest() {
        // soft cancel to allow toc to be written
        if (window.isOperationRunning()) {
            window.pendingExitAfterOperationCancel = true;
            window.pendingExitAfterCommit = false;
            statusText.text = "Cancelling operation...";
            if (typeof progressWindow !== "undefined" && progressWindow && progressWindow.visible) {
                progressWindow.isCanceling = true;
            }
            if (typeof archiveInterface !== "undefined" && archiveInterface) {
                archiveInterface.cancelCurrentOperation();
            }
            forceExitTimer.restart();
            closingPendingDialog.open();
            return;
        }
        
        let hasArchive = (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.hasArchive);
        let uncommitted = false;
        if (hasArchive) {
            uncommitted = (archiveInterface.hasUncommittedChanges !== undefined) ? archiveInterface.hasUncommittedChanges : (archiveInterface.pendingJobCount > 0);
        }

        if (hasArchive && uncommitted) {
            window.pendingExitApp = true;
            closePromptDialog.open();
            return;
        }

        if (hasArchive) {
            window.closeArchiveDirectly();
        }
        window.exitApplication();
    }

    function isItemOrChildrenLocked(item) {
        if (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.hasArchive) {
            let p = "";
            if (item) {
                p = item.filePath || item.path || "";
            }
            return archiveInterface.isItemLocked(p);
        }
        return false;
    }

    function startCommitWorkflow() {
        if (typeof archiveInterface === "undefined" || !archiveInterface || !archiveInterface.hasArchive) {
            statusText.text = "No archive open to commit changes.";
            return;
        }
        window.ensureKeyRegistered(function () {
            archiveInterface.optimizeJobsAsync();
        });
    }

    function launchCommitAndShowProgress() {
        if (typeof archiveInterface === "undefined" || !archiveInterface) {
            return;
        }
        progressWindow.resetProgressState();
        progressWindow.show();
        progressWindow.raise();
        progressWindow.requestActivate();
        archiveInterface.saveChanges();
    }

    function launchTestFile(targetItem) {
        if (typeof archiveInterface === "undefined" || !archiveInterface || !archiveInterface.hasArchive) {
            errorDialog.showError("No Archive Open", "Please open an archive before testing files.");
            return;
        }
        if (!targetItem || targetItem.isFolder) {
            errorDialog.showError("Select a File", "Please select a file in the archive to test.");
            return;
        }
        let filePath = targetItem.filePath || targetItem.fullPath || targetItem.path || ("/" + targetItem.name);
        window.ensureKeyRegistered(function () {
            progressWindow.resetProgressState();
            progressWindow.show();
            progressWindow.raise();
            progressWindow.requestActivate();
            let started = archiveInterface.testFile(filePath);
            if (!started) {
                progressWindow.hide();
            }
        });
    }

    function launchTestArchive() {
        if (typeof archiveInterface === "undefined" || !archiveInterface || !archiveInterface.hasArchive) {
            errorDialog.showError("No Archive Open", "Please open an archive before testing.");
            return;
        }
        window.ensureKeyRegistered(function () {
            progressWindow.resetProgressState();
            progressWindow.show();
            progressWindow.raise();
            progressWindow.requestActivate();
            let started = archiveInterface.testArchive();
            if (!started) {
                progressWindow.hide();
            }
        });
    }

    function ensureKeyRegistered(actionCallback) {
        if (typeof archiveInterface === "undefined" || !archiveInterface) {
            return false;
        }
        if (!archiveInterface.hasArchive) {
            statusText.text = "No archive open.";
            errorDialog.showError("No Archive Open", "Please open or create an archive before performing this operation.");
            return false;
        }

        if (archiveInterface.isKeyRegistered) {
            if (actionCallback) {
                actionCallback();
            }
            return true;
        }

        pendingPostUnlockAction = actionCallback || null;
        passIn.open();
        passIn.focusInput();
        return false;
    }

    function requestCloseArchive() {
        if (typeof archiveInterface === "undefined" || !archiveInterface || !archiveInterface.hasArchive) {
            return;
        }
        if (window.isOperationRunning()) {
            errorDialog.showError("Operation in Progress", "Please wait for the active operation to finish or cancel it before closing the archive.");
            return;
        }
        let uncommitted = (archiveInterface.hasUncommittedChanges !== undefined) ? archiveInterface.hasUncommittedChanges : (archiveInterface.pendingJobCount > 0);
        if (uncommitted) {
            window.pendingExitApp = false;
            closePromptDialog.open();
        } else {
            closeArchiveDirectly();
        }
    }

    function closeArchiveDirectly() {
        pendingPostUnlockAction = null;
        pendingAddTargetFolder = null;
        pendingExtractTarget = null;
        clearSelection();
        if (typeof archiveInterface !== "undefined" && archiveInterface) {
            archiveInterface.closeArchive();
        }
        archiveTreeData = [];
        if (infoPageLoader.visible) {
            infoPageLoader.visible = false;
        }
        statusText.text = "No archive open";
    }

    FolderDialog {
        id: extractFolderDialog
        title: "Select Extraction Destination Directory"
        onAccepted: {
            if (typeof archiveInterface !== "undefined" && archiveInterface) {
                let dest = selectedFolder.toString();
                let target = window.pendingExtractTarget;
                window.ensureKeyRegistered(function () {
                    progressWindow.resetProgressState();
                    let targetPath = (target && (target.filePath || target.path)) ? (target.filePath || target.path) : "";
                    if (targetPath !== "") {
                        let displayItemName = targetPath.split("/").filter(Boolean).pop() || targetPath;
                        progressWindow.title = "Extracting " + displayItemName + " ...";
                    } else {
                        progressWindow.title = "Extracting all files ...";
                    }
                    progressWindow.show();
                    progressWindow.raise();
                    progressWindow.requestActivate();

                    let success = false;
                    if (targetPath !== "") {
                        success = archiveInterface.extractItem(targetPath, dest);
                    } else {
                        success = archiveInterface.extractAll(dest);
                    }
                    window.pendingExtractTarget = null;
                    if (!success) {
                        progressWindow.hide();
                    }
                });
            }
        }
        onRejected: {
            window.pendingExtractTarget = null;
        }
    }

    FileDialog {
        id: addFilesDialog
        title: "Add Files to Archive"
        fileMode: FileDialog.OpenFiles
        nameFilters: ["All Files (*.*)"]
        onAccepted: {
            let files = [];
            for (let i = 0; i < selectedFiles.length; ++i) {
                files.push(selectedFiles[i].toString());
            }
            let target = window.pendingAddTargetFolder;
            window.pendingAddTargetFolder = null;
            window.addPendingItems(files, target);
        }
        onRejected: {
            window.pendingAddTargetFolder = null;
        }
    }

    Connections {
        target: typeof archiveInterface !== "undefined" ? archiveInterface : null

        // ── Native OS drag drop handler ──────────────────────────────────
        function onNativeDragDropped(archiveRelativePath, dropTargetDir) {
            if (!dropTargetDir || dropTargetDir === "") return;
            let displayItemName = archiveRelativePath.split("/").filter(Boolean).pop() || archiveRelativePath;
            if (typeof progressWindow !== "undefined" && progressWindow) {
                progressWindow.resetProgressState();
                progressWindow.title = "Extracting " + displayItemName + " ...";
                progressWindow.show();
                progressWindow.raise();
                progressWindow.requestActivate();
            }
            archiveInterface.extractItem(archiveRelativePath, dropTargetDir);
        }
        function onArchiveTreeChanged() {
            window.archiveTreeData = archiveInterface.archiveTree;
        }
        function onArchiveLoadedChanged(loaded) {
            if (loaded) {
                window.isUserLoadingArchive = false;
            } else {
                window.archiveTreeData = [];
                if (infoPageLoader.visible) {
                    infoPageLoader.visible = false;
                }
            }
        }
        function onOperationCompleted(opName, success, msg) {
            var isCancel = (msg && msg.toLowerCase().indexOf("cancel") !== -1);
            if (window.pendingExitAfterOperationCancel) {
                window.finalizeExitAfterOperation();
                return;
            }
            if (opName === "Save Changes") {
                if (success) {
                    if (window.pendingExitAfterCommit) {
                        window.pendingExitAfterCommit = false;
                        window.closeArchiveDirectly();
                        window.exitApplication();
                        return;
                    } else if (window.pendingCloseAfterCommit) {
                        window.pendingCloseAfterCommit = false;
                        window.closeArchiveDirectly();
                    }
                } else {
                    window.pendingExitAfterCommit = false;
                    window.pendingCloseAfterCommit = false;
                }
            }
            if (!success && !isCancel) {
                bottomProgressBar.scrollToFailedJob(true);
            }
        }
        function onOptimizationCompleted(deletedJobIds) {
            if (window.pendingExitAfterOperationCancel) {
                window.finalizeExitAfterOperation();
                return;
            }
            if (deletedJobIds && deletedJobIds.length > 0) {
                bottomProgressBar.playOptimizationDeletionSequence(deletedJobIds, function () {
                    window.launchCommitAndShowProgress();
                });
            } else {
                window.launchCommitAndShowProgress();
            }
        }
        function onIsBusyChanged(busy) {
            if (!busy && window.pendingExitAfterOperationCancel) {
                if (!archiveInterface.isOptimizing && !archiveInterface.isCommitting) {
                    window.finalizeExitAfterOperation();
                }
            }
        }
        function onIsOptimizingChanged(optimizing) {
            if (!optimizing && window.pendingExitAfterOperationCancel) {
                if (!archiveInterface.isBusy && !archiveInterface.isCommitting) {
                    window.finalizeExitAfterOperation();
                }
            }
        }
        function onStatusMessageChanged(msg) {
            statusText.text = msg;
        }
        function onPasswordRequired(path) {
            window.ensureKeyRegistered(null);
        }
        function onExtractionCryptoMismatch(failedPath, destDir) {
            progressWindow.close();
            progressWindow.resetProgressState();

            let targetName = failedPath || "";
            if (targetName.length > 0) {
                let parts = targetName.split("/");
                if (parts.length > 0) {
                    targetName = parts[parts.length - 1] || parts[parts.length - 2] || targetName;
                }
            }

            passIn.titleText = "Enter Password";
            passIn.reasonDescription = "Enter password to decrypt '" + (targetName || "encrypted files") + "'";
            window.pendingPostUnlockAction = function () {
                progressWindow.resetProgressState();
                progressWindow.show();
                progressWindow.raise();
                progressWindow.requestActivate();
                archiveInterface.extractItem(failedPath, destDir);
            };
            passIn.open();
            passIn.focusInput();
        }
        function onErrorOccurred(title, message) {
            if (message && message.toLowerCase().indexOf("cancel") !== -1) {
                return;
            }

            let lowerTitle = (title || "").toLowerCase();
            let lowerMsg = (message || "").toLowerCase();
            let isTocError = (lowerTitle.indexOf("invalid toc") !== -1 ||
                              lowerTitle === "invalid toc" ||
                              lowerMsg.indexOf("invalid toc") !== -1 ||
                              lowerMsg.indexOf("toc magic") !== -1 ||
                              lowerMsg.indexOf("no toc") !== -1 ||
                              (lowerTitle.indexOf("toc") !== -1 && lowerTitle.indexOf("error") !== -1));

            let wasLoadingArchive = window.isUserLoadingArchive || (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.isLoadingArchive);
            let targetPath = window.lastLoadingArchivePath || ((typeof archiveInterface !== "undefined" && archiveInterface) ? archiveInterface.lastAttemptedArchivePath : "");

            window.isUserLoadingArchive = false;

            if (progressWindow && progressWindow.visible) {
                progressWindow.showError(title, message);
            } else {
                if (isTocError && wasLoadingArchive && targetPath && targetPath.length > 0) {
                    errorDialog.showErrorWithRecovery(title, message, targetPath);
                } else {
                    errorDialog.showError(title, message);
                }
            }
        }
    }

    ErrorDialog {
        id: errorDialog
        anchors.centerIn: parent
        onRecoveryRequested: (filePath) => {
            window.openRecoveryWithFile(filePath);
        }
    }

    Dialog {
        id: closePromptDialog
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 480)
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape
        padding: 20
        onClosed: {
            if (window.pendingExitApp) {
                window.pendingExitApp = false;
            }
        }

        Overlay.modal: Rectangle {
            color: Colors.overlayModal
            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
            }
        }

        background: Rectangle {
            color: Colors.bgSurface
            radius: 14
            border.color: Colors.goldBorder
            border.width: 1.5

            // Gold accent line at top
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                height: 2.5
                radius: 1.25
                color: Colors.goldPrimary
            }
        }

        contentItem: ColumnLayout {
            spacing: 16

            RowLayout {
                spacing: 12
                Layout.fillWidth: true

                Rectangle {
                    width: 40
                    height: 40
                    radius: 20
                    color: Colors.goldLight
                    border.color: Colors.goldBorderHi
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "\ue002"
                        font.family: materialIcons.name
                        font.pixelSize: 22
                        color: Colors.goldPrimary
                    }
                }

                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true

                    Text {
                        text: "Uncommitted Changes"
                        font.family: Colors.fontFamily
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        color: Colors.textMain
                    }

                    Text {
                        text: "You have uncommitted modifications in this archive."
                        font.family: Colors.fontFamily
                        font.pixelSize: 12
                        color: Colors.textMuted
                    }
                }
            }

            Text {
                text: "Would you like to commit these changes to the archive before closing, or discard them?"
                font.family: Colors.fontFamily
                font.pixelSize: 13
                color: Colors.textMain
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                spacing: 8
                
                Rectangle {
                    implicitWidth: 124
                    implicitHeight: 34
                    radius: 6
                    color: discardMouse.containsMouse ? (Colors.isDarkMode ? Qt.rgba(0.9, 0.32, 0.32, 0.18) : Qt.rgba(0.85, 0.25, 0.25, 0.12)) : "transparent"
                    border.color: discardMouse.containsMouse ? "#e05353" : Colors.borderSubtle
                    border.width: 1

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }
                    Behavior on border.color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Discard & Close"
                        font.family: Colors.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: "#e05353"
                    }

                    MouseArea {
                        id: discardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            closePromptDialog.close();
                            if (window.pendingExitApp) {
                                window.pendingExitApp = false;
                                window.closeArchiveDirectly();
                                window.exitApplication();
                            } else {
                                window.closeArchiveDirectly();
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                // Cancel button
                Rectangle {
                    implicitWidth: 80
                    implicitHeight: 34
                    radius: 6
                    color: cancelCloseMouse.containsMouse ? Colors.bgHover : Colors.bgElevated
                    border.color: Colors.goldBorder
                    border.width: 1

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        font.family: Colors.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: Colors.textMain
                    }

                    MouseArea {
                        id: cancelCloseMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            window.pendingExitApp = false;
                            closePromptDialog.close();
                        }
                    }
                }

                // Commit & Close button
                Rectangle {
                    implicitWidth: 130
                    implicitHeight: 34
                    radius: 6
                    color: commitCloseMouse.containsPress ? Qt.darker(Colors.goldPrimary, 1.15) : (commitCloseMouse.containsMouse ? Colors.goldHover : Colors.goldPrimary)
                    border.color: Colors.goldBorderHi
                    border.width: 1

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Commit & Close"
                        font.family: Colors.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: Colors.textOnGold
                    }

                    MouseArea {
                        id: commitCloseMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            closePromptDialog.close();
                            if (window.pendingExitApp) {
                                window.pendingExitApp = false;
                                window.pendingExitAfterCommit = true;
                            } else {
                                window.pendingCloseAfterCommit = true;
                            }
                            window.startCommitWorkflow();
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: closingPendingDialog
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 430)
        modal: true
        focus: true
        closePolicy: Popup.NoAutoClose
        padding: 24

        Overlay.modal: Rectangle {
            color: Colors.overlayModal
            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
            }
        }

        background: Rectangle {
            color: Colors.bgSurface
            radius: 14
            border.color: Colors.goldBorder
            border.width: 1.5
            
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                height: 2.5
                radius: 1.25
                color: Colors.goldPrimary
            }
        }

        contentItem: ColumnLayout {
            spacing: 16
            Layout.fillWidth: true

            RowLayout {
                spacing: 14
                Layout.fillWidth: true

                Rectangle {
                    width: 44
                    height: 44
                    radius: 22
                    color: Colors.goldLight
                    border.color: Colors.goldBorderHi
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "\ue5d5"
                        font.family: materialIcons.name
                        font.pixelSize: 24
                        color: Colors.goldPrimary

                        RotationAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 1000
                            loops: Animation.Infinite
                            running: closingPendingDialog.visible
                        }
                    }
                }

                ColumnLayout {
                    spacing: 3
                    Layout.fillWidth: true

                    Text {
                        text: "Waiting for active tasks...."
                        font.family: Colors.fontFamily
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        color: Colors.textMain
                    }
                }
            }

            Text {
                text: "An operation is currently in progress. Stopping active tasks safely and preserving archive table of contents integrity before closing..."
                font.family: Colors.fontFamily
                font.pixelSize: 12
                color: Colors.textMain
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Item {
                id: barContainer
                Layout.fillWidth: true
                height: 4
                clip: true

                Rectangle {
                    anchors.fill: parent
                    color: Colors.bgInput
                    radius: 2
                }

                Rectangle {
                    id: securingIndBar
                    width: Math.max(40, barContainer.width * 0.35)
                    height: barContainer.height
                    radius: 2
                    color: Colors.goldPrimary

                    NumberAnimation on x {
                        from: -securingIndBar.width
                        to: barContainer.width
                        duration: 1100
                        loops: Animation.Infinite
                        running: closingPendingDialog.visible
                    }
                }
            }
        }
    }

    Timer {
        id: forceExitTimer
        interval: 10000
        repeat: false
        onTriggered: {
            closingPendingDialog.close();
            window.exitApplication();
        }
    }

    PasswordDialog {
        id: passIn
        anchors.centerIn: parent
        onAcceptedPassword: password => {
            if (typeof archiveInterface !== "undefined" && archiveInterface) {
                let success = archiveInterface.registerKey(password);
                if (success) {
                    passIn.close();
                    if (window.pendingPostUnlockAction) {
                        let action = window.pendingPostUnlockAction;
                        window.pendingPostUnlockAction = null;
                        action();
                    }
                } else {
                    passIn.errorMessage = "Incorrect password. Please try again.";
                    passIn.focusInput();
                }
            }
        }
        onRejected: {
            window.pendingPostUnlockAction = null;
            statusText.text = "Operation cancelled: password required.";
        }
    }

    Loader {
        id: createArchiveLoader
        active: false
        source: "CreateArchive.qml"
        onLoaded: {
            item.closeRequested.connect(() => {});
            item.archiveCreated.connect(archiveInfo => {
                if (typeof archiveInterface !== "undefined" && archiveInterface) {
                    let preserve = (archiveInfo.preserveMetadata !== undefined) ? archiveInfo.preserveMetadata : Boolean(archiveInfo.preservePermissions);
                    archiveInterface.createArchive(archiveInfo.filePath || archiveInfo.name, archiveInfo.password, archiveInfo.compressionLevel, preserve, archiveInfo.files);
                } else {
                    statusText.text = "Created archive: " + archiveInfo.name + " (" + archiveInfo.files.length + " files)";
                    pBar.value = 1.0;
                }
            });
            if (item.resetFields) {
                item.resetFields();
            }
            item.open();
        }
    }

    ProgressWindow {
        id: progressWindow
        onPauseToggled: function(paused) {
            if (typeof archiveInterface !== "undefined" && archiveInterface) {
                archiveInterface.setOperationPaused(paused);
            }
        }
    }

    Rectangle {
        id: mainContainer
        anchors.fill: parent
        color: Colors.bgMain
        border.color: Colors.borderSubtle
        border.width: 1

        Behavior on color {
            ColorAnimation {
                duration: 200
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: window.clearSelection()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        Rectangle {
            id: topFunctionBar
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            radius: 10
            color: Colors.bgCard
            border.color: Colors.borderSubtle
            border.width: 1

            Behavior on color {
                ColorAnimation {
                    duration: 200
                }
            }
            Behavior on border.color {
                ColorAnimation {
                    duration: 200
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 12
                spacing: 2
                
                IslandButton {
                    iconText: "add_circle"
                    labelText: "Create"
                    accentColor: Colors.goldPrimary
                    onClicked: {
                        if (createArchiveLoader.item) {
                            if (createArchiveLoader.item.resetFields) {
                                createArchiveLoader.item.resetFields();
                            }
                            createArchiveLoader.item.open();
                        } else {
                            createArchiveLoader.active = true;
                        }
                    }
                }

                IslandButton {
                    iconText: "\ue2c8"
                    labelText: "Open"
                    accentColor: Colors.goldPrimary
                    onClicked: {
                        openArchiveDialog.open();
                    }
                }

                Rectangle {
                    width: 1
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    color: Colors.divider
                }

                IslandButton {
                    iconText: "unarchive"
                    labelText: "Extract All"
                    accentColor: Colors.isDarkMode ? "#34d399" : "#059669"
                    enabled: window.hasArchive
                    onClicked: {
                        window.ensureKeyRegistered(function () {
                            window.pendingExtractTarget = null;
                            extractFolderDialog.open();
                        });
                    }
                }
                
                IslandButton {
                    iconText: "\ue2c6" // file download / extract
                    labelText: "Extract"
                    accentColor: Colors.isDarkMode ? "#38bdf8" : "#0284c7"
                    enabled: window.hasArchive && window.selectedCount > 0
                    onClicked: {
                        if (window.selectedTreeItem) {
                            let target = window.selectedTreeItem;
                            window.ensureKeyRegistered(function () {
                                window.pendingExtractTarget = target;
                                extractFolderDialog.open();
                            });
                        }
                    }
                }

                IslandButton {
                    iconText: "delete"
                    labelText: "Delete"
                    accentColor: "#e05353"
                    enabled: window.hasArchive && window.selectedCount > 0
                    onClicked: {
                        if (window.selectedCount > 0) {
                            let items = window.getSelectedItemsList();
                            for (let i = 0; i < items.length; ++i) {
                                window.removeTreeItem(items[i].filePath || items[i].name, items[i].isFolder || false);
                            }
                            window.clearSelection();
                        }
                    }
                }
                
                IslandButton {
                    iconText: "\ue86c" // done_all / verified
                    labelText: "Test"
                    accentColor: Colors.textMuted
                    enabled: window.hasArchive && (window.selectedTreeItem !== null && !window.selectedTreeItem.isFolder && !window.selectedTreeItem.isPending)
                    onClicked: {
                        if (!archiveInterface || !archiveInterface.hasArchive) {
                            errorDialog.showError("No Archive Open", "Please open an archive before testing files.");
                            return;
                        }
                        if (window.selectedTreeItem && !window.selectedTreeItem.isFolder && !window.selectedTreeItem.isPending) {
                            window.launchTestFile(window.selectedTreeItem);
                        } else {
                            errorDialog.showError("Select a File", "Please select a file in the archive tree to test its integrity.");
                        }
                    }
                }

                IslandButton {
                    iconText: "\ue8e8"
                    labelText: "Test Archive"
                    accentColor: Colors.textMuted
                    enabled: window.hasArchive
                    onClicked: {
                        if (!archiveInterface || !archiveInterface.hasArchive) {
                            errorDialog.showError("No Archive Open", "Please open an archive before testing.");
                            return;
                        }
                        window.launchTestArchive();
                    }
                }

                IslandButton {
                    iconText: "\ue88e" // info
                    labelText: "Info"
                    accentColor: Qt.rgba(65 / 255, 105 / 255, 225 / 255, 0.8)
                    enabled: window.hasArchive
                    highlighted: infoPageLoader.visible
                    onClicked: {
                        infoPageLoader.visible = !infoPageLoader.visible;
                        if (infoPageLoader.visible && recoveryPageLoader.visible) {
                            recoveryPageLoader.visible = false;
                        }
                    }
                }

                IslandButton {
                    id: recoveryBtn
                    readonly property bool hasRecoveryOpen: (typeof recoveryInterface !== "undefined" && recoveryInterface) ? recoveryInterface.hasArchive : ((typeof archiveInterface !== "undefined" && archiveInterface) ? archiveInterface.hasRecoveryArchive : false)

                    iconText: "\ue869"
                    labelText: "Recovery"
                    accentColor: hasRecoveryOpen ? (Colors.isDarkMode ? "#34d399" : "#059669") : Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.85) // Sea green
                    activeState: hasRecoveryOpen
                    activeBgColor: Colors.isDarkMode ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.22) : Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.14)
                    activeBorderColor: Colors.isDarkMode ? Qt.rgba(52 / 255, 211 / 255, 153 / 255, 0.60) : Qt.rgba(5 / 255, 150 / 255, 105 / 255, 0.50)
                    showIndicatorDot: hasRecoveryOpen
                    indicatorColor: Colors.isDarkMode ? "#34d399" : "#059669"
                    enabled: true
                    highlighted: recoveryPageLoader.visible
                    onClicked: {
                        if (recoveryPageLoader.visible && recoveryPageLoader.item && recoveryPageLoader.item.hasActiveArchive) {
                            recoveryPageLoader.item.promptCloseSession();
                            return;
                        }
                        recoveryPageLoader.visible = !recoveryPageLoader.visible;
                        if (recoveryPageLoader.visible && infoPageLoader.visible) {
                            infoPageLoader.visible = false;
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                ThemeToggle {
                    id: headerThemeToggle
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Item {
                id: tabStripItem
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                height: 36
                z: 10
                
                Rectangle {
                    id: archiveTab
                    anchors.left: parent.left
                    anchors.leftMargin: 0
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -1
                    height: 37
                    width: tabRow.implicitWidth + 30

                    color: Colors.bgSurface
                    border.color: Colors.goldBorder
                    border.width: 1

                    topLeftRadius: 10
                    topRightRadius: 10
                    bottomLeftRadius: 0
                    bottomRightRadius: 0

                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                        }
                    }
                    Behavior on border.color {
                        ColorAnimation {
                            duration: 200
                        }
                    }

                    RowLayout {
                        id: tabRow
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -1
                        spacing: 8

                        Text {
                            text: "folder_zip"
                            font.family: materialIcons.name
                            font.pixelSize: 16
                            color: Colors.goldPrimary
                        }

                        Text {
                            text: (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.hasArchive) ? archiveInterface.archiveFileName : "No Archive Open"
                            font.family: Colors.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: Colors.textMain
                        }

                        Rectangle {
                            width: 36
                            height: 18
                            radius: 4
                            color: Colors.goldLight
                            visible: (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.hasArchive)

                            Text {
                                anchors.centerIn: parent
                                text: "SDA"
                                font.family: Colors.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: Colors.goldPrimary
                            }
                        }
                        Rectangle {
                            id: headerKeyBtn
                            width: 24
                            height: 20
                            radius: 4
                            visible: (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.hasArchive)
                            color: (archiveInterface && archiveInterface.isKeyRegistered)
                                 ? (Colors.isDarkMode ? Qt.rgba(0.06, 0.73, 0.51, 0.20) : Qt.rgba(0.06, 0.73, 0.51, 0.12))
                                 : keyMouse.containsPress ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.20))
                                 : keyMouse.containsMouse ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.10))
                                 : (Colors.isDarkMode ? Qt.rgba(0.94, 0.27, 0.27, 0.20) : Qt.rgba(0.94, 0.27, 0.27, 0.12))
                            border.color: (archiveInterface && archiveInterface.isKeyRegistered)
                                        ? (Colors.isDarkMode ? Qt.rgba(0.06, 0.73, 0.51, 0.6) : Qt.rgba(0.06, 0.73, 0.51, 0.4))
                                        : (keyMouse.containsMouse ? "#F87171" : (Colors.isDarkMode ? Qt.rgba(0.94, 0.27, 0.27, 0.6) : Qt.rgba(0.94, 0.27, 0.27, 0.4)))
                            border.width: 1

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }
                            Behavior on border.color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "\ue0da" // vpn_key icon
                                font.family: materialIcons.name
                                font.pixelSize: 12
                                color: (archiveInterface && archiveInterface.isKeyRegistered) ? "#10B981" : "#EF4444"
                            }

                            MouseArea {
                                id: keyMouse
                                anchors.fill: parent
                                enabled: !(archiveInterface && archiveInterface.isKeyRegistered)
                                hoverEnabled: enabled
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (archiveInterface && archiveInterface.isKeyRegistered)
                                        return;
                                    passIn.open();
                                    passIn.focusInput();
                                }
                            }
                            ToolTip {
                                id: keyTooltip
                                visible: keyMouse.containsMouse
                                delay: 400
                                text: {
                                    if (!archiveInterface.isKeyRegistered) {
                                        return "No key is registered";
                                    }
                                    return "Key is registered";
                                }
                            }
                        }

                        // archive close button in header
                        Rectangle {
                            id: tabCloseBtn
                            width: 20
                            height: 20
                            radius: 10
                            color: tabCloseMouse.containsPress ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(0, 0, 0, 0.15)) : tabCloseMouse.containsMouse ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.08)) : "transparent"
                            visible: (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.hasArchive)
                            Layout.alignment: Qt.AlignVCenter

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "\ue5cd" 
                                font.family: materialIcons.name
                                font.pixelSize: 14
                                color: tabCloseMouse.containsMouse ? "#e05353" : Colors.textMuted
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }
                            }

                            MouseArea {
                                id: tabCloseMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: window.requestCloseArchive()
                            }
                        }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 1
                        anchors.rightMargin: 1
                        height: 3
                        color: Colors.bgSurface
                        z: 2

                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }
                    }
                }
            }
            
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                Rectangle {
                    id: treeContainer
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 420
                    Layout.minimumWidth: 280
                    color: Colors.bgSurface

                    topLeftRadius: 0
                    topRightRadius: 10
                    bottomLeftRadius: 10
                    bottomRightRadius: 10

                    border.color: (treeDropArea.containsDrag || window.isTreeDragActive) ? Colors.goldPrimary : Colors.goldBorder
                    border.width: (treeDropArea.containsDrag || window.isTreeDragActive) ? 2 : 1

                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                        }
                    }
                    Behavior on border.color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                    Behavior on border.width {
                        NumberAnimation {
                            duration: 150
                        }
                    }

                    
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                treeContextMenu.targetItem = null;
                                treeContextMenu.parentFolderName = "";
                                treeContextMenu.isTargetPending = false;
                                treeContextMenu.isBlankArea = true;
                                let globalPoint = mapToItem(window.contentItem, mouse.x, mouse.y);
                                treeContextMenu.x = Math.min(globalPoint.x, window.width - treeContextMenu.width - 10);
                                treeContextMenu.y = Math.min(globalPoint.y, window.height - 200);
                                treeContextMenu.open();
                            } else if (mouse.button === Qt.LeftButton) {
                                window.clearSelection();
                            }
                        }
                    }

                    ColumnLayout {
                        id: treeLayout
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4
                        visible: !(typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.isLoadingArchive) && ((typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.treeModel) ? (archiveInterface.treeModel.count > 0) : (window.archiveTreeData && window.archiveTreeData.length > 0))

                        Rectangle {
                            id: stickyTreeHeader
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            color: Colors.bgElevated
                            border.color: Colors.borderSubtle
                            border.width: 1
                            radius: 6

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 8

                                Text {
                                    text: "Name"
                                    color: Colors.textMuted
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    width: 1
                                    height: 14
                                    color: Colors.divider
                                }

                                Text {
                                    text: "Compressed"
                                    color: Colors.textMuted
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    Layout.preferredWidth: window.colCompressedWidth
                                    horizontalAlignment: Text.AlignRight
                                }

                                Rectangle {
                                    width: 1
                                    height: 14
                                    color: Colors.divider
                                }

                                Text {
                                    text: "Real Size"
                                    color: Colors.textMuted
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    Layout.preferredWidth: window.colRealWidth
                                    horizontalAlignment: Text.AlignRight
                                }

                                Rectangle {
                                    width: 1
                                    height: 14
                                    color: Colors.divider
                                }

                                Text {
                                    text: "Ratio"
                                    color: Colors.textMuted
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    Layout.preferredWidth: window.colRatioWidth
                                    horizontalAlignment: Text.AlignRight
                                }

                                Rectangle {
                                    width: 1
                                    height: 14
                                    color: Colors.divider
                                }

                                Text {
                                    text: "CRC32"
                                    color: Colors.textMuted
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    Layout.preferredWidth: window.colCrcWidth
                                    horizontalAlignment: Text.AlignRight
                                }

                                Item {
                                    Layout.preferredWidth: 28
                                    Layout.fillHeight: true
                                }
                            }

                            Rectangle { // BUG: laggs on high file count
                                id: treeFindBar
                                anchors.right: parent.right
                                anchors.rightMargin: 2
                                anchors.verticalCenter: parent.verticalCenter
                                visible: false // temp fix to high file count lag problem
                                z: 30

                                property bool isOpen: false
                                width: isOpen ? 250 : 26
                                height: 26
                                radius: 13

                                color: isOpen ? Colors.bgElevated : (findBtnMouse.containsMouse ? Colors.bgHover : Colors.bgSurface)
                                border.color: isOpen ? Colors.goldPrimary : (findBtnMouse.containsMouse ? Colors.goldPrimary : Colors.borderSubtle)
                                border.width: isOpen ? 1.5 : 1

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 220
                                        easing.type: Easing.OutCubic
                                    }
                                }
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                MouseArea {
                                    id: findBtnMouse
                                    anchors.fill: parent
                                    enabled: !treeFindBar.isOpen
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        treeFindBar.openFind();
                                    }
                                }

                                ToolTip.visible: findBtnMouse.containsMouse && !treeFindBar.isOpen
                                ToolTip.delay: 400
                                ToolTip.text: "Find files (Ctrl+F)"

                                function openFind() {
                                    isOpen = true;
                                    Qt.callLater(function() {
                                        treeFindInput.forceActiveFocus();
                                        treeFindInput.selectAll();
                                    });
                                }

                                function closeFind() {
                                    treeFindInput.text = "";
                                    window.mainTreeFindQuery = "";
                                    isOpen = false;
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: treeFindBar.isOpen ? 8 : 6
                                    anchors.rightMargin: treeFindBar.isOpen ? 4 : 6
                                    spacing: 4

                                    Text {
                                        text: "\ue8b6"
                                        font.family: materialIcons.name
                                        font.pixelSize: 13
                                        color: treeFindBar.isOpen ? Colors.goldPrimary : (findBtnMouse.containsMouse ? Colors.goldPrimary : Colors.textMuted)
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.preferredWidth: 14
                                        horizontalAlignment: Text.AlignHCenter

                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: treeFindBar.isOpen
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                treeFindInput.forceActiveFocus();
                                                treeFindInput.accepted();
                                            }
                                        }
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        visible: treeFindBar.isOpen || treeFindBar.width > 35
                                        clip: true

                                        TextInput {
                                            id: treeFindInput
                                            anchors.fill: parent
                                            verticalAlignment: TextInput.AlignVCenter
                                            font.family: Colors.fontFamily
                                            font.pixelSize: 11
                                            color: Colors.textMain
                                            selectionColor: Colors.goldPrimary
                                            selectedTextColor: Colors.textOnGold
                                            selectByMouse: true
                                            activeFocusOnTab: true

                                            onAccepted: {
                                                window.mainTreeFindQuery = text;
                                                if (text.trim().length > 0 && archiveInterface && archiveInterface.treeModel) {
                                                    archiveInterface.treeModel.expandAll();
                                                }
                                            }

                                            onTextChanged: {
                                                if (text.trim().length === 0 && window.mainTreeFindQuery.length > 0) {
                                                    window.mainTreeFindQuery = "";
                                                }
                                            }

                                            Keys.onEscapePressed: {
                                                if (text.length > 0) {
                                                    text = "";
                                                    window.mainTreeFindQuery = "";
                                                } else {
                                                    treeFindBar.closeFind();
                                                }
                                            }
                                        }

                                        Text {
                                            anchors.fill: parent
                                            verticalAlignment: Text.AlignVCenter
                                            visible: !treeFindInput.text && !treeFindInput.activeFocus
                                            text: "Filter files by name..."
                                            color: Colors.textMuted
                                            font.family: Colors.fontFamily
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Rectangle {
                                        visible: treeFindBar.isOpen
                                        Layout.preferredWidth: 18
                                        Layout.preferredHeight: 18
                                        Layout.alignment: Qt.AlignVCenter
                                        radius: 9
                                        color: closeMouse.containsMouse ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.08)) : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\ue5cd"
                                            font.family: materialIcons.name
                                            font.pixelSize: 12
                                            color: closeMouse.containsMouse ? Colors.goldPrimary : Colors.textMuted
                                        }

                                        MouseArea {
                                            id: closeMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (treeFindInput.text.length > 0) {
                                                    treeFindInput.text = "";
                                                    window.mainTreeFindQuery = "";
                                                    treeFindInput.forceActiveFocus();
                                                } else {
                                                    treeFindBar.closeFind();
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        ListView {
                            id: mainTreeListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            spacing: (window.mainTreeFindQuery.trim().length > 0) ? 0 : 2
                            model: (typeof archiveInterface !== "undefined" && archiveInterface) ? archiveInterface.treeModel : null

                            MouseArea {
                                anchors.fill: parent
                                z: -1
                                onClicked: window.clearSelection()
                            }

                            ScrollBar.vertical: Basic.ScrollBar {
                                active: mainTreeListView.moving || mainTreeListView.flicking
                                policy: ScrollBar.AsNeeded
                                contentItem: Rectangle {
                                    implicitWidth: 5
                                    radius: 2.5
                                    color: parent.pressed ? Colors.goldPrimary : parent.hovered ? Colors.goldHover : (Colors.isDarkMode ? Qt.rgba(0.9, 0.76, 0.35, 0.35) : Qt.rgba(0.69, 0.51, 0.12, 0.35))
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 150
                                        }
                                    }
                                }
                                background: Rectangle {
                                    implicitWidth: 5
                                    color: "transparent"
                                }
                            }

                            delegate: Item {
                                id: rowDelegate
                                width: mainTreeListView.width
                                readonly property string nodeName: model.name || ""
                                readonly property string filePathStr: model.filePath || ""
                                readonly property bool isSearching: window.mainTreeFindQuery.trim().length > 0
                                readonly property bool matchesFilter: {
                                    if (!isSearching) return true;
                                    let q = window.mainTreeFindQuery.trim().toLowerCase();
                                    let nameMatch = nodeName.toLowerCase().indexOf(q) !== -1;
                                    let pathMatch = filePathStr.toLowerCase().indexOf(q) !== -1;
                                    return nameMatch || pathMatch;
                                }
                                readonly property bool isRowVisible: matchesFilter

                                height: isRowVisible ? 34 : 0
                                visible: isRowVisible
                                clip: true

                                readonly property bool isPending: model.pending
                                readonly property bool isSelected: window.isItemSelected(model.filePath || rowDelegate.nodeName)
                                readonly property bool canDrag: !isPending
                                readonly property bool isFolder: model.isFolder
                                readonly property bool isOpen: model.expanded

                                Rectangle {
                                    id: itemRowRect
                                    anchors.fill: parent
                                    anchors.bottomMargin: (window.mainTreeFindQuery.trim().length > 0) ? 2 : 0
                                    radius: 6

                                    readonly property bool isDropTargetHovered: rowDelegate.isFolder && (
                                        (window.isTreeDragActive && window.dragTargetDir !== "" && (
                                            window.dragTargetDir === model.filePath ||
                                            window.dragTargetDir === (model.filePath ? (model.filePath.endsWith("/") ? model.filePath : (model.filePath + "/")) : "")
                                        )) ||
                                        (treeDropArea.containsDrag && treeDropArea.targetFolderPath !== "" && (
                                            treeDropArea.targetFolderPath === model.filePath ||
                                            treeDropArea.targetFolderPath === (model.filePath ? (model.filePath.endsWith("/") ? model.filePath : (model.filePath + "/")) : "")
                                        ))
                                    )

                                    color: isDropTargetHovered ? Colors.goldLightHover : rowDelegate.isPending ? (itemMouse.containsMouse ? Colors.goldLightHover : (Colors.isDarkMode ? Qt.rgba(0.9, 0.76, 0.35, 0.09) : Qt.rgba(0.69, 0.51, 0.12, 0.08))) : rowDelegate.isSelected ? (Colors.isDarkMode ? Qt.rgba(0.32, 0.36, 0.44, 0.70) : Qt.rgba(0.55, 0.58, 0.65, 0.70)) : itemMouse.containsPress ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.08)) : itemMouse.containsMouse ? Colors.bgHover : "transparent"

                                    border.color: isDropTargetHovered ? Colors.goldPrimary : rowDelegate.isPending ? Colors.goldBorderHi : rowDelegate.isSelected ? (Colors.isDarkMode ? "#5f6c80" : "#64748b") : "transparent"
                                    border.width: isDropTargetHovered ? 2 : (rowDelegate.isSelected ? 1.5 : (rowDelegate.isPending ? 1 : 0))

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 120
                                        }
                                    }
                                    Behavior on border.color {
                                        ColorAnimation {
                                            duration: 120
                                        }
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: (model.depth * 18) + 10
                                        anchors.rightMargin: 12
                                        spacing: 8

                                        Rectangle {
                                            width: 3
                                            height: 18
                                            radius: 1.5
                                            color: rowDelegate.isPending ? Colors.goldPrimary : (rowDelegate.isSelected ? (Colors.isDarkMode ? "#cbd5e1" : "#475569") : "transparent")
                                            visible: rowDelegate.isPending || rowDelegate.isSelected
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        Text {
                                            text: rowDelegate.isFolder ? (rowDelegate.isOpen ? "\ue5cf" : "\ue5cc") : " "
                                            font.family: materialIcons.name
                                            font.pixelSize: 16
                                            color: rowDelegate.isSelected ? (Colors.isDarkMode ? "#cbd5e1" : "#334155") : Colors.textMuted
                                            visible: rowDelegate.isFolder
                                            Layout.preferredWidth: 16

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (archiveInterface && archiveInterface.treeModel) {
                                                        archiveInterface.treeModel.toggleExpand(index);
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            text: rowDelegate.isFolder ? (rowDelegate.isOpen ? "\ue2c8" : "\ue2c7") : (rowDelegate.isPending ? "\ue2c6" : "\ue873")
                                            font.family: materialIcons.name
                                            font.pixelSize: 18
                                            color: rowDelegate.isPending ? Colors.goldHover : (rowDelegate.isSelected ? (rowDelegate.isFolder ? (Colors.isDarkMode ? "#fbbf24" : "#b45309") : (Colors.isDarkMode ? "#e2e8f0" : "#1e293b")) : (rowDelegate.isFolder ? Colors.goldPrimary : Colors.textMuted))
                                            Layout.preferredWidth: 18
                                        }

                                        Text {
                                            text: model.name || ""
                                            color: rowDelegate.isPending ? Colors.goldHover : (rowDelegate.isSelected ? (Colors.isDarkMode ? "#f8fafc" : "#0f172a") : Colors.textMain)
                                            font.family: Colors.fontFamily
                                            font.pixelSize: 12
                                            font.weight: (rowDelegate.isPending || rowDelegate.isSelected) ? Font.DemiBold : Font.Medium
                                            font.italic: rowDelegate.isPending
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                        
                                        Rectangle {
                                            visible: rowDelegate.isSearching && rowDelegate.matchesFilter
                                            Layout.preferredHeight: 18
                                            Layout.preferredWidth: 64
                                            radius: 9
                                            color: Colors.isDarkMode ? Qt.rgba(0.9, 0.76, 0.35, 0.18) : Qt.rgba(0.69, 0.51, 0.12, 0.14)
                                            border.color: Colors.goldBorder
                                            border.width: 1

                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 3
                                                Text {
                                                    text: "\ue8b6"
                                                    font.family: materialIcons.name
                                                    font.pixelSize: 10
                                                    color: Colors.goldPrimary
                                                }
                                                Text {
                                                    text: "1 match"
                                                    font.family: Colors.fontFamily
                                                    font.pixelSize: 10
                                                    font.weight: Font.DemiBold
                                                    color: Colors.goldPrimary
                                                }
                                            }
                                        }

                                        // Target Drop Cue Pill
                                        Rectangle {
                                            visible: itemRowRect.isDropTargetHovered
                                            Layout.preferredHeight: 20
                                            Layout.preferredWidth: 140
                                            radius: 4
                                            color: Colors.goldPrimary

                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 4
                                                Text {
                                                    text: "\ue5c8"
                                                    font.family: materialIcons.name
                                                    font.pixelSize: 11
                                                    color: Colors.textOnGold
                                                }
                                                Text {
                                                    text: window.isTreeDragActive ? "Move into folder" : "Add into folder"
                                                    font.family: Colors.fontFamily
                                                    font.pixelSize: 10
                                                    font.weight: Font.Bold
                                                    color: Colors.textOnGold
                                                }
                                            }
                                        }

                                        // Divider before Compressed
                                        Rectangle {
                                            visible: !itemRowRect.isDropTargetHovered
                                            width: 1
                                            height: 14
                                            color: rowDelegate.isSelected ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.16)) : Colors.divider
                                        }

                                        // Column 1: Compressed Size
                                        Text {
                                            visible: !itemRowRect.isDropTargetHovered
                                            text: model.compressedSize !== undefined ? model.compressedSize : "-"
                                            color: rowDelegate.isPending ? Colors.goldPrimary : (rowDelegate.isSelected ? (Colors.isDarkMode ? "#f8fafc" : "#0f172a") : Colors.textMuted)
                                            font.family: Colors.fontFamily
                                            font.pixelSize: 11
                                            font.weight: rowDelegate.isSelected ? Font.Medium : Font.Normal
                                            font.italic: rowDelegate.isPending
                                            Layout.preferredWidth: window.colCompressedWidth
                                            horizontalAlignment: Text.AlignRight
                                            elide: Text.ElideRight
                                        }

                                        // Divider before Real Size
                                        Rectangle {
                                            visible: !itemRowRect.isDropTargetHovered
                                            width: 1
                                            height: 14
                                            color: rowDelegate.isSelected ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.16)) : Colors.divider
                                        }

                                        // Column 2: Real Size
                                        Text {
                                            visible: !itemRowRect.isDropTargetHovered
                                            text: model.realSize !== undefined ? model.realSize : "-"
                                            color: rowDelegate.isSelected ? (Colors.isDarkMode ? "#f8fafc" : "#0f172a") : Colors.textMuted
                                            font.family: Colors.fontFamily
                                            font.pixelSize: 11
                                            font.weight: rowDelegate.isSelected ? Font.Medium : Font.Normal
                                            Layout.preferredWidth: window.colRealWidth
                                            horizontalAlignment: Text.AlignRight
                                            elide: Text.ElideRight
                                        }

                                        // Divider before Ratio
                                        Rectangle {
                                            visible: !itemRowRect.isDropTargetHovered
                                            width: 1
                                            height: 14
                                            color: rowDelegate.isSelected ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.16)) : Colors.divider
                                        }

                                        // Column 3: Ratio / Pending Badge
                                        Rectangle {
                                            visible: !itemRowRect.isDropTargetHovered
                                            Layout.preferredWidth: window.colRatioWidth
                                            Layout.preferredHeight: 20
                                            radius: 4
                                            color: rowDelegate.isSelected ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.08)) : (rowDelegate.isPending ? Colors.goldLight : (model.ratio && model.ratio !== "-" ? Colors.goldLight : "transparent"))
                                            border.color: rowDelegate.isSelected ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(0, 0, 0, 0.15)) : (rowDelegate.isPending ? Colors.goldBorderHi : "transparent")
                                            border.width: (rowDelegate.isPending || rowDelegate.isSelected) ? 1 : 0

                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 2
                                                Text {
                                                    visible: rowDelegate.isPending
                                                    text: "\ue8b5"
                                                    font.family: materialIcons.name
                                                    font.pixelSize: 9
                                                    color: rowDelegate.isSelected ? (Colors.isDarkMode ? "#f8fafc" : "#0f172a") : Colors.goldPrimary
                                                }
                                                Text {
                                                    text: rowDelegate.isPending ? "PEND" : (model.ratio !== undefined ? model.ratio : "-")
                                                    color: rowDelegate.isSelected ? (Colors.isDarkMode ? "#f8fafc" : "#0f172a") : Colors.goldPrimary
                                                    font.family: Colors.fontFamily
                                                    font.pixelSize: rowDelegate.isPending ? 8 : 11
                                                    font.weight: Font.Bold
                                                }
                                            }
                                        }
                                        
                                        Rectangle {
                                            visible: !itemRowRect.isDropTargetHovered
                                            width: 1
                                            height: 14
                                            color: rowDelegate.isSelected ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.16)) : Colors.divider
                                        }
                                        
                                        Rectangle {
                                            visible: !itemRowRect.isDropTargetHovered
                                            Layout.preferredWidth: window.colCrcWidth
                                            Layout.preferredHeight: 20
                                            radius: 4
                                            color: (!rowDelegate.isFolder && !rowDelegate.isPending && model.crc && model.crc !== "-") ? (rowDelegate.isSelected ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.08)) : Colors.bgElevated) : "transparent"
                                            border.color: (!rowDelegate.isFolder && !rowDelegate.isPending && model.crc && model.crc !== "-") ? (rowDelegate.isSelected ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(0, 0, 0, 0.15)) : Colors.goldBorder) : "transparent"
                                            border.width: 1

                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 3
                                                Text {
                                                    visible: !rowDelegate.isFolder && !rowDelegate.isPending && model.crc && model.crc !== "-"
                                                    text: (model.healthStatus === 1) ? "\ue86c" : ((model.healthStatus === 2) ? "\ue5c9" : "\ue836")
                                                    font.family: materialIcons.name
                                                    font.pixelSize: (model.healthStatus === 1 || model.healthStatus === 2) ? 10 : 9
                                                    color: (model.healthStatus === 1) ? "#10B981" : ((model.healthStatus === 2) ? "#e05353" : (rowDelegate.isSelected ? (Colors.isDarkMode ? "#cbd5e1" : "#334155") : Colors.textMuted))
                                                }
                                                Text {
                                                    text: (model.crc !== undefined) ? model.crc : "-"
                                                    color: (!rowDelegate.isFolder && !rowDelegate.isPending && model.crc && model.crc !== "-") ? (rowDelegate.isSelected ? (Colors.isDarkMode ? "#f8fafc" : "#0f172a") : Colors.textMain) : (rowDelegate.isSelected ? (Colors.isDarkMode ? "#cbd5e1" : "#334155") : Colors.textMuted)
                                                    font.family: "Consolas, Segoe UI, monospace"
                                                    font.pixelSize: 10
                                                    font.bold: !rowDelegate.isFolder
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: itemMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        cursorShape: {
                                            if (window.isTreeDragActive)
                                                return Qt.DragMoveCursor;
                                            if (rowDelegate.canDrag)
                                                return Qt.OpenHandCursor;
                                            return Qt.PointingHandCursor;
                                        }

                                        property real pressGlobalX: -9999
                                        property real pressGlobalY: -9999
                                        property bool isDragging: false
                                        property bool nativeDragStarted: false

                                        onPressed: mouse => {
                                            if (mouse.button === Qt.LeftButton) {
                                                let gPt = mapToItem(window.contentItem, mouse.x, mouse.y);
                                                pressGlobalX = gPt.x;
                                                pressGlobalY = gPt.y;
                                                isDragging = false;
                                                nativeDragStarted = false;
                                            }
                                        }

                                        onPositionChanged: mouse => {
                                            if (!(pressed && (mouse.buttons & Qt.LeftButton))) return;
                                            if (pressGlobalX < 0) return;
                                            if (nativeDragStarted) return;

                                            let gPt = mapToItem(window.contentItem, mouse.x, mouse.y);
                                            let dist = Math.sqrt(Math.pow(gPt.x - pressGlobalX, 2) + Math.pow(gPt.y - pressGlobalY, 2));

                                            if (!isDragging) {
                                                if (dist <= 8) return;
                                                if (!rowDelegate.canDrag) {
                                                    if (rowDelegate.isPending)
                                                        statusText.text = "Item '" + rowDelegate.nodeName + "' is pending — commit before moving.";
                                                    return;
                                                }
                                                isDragging = true;
                                                window.draggedTreeItem = archiveInterface ? archiveInterface.treeModel.getNodeData(index) : null;
                                            }

                                            if (!window.draggedTreeItem) return;

                                            // 1. Outside application window: start native OS file drag
                                            let outsideWindow = (gPt.x < 0 || gPt.x > window.width || gPt.y < 0 || gPt.y > window.height);
                                            if (outsideWindow) {
                                                window.isTreeDragActive = false;
                                                window.dragTargetDir = "";
                                                window.dragTargetName = "";
                                                window.dragOverlayText = "";
                                                window.dragOverlayValid = false;

                                                nativeDragStarted = true;
                                                let node = window.draggedTreeItem;
                                                let archivePath = node.filePath || node.path || ("/" + node.name);
                                                if (!archivePath.startsWith("/")) archivePath = "/" + archivePath;
                                                let isDir = Boolean(node.isFolder);
                                                if (isDir && !archivePath.endsWith("/")) archivePath += "/";

                                                archiveInterface.startNativeFileDrag(archivePath, node.name, isDir);
                                                return;
                                            }

                                            // 2. Mouse inside file tree container: track directories and update overlay
                                            let treePt = mapToItem(treeContainer, mouse.x, mouse.y);
                                            let isInsideTree = (treePt.x >= 0 && treePt.x <= treeContainer.width && treePt.y >= 0 && treePt.y <= treeContainer.height);

                                            if (isInsideTree) {
                                                window.isTreeDragActive = true;
                                                window.dragOverlayX = Math.min(treeContainer.width - 240, Math.max(10, treePt.x + 14));
                                                window.dragOverlayY = Math.min(treeContainer.height - 44, Math.max(10, treePt.y + 14));

                                                let srcNode = window.draggedTreeItem;
                                                let srcName = srcNode.name || "Item";
                                                let srcPath = srcNode.filePath || srcNode.path || ("/" + srcName);
                                                if (!srcPath.startsWith("/")) srcPath = "/" + srcPath;
                                                if (srcNode.isFolder && !srcPath.endsWith("/")) srcPath += "/";

                                                // Check directory under cursor in mainTreeListView
                                                let listPt = mapToItem(mainTreeListView, mouse.x, mouse.y);
                                                let targetIdx = mainTreeListView.indexAt(listPt.x, listPt.y);

                                                if (targetIdx >= 0 && archiveInterface && archiveInterface.treeModel) {
                                                    let targetNode = archiveInterface.treeModel.getNodeData(targetIdx);
                                                    if (targetNode && targetNode.isFolder) {
                                                        let targetPath = targetNode.filePath || ("/" + targetNode.name);
                                                        if (!targetPath.startsWith("/")) targetPath = "/" + targetPath;
                                                        if (!targetPath.endsWith("/")) targetPath += "/";

                                                        let targetName = targetNode.name || targetPath;

                                                        // Validate destination
                                                        let isValid = true;
                                                        let invalidMsg = "";

                                                        if (srcPath === targetPath || (srcPath + "/") === targetPath) {
                                                            isValid = false;
                                                            invalidMsg = "Cannot move item into itself";
                                                        } else if (srcNode.isFolder && archiveInterface.treeModel.isFolderDescendant(srcPath, targetPath)) {
                                                            isValid = false;
                                                            invalidMsg = "Cannot move folder into its subfolder";
                                                        } else {
                                                            let stripped = srcPath.endsWith("/") ? srcPath.slice(0, -1) : srcPath;
                                                            let parentDir = stripped.substring(0, stripped.lastIndexOf("/") + 1);
                                                            if (!parentDir.startsWith("/")) parentDir = "/" + parentDir;
                                                            if (!parentDir.endsWith("/")) parentDir += "/";
                                                            if (parentDir === targetPath) {
                                                                isValid = false;
                                                                invalidMsg = "Already in " + targetName;
                                                            }
                                                        }

                                                        if (isValid) {
                                                            window.dragTargetDir = targetPath;
                                                            window.dragTargetName = targetName;
                                                            window.dragOverlayValid = true;
                                                            window.dragOverlayText = "Move " + srcName + " to " + targetName + " !";
                                                        } else {
                                                            window.dragTargetDir = "";
                                                            window.dragTargetName = "";
                                                            window.dragOverlayValid = false;
                                                            window.dragOverlayText = invalidMsg;
                                                        }
                                                    } else {
                                                        window.dragTargetDir = "";
                                                        window.dragTargetName = "";
                                                        window.dragOverlayValid = false;
                                                        window.dragOverlayText = "Drag over a folder to move " + srcName;
                                                    }
                                                } else {
                                                    window.dragTargetDir = "";
                                                    window.dragTargetName = "";
                                                    window.dragOverlayValid = false;
                                                    window.dragOverlayText = "Drag over a folder to move " + srcName;
                                                }
                                            } else {
                                                // 3. User dragged outside of file tree into main window section: dismiss drag operation
                                                window.isTreeDragActive = false;
                                                window.dragTargetDir = "";
                                                window.dragTargetName = "";
                                                window.dragOverlayText = "";
                                                window.dragOverlayValid = false;
                                            }
                                        }

                                        onReleased: mouse => {
                                            pressGlobalX = -9999;
                                            pressGlobalY = -9999;

                                            if (nativeDragStarted) {
                                                nativeDragStarted = false;
                                                isDragging = false;
                                                window.isTreeDragActive = false;
                                                window.draggedTreeItem = null;
                                                window.dragTargetDir = "";
                                                window.dragTargetName = "";
                                                window.dragOverlayText = "";
                                                window.dragOverlayValid = false;
                                                return;
                                            }

                                            if (isDragging) {
                                                isDragging = false;
                                                let wasActive = window.isTreeDragActive;
                                                let valid = window.dragOverlayValid;
                                                let targetDir = window.dragTargetDir;
                                                let targetName = window.dragTargetName;
                                                let srcNode = window.draggedTreeItem;

                                                window.isTreeDragActive = false;
                                                window.draggedTreeItem = null;
                                                window.dragTargetDir = "";
                                                window.dragTargetName = "";
                                                window.dragOverlayText = "";
                                                window.dragOverlayValid = false;

                                                if (wasActive && valid && targetDir !== "" && srcNode) {
                                                    let srcPath = srcNode.filePath || srcNode.path || ("/" + srcNode.name);
                                                    if (!srcPath.startsWith("/")) srcPath = "/" + srcPath;
                                                    let isDir = Boolean(srcNode.isFolder);
                                                    if (isDir && !srcPath.endsWith("/")) srcPath += "/";

                                                    if (archiveInterface && archiveInterface.moveArchiveItem(srcPath, targetDir, isDir)) {
                                                        moveToast.show(1, targetName || targetDir);
                                                        statusText.text = "Moved " + srcNode.name + " into '" + targetDir + "' (staged for commit)";
                                                    }
                                                }
                                                return;
                                            }
                                        }

                                        onCanceled: {
                                            pressGlobalX = -9999;
                                            pressGlobalY = -9999;
                                            isDragging = false;
                                            nativeDragStarted = false;
                                            window.isTreeDragActive = false;
                                            window.draggedTreeItem = null;
                                            window.dragTargetDir = "";
                                            window.dragTargetName = "";
                                            window.dragOverlayText = "";
                                            window.dragOverlayValid = false;
                                        }

                                        onClicked: mouse => {
                                            if (isDragging || nativeDragStarted) return;
                                            let nodeData = archiveInterface ? archiveInterface.treeModel.getNodeData(index) : {};
                                            let isCtrl = Boolean(mouse.modifiers & Qt.ControlModifier);
                                            window.selectItem(nodeData, isCtrl);

                                            if (mouse.button === Qt.RightButton) {
                                                treeContextMenu.targetItem = nodeData;
                                                treeContextMenu.parentFolderName = model.parentName || "";
                                                treeContextMenu.isTargetPending = rowDelegate.isPending;
                                                treeContextMenu.isBlankArea = false;
                                                let globalPoint = mapToItem(window.contentItem, mouse.x, mouse.y);
                                                treeContextMenu.x = Math.min(globalPoint.x, window.width - treeContextMenu.width - 10);
                                                treeContextMenu.y = Math.min(globalPoint.y, window.height - 240);
                                                treeContextMenu.open();
                                            } else if (mouse.button === Qt.LeftButton) {
                                                if (rowDelegate.isFolder && !isCtrl) {
                                                    if (archiveInterface && archiveInterface.treeModel) {
                                                        archiveInterface.treeModel.toggleExpand(index);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        id: loadingPlaceholder
                        anchors.fill: parent
                        visible: typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.isLoadingArchive

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 16

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 56
                                height: 56
                                radius: 28
                                color: Colors.isDarkMode ? Qt.rgba(0.9, 0.76, 0.35, 0.12) : Qt.rgba(0.69, 0.51, 0.12, 0.08)
                                border.color: Colors.goldBorder
                                border.width: 1

                                BusyIndicator {
                                    anchors.centerIn: parent
                                    running: loadingPlaceholder.visible
                                    width: 36
                                    height: 36
                                }
                            }

                            ColumnLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 4

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "Loading Archive..."
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                    color: Colors.textMain
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: (typeof archiveInterface !== "undefined" && archiveInterface) ? archiveInterface.statusMessage : "Parsing Table of Contents..."
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 11
                                    color: Colors.textMuted
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                    }

                    // Empty State Placeholder for File Tree View
                    Item {
                        id: emptyTreePlaceholder
                        anchors.fill: parent
                        visible: !(typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.isLoadingArchive) && ((typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.treeModel) ? (archiveInterface.treeModel.count === 0) : (!window.archiveTreeData || window.archiveTreeData.length === 0))

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 14
                            width: Math.min(parent.width - 40, 320)

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 56
                                height: 56
                                radius: 28
                                color: Colors.isDarkMode ? Qt.rgba(0.9, 0.76, 0.35, 0.08) : Qt.rgba(0.69, 0.51, 0.12, 0.06)
                                border.color: Colors.goldBorder
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "\ue2c8" // folder icon
                                    font.family: materialIcons.name
                                    font.pixelSize: 28
                                    color: Colors.goldPrimary
                                    opacity: 0.85
                                }
                            }

                            ColumnLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 4

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.hasArchive) ? "Archive is Empty" : "No Archive Loaded"
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                    color: Colors.textMain
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.hasArchive) ? "Drag and drop files here, or click Add Files to populate this archive" : "Open an existing archive or create a new one to begin"
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 11
                                    color: Colors.textMuted
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }
                            }

                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 10

                                // If no archive loaded: Open File button
                                Rectangle {
                                    visible: !(typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.hasArchive)
                                    implicitWidth: 108
                                    implicitHeight: 32
                                    radius: 6
                                    color: emptyOpenMouse.containsPress ? Qt.darker(Colors.goldPrimary, 1.15) : (emptyOpenMouse.containsMouse ? Colors.goldHover : Colors.goldPrimary)
                                    border.color: Colors.goldBorderHi
                                    border.width: 1

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 120
                                        }
                                    }

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Text {
                                            text: "\ue89e"
                                            font.family: materialIcons.name
                                            font.pixelSize: 14
                                            color: Colors.textOnGold
                                        }
                                        Text {
                                            text: "Open File"
                                            font.family: Colors.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                            color: Colors.textOnGold
                                        }
                                    }

                                    MouseArea {
                                        id: emptyOpenMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: openArchiveDialog.open()
                                    }
                                }

                                // If archive is loaded: Add Files button
                                Rectangle {
                                    visible: (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.hasArchive)
                                    implicitWidth: 116
                                    implicitHeight: 32
                                    radius: 6
                                    color: emptyAddFilesMouse.containsPress ? Qt.darker(Colors.goldPrimary, 1.15) : (emptyAddFilesMouse.containsMouse ? Colors.goldHover : Colors.goldPrimary)
                                    border.color: Colors.goldBorderHi
                                    border.width: 1

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 120
                                        }
                                    }

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Text {
                                            text: "\ue145"
                                            font.family: materialIcons.name
                                            font.pixelSize: 14
                                            color: Colors.textOnGold
                                        }
                                        Text {
                                            text: "Add Files..."
                                            font.family: Colors.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                            color: Colors.textOnGold
                                        }
                                    }

                                    MouseArea {
                                        id: emptyAddFilesMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: addFilesDialog.open()
                                    }
                                }

                                // Secondary button: New Archive or Close Archive
                                Rectangle {
                                    implicitWidth: 116
                                    implicitHeight: 32
                                    radius: 6
                                    color: emptyNewMouse.containsMouse ? Colors.bgHover : Colors.bgElevated
                                    border.color: Colors.goldBorder
                                    border.width: 1

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 120
                                        }
                                    }

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Text {
                                            text: (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.hasArchive) ? "\ue5cd" : "\ue145"
                                            font.family: materialIcons.name
                                            font.pixelSize: 14
                                            color: (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.hasArchive) ? Colors.textMuted : Colors.goldPrimary
                                        }
                                        Text {
                                            text: (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.hasArchive) ? "Close Archive" : "New Archive"
                                            font.family: Colors.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                            color: Colors.textMain
                                        }
                                    }

                                    MouseArea {
                                        id: emptyNewMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.hasArchive) {
                                                window.requestCloseArchive();
                                            } else {
                                                if (createArchiveLoader.item) {
                                                    if (createArchiveLoader.item.resetFields) {
                                                        createArchiveLoader.item.resetFields();
                                                    }
                                                    createArchiveLoader.item.open();
                                                } else {
                                                    createArchiveLoader.active = true;
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── External File Drop Area (from OS / Windows Explorer) ────────────
                    DropArea {
                        id: treeDropArea
                        anchors.fill: parent

                        property string targetFolderPath: ""
                        property bool isValidDropTarget: false

                        function resolveTargetFolder(dropX, dropY) {
                            if (typeof archiveInterface === "undefined" || !archiveInterface || !archiveInterface.hasArchive)
                                return "";
                            let localPt = mainTreeListView.mapFromItem(treeDropArea, dropX, dropY);
                            let idx = mainTreeListView.indexAt(localPt.x, localPt.y);
                            if (idx >= 0 && archiveInterface.treeModel) {
                                let node = archiveInterface.treeModel.getNodeData(idx);
                                if (node && node.isFolder) {
                                    let p = node.filePath || ("/" + node.name);
                                    if (!p.startsWith("/")) p = "/" + p;
                                    if (!p.endsWith("/")) p += "/";
                                    return p;
                                }
                                return "";
                            }
                            return "/"; // blank area = root
                        }

                        onEntered: drag => {
                            if (drag.hasUrls) {
                                drag.acceptProposedAction();
                            } else {
                                drag.accepted = false;
                            }
                        }

                        onPositionChanged: drag => {
                            if (drag.hasUrls) {
                                if (typeof archiveInterface === "undefined" || !archiveInterface || !archiveInterface.hasArchive) {
                                    targetFolderPath = "";
                                    isValidDropTarget = true;
                                    statusText.text = "Drop .sda archive to open";
                                    drag.acceptProposedAction();
                                    return;
                                }
                                let target = resolveTargetFolder(drag.x, drag.y);
                                targetFolderPath = target;
                                isValidDropTarget = true;
                                statusText.text = target !== "" ? ("Add file(s) into folder: '" + target + "'") : "Add file(s) to archive root (/)";
                                drag.acceptProposedAction();
                            }
                        }

                        onExited: {
                            targetFolderPath = "";
                            isValidDropTarget = false;
                            statusText.text = (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.hasArchive) ? "Ready" : "No archive open";
                        }

                        onDropped: drop => {
                            if (drop.hasUrls) {
                                let target = targetFolderPath;
                                targetFolderPath = "";
                                isValidDropTarget = false;

                                if (typeof archiveInterface === "undefined" || !archiveInterface || !archiveInterface.hasArchive) {
                                    drop.acceptProposedAction();
                                    if (!drop.urls || drop.urls.length === 0) return;
                                    let rawUrl = drop.urls[0].toString();
                                    let cleanPath = rawUrl;
                                    if (cleanPath.startsWith("file:///")) {
                                        cleanPath = (cleanPath.length >= 10 && cleanPath.charAt(9) === ':')
                                            ? cleanPath.substring(8)
                                            : cleanPath.substring(7);
                                    } else if (cleanPath.startsWith("file://")) {
                                        cleanPath = cleanPath.substring(7);
                                    }
                                    cleanPath = decodeURIComponent(cleanPath);
                                    if (!cleanPath.toLowerCase().endsWith(".sda")) {
                                        let fiName = cleanPath.split("/").pop().split("\\").pop();
                                        errorDialog.showError("Invalid Archive File", "The file '" + fiName + "' is not a valid SecDet Archive (.sda).\n\nOnly .sda archives can be opened directly. To add files to an archive, please create or open an archive first.");
                                        return;
                                    }
                                    if (typeof archiveInterface !== "undefined" && archiveInterface) {
                                        window.lastLoadingArchivePath = cleanPath;
                                        window.isUserLoadingArchive = true;
                                        archiveInterface.loadArchive(cleanPath);
                                    }
                                    return;
                                }

                                // Filter out any SecDet staging URLs
                                let validUrls = [];
                                for (let i = 0; i < drop.urls.length; ++i) {
                                    if (drop.urls[i].toString().indexOf("SecDet_Drag") === -1)
                                        validUrls.push(drop.urls[i]);
                                }
                                if (validUrls.length === 0) { drop.acceptProposedAction(); return; }
                                window.addPendingItems(validUrls, target || "/");
                                drop.acceptProposedAction();
                            }
                        }
                    }

                    // ── Tree Drag Floating Overlay (Follows Mouse Cursor) ────────────────
                    Rectangle {
                        id: treeDragOverlay
                        visible: window.isTreeDragActive && window.dragOverlayText !== ""
                        x: window.dragOverlayX
                        y: window.dragOverlayY
                        z: 1000
                        implicitHeight: 34
                        implicitWidth: overlayLayout.implicitWidth + 24
                        radius: 8
                        color: Colors.isDarkMode ? Qt.rgba(0.12, 0.15, 0.20, 0.96) : Qt.rgba(0.98, 0.98, 1.0, 0.96)
                        border.color: window.dragOverlayValid ? Colors.goldPrimary : (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(0, 0, 0, 0.2))
                        border.width: window.dragOverlayValid ? 1.5 : 1

                        RowLayout {
                            id: overlayLayout
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: window.dragOverlayValid ? "\ue5c8" : "\ue5cd"
                                font.family: materialIcons.name
                                font.pixelSize: 15
                                color: window.dragOverlayValid ? Colors.goldPrimary : Colors.textMuted
                            }

                            Text {
                                text: window.dragOverlayText
                                font.family: Colors.fontFamily
                                font.pixelSize: 11
                                font.weight: window.dragOverlayValid ? Font.Bold : Font.Normal
                                color: window.dragOverlayValid ? Colors.textMain : Colors.textMuted
                            }
                        }

                        Behavior on x {
                            NumberAnimation { duration: 40; easing.type: Easing.OutQuad }
                        }
                        Behavior on y {
                            NumberAnimation { duration: 40; easing.type: Easing.OutQuad }
                        }
                    }

                    // ── Tree Drag Bottom Status Banner ──────────────────────────────────
                    Rectangle {
                        id: treeDragBottomBanner
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 8
                        height: 38
                        radius: 8
                        color: Colors.isDarkMode ? Qt.rgba(0.10, 0.13, 0.18, 0.97) : Qt.rgba(0.97, 0.97, 0.99, 0.97)
                        border.color: window.dragOverlayValid ? Colors.goldPrimary : Colors.goldBorder
                        border.width: 1.5
                        z: 900

                        visible: opacity > 0
                        opacity: (window.isTreeDragActive && window.dragOverlayText !== "") ? 1.0 : 0.0

                        Behavior on opacity {
                            NumberAnimation { duration: 120 }
                        }
                        Behavior on border.color {
                            ColorAnimation { duration: 120 }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8

                            Text {
                                text: window.dragOverlayValid ? "\ue5c8" : "\ue88e"
                                font.family: materialIcons.name
                                font.pixelSize: 17
                                color: window.dragOverlayValid ? Colors.goldPrimary : Colors.textMuted
                            }

                            Text {
                                text: window.dragOverlayText
                                font.family: Colors.fontFamily
                                font.pixelSize: 11
                                font.weight: window.dragOverlayValid ? Font.Bold : Font.Normal
                                color: window.dragOverlayValid ? Colors.textMain : Colors.textMuted
                                Layout.fillWidth: true
                                elide: Text.ElideMiddle
                            }

                            Rectangle {
                                visible: window.dragOverlayValid
                                implicitWidth: 90
                                implicitHeight: 22
                                radius: 4
                                color: Colors.goldPrimary
                                Text {
                                    anchors.centerIn: parent
                                    text: "Release to Move"
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: Colors.textOnGold
                                }
                            }
                        }
                    }

                    // ── Move Confirmation Toast ─────────────────────────────────────────
                    // Slides in at bottom-right after a successful internal move, auto-dismisses
                    Rectangle {
                        id: moveToast
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.rightMargin: 12
                        anchors.bottomMargin: 56
                        width: 280
                        height: 42
                        radius: 8
                        color: Colors.isDarkMode ? Qt.rgba(0.08, 0.11, 0.15, 0.97) : Qt.rgba(0.97, 0.97, 0.99, 0.97)
                        border.color: "#10B981"
                        border.width: 1.5
                        z: 150

                        visible: opacity > 0
                        opacity: 0.0

                        property int movedCount: 0
                        property string targetFolder: ""

                        function show(count, folder) {
                            movedCount = count;
                            targetFolder = folder;
                            opacity = 1.0;
                            dismissTimer.restart();
                        }

                        Timer {
                            id: dismissTimer
                            interval: 2800
                            onTriggered: moveToast.opacity = 0.0
                        }

                        Behavior on opacity {
                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 10
                            spacing: 8

                            Text {
                                text: "\ue5ca"
                                font.family: materialIcons.name
                                font.pixelSize: 16
                                color: "#10B981"
                                Layout.alignment: Qt.AlignVCenter
                            }

                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                Text {
                                    text: "Move staged for commit"
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: Colors.textMain
                                }
                                Text {
                                    text: moveToast.movedCount + " item(s) → " + moveToast.targetFolder
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 10
                                    color: Colors.textMuted
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }



                    
                    // Scanning items
                    Rectangle {
                        id: addingItemsOverlay
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 40, 390)
                        height: 96
                        radius: 12
                        color: Colors.isDarkMode ? Qt.rgba(0.10, 0.12, 0.16, 0.96) : Qt.rgba(0.98, 0.98, 0.99, 0.96)
                        border.color: Colors.goldPrimary
                        border.width: 1
                        z: 110

                        visible: opacity > 0
                        opacity: (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.isAddingFiles) ? 1.0 : 0.0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                        }

                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 18
                            anchors.rightMargin: 18
                            height: 2.5
                            radius: 1.25
                            color: Colors.goldPrimary
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 14

                            Rectangle {
                                width: 44
                                height: 44
                                radius: 22
                                color: Colors.isDarkMode ? Qt.rgba(0.9, 0.76, 0.35, 0.12) : Qt.rgba(0.69, 0.51, 0.12, 0.08)
                                border.color: Colors.goldBorder
                                border.width: 1
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: "\ue5d5" // sync / refresh icon
                                    font.family: materialIcons.name
                                    font.pixelSize: 22
                                    color: Colors.goldPrimary

                                    RotationAnimation on rotation {
                                        from: 0
                                        to: 360
                                        duration: 1000
                                        loops: Animation.Infinite
                                        running: addingItemsOverlay.visible
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 3

                                Text {
                                    text: "Scanning Folder"
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    color: Colors.textMain
                                }

                                Text {
                                    text: "Indexing is in progress....."
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 10
                                    color: Colors.textMuted
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.topMargin: 3

                                    // Folders counter
                                    RowLayout {
                                        spacing: 4
                                        Text {
                                            text: "\ue2c7" // folder icon
                                            font.family: materialIcons.name
                                            font.pixelSize: 13
                                            color: Colors.goldPrimary
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                        Text {
                                            text: "Folders:"
                                            font.family: Colors.fontFamily
                                            font.pixelSize: 10
                                            color: Colors.textMuted
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                        Text {
                                            text: (typeof archiveInterface !== "undefined" && archiveInterface) ? archiveInterface.indexedFolders.toLocaleString() : "0"
                                            font.family: Colors.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                            color: Colors.textMain
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                    }

                                    // Divider
                                    Rectangle {
                                        width: 1
                                        height: 11
                                        color: Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    // Files counter
                                    RowLayout {
                                        spacing: 4
                                        Text {
                                            text: "\ue873" // file icon
                                            font.family: materialIcons.name
                                            font.pixelSize: 13
                                            color: Colors.goldPrimary
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                        Text {
                                            text: "Files:"
                                            font.family: Colors.fontFamily
                                            font.pixelSize: 10
                                            color: Colors.textMuted
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                        Text {
                                            text: (typeof archiveInterface !== "undefined" && archiveInterface) ? archiveInterface.indexedFiles.toLocaleString() : "0"
                                            font.family: Colors.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                            color: Colors.textMain
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Loader {
                    id: infoPageLoader
                    Layout.fillHeight: true
                    Layout.fillWidth: false
                    Layout.preferredWidth: 580
                    Layout.minimumWidth: 520
                    Layout.maximumWidth: 680

                    visible: false
                    active: visible
                    source: "ArchiveInfoPage.qml"

                    onVisibleChanged: {
                        if (visible && item) {
                            if (window.selectedTreeItem) {
                                let path = window.selectedTreeItem.filePath || window.selectedTreeItem.path || ("/" + window.selectedTreeItem.name);
                                let isFolder = Boolean(window.selectedTreeItem.isFolder);
                                item.navigateToItem(path, isFolder);
                            }
                        }
                    }

                    onLoaded: {
                        item.closeRequested.connect(() => {
                            infoPageLoader.visible = false;
                        });
                        item.itemNavigated.connect((path, isFolder) => {
                            if (infoPageLoader.visible) {
                                window.navigateToFileTreePath(path);
                            }
                        });
                        if (visible && window.selectedTreeItem) {
                            let path = window.selectedTreeItem.filePath || window.selectedTreeItem.path || ("/" + window.selectedTreeItem.name);
                            let isFolder = Boolean(window.selectedTreeItem.isFolder);
                            item.navigateToItem(path, isFolder);
                        }
                    }
                }

                Loader {
                    id: recoveryPageLoader
                    Layout.fillHeight: true
                    Layout.fillWidth: false
                    Layout.preferredWidth: 580
                    Layout.minimumWidth: 520
                    Layout.maximumWidth: 680

                    visible: false
                    active: visible
                    source: "ArchiveRecoveryTools.qml"

                    onLoaded: {
                        item.closeRequested.connect(() => {
                            recoveryPageLoader.visible = false;
                        });
                    }
                }
            }
        }
        
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            spacing: 8

            Rectangle {
                width: 7
                height: 7
                radius: 3.5
                color: Colors.goldPrimary
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                id: liveStatusBarText
                text: statusText.text
                color: Colors.textMuted
                font.family: Colors.fontFamily
                font.pixelSize: 11
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            Layout.maximumHeight: 36
            implicitHeight: 36
            spacing: 8


            MultiPartProgressBar {
                id: bottomProgressBar
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: 36
                Layout.maximumHeight: 36
                implicitHeight: 36
                forceText: true
                onProgressClicked: {
                    if (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.isBusy) {
                        progressWindow.show();
                        progressWindow.raise();
                        progressWindow.requestActivate();
                    }
                }
                onRetryRequested: (index, jobId) => {
                    progressWindow.resetProgressState();
                    progressWindow.show();
                    progressWindow.raise();
                    progressWindow.requestActivate();
                }
            }

            Rectangle {
                id: bottomCommitButton
                Layout.preferredWidth: commitRow.implicitWidth + 24
                Layout.fillHeight: true
                Layout.preferredHeight: 36
                implicitHeight: 36
                radius: 6

                property bool isOptimizing: typeof archiveInterface !== "undefined" && archiveInterface && ((archiveInterface.isOptimizing !== undefined && archiveInterface.isOptimizing) || false)
                property bool isCommitting: typeof archiveInterface !== "undefined" && archiveInterface && ((archiveInterface.isCommitting !== undefined && archiveInterface.isCommitting) || false)
                property bool hasPendingChanges: typeof archiveInterface !== "undefined" && archiveInterface && ((archiveInterface.hasUncommittedChanges !== undefined && archiveInterface.hasUncommittedChanges) || (archiveInterface.pendingJobCount !== undefined && archiveInterface.pendingJobCount > 0))
                property int pendingCount: (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.pendingJobCount !== undefined) ? archiveInterface.pendingJobCount : 0


                color: {
                    if (isOptimizing) {
                        return Colors.isDarkMode ? Qt.rgba(0.95, 0.65, 0.15, 0.22) : Qt.rgba(0.90, 0.55, 0.10, 0.18);
                    }
                    if (isCommitting) {
                        return Colors.isDarkMode ? Qt.rgba(0.9, 0.76, 0.35, 0.16) : Qt.rgba(0.69, 0.51, 0.12, 0.14);
                    }
                    if (hasPendingChanges) {
                        if (commitMouse.pressed)
                            return "#c49200";
                        if (commitMouse.containsMouse)
                            return "#ffd738";
                        return Colors.goldPrimary;
                    }
                    if (commitMouse.pressed)
                        return Qt.rgba(1, 1, 1, 0.10);
                    if (commitMouse.containsMouse)
                        return Qt.rgba(1, 1, 1, 0.07);
                    return Colors.bgCard;
                }

                border.width: 1
                border.color: {
                    if (isOptimizing) {
                        return Colors.goldPrimary;
                    }
                    if (isCommitting) {
                        return Colors.goldBorderHi;
                    }
                    if (hasPendingChanges) {
                        return commitMouse.containsMouse ? "#ffffff" : Colors.goldLight;
                    }
                    return commitMouse.containsMouse ? Colors.borderFocus : Colors.borderSubtle;
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
                Behavior on border.color {
                    ColorAnimation {
                        duration: 150
                    }
                }

                function resetCommitIconRotation() {
                    if (!isCommitting && !isOptimizing) {
                        if (typeof commitIconText !== "undefined" && commitIconText) {
                            commitIconText.rotation = 0;
                        }
                        Qt.callLater(function () {
                            if (typeof commitIconText !== "undefined" && commitIconText && !bottomCommitButton.isCommitting && !bottomCommitButton.isOptimizing) {
                                commitIconText.rotation = 0;
                            }
                        });
                    }
                }

                onIsOptimizingChanged: resetCommitIconRotation()
                onIsCommittingChanged: resetCommitIconRotation()
                onHasPendingChangesChanged: resetCommitIconRotation()


                SequentialAnimation on border.color {
                    running: (bottomCommitButton.hasPendingChanges || bottomCommitButton.isOptimizing) && !bottomCommitButton.isCommitting && !commitMouse.containsMouse
                    loops: Animation.Infinite
                    ColorAnimation {
                        from: bottomCommitButton.isOptimizing ? "#ff9500" : Colors.goldLight
                        to: bottomCommitButton.isOptimizing ? "#ffd700" : Colors.goldPrimary
                        duration: bottomCommitButton.isOptimizing ? 500 : 1100
                    }
                    ColorAnimation {
                        from: bottomCommitButton.isOptimizing ? "#ffd700" : Colors.goldPrimary
                        to: bottomCommitButton.isOptimizing ? "#ff9500" : Colors.goldLight
                        duration: bottomCommitButton.isOptimizing ? 500 : 1100
                    }
                }

                RowLayout {
                    id: commitRow
                    anchors.centerIn: parent
                    spacing: 7

                    Text {
                        id: commitIconText
                        transformOrigin: Item.Center
                        rotation: 0
                        text: {
                            if (bottomCommitButton.isOptimizing)
                                return "\ue8b8";
                            if (bottomCommitButton.isCommitting)
                                return "\ue86a";
                            return "\ue161";
                        }
                        font.family: materialIcons.name
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        color: (bottomCommitButton.isCommitting || bottomCommitButton.isOptimizing) ? Colors.goldPrimary : (bottomCommitButton.hasPendingChanges ? Colors.textOnGold : Colors.textMuted)
                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }

                        RotationAnimation {
                            id: commitRotateAnim
                            target: commitIconText
                            property: "rotation"
                            running: bottomCommitButton.isCommitting || bottomCommitButton.isOptimizing
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: bottomCommitButton.isOptimizing ? 700 : 1000
                            onRunningChanged: {
                                if (!running) {
                                    bottomCommitButton.resetCommitIconRotation();
                                }
                            }
                            onStopped: {
                                bottomCommitButton.resetCommitIconRotation();
                            }
                        }
                    }

                    Text {
                        text: {
                            if (bottomCommitButton.isOptimizing)
                                return "Optimizing...";
                            if (bottomCommitButton.isCommitting)
                                return "Committing...";
                            return "Commit";
                        }
                        font.family: Colors.fontFamily
                        font.pixelSize: 12
                        font.weight: (bottomCommitButton.hasPendingChanges || bottomCommitButton.isCommitting || bottomCommitButton.isOptimizing) ? Font.Bold : Font.Medium
                        color: (bottomCommitButton.isCommitting || bottomCommitButton.isOptimizing) ? Colors.goldPrimary : (bottomCommitButton.hasPendingChanges ? Colors.textOnGold : Colors.textMuted)
                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                    }


                    Rectangle {
                        visible: bottomCommitButton.hasPendingChanges && !bottomCommitButton.isCommitting && !bottomCommitButton.isOptimizing
                        Layout.preferredWidth: Math.max(18, countText.implicitWidth + 8)
                        Layout.preferredHeight: 18
                        radius: 9
                        color: Qt.rgba(0, 0, 0, 0.35)

                        Text {
                            id: countText
                            anchors.centerIn: parent
                            text: bottomCommitButton.pendingCount > 0 ? bottomCommitButton.pendingCount : "!"
                            font.family: Colors.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: "#ffffff"
                        }
                    }
                }

                MouseArea {
                    id: commitMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !bottomCommitButton.isCommitting && !bottomCommitButton.isOptimizing
                    cursorShape: (bottomCommitButton.isCommitting || bottomCommitButton.isOptimizing) ? Qt.ArrowCursor : (bottomCommitButton.hasPendingChanges ? Qt.PointingHandCursor : Qt.ArrowCursor)
                    onClicked: {
                        if (bottomCommitButton.isCommitting || bottomCommitButton.isOptimizing) {
                            return;
                        }

                        if (!bottomCommitButton.hasPendingChanges) {
                            commitToolTip.show("There is nothing to commit", 2500);
                            statusText.text = "There is nothing to commit.";
                            return;
                        }

                        window.startCommitWorkflow();
                    }
                }

                ToolTip {
                    id: commitToolTip
                    visible: commitMouse.containsMouse && !bottomCommitButton.isCommitting && !bottomCommitButton.isOptimizing
                    delay: 400
                    text: {
                        if (bottomCommitButton.isOptimizing) {
                            return "Optimizing job queue...";
                        }
                        if (bottomCommitButton.isCommitting) {
                            return "Commit in progress...";
                        }
                        if (bottomCommitButton.hasPendingChanges) {
                            return "Commit " + (bottomCommitButton.pendingCount > 0 ? bottomCommitButton.pendingCount + " pending change(s)" : "pending changes") + " to archive";
                        }
                        return "There is nothing to commit";
                    }
                }
            }
        }
    }




    Component.onCompleted: {
        if (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.hasArchive) {
            window.archiveTreeData = archiveInterface.archiveTree;
        } else {
            window.archiveTreeData = [];
        }
    }
}
