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
        property color indicatorColor: "#10B981"
        signal clicked

        implicitWidth: 62
        implicitHeight: 50
        opacity: enabled ? 1.0 : 0.38

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }

        // Hover / Active Background Rectangle
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

        // Active indicator dot in top right
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

            // Subtle glow ring
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

    // ==========================================
    // --- Clean Interfaces for Tree Actions ---
    // ==========================================
    signal itemMoved(var moveEvent)
    signal externalDragStarted(var exportEvent)
    signal fileDragExportRequested(var exportEvent)
    signal pendingFilesAdded(var pendingEvent)
    signal pendingCommitted(var commitEvent)

    property var lastTreeAction: null

    function getExternalDragInterface() {
        return {
            name: "SecDet External Drag Interface",
            version: "1.0",
            exportActive: dragManager.isDragging,
            draggedItem: dragManager.draggedItem,
            lastExport: lastTreeAction
        };
    }

    // Status Objects
    QtObject {
        id: statusText
        property string text: (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.hasArchive) ? ("Ready • " + archiveInterface.archiveFileName + " loaded") : "Ready • No archive loaded"
    }

    QtObject {
        id: pBar
        property real value: 0.0
    }

    // Centralized Reactive Tree Model & Multi-Selection Tracking
    readonly property bool hasArchive: typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.hasArchive
    property var archiveTreeData: []
    property var selectedTreeItem: null
    property var selectedItemMap: ({})
    property int selectedCount: 0

    // Standardized Tree Column Width Constants (shared between sticky header & row delegates)
    readonly property int colCompressedWidth: 95
    readonly property int colRealWidth: 95
    readonly property int colRatioWidth: 60
    readonly property int colCrcWidth: 95

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

        // Synchronize navigation to archive info file map if the page is open
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

        // 1. Remove the item from its current location
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

        // 2. Insert into the target folder
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

    // Folder hit-testing registry for bulletproof drag & drop
    property var registeredFolderRows: ({})

    function registerFolderRow(path, name, rowItem) {
        registeredFolderRows[path] = {
            name: name,
            path: path,
            item: rowItem
        };
    }

    function unregisterFolderRow(path) {
        delete registeredFolderRows[path];
    }

    function isFolderDescendant(parentName, checkName) {
        if (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.treeModel) {
            return archiveInterface.treeModel.isFolderDescendant(parentName, checkName);
        }
        function searchIn(nodes) {
            if (!nodes)
                return false;
            for (let i = 0; i < nodes.length; ++i) {
                if ((nodes[i].name === parentName || nodes[i].filePath === parentName) && nodes[i].isFolder) {
                    return hasChildRecursive(nodes[i].children, checkName);
                }
                if (nodes[i].children && searchIn(nodes[i].children))
                    return true;
            }
            return false;
        }
        function hasChildRecursive(children, target) {
            if (!children)
                return false;
            for (let c = 0; c < children.length; ++c) {
                if (children[c].name === target || children[c].filePath === target)
                    return true;
                if (children[c].children && hasChildRecursive(children[c].children, target))
                    return true;
            }
            return false;
        }
        return searchIn(archiveTreeData);
    }

    function findFolderTargetAt(globalX, globalY) {
        for (let pathKey in registeredFolderRows) {
            let entry = registeredFolderRows[pathKey];
            let rowItem = entry ? entry.item : null;
            if (rowItem && rowItem.visible) {
                let localPt = rowItem.mapFromItem(window.contentItem, globalX, globalY);
                if (localPt.x >= 0 && localPt.x <= rowItem.width && localPt.y >= 0 && localPt.y <= rowItem.height) {
                    return entry;
                }
            }
        }
        return null;
    }

    QtObject {
        id: dragManager

        property bool isDragging: false
        property var draggedItem: null
        property string sourceParentFolder: ""
        property string activeTargetFolder: ""
        property string activeTargetPath: ""
        property real mouseX: 0
        property real mouseY: 0

        function startDrag(itemData, parentFolderName, startX, startY) {
            draggedItem = itemData;
            sourceParentFolder = parentFolderName;
            activeTargetFolder = "";
            activeTargetPath = "";
            mouseX = startX;
            mouseY = startY;
            isDragging = true;
            statusText.text = "Dragging '" + itemData.name + "' • Drop on a folder to move, or outside to export";
        }

        function updatePosition(globalX, globalY) {
            if (!isDragging)
                return;
            mouseX = globalX;
            mouseY = globalY;

            let hit = window.findFolderTargetAt(globalX, globalY);
            if (hit && hit.name !== sourceParentFolder && hit.name !== draggedItem.name && hit.path !== draggedItem.filePath) {
                if (draggedItem.isFolder && window.isFolderDescendant(draggedItem.filePath || draggedItem.name, hit.path || hit.name)) {
                    activeTargetFolder = "";
                    activeTargetPath = "";
                    statusText.text = "Cannot move folder '" + draggedItem.name + "' into its own subfolder";
                } else {
                    activeTargetFolder = hit.name;
                    activeTargetPath = hit.path;
                    statusText.text = "Drop to move '" + draggedItem.name + "' into folder '" + (hit.path || hit.name) + "'";
                }
            } else {
                activeTargetFolder = "";
                activeTargetPath = "";
                let treePt = treeContainer.mapFromItem(window.contentItem, globalX, globalY);
                let isOutside = (treePt.x < 0 || treePt.x > treeContainer.width || treePt.y < 0 || treePt.y > treeContainer.height);
                if (isOutside) {
                    statusText.text = "Release to export '" + draggedItem.name + "' outside archive (External Export)";
                } else {
                    statusText.text = "Dragging '" + draggedItem.name + "' • Drop on a folder to move";
                }
            }
        }

        function finishDrag(globalX, globalY) {
            if (!isDragging)
                return;

            let item = draggedItem;
            let srcParent = sourceParentFolder;
            let targetName = activeTargetFolder;
            let targetPath = activeTargetPath;

            let treePt = treeContainer.mapFromItem(window.contentItem, globalX, globalY);
            let isOutside = (treePt.x < 0 || treePt.x > treeContainer.width || treePt.y < 0 || treePt.y > treeContainer.height);

            isDragging = false;
            draggedItem = null;
            sourceParentFolder = "";
            activeTargetFolder = "";
            activeTargetPath = "";

            if (isOutside) {
                window.handleExternalDragOut(item, srcParent);
            } else if (targetName !== "" && targetName !== srcParent) {
                window.executeMoveItem(item, srcParent, targetName, targetPath);
            } else {
                statusText.text = "Drag completed without move. Items can only be dropped into different folders.";
            }
        }

        function cancelDrag() {
            isDragging = false;
            draggedItem = null;
            sourceParentFolder = "";
            activeTargetFolder = "";
            activeTargetPath = "";
        }
    }

    function startNativeItemDrag(itemData, parentFolderName) {
        if (!itemData)
            return;
        let archivePath = itemData.filePath || itemData.path || ("/" + (parentFolderName ? parentFolderName + "/" : "") + itemData.name);
        if (!archivePath.startsWith("/"))
            archivePath = "/" + archivePath;
        if (itemData.isFolder && !archivePath.endsWith("/"))
            archivePath = archivePath + "/";

        ensureKeyRegistered(function () {
            if (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.hasArchive) {
                let pathsToDrag = [archivePath];
                // If multiple items are selected and the dragged item is in the selection, drag all selected items!
                if (window.selectedCount > 1 && window.isItemSelected(itemData.filePath || itemData.path || itemData.name)) {
                    let selList = window.getSelectedItemsList();
                    let collected = [];
                    for (let i = 0; i < selList.length; ++i) {
                        let p = selList[i].filePath || selList[i].path || ("/" + selList[i].name);
                        if (!p.startsWith("/")) p = "/" + p;
                        if (selList[i].isFolder && !p.endsWith("/")) p = p + "/";
                        collected.push(p);
                    }
                    if (collected.length > 0) {
                        pathsToDrag = collected;
                    }
                }

                let exportDetails = {
                    action: "EXTERNAL_EXPORT_DRAG",
                    item: {
                        name: itemData.name,
                        isFolder: itemData.isFolder,
                        realSize: itemData.realSize,
                        compressedSize: itemData.compressedSize,
                        ratio: itemData.ratio
                    },
                    archiveSourcePath: archivePath,
                    exportTarget: "NATIVE_DESKTOP_DROP",
                    timestamp: new Date().toISOString()
                };
                lastTreeAction = exportDetails;
                externalDragStarted(exportDetails);
                fileDragExportRequested(exportDetails);

                archiveInterface.startNativeDrag(pathsToDrag, itemData.name, Boolean(itemData.isFolder));
            }
        });
    }

    function handleExternalDragOut(itemData, parentFolderName) {
        startNativeItemDrag(itemData, parentFolderName);
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

            // ACTION: Commit to Archive (Only for Pending items)
            ContextMenuItem {
                text: "Commit to Archive"
                iconText: "\ue2c6"
                accentColor: Colors.goldPrimary
                visible: treeContextMenu.isTargetPending
                onClicked: {
                    let targetName = treeContextMenu.targetItem ? treeContextMenu.targetItem.name : "";
                    treeContextMenu.close();
                    if (targetName.length > 0) {
                        commitPendingItem(targetName);
                    }
                }
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

            // ACTION: Test File (Committed files only)
            ContextMenuItem {
                text: "Test File"
                iconText: "\ue86c"
                accentColor: Colors.goldPrimary
                visible: !treeContextMenu.isBlankArea && (!treeContextMenu.targetItem || !treeContextMenu.targetItem.isFolder) && !treeContextMenu.isTargetPending
                onClicked: {
                    let target = treeContextMenu.targetItem;
                    treeContextMenu.close();
                    if (target) {
                        launchTestFile(target);
                    }
                }
            }

            // ACTION: Shannon Entropy & Hashes (Files)
            ContextMenuItem {
                text: "Shannon Entropy & Hashes"
                iconText: "\ue88e"
                visible: !treeContextMenu.isBlankArea && (!treeContextMenu.targetItem || !treeContextMenu.targetItem.isFolder)
                onClicked: {
                    treeContextMenu.close();
                    statusText.text = "Calculating entropy & SHA-256 for '" + treeContextMenu.targetItem.name + "'...";
                    infoPageLoader.visible = true;
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
                text: "Add Files to Root..."
                iconText: "\ue145"
                visible: treeContextMenu.isBlankArea
                onClicked: {
                    treeContextMenu.close();
                    window.pendingAddTargetFolder = "/";
                    addFilesDialog.open();
                }
            }

            ContextMenuItem {
                text: "New Root Folder"
                iconText: "\ue2cc"
                visible: treeContextMenu.isBlankArea
                onClicked: {
                    treeContextMenu.close();
                    addPendingItems(["file:///New_Folder"], null);
                }
            }

            ContextMenuItem {
                text: "Refresh View"
                iconText: "\ue5d5"
                visible: treeContextMenu.isBlankArea
                onClicked: {
                    treeContextMenu.close();
                    statusText.text = "Archive view refreshed.";
                }
            }
        }
    }
    FileDialog {
        id: openArchiveDialog
        title: "Open Secure Detective Archive"
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
        closingSecuringDialog.close();
        window.closeArchiveDirectly();
        window.exitApplication();
    }

    function handleWindowCloseRequest() {
        // 1. If an operation is running, cancel that operation first so the TOC won't get damaged, then close
        if (window.isOperationRunning()) {
            window.pendingExitAfterOperationCancel = true;
            window.pendingExitAfterCommit = false;
            statusText.text = "Cancelling operation and securing archive before closing...";
            if (typeof progressWindow !== "undefined" && progressWindow && progressWindow.visible) {
                progressWindow.isCanceling = true;
            }
            if (typeof archiveInterface !== "undefined" && archiveInterface) {
                archiveInterface.cancelCurrentOperation();
            }
            forceExitTimer.restart();
            closingSecuringDialog.open();
            return;
        }

        // 2. If there are uncommitted jobs, show the same popup as the file header on top of file tree close button shows
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

        // 3. No operation running, and no uncommitted changes
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
            // Worker thread job optimization is initiated
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
        registeredFolderRows = ({});
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
                    progressWindow.show();
                    progressWindow.raise();
                    progressWindow.requestActivate();

                    let success = false;
                    if (target && target.path) {
                        success = archiveInterface.extractItem(target.path, dest);
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
        function onDragStagingStarted(itemName) {
            progressWindow.resetProgressState();
            progressWindow.title = "Extracting: " + itemName;
            progressWindow.currentFileName = itemName;
            progressWindow.show();
            progressWindow.raise();
            progressWindow.requestActivate();
        }
        function onDragStagingCompleted() {
            // Drag extraction finished; onOperationCompleted smoothly animates 100% completion and closes via timer
        }
        function onArchiveTreeChanged() {
            window.archiveTreeData = archiveInterface.archiveTree;
        }
        function onArchiveLoadedChanged(loaded) {
            window.registeredFolderRows = ({});
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
                // Scroll to deleted jobs sequentially and play the catchy deletion animation
                bottomProgressBar.playOptimizationDeletionSequence(deletedJobIds, function () {
                    // When deletion sequence finishes: open progress window & start main commit task!
                    window.launchCommitAndShowProgress();
                });
            } else {
                // No jobs eliminated: directly open progress window & start main commit task!
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
                        text: "\ue002" // warning icon
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

                // Discard & Close button (subtle danger style)
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
        id: closingSecuringDialog
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
                        text: "\ue5d5" // refresh / sync icon
                        font.family: materialIcons.name
                        font.pixelSize: 24
                        color: Colors.goldPrimary

                        RotationAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 1000
                            loops: Animation.Infinite
                            running: closingSecuringDialog.visible
                        }
                    }
                }

                ColumnLayout {
                    spacing: 3
                    Layout.fillWidth: true

                    Text {
                        text: "Securing Archive"
                        font.family: Colors.fontFamily
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        color: Colors.textMain
                    }

                    Text {
                        text: "Cancelling active operation..."
                        font.family: Colors.fontFamily
                        font.pixelSize: 12
                        color: Colors.textMuted
                    }
                }
            }

            Text {
                text: "An operation is currently in progress. Stopping active tasks safely and preserving archive table of contents integrity before closing..."
                font.family: Colors.fontFamily
                font.pixelSize: 13
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
                        running: closingSecuringDialog.visible
                    }
                }
            }
        }
    }

    Timer {
        id: forceExitTimer
        interval: 8000
        repeat: false
        onTriggered: {
            console.warn("Securing timeout reached, forcing exit.");
            closingSecuringDialog.close();
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

    // Note: Archive settings have been moved into the bottom of ArchiveInfoPage.

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

        // ==========================================
        // --- Top Function & Actions Rectangle ---
        // ==========================================
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

                // 1. Create Archive (Warm Gold / Amber Accent)
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

                // 2. Open Archive (Updated folder_open icon)
                IslandButton {
                    iconText: "\ue2c8" // folder_open
                    labelText: "Open"
                    accentColor: Colors.goldPrimary
                    onClicked: {
                        openArchiveDialog.open();
                    }
                }

                // Vertical Separator
                Rectangle {
                    width: 1
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    color: Colors.divider
                }

                // 3. Extract All (Extracts entire archive, active when archive is loaded)
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

                // 4. Extract (Active only when item(s) selected in tree)
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

                // 5. Delete / Purge Action (Active only when item(s) selected in tree)
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

                // 6. Test File Integrity (Active only when a file is selected in tree)
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

                // 7. Test Entire Archive Integrity (Active when archive is loaded)
                IslandButton {
                    iconText: "\ue8e8" // verified_user (shield with checkmark)
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

                // 8. Inspect Archive Info Page (Active when archive is loaded)
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

                // 9. Inspect Archive Recovery Tools (Independent context, always accessible)
                IslandButton {
                    id: recoveryBtn
                    readonly property bool hasRecoveryOpen: (typeof archiveInterface !== "undefined" && archiveInterface) ? archiveInterface.hasRecoveryArchive : false

                    iconText: "\ue869" // build / repair tool icon
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

            // --- Tab Strip Bar (Chrome-style Archive Tab) ---
            Item {
                id: tabStripItem
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                height: 36
                z: 10

                // Active Archive Tab
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

                        // Archive Header Key Icon Button (Click to unlock archive)
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
                        }

                        // Close Button for active archive tab
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
                                text: "\ue5cd" // close
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

                    // Seamless Bottom Eraser Patch
                    // Seamlessly removes the tab bottom border and masks the treeContainer top border directly underneath
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

            // --- Main Content Views (Tree & Info Page) ---
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

                    border.color: treeDropArea.containsDrag ? Colors.goldPrimary : Colors.goldBorder
                    border.width: treeDropArea.containsDrag ? 2 : 1

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

                    // Background right-click menu & left-click deselection for empty/blank tree area
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

                        // 1. Sticky Tree Header
                        Rectangle {
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
                                    text: "CRC (Health)"
                                    color: Colors.textMuted
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    Layout.preferredWidth: window.colCrcWidth
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }

                        // 2. High-Performance Virtualized ListView
                        ListView {
                            id: mainTreeListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            spacing: 2
                            model: (typeof archiveInterface !== "undefined" && archiveInterface) ? archiveInterface.treeModel : null

                            // Deselect when clicking on empty area below items
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
                                height: 34

                                readonly property bool isPending: model.pending
                                readonly property bool isSelected: window.isItemSelected(model.filePath || rowDelegate.nodeName)
                                readonly property bool canDrag: !isPending
                                readonly property bool isFolder: model.isFolder
                                readonly property bool isOpen: model.expanded
                                readonly property string nodeName: model.name

                                Component.onCompleted: {
                                    if (rowDelegate.isFolder) {
                                        window.registerFolderRow(model.filePath || rowDelegate.nodeName, rowDelegate.nodeName, itemRowRect);
                                    }
                                }

                                Component.onDestruction: {
                                    if (rowDelegate.isFolder) {
                                        window.unregisterFolderRow(model.filePath || rowDelegate.nodeName);
                                    }
                                }

                                Rectangle {
                                    id: itemRowRect
                                    anchors.fill: parent
                                    radius: 6

                                    readonly property bool isDropTargetHovered: (dragManager.isDragging && (dragManager.activeTargetPath === model.filePath || dragManager.activeTargetFolder === rowDelegate.nodeName)) || (treeDropArea.containsDrag && treeDropArea.externalTargetFolder && (treeDropArea.externalTargetFolder.path === model.filePath || treeDropArea.externalTargetFolder.name === rowDelegate.nodeName))

                                    // Darkened Silver 70% opacity background for selection; Gold for pending; Fluent hover for normal
                                    color: isDropTargetHovered ? Colors.goldLightHover : rowDelegate.isPending ? (itemMouse.containsMouse ? Colors.goldLightHover : (Colors.isDarkMode ? Qt.rgba(0.9, 0.76, 0.35, 0.09) : Qt.rgba(0.69, 0.51, 0.12, 0.08))) : rowDelegate.isSelected ? (Colors.isDarkMode ? Qt.rgba(0.32, 0.36, 0.44, 0.70) : Qt.rgba(0.55, 0.58, 0.65, 0.70)) : itemMouse.containsPress ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.08)) : itemMouse.containsMouse ? Colors.bgHover : "transparent"

                                    // Darkened Silver border for selection; Gold for pending
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

                                        // Left Indicator Bar (Gold for pending, Silver/White for selected)
                                        Rectangle {
                                            width: 3
                                            height: 18
                                            radius: 1.5
                                            color: rowDelegate.isPending ? Colors.goldPrimary : (rowDelegate.isSelected ? (Colors.isDarkMode ? "#cbd5e1" : "#475569") : "transparent")
                                            visible: rowDelegate.isPending || rowDelegate.isSelected
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        // Expand/Collapse Chevron
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

                                        // Folder / File Icon
                                        Text {
                                            text: rowDelegate.isFolder ? (rowDelegate.isOpen ? "\ue2c8" : "\ue2c7") : (rowDelegate.isPending ? "\ue2c6" : "\ue873")
                                            font.family: materialIcons.name
                                            font.pixelSize: 18
                                            color: rowDelegate.isPending ? Colors.goldHover : (rowDelegate.isSelected ? (rowDelegate.isFolder ? (Colors.isDarkMode ? "#fbbf24" : "#b45309") : (Colors.isDarkMode ? "#e2e8f0" : "#1e293b")) : (rowDelegate.isFolder ? Colors.goldPrimary : Colors.textMuted))
                                            Layout.preferredWidth: 18
                                        }

                                        // File / Folder Name
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
                                                    text: dragManager.isDragging ? "Move into folder" : "Add into folder"
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

                                        // Divider before CRC
                                        Rectangle {
                                            visible: !itemRowRect.isDropTargetHovered
                                            width: 1
                                            height: 14
                                            color: rowDelegate.isSelected ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.16)) : Colors.divider
                                        }

                                        // Column 4: CRC (Health)
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

                                    // MouseArea for Selection, Right-Click Menu, and Drag Initiation
                                    MouseArea {
                                        id: itemMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        cursorShape: rowDelegate.canDrag ? Qt.OpenHandCursor : Qt.PointingHandCursor

                                        property real pressX: -9999
                                        property real pressY: -9999
                                        property bool dragInitiated: false
                                        property bool dragTriggered: false

                                        onPressed: mouse => {
                                            if (mouse.button === Qt.LeftButton) {
                                                pressX = mouse.x;
                                                pressY = mouse.y;
                                                dragInitiated = false;
                                                dragTriggered = false;
                                            }
                                        }

                                        onPositionChanged: mouse => {
                                            if (pressed && (mouse.buttons & Qt.LeftButton) && pressX >= 0 && !dragTriggered) {
                                                if (!dragInitiated) {
                                                    let dist = Math.sqrt(Math.pow(mouse.x - pressX, 2) + Math.pow(mouse.y - pressY, 2));
                                                    if (dist > 8) {
                                                        if (rowDelegate.canDrag) {
                                                            dragTriggered = true;
                                                            dragInitiated = true;
                                                            pressX = -9999;
                                                            pressY = -9999;
                                                            let nodeData = archiveInterface ? archiveInterface.treeModel.getNodeData(index) : {};
                                                            window.startNativeItemDrag(nodeData, model.parentName || "");
                                                            dragInitiated = false;
                                                        } else if (rowDelegate.isPending) {
                                                            statusText.text = "Item '" + rowDelegate.nodeName + "' is pending. Commit before moving.";
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        onReleased: mouse => {
                                            pressX = -9999;
                                            pressY = -9999;
                                            dragInitiated = false;
                                        }

                                        onCanceled: {
                                            pressX = -9999;
                                            pressY = -9999;
                                            dragInitiated = false;
                                            dragTriggered = false;
                                        }

                                        onClicked: mouse => {
                                            if (dragTriggered) {
                                                dragTriggered = false;
                                                return;
                                            }
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
                                                if (!dragInitiated && !dragManager.isDragging) {
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
                    }

                    // Loading State Placeholder during async archive open
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

                    // Drop Area for external Explorer files
                    DropArea {
                        id: treeDropArea
                        anchors.fill: parent

                        property var externalTargetFolder: null

                        function eventHasFormat(eventObj, fmt) {
                            if (!eventObj) return false;
                            if (typeof eventObj.hasFormat === "function") {
                                return eventObj.hasFormat(fmt);
                            }
                            if (eventObj.formats && typeof eventObj.formats.indexOf === "function") {
                                return eventObj.formats.indexOf(fmt) !== -1;
                            }
                            return false;
                        }

                        onEntered: drag => {
                            if (drag.hasUrls || eventHasFormat(drag, "application/x-secdet-item")) {
                                drag.acceptProposedAction();
                            }
                        }

                        onPositionChanged: drag => {
                            if (drag.hasUrls || eventHasFormat(drag, "application/x-secdet-item")) {
                                drag.acceptProposedAction();
                                if (typeof archiveInterface === "undefined" || !archiveInterface || !archiveInterface.hasArchive) {
                                    statusText.text = "Drop .sda archive to open";
                                    return;
                                }
                                let globalPt = mapToItem(window.contentItem, drag.x, drag.y);
                                let hit = window.findFolderTargetAt(globalPt.x, globalPt.y);
                                externalTargetFolder = hit;
                                if (eventHasFormat(drag, "application/x-secdet-item")) {
                                    if (hit) {
                                        statusText.text = "Move item into folder: '" + (hit.path || hit.name) + "'";
                                    } else {
                                        statusText.text = "Drop on folder to move, or outside window to extract immediately";
                                    }
                                } else {
                                    if (hit) {
                                        statusText.text = "Add file(s) into folder: '" + (hit.path || hit.name) + "'";
                                    } else {
                                        statusText.text = "Add file(s) to archive root (/)";
                                    }
                                }
                            }
                        }

                        onExited: {
                            externalTargetFolder = null;
                            statusText.text = (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.hasArchive) ? "Ready" : "No archive open";
                        }

                        onDropped: drop => {
                            if (eventHasFormat(drop, "application/x-secdet-item")) {
                                let srcPath = (typeof drop.getDataAsString === "function") ? drop.getDataAsString("application/x-secdet-item") : (drop.text || "");
                                let isDir = eventHasFormat(drop, "application/x-secdet-isfolder")
                                            ? ((typeof drop.getDataAsString === "function") ? (drop.getDataAsString("application/x-secdet-isfolder") === "1") : false)
                                            : false;
                                let target = externalTargetFolder;
                                externalTargetFolder = null;
                                if (target && target.path && target.path !== srcPath) {
                                    archiveInterface.moveArchiveItem(srcPath, target.path, isDir);
                                    drop.acceptProposedAction();
                                }
                                return;
                            }
                            if (drop.hasUrls) {
                                if (typeof archiveInterface === "undefined" || !archiveInterface || !archiveInterface.hasArchive) {
                                    drop.acceptProposedAction();
                                    if (!drop.urls || drop.urls.length === 0)
                                        return;
                                    let rawUrl = drop.urls[0].toString();
                                    let cleanPath = rawUrl;
                                    if (cleanPath.startsWith("file:///")) {
                                        if (cleanPath.length >= 10 && cleanPath.charAt(9) === ':')
                                            cleanPath = cleanPath.substring(8);
                                        else
                                            cleanPath = cleanPath.substring(7);
                                    } else if (cleanPath.startsWith("file://")) {
                                        cleanPath = cleanPath.substring(7);
                                    }
                                    cleanPath = decodeURIComponent(cleanPath);

                                    // Validate .sda extension
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

                                // Filter out self-drops from temporary drag staging
                                let validUrls = [];
                                for (let i = 0; i < drop.urls.length; ++i) {
                                    let uStr = drop.urls[i].toString();
                                    if (uStr.indexOf("SecDet_Drag") === -1) {
                                        validUrls.push(drop.urls[i]);
                                    }
                                }
                                if (validUrls.length === 0) {
                                    drop.acceptProposedAction();
                                    return;
                                }

                                let target = externalTargetFolder;
                                externalTargetFolder = null;
                                window.addPendingItems(validUrls, target ? target.path : "/");
                                drop.acceptProposedAction();
                            }
                        }
                    }

                    // Non-blocking sleek Drag Banner overlay at bottom of tree view
                    Rectangle {
                        id: dragIndicatorBanner
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 8
                        height: 38
                        radius: 8
                        color: Colors.isDarkMode ? Qt.rgba(0.12, 0.14, 0.18, 0.96) : Qt.rgba(0.98, 0.98, 0.99, 0.96)
                        border.color: Colors.goldPrimary
                        border.width: 1.5
                        z: 100

                        visible: opacity > 0
                        opacity: treeDropArea.containsDrag ? 1.0 : 0.0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutCubic
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8

                            Text {
                                text: "\ue2c6" // file_upload
                                font.family: materialIcons.name
                                font.pixelSize: 17
                                color: Colors.goldPrimary
                            }

                            Text {
                                text: (typeof archiveInterface === "undefined" || !archiveInterface || !archiveInterface.hasArchive) ? "Open archive (.sda)" : (treeDropArea.externalTargetFolder ? ("Adding to folder: " + (treeDropArea.externalTargetFolder.path || treeDropArea.externalTargetFolder.name)) : "Adding to archive root (/)")
                                font.family: Colors.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: Colors.textMain
                                Layout.fillWidth: true
                                elide: Text.ElideMiddle
                            }

                            Rectangle {
                                implicitWidth: 100
                                implicitHeight: 22
                                radius: 4
                                color: Colors.goldPrimary

                                Text {
                                    anchors.centerIn: parent
                                    text: "Release to drop"
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: Colors.textOnGold
                                }
                            }
                        }
                    }

                    // Background Scanning & Adding Items Animation Overlay
                    Rectangle {
                        id: addingItemsOverlay
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 40, 390)
                        height: 96
                        radius: 12
                        color: Colors.isDarkMode ? Qt.rgba(0.10, 0.12, 0.16, 0.96) : Qt.rgba(0.98, 0.98, 0.99, 0.96)
                        border.color: Colors.goldPrimary
                        border.width: 1.5
                        z: 110

                        visible: opacity > 0
                        opacity: (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.isAddingFiles) ? 1.0 : 0.0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                        }

                        // Subtle outer glow
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -3
                            radius: 15
                            z: -1
                            color: "transparent"
                            border.color: Qt.rgba(0.9, 0.76, 0.35, 0.3)
                            border.width: 2
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
                                    text: "Scanning Folder Structure..."
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    color: Colors.textMain
                                }

                                Text {
                                    text: "Listing files and subdirectories in background"
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

        // ==========================================
        // --- Live Status Feedback Bar ---
        // ==========================================
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

            Text {
                text: "SecDet Engine v2.4 • Drag/Drop Ready"
                color: Colors.textSubtle
                font.family: Colors.fontFamily
                font.pixelSize: 10
            }
        }

        // =========================================================
        // --- Windows 11 Bottom Multi-Part Progress Bar & Commit ---
        // =========================================================
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            Layout.maximumHeight: 36
            implicitHeight: 36
            spacing: 8

            // =========================================================
            // --- High-Performance Multi-Part Progress Bar ---
            // =========================================================
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

            // Core Logic: Commit & Write Changes Button
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

                // Dynamic styling matching bottom multipart bar vibe
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

                // Dynamic subtle breathing glow pulse when changes are staged or optimizing
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
                                return "\ue8b8"; // settings / gear (catchy mechanical optimizer)
                            if (bottomCommitButton.isCommitting)
                                return "\ue86a"; // sync
                            return "\ue161"; // save
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

                    // Staged jobs count badge
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

    // ==========================================
    // --- Global Drag Overlay & Proxy Floating Item ---
    // ==========================================
    MouseArea {
        id: globalDragOverlay
        anchors.fill: parent
        z: 99998
        enabled: dragManager.isDragging
        visible: dragManager.isDragging
        hoverEnabled: true
        cursorShape: Qt.ClosedHandCursor
        preventStealing: true

        onPositionChanged: mouse => {
            dragManager.updatePosition(mouse.x, mouse.y);
        }

        onReleased: mouse => {
            dragManager.finishDrag(mouse.x, mouse.y);
        }

        onCanceled: {
            dragManager.cancelDrag();
        }
    }

    Item {
        id: dragProxyItem
        width: 210
        height: 36
        z: 99999
        enabled: false // Mouse-transparent to prevent absorbing clicks
        visible: dragManager.isDragging && dragManager.draggedItem !== null

        x: Math.min(Math.max(10, dragManager.mouseX + 14), window.width - width - 10)
        y: Math.min(Math.max(10, dragManager.mouseY + 14), window.height - height - 10)

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: Colors.isDarkMode ? Qt.rgba(0.12, 0.14, 0.18, 0.96) : Qt.rgba(0.98, 0.98, 0.98, 0.96)
            border.color: dragManager.activeTargetFolder !== "" ? Colors.goldPrimary : Colors.goldBorderHi
            border.width: dragManager.activeTargetFolder !== "" ? 2 : 1.5

            Rectangle {
                anchors.fill: parent
                anchors.margins: -2
                radius: 10
                z: -1
                color: "transparent"
                border.color: dragManager.activeTargetFolder !== "" ? Qt.rgba(0.9, 0.76, 0.35, 0.35) : Qt.rgba(0, 0, 0, 0.25)
                border.width: 2
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                Text {
                    text: dragManager.draggedItem && dragManager.draggedItem.isFolder ? "\ue2c8" : "\ue873"
                    font.family: materialIcons.name
                    font.pixelSize: 17
                    color: Colors.goldPrimary
                }

                Text {
                    text: dragManager.draggedItem ? dragManager.draggedItem.name : ""
                    font.family: Colors.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: Colors.textMain
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: dragManager.activeTargetFolder !== "" ? "\ue5ca" : "\ue5c8"
                    font.family: materialIcons.name
                    font.pixelSize: 14
                    color: dragManager.activeTargetFolder !== "" ? Colors.goldPrimary : Colors.textMuted
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
