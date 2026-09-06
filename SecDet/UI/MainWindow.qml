import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import UI

Window {
    id: window
    width: 1040
    height: 800
    minimumWidth: 720
    minimumHeight: 680
    visible: true
    title: "SecDet - Secure Archive Detective"
    color: Colors.bgMain

    FontLoader {
        id: materialIcons
        source: "Fonts/MaterialIconsRound-Regular.otf"
    }

    component IslandButton : Item {
        id: iconBtn
        property string iconText: ""
        property string labelText: ""
        property color accentColor: Colors.goldPrimary
        property bool highlighted: false
        signal clicked()

        implicitWidth: 62
        implicitHeight: 50

        // Hover Background Rectangle (only visible upon hover / press / highlighted)
        Rectangle {
            id: hoverBg
            anchors.fill: parent
            radius: 8
            color: mouseArea.containsPress ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.08))
                 : mouseArea.containsMouse ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.04))
                 : iconBtn.highlighted ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.04))
                 : "transparent"

            border.color: mouseArea.containsMouse || iconBtn.highlighted
                        ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.10))
                        : "transparent"
            border.width: 1

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }
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
                color: mouseArea.containsMouse
                     ? (iconBtn.accentColor === Colors.textMuted ? Colors.textMain : iconBtn.accentColor)
                     : iconBtn.accentColor

                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: iconBtn.labelText
                font.family: Colors.fontFamily
                font.pixelSize: 11
                font.weight: Font.Medium
                color: mouseArea.containsMouse ? Colors.textMain : Colors.textMuted

                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: iconBtn.clicked()
            scale: containsPress ? 0.95 : 1.0
            Behavior on scale { NumberAnimation { duration: 100 } }
        }
    }

    component ThemeToggle : Rectangle {
        id: themeToggleRoot
        implicitWidth: 72
        implicitHeight: 32
        radius: 16
        color: Colors.bgElevated
        border.color: themeToggleMouse.containsMouse ? Colors.goldBorderHi : Colors.goldBorder
        border.width: 1

        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on border.color { ColorAnimation { duration: 200 } }

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

            Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 200 } }

            // Active Icon inside pill
            Text {
                anchors.centerIn: parent
                text: Colors.isDarkMode ? "nightlight" : "\ue518"
                font.family: materialIcons.name
                font.pixelSize: 14
                color: Colors.isDarkMode ? Colors.goldPrimary : Colors.textOnGold

                Behavior on color { ColorAnimation { duration: 150 } }
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

            Item { Layout.fillWidth: true }

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
            Behavior on scale { NumberAnimation { duration: 100 } }
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
        property string text: "Ready • Project_Backup.zip loaded"
    }

    QtObject {
        id: pBar
        property real value: 0.0
    }

    // Centralized Reactive Tree Model
    property var archiveTreeData: [
        {
            name: "Project_Backup.zip",
            isFolder: true,
            expanded: true,
            pending: false,
            children: [
                {
                    name: "Source Code",
                    isFolder: true,
                    expanded: true,
                    pending: false,
                    children: [
                        { name: "main.qml", isFolder: false, compressedSize: "12 KB", realSize: "28 KB", ratio: "42%", pending: false },
                        { name: "CMakeLists.txt", isFolder: false, compressedSize: "1.2 KB", realSize: "3.4 KB", ratio: "35%", pending: false },
                        { name: "app_icon.png", isFolder: false, compressedSize: "45 KB", realSize: "48 KB", ratio: "93%", pending: false }
                    ]
                },
                {
                    name: "Assets",
                    isFolder: true,
                    expanded: false,
                    pending: false,
                    children: [
                        { name: "logo.svg", isFolder: false, compressedSize: "8 KB", realSize: "19 KB", ratio: "42%", pending: false },
                        { name: "theme.json", isFolder: false, compressedSize: "2 KB", realSize: "5 KB", ratio: "40%", pending: false }
                    ]
                },
                { name: "README.md", isFolder: false, compressedSize: "1.1 KB", realSize: "2.8 KB", ratio: "39%", pending: false }
            ]
        },
        {
            name: "Documents",
            isFolder: true,
            expanded: false,
            pending: false,
            children: [
                { name: "License.txt", isFolder: false, compressedSize: "1.0 KB", realSize: "2.1 KB", ratio: "48%", pending: false },
                { name: "Changelog.pdf", isFolder: false, compressedSize: "120 KB", realSize: "190 KB", ratio: "63%", pending: false }
            ]
        },
        { name: "archive_manifest.json", isFolder: false, compressedSize: "0.8 KB", realSize: "1.5 KB", ratio: "53%", pending: false }
    ]

    // Tree Model Actions
    function addPendingItems(urls, targetFolder) {
        let newItems = [];
        for (let i = 0; i < urls.length; ++i) {
            let rawUrl = urls[i].toString();
            let fullPath = rawUrl;
            if (fullPath.startsWith("file:///")) {
                if (fullPath.length >= 10 && fullPath.charAt(9) === ':') fullPath = fullPath.substring(8);
                else fullPath = fullPath.substring(7);
            } else if (fullPath.startsWith("file://")) fullPath = fullPath.substring(7);
            fullPath = decodeURIComponent(fullPath);
            let name = fullPath.split("/").pop().split("\\").pop();
            let isDir = !name.includes(".");

            let itemObj = {
                name: name,
                filePath: fullPath,
                isFolder: isDir,
                expanded: true,
                pending: true,
                realSize: isDir ? "-" : "164 KB",
                compressedSize: "Staged",
                ratio: "Pending",
                children: isDir ? [
                    { name: "child_preview.dat", isFolder: false, realSize: "64 KB", compressedSize: "Staged", ratio: "Pending", pending: true }
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
                        nodes[k].expanded = true;
                        return true;
                    }
                    if (nodes[k].children && insertIntoTarget(nodes[k].children, targetName)) return true;
                }
                return false;
            }
            if (!insertIntoTarget(cloned, targetFolder.name)) {
                if (cloned.length > 0 && cloned[0].children) cloned[0].children = cloned[0].children.concat(newItems);
                else cloned = cloned.concat(newItems);
            }
        } else if (cloned.length > 0 && cloned[0].isFolder) {
            cloned[0].children = (cloned[0].children || []).concat(newItems);
            cloned[0].expanded = true;
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
                if (nodes[i].children && commitRecursive(nodes[i].children)) return true;
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

    function removeTreeItem(nodeName) {
        let cloned = JSON.parse(JSON.stringify(archiveTreeData));
        function removeRecursive(nodes) {
            for (let i = 0; i < nodes.length; ++i) {
                if (nodes[i].name === nodeName) {
                    nodes.splice(i, 1);
                    return true;
                }
                if (nodes[i].children && removeRecursive(nodes[i].children)) return true;
            }
            return false;
        }
        if (removeRecursive(cloned)) {
            archiveTreeData = cloned;
            statusText.text = "Removed '" + nodeName + "' from archive";
        }
    }

    function executeMoveItem(itemData, srcParent, targetFolderName) {
        if (!itemData || !targetFolderName || targetFolderName === srcParent || itemData.name === targetFolderName) {
            return;
        }

        if (itemData.isFolder && isFolderDescendant(itemData.name, targetFolderName)) {
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
                if (nodes[i].children && removeTarget(nodes[i].children)) return true;
            }
            return false;
        }

        removeTarget(cloned);
        if (!extractedItem) return;

        // 2. Insert into the target folder
        let inserted = false;
        function insertTarget(nodes) {
            for (let i = 0; i < nodes.length; ++i) {
                if (nodes[i].name === targetFolderName && nodes[i].isFolder) {
                    if (!nodes[i].children) nodes[i].children = [];
                    nodes[i].children.push(extractedItem);
                    nodes[i].expanded = true;
                    inserted = true;
                    return true;
                }
                if (nodes[i].children && insertTarget(nodes[i].children)) return true;
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
                sourcePath: "/" + (srcParent ? srcParent + "/" : "") + itemData.name,
                destinationPath: "/" + targetFolderName + "/" + itemData.name,
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

    function registerFolderRow(name, rowItem) {
        registeredFolderRows[name] = rowItem;
    }

    function unregisterFolderRow(name) {
        delete registeredFolderRows[name];
    }

    function isFolderDescendant(parentName, checkName) {
        function searchIn(nodes) {
            for (let i = 0; i < nodes.length; ++i) {
                if (nodes[i].name === parentName && nodes[i].isFolder) {
                    return hasChildRecursive(nodes[i].children, checkName);
                }
                if (nodes[i].children && searchIn(nodes[i].children)) return true;
            }
            return false;
        }
        function hasChildRecursive(children, target) {
            if (!children) return false;
            for (let c = 0; c < children.length; ++c) {
                if (children[c].name === target) return true;
                if (children[c].children && hasChildRecursive(children[c].children, target)) return true;
            }
            return false;
        }
        return searchIn(archiveTreeData);
    }

    function findFolderTargetAt(globalX, globalY) {
        for (let folderName in registeredFolderRows) {
            let rowItem = registeredFolderRows[folderName];
            if (rowItem && rowItem.visible) {
                let localPt = rowItem.mapFromItem(window.contentItem, globalX, globalY);
                if (localPt.x >= 0 && localPt.x <= rowItem.width &&
                    localPt.y >= 0 && localPt.y <= rowItem.height) {
                    return folderName;
                }
            }
        }
        return "";
    }

    QtObject {
        id: dragManager

        property bool isDragging: false
        property var draggedItem: null
        property string sourceParentFolder: ""
        property string activeTargetFolder: ""
        property real mouseX: 0
        property real mouseY: 0

        function startDrag(itemData, parentFolderName, startX, startY) {
            draggedItem = itemData;
            sourceParentFolder = parentFolderName;
            activeTargetFolder = "";
            mouseX = startX;
            mouseY = startY;
            isDragging = true;
            statusText.text = "Dragging '" + itemData.name + "' • Drop on a folder to move, or outside to export";
        }

        function updatePosition(globalX, globalY) {
            if (!isDragging) return;
            mouseX = globalX;
            mouseY = globalY;

            let hitFolder = window.findFolderTargetAt(globalX, globalY);
            if (hitFolder !== "" && hitFolder !== sourceParentFolder && hitFolder !== draggedItem.name) {
                if (draggedItem.isFolder && window.isFolderDescendant(draggedItem.name, hitFolder)) {
                    activeTargetFolder = "";
                    statusText.text = "Cannot move folder '" + draggedItem.name + "' into its own subfolder";
                } else {
                    activeTargetFolder = hitFolder;
                    statusText.text = "Drop to move '" + draggedItem.name + "' into folder '" + hitFolder + "'";
                }
            } else {
                activeTargetFolder = "";
                let treePt = treeContainer.mapFromItem(window.contentItem, globalX, globalY);
                let isOutside = (treePt.x < 0 || treePt.x > treeContainer.width ||
                                 treePt.y < 0 || treePt.y > treeContainer.height);
                if (isOutside) {
                    statusText.text = "Release to export '" + draggedItem.name + "' outside archive (External Export)";
                } else {
                    statusText.text = "Dragging '" + draggedItem.name + "' • Drop on a folder to move";
                }
            }
        }

        function finishDrag(globalX, globalY) {
            if (!isDragging) return;

            let item = draggedItem;
            let srcParent = sourceParentFolder;
            let target = activeTargetFolder;

            let treePt = treeContainer.mapFromItem(window.contentItem, globalX, globalY);
            let isOutside = (treePt.x < 0 || treePt.x > treeContainer.width ||
                             treePt.y < 0 || treePt.y > treeContainer.height);

            isDragging = false;
            draggedItem = null;
            sourceParentFolder = "";
            activeTargetFolder = "";

            if (isOutside) {
                window.handleExternalDragOut(item, srcParent);
            } else if (target !== "" && target !== srcParent) {
                window.executeMoveItem(item, srcParent, target);
            } else {
                statusText.text = "Drag completed without move. Items can only be dropped into different folders.";
            }
        }

        function cancelDrag() {
            isDragging = false;
            draggedItem = null;
            sourceParentFolder = "";
            activeTargetFolder = "";
        }
    }

    function handleExternalDragOut(itemData, parentFolderName) {
        let exportDetails = {
            action: "EXTERNAL_EXPORT_DRAG",
            item: {
                name: itemData.name,
                isFolder: itemData.isFolder,
                realSize: itemData.realSize,
                compressedSize: itemData.compressedSize,
                ratio: itemData.ratio
            },
            archiveSourcePath: "/" + (parentFolderName ? parentFolderName + "/" : "") + itemData.name,
            exportTarget: "EXTERNAL_DESTINATION",
            timestamp: new Date().toISOString()
        };
        lastTreeAction = exportDetails;
        externalDragStarted(exportDetails);
        fileDragExportRequested(exportDetails);
        console.log("[SecDet Clean Interface] External Drag Export:", JSON.stringify(exportDetails, null, 2));
        statusText.text = "Exporting '" + itemData.name + "' outside archive (External Drag)";
    }

    component ContextMenuItem : Rectangle {
        id: cmiRoot
        property string text: ""
        property string iconText: ""
        property color accentColor: Colors.textMain
        signal clicked()

        Layout.fillWidth: true
        height: 28
        radius: 4
        color: cmiMouse.containsMouse ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05)) : "transparent"

        Behavior on color { ColorAnimation { duration: 100 } }

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
                    treeContextMenu.close();
                    if (treeContextMenu.targetItem) {
                        commitPendingItem(treeContextMenu.targetItem.name);
                    }
                }
            }

            // ACTION: Discard Pending (Only for Pending items)
            ContextMenuItem {
                text: "Discard / Remove Pending"
                iconText: "\ue5cd"
                accentColor: "#e05353"
                visible: treeContextMenu.isTargetPending
                onClicked: {
                    treeContextMenu.close();
                    if (treeContextMenu.targetItem) {
                        removeTreeItem(treeContextMenu.targetItem.name);
                    }
                }
            }

            // ACTION: View / Inspect (Committed files)
            ContextMenuItem {
                text: "View / Inspect"
                iconText: "\ue8f4"
                visible: !treeContextMenu.isBlankArea && (!treeContextMenu.targetItem || !treeContextMenu.targetItem.isFolder) && !treeContextMenu.isTargetPending
                onClicked: {
                    treeContextMenu.close();
                    statusText.text = "Inspecting '" + treeContextMenu.targetItem.name + "'...";
                    infoPageLoader.visible = true;
                }
            }

            // ACTION: Extract (Committed files or folders)
            ContextMenuItem {
                text: "Extract to Folder..."
                iconText: "unarchive"
                visible: !treeContextMenu.isBlankArea && !treeContextMenu.isTargetPending
                onClicked: {
                    treeContextMenu.close();
                    statusText.text = "Extracting '" + treeContextMenu.targetItem.name + "' to folder...";
                    pBar.value = 0.5;
                }
            }

            // ACTION: Entropy & Hashes (Files)
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
                    treeContextMenu.close();
                    addPendingItems(["file:///NewFile_Staged.dat"], treeContextMenu.targetItem);
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

            // ACTION: Rename
            ContextMenuItem {
                text: "Rename"
                iconText: "\ue3c9"
                visible: !treeContextMenu.isBlankArea
                onClicked: {
                    treeContextMenu.close();
                    statusText.text = "Rename initiated for '" + treeContextMenu.targetItem.name + "'";
                }
            }

            // ACTION: Delete from Archive (Committed items)
            ContextMenuItem {
                text: "Delete from Archive"
                iconText: "\ue872"
                accentColor: "#e05353"
                visible: !treeContextMenu.isBlankArea && !treeContextMenu.isTargetPending
                onClicked: {
                    treeContextMenu.close();
                    if (treeContextMenu.targetItem) {
                        removeTreeItem(treeContextMenu.targetItem.name);
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
                    addPendingItems(["file:///Imported_Root_Doc.pdf"], null);
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

    Component {
        id: treeDirectoryViewComp

        Column {
            id: treeComp
            property var nodes: []
            property int depth: 0
            property bool parentPending: false
            property string parentFolderName: ""
            signal itemSelected(string name)

            spacing: 2
            width: parent ? parent.width : 0

            Rectangle {
                visible: treeComp.depth === 0
                width: parent.width
                height: 30
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

                    Rectangle { width: 1; height: 14; color: Colors.divider }

                    Text {
                        text: "Compressed"
                        color: Colors.textMuted
                        font.family: Colors.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        Layout.preferredWidth: 85
                        horizontalAlignment: Text.AlignRight
                    }

                    Rectangle { width: 1; height: 14; color: Colors.divider }

                    Text {
                        text: "Real Size"
                        color: Colors.textMuted
                        font.family: Colors.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        Layout.preferredWidth: 85
                        horizontalAlignment: Text.AlignRight
                    }

                    Rectangle { width: 1; height: 14; color: Colors.divider }

                    Text {
                        text: "Ratio"
                        color: Colors.textMuted
                        font.family: Colors.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        Layout.preferredWidth: 68
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            // --- Tree View Rows ---
            Repeater {
                model: treeComp.nodes

                delegate: Column {
                    id: rowDelegate
                    width: parent.width
                    property bool isOpen: modelData.expanded || false
                    readonly property bool isPending: (modelData.pending === true) || treeComp.parentPending
                    readonly property bool canDrag: !isPending

                    Component.onCompleted: {
                        if (modelData.isFolder) {
                            window.registerFolderRow(modelData.name, itemRowRect);
                        }
                    }

                    Component.onDestruction: {
                        if (modelData.isFolder) {
                            window.unregisterFolderRow(modelData.name);
                        }
                    }

                    Rectangle {
                        id: itemRowRect
                        width: parent.width
                        height: 34
                        radius: 6

                        readonly property bool isDropTargetHovered: dragManager.isDragging && (dragManager.activeTargetFolder === modelData.name)

                        color: isDropTargetHovered ? Colors.goldLightHover
                             : itemMouse.containsPress ? Colors.goldLightHover
                             : isPending ? (itemMouse.containsMouse ? Colors.goldLightHover : (Colors.isDarkMode ? Qt.rgba(0.9, 0.76, 0.35, 0.09) : Qt.rgba(0.69, 0.51, 0.12, 0.08)))
                             : itemMouse.containsMouse ? Colors.bgHover
                             : "transparent"

                        border.color: isDropTargetHovered ? Colors.goldPrimary
                                    : isPending ? Colors.goldBorderHi
                                    : "transparent"
                        border.width: isDropTargetHovered ? 2 : (isPending ? 1 : 0)

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: (treeComp.depth * 18) + 10
                            anchors.rightMargin: 12
                            spacing: 8

                            // Pending Left Indicator Bar
                            Rectangle {
                                width: 3
                                height: 18
                                radius: 1.5
                                color: Colors.goldPrimary
                                visible: isPending
                                Layout.alignment: Qt.AlignVCenter
                            }

                            // Expand/Collapse Chevron
                            Text {
                                text: modelData.isFolder ? (isOpen ? "\ue5cf" : "\ue5cc") : " "
                                font.family: materialIcons.name
                                font.pixelSize: 16
                                color: Colors.textMuted
                                visible: modelData.isFolder
                                Layout.preferredWidth: 16

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: rowDelegate.isOpen = !rowDelegate.isOpen
                                }
                            }

                            // Folder / File Icon
                            Text {
                                text: modelData.isFolder ? (isOpen ? "\ue2c8" : "\ue2c7") : (isPending ? "\ue2c6" : "\ue873")
                                font.family: materialIcons.name
                                font.pixelSize: 18
                                color: isPending ? Colors.goldHover : (modelData.isFolder ? Colors.goldPrimary : Colors.textMuted)
                                Layout.preferredWidth: 18
                            }

                            // File / Folder Name
                            Text {
                                text: modelData.name || ""
                                color: isPending ? Colors.goldHover : Colors.textMain
                                font.family: Colors.fontFamily
                                font.pixelSize: 12
                                font.weight: isPending ? Font.DemiBold : Font.Medium
                                font.italic: isPending
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            // Target Drop Cue Pill (visible when dragging file over this folder)
                            Rectangle {
                                visible: itemRowRect.isDropTargetHovered
                                Layout.preferredHeight: 20
                                Layout.preferredWidth: 130
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
                                        text: "Move into folder"
                                        font.family: Colors.fontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: Colors.textOnGold
                                    }
                                }
                            }

                            // Column 1: Compressed Size
                            Text {
                                visible: !itemRowRect.isDropTargetHovered
                                text: isPending ? "Staged" : (modelData.compressedSize !== undefined ? modelData.compressedSize : "-")
                                color: isPending ? Colors.goldPrimary : Colors.textMuted
                                font.family: Colors.fontFamily
                                font.pixelSize: 11
                                font.italic: isPending
                                Layout.preferredWidth: 85
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                            }

                            // Column 2: Real Size
                            Text {
                                visible: !itemRowRect.isDropTargetHovered
                                text: modelData.realSize !== undefined ? modelData.realSize : "-"
                                color: Colors.textMuted
                                font.family: Colors.fontFamily
                                font.pixelSize: 11
                                Layout.preferredWidth: 85
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                            }

                            // Column 3: Ratio / Pending Badge
                            Rectangle {
                                visible: !itemRowRect.isDropTargetHovered
                                Layout.preferredWidth: 68
                                Layout.preferredHeight: 20
                                radius: 4
                                color: isPending ? Colors.goldLight : (modelData.ratio ? Colors.goldLight : "transparent")
                                border.color: isPending ? Colors.goldBorderHi : "transparent"
                                border.width: isPending ? 1 : 0

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Text {
                                        visible: isPending
                                        text: "\ue8b5"
                                        font.family: materialIcons.name
                                        font.pixelSize: 10
                                        color: Colors.goldPrimary
                                    }
                                    Text {
                                        text: isPending ? "PENDING" : (modelData.ratio !== undefined ? modelData.ratio : "-")
                                        color: Colors.goldPrimary
                                        font.family: Colors.fontFamily
                                        font.pixelSize: isPending ? 9 : 11
                                        font.weight: Font.Bold
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
                            cursorShape: canDrag ? (dragManager.isDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.PointingHandCursor

                            property real pressX: 0
                            property real pressY: 0
                            property bool dragInitiated: false

                            onPressed: (mouse) => {
                                if (mouse.button === Qt.LeftButton) {
                                    pressX = mouse.x;
                                    pressY = mouse.y;
                                    dragInitiated = false;
                                }
                            }

                            onPositionChanged: (mouse) => {
                                if (pressed && (mouse.buttons & Qt.LeftButton) && !dragInitiated && !dragManager.isDragging) {
                                    let dist = Math.sqrt(Math.pow(mouse.x - pressX, 2) + Math.pow(mouse.y - pressY, 2));
                                    if (dist > 5) {
                                        if (canDrag) {
                                            dragInitiated = true;
                                            let globalPt = mapToItem(window.contentItem, mouse.x, mouse.y);
                                            dragManager.startDrag(modelData, treeComp.parentFolderName, globalPt.x, globalPt.y);
                                        } else if (isPending) {
                                            statusText.text = "Item '" + modelData.name + "' is pending. Commit before moving.";
                                        }
                                    }
                                }
                            }

                            onReleased: (mouse) => {
                                dragInitiated = false;
                            }

                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    treeContextMenu.targetItem = modelData;
                                    treeContextMenu.parentFolderName = treeComp.parentFolderName;
                                    treeContextMenu.isTargetPending = isPending;
                                    treeContextMenu.isBlankArea = false;
                                    let globalPoint = mapToItem(window.contentItem, mouse.x, mouse.y);
                                    treeContextMenu.x = Math.min(globalPoint.x, window.width - treeContextMenu.width - 10);
                                    treeContextMenu.y = Math.min(globalPoint.y, window.height - 240);
                                    treeContextMenu.open();
                                } else if (mouse.button === Qt.LeftButton) {
                                    if (!dragInitiated && !dragManager.isDragging) {
                                        if (modelData.isFolder) {
                                            rowDelegate.isOpen = !rowDelegate.isOpen;
                                        }
                                        treeComp.itemSelected(modelData.name);
                                    }
                                }
                            }
                        }
                    }

                    Loader {
                        width: parent.width
                        visible: modelData.isFolder && rowDelegate.isOpen
                        active: modelData.isFolder && rowDelegate.isOpen
                        sourceComponent: treeDirectoryViewComp
                        onLoaded: {
                            item.nodes = modelData.children || []
                            item.depth = treeComp.depth + 1
                            item.parentPending = treeComp.parentPending || (modelData.pending === true)
                            item.parentFolderName = modelData.name
                            item.itemSelected.connect((name) => treeComp.itemSelected(name))
                        }
                    }
                }
            }
        }
    }

    PasswordDialog {
        id: passIn
        anchors.centerIn: parent
    }

    Loader {
        id: createArchiveLoader
        active: false
        source: "CreateArchive.qml"
        onLoaded: {
            item.closeRequested.connect(() => {})
            item.archiveCreated.connect((archiveInfo) => {
                statusText.text = "Created archive: " + archiveInfo.name + " (" + archiveInfo.files.length + " files)"
                pBar.value = 1.0
            })
            item.open()
        }
    }

    Loader {
        id: archiveSettingsLoader
        active: false
        source: "ArchiveSettingsPage.qml"
        onLoaded: {
            item.closeRequested.connect(() => {})
            item.saveRequested.connect(() => {})
            item.open()
        }
    }

    ProgressWindow {
        id: progressWindow
    }

    Rectangle {
        id: mainContainer
        anchors.fill: parent
        color: Colors.bgMain
        border.color: Colors.borderSubtle
        border.width: 1

        Behavior on color { ColorAnimation { duration: 200 } }
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

            Behavior on color { ColorAnimation { duration: 200 } }
            Behavior on border.color { ColorAnimation { duration: 200 } }

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
                            createArchiveLoader.item.open();
                        } else {
                            createArchiveLoader.active = true;
                        }
                    }
                }

                // 2. Extract Archive
                IslandButton {
                    iconText: "unarchive"
                    labelText: "Extract"
                    accentColor: Colors.textMuted
                    onClicked: {
                        statusText.text = "Extracting all into a folder..."
                        pBar.value = 0.6
                    }
                }

                // 3. Inspect Archive Info Page (File Map & Shannon Entropy)
                IslandButton {
                    iconText: "\ue88e" // info
                    labelText: "Info"
                    accentColor: Colors.textMuted
                    highlighted: infoPageLoader.visible
                    onClicked: {
                        infoPageLoader.visible = !infoPageLoader.visible
                    }
                }

                // 4. Archive Settings Dialog
                IslandButton {
                    iconText: "\ue8b8" // settings
                    labelText: "Settings"
                    accentColor: Colors.textMuted
                    highlighted: archiveSettingsLoader.item && archiveSettingsLoader.item.visible
                    onClicked: {
                        if (archiveSettingsLoader.item) {
                            archiveSettingsLoader.item.open();
                        } else {
                            archiveSettingsLoader.active = true;
                        }
                    }
                }

                // 5. Delete / Purge Action (Matching Red Accent)
                IslandButton {
                    iconText: "delete"
                    labelText: "Delete"
                    accentColor: "#e05353"
                    onClicked: {
                        statusText.text = "Archive items cleared"
                        pBar.value = 0.0
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

                // 6. Test (Dummy Button 1)
                IslandButton {
                    iconText: "\ue86c" // done_all / verified
                    labelText: "Test"
                    accentColor: Colors.textMuted
                    onClicked: {
                        statusText.text = "Testing archive integrity... OK"
                        pBar.value = 1.0
                    }
                }

                // 7. View / Info (Dummy Button 2 - Opens Progress Window)
                IslandButton {
                    iconText: "\ue8f4" // visibility / view
                    labelText: "View"
                    accentColor: Colors.textMuted
                    onClicked: {
                        statusText.text = "Opening Operation Progress..."
                        progressWindow.show();
                        progressWindow.raise();
                        progressWindow.requestActivate();
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

                    Behavior on color { ColorAnimation { duration: 200 } }
                    Behavior on border.color { ColorAnimation { duration: 200 } }

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
                            text: "Project_Backup.zip"
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

                            Text {
                                anchors.centerIn: parent
                                text: "ZIP"
                                font.family: Colors.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: Colors.goldPrimary
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

                        Behavior on color { ColorAnimation { duration: 200 } }
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

                    Behavior on color { ColorAnimation { duration: 200 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                    Behavior on border.width { NumberAnimation { duration: 150 } }

                    // Background right-click menu for empty/blank tree area
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.RightButton) {
                                treeContextMenu.targetItem = null;
                                treeContextMenu.parentFolderName = "";
                                treeContextMenu.isTargetPending = false;
                                treeContextMenu.isBlankArea = true;
                                let globalPoint = mapToItem(window.contentItem, mouse.x, mouse.y);
                                treeContextMenu.x = Math.min(globalPoint.x, window.width - treeContextMenu.width - 10);
                                treeContextMenu.y = Math.min(globalPoint.y, window.height - 200);
                                treeContextMenu.open();
                            }
                        }
                    }

                    ScrollView {
                        id: mainTreeScrollView
                        anchors.fill: parent
                        anchors.margins: 10
                        clip: true
                        contentWidth: availableWidth
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                        ScrollBar.vertical: ScrollBar {
                            parent: mainTreeScrollView
                            x: mainTreeScrollView.mirrored ? 0 : mainTreeScrollView.width - width - 2
                            y: mainTreeScrollView.topPadding
                            height: mainTreeScrollView.availableHeight
                            active: mainTreeScrollView.ScrollBar.vertical.active
                            policy: ScrollBar.AsNeeded

                            contentItem: Rectangle {
                                implicitWidth: 5
                                radius: 2.5
                                color: parent.pressed ? Colors.goldPrimary
                                     : parent.hovered ? Colors.goldHover
                                     : (Colors.isDarkMode ? Qt.rgba(0.9, 0.76, 0.35, 0.35) : Qt.rgba(0.69, 0.51, 0.12, 0.35))

                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            background: Rectangle {
                                implicitWidth: 5
                                color: "transparent"
                            }
                        }

                        Loader {
                            id: mainTreeLoader
                            width: parent.width
                            sourceComponent: treeDirectoryViewComp
                            property var currentNodes: window.archiveTreeData
                            onCurrentNodesChanged: {
                                if (item) {
                                    item.nodes = currentNodes;
                                }
                            }
                            onLoaded: {
                                item.nodes = currentNodes;
                                item.depth = 0;
                                item.parentPending = false;
                                item.parentFolderName = "";
                                item.itemSelected.connect((name) => { statusText.text = "Selected: " + name; });
                            }
                        }
                    }

                    // Drop Area for external Explorer files
                    DropArea {
                        id: treeDropArea
                        anchors.fill: parent

                        onEntered: (drag) => {
                            if (drag.hasUrls) {
                                drag.acceptProposedAction();
                            }
                        }

                        onDropped: (drop) => {
                            if (drop.hasUrls) {
                                window.addPendingItems(drop.urls, null);
                                drop.acceptProposedAction();
                            }
                        }
                    }

                    // Animated Drag Overlay
                    Rectangle {
                        id: dragOverlay
                        anchors.fill: parent
                        anchors.margins: 1
                        topLeftRadius: 0
                        topRightRadius: 9
                        bottomLeftRadius: 9
                        bottomRightRadius: 9
                        color: Colors.isDarkMode ? Qt.rgba(0.08, 0.09, 0.12, 0.92) : Qt.rgba(0.95, 0.95, 0.97, 0.92)
                        border.color: Colors.goldHover
                        border.width: 1

                        visible: opacity > 0
                        opacity: treeDropArea.containsDrag ? 1.0 : 0.0

                        Behavior on opacity {
                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: Math.min(parent.width - 40, 320)
                            height: 150
                            radius: 12
                            color: Colors.bgSurface
                            border.color: Colors.goldBorderHi
                            border.width: 1

                            scale: treeDropArea.containsDrag ? 1.0 : 0.88
                            Behavior on scale {
                                NumberAnimation { duration: 200; easing.type: Easing.OutBack }
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 10

                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter
                                    width: 52
                                    height: 52
                                    radius: 26
                                    color: Colors.goldLight
                                    border.color: Colors.goldPrimary
                                    border.width: 1.5

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\ue2c6" // file_upload icon
                                        font.family: materialIcons.name
                                        font.pixelSize: 28
                                        color: Colors.goldHover
                                    }
                                }

                                ColumnLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 3

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "Drop files to add"
                                        font.family: Colors.fontFamily
                                        font.pixelSize: 14
                                        font.weight: Font.Bold
                                        color: Colors.goldHover
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "Release to stage into archive (Pending)"
                                        font.family: Colors.fontFamily
                                        font.pixelSize: 11
                                        color: Colors.textMuted
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
                    source: "ArchiveInfoPage.qml"
                    onLoaded: {
                        item.closeRequested.connect(() => {
                            infoPageLoader.visible = false;
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

        // ==========================================
        // --- Windows 11 Bottom Multi-Part Progress Bar ---
        // ==========================================
        MultiPartProgressBar {
            id: bottomProgressBar
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            implicitHeight: 34
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

        onPositionChanged: (mouse) => {
            dragManager.updatePosition(mouse.x, mouse.y);
        }

        onReleased: (mouse) => {
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
}