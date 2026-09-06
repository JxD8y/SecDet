import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import UI

Dialog {
    id: createDialog
    parent: Overlay.overlay
    x: parent ? Math.round((parent.width - width) / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0
    width: parent ? Math.min(parent.width - 40, 540) : 540
    height: parent ? Math.min(parent.height - 40, 660) : 660
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding: 16

    signal archiveCreated(var archiveInfo)
    signal closeRequested()

    FontLoader {
        id: materialIcons
        source: "Fonts/MaterialIconsRound-Regular.otf"
    }

    Overlay.modal: Rectangle {
        color: Colors.overlayModal
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    background: Rectangle {
        color: Colors.bgSurface
        radius: 14
        border.color: Colors.goldBorderHi
        border.width: 1

        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on border.color { ColorAnimation { duration: 200 } }
    }

    // ==========================================
    // --- Custom Component: Fluent Gold CheckBox ---
    // ==========================================
    component GoldCheckBox : Item {
        id: cbRoot
        property string text: ""
        property bool checked: false
        signal toggled(bool isChecked)

        implicitWidth: cbRow.implicitWidth
        implicitHeight: Math.max(20, cbRow.implicitHeight)

        RowLayout {
            id: cbRow
            anchors.fill: parent
            spacing: 10

            Rectangle {
                id: box
                width: 18
                height: 18
                radius: 4
                Layout.alignment: Qt.AlignVCenter
                color: cbRoot.checked ? Colors.goldPrimary : "transparent"
                border.color: cbRoot.checked ? Colors.goldHover : (cbArea.containsMouse ? Colors.goldBorderHi : Colors.goldBorder)
                border.width: 1

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "\ue5ca" // check mark
                    font.family: materialIcons.name
                    font.pixelSize: 14
                    color: Colors.textOnGold
                    visible: cbRoot.checked
                }
            }

            Text {
                text: cbRoot.text
                color: Colors.textMain
                font.family: Colors.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: cbArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                cbRoot.checked = !cbRoot.checked
                cbRoot.toggled(cbRoot.checked)
            }
        }
    }

    // ==========================================
    // --- Custom Component: Fluent Gold Switch ---
    // ==========================================
    component GoldSwitch : Item {
        id: swRoot
        property string text: ""
        property bool checked: false
        signal toggled(bool isChecked)

        implicitWidth: swRow.implicitWidth
        implicitHeight: Math.max(22, swRow.implicitHeight)

        RowLayout {
            id: swRow
            anchors.fill: parent
            spacing: 12

            Text {
                text: swRoot.text
                color: Colors.textMain
                font.family: Colors.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                elide: Text.ElideRight
            }

            Rectangle {
                id: track
                width: 38
                height: 20
                radius: 10
                Layout.alignment: Qt.AlignVCenter
                color: swRoot.checked ? Colors.goldLightHover : Colors.bgInput
                border.color: swRoot.checked ? Colors.goldBorderHi : Colors.goldBorder
                border.width: 1

                Behavior on color { ColorAnimation { duration: 150 } }

                Rectangle {
                    id: thumb
                    width: 14
                    height: 14
                    radius: 7
                    anchors.verticalCenter: parent.verticalCenter
                    x: swRoot.checked ? parent.width - width - 3 : 3
                    color: swRoot.checked ? Colors.goldPrimary : Colors.textMuted

                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }
        }

        MouseArea {
            id: swArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                swRoot.checked = !swRoot.checked
                swRoot.toggled(swRoot.checked)
            }
        }
    }

    // ==========================================
    // --- Custom Component: Fluent Segmented Toggle ---
    // ==========================================
    component TripleToggle : Rectangle {
        id: toggleRoot
        property int currentIndex: 1 // 0: Fast, 1: Balanced, 2: Ultra
        property var options: ["Fast (Store)", "Balanced (Deflate)", "Ultra (LZMA2)"]
        signal selected(int index)

        implicitWidth: 320
        implicitHeight: 34
        radius: 8
        color: Colors.bgInput
        border.color: Colors.goldBorder
        border.width: 1

        Rectangle {
            id: activePill
            width: (toggleRoot.width - 6) / 3
            height: toggleRoot.height - 6
            y: 3
            x: 3 + toggleRoot.currentIndex * width
            radius: 6
            color: Colors.goldLight
            border.color: Colors.goldBorderHi
            border.width: 1

            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Repeater {
                model: toggleRoot.options

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        font.family: Colors.fontFamily
                        font.pixelSize: 11
                        font.weight: toggleRoot.currentIndex === index ? Font.Bold : Font.Medium
                        color: toggleRoot.currentIndex === index ? Colors.goldHover : Colors.textMuted

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            toggleRoot.currentIndex = index
                            toggleRoot.selected(index)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: createTreeDirViewComp

        Column {
            id: treeComp
            property var nodes: []
            property int depth: 0
            signal itemRemoved(var itemToRemove)

            spacing: 2
            width: parent ? parent.width : 0

            Repeater {
                model: treeComp.nodes

                delegate: Column {
                    width: parent.width
                    property bool isOpen: modelData.expanded !== undefined ? modelData.expanded : true

                    Rectangle {
                        width: parent.width
                        height: 28
                        radius: 4
                        color: itemMouse.containsMouse ? Colors.bgHover : "transparent"

                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: (treeComp.depth * 16) + 6
                            anchors.rightMargin: 8
                            spacing: 6

                            // Expand/Collapse Chevron for folders
                            Text {
                                text: modelData.isFolder ? (isOpen ? "\ue5cf" : "\ue5cc") : " "
                                font.family: materialIcons.name
                                font.pixelSize: 14
                                color: Colors.textMuted
                                visible: modelData.isFolder
                                Layout.preferredWidth: 16

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: parent.parent.parent.parent.isOpen = !parent.parent.parent.parent.isOpen
                                }
                            }

                            // Folder / File Icon
                            Text {
                                text: modelData.isFolder ? (isOpen ? "\ue2c8" : "\ue2c7") : "\ue873"
                                font.family: materialIcons.name
                                font.pixelSize: 16
                                color: modelData.isFolder ? Colors.goldPrimary : Colors.textMuted
                                Layout.preferredWidth: 18
                            }

                            // Name
                            Text {
                                text: modelData.name || ""
                                color: Colors.textMain
                                font.family: Colors.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            // Size
                            Text {
                                text: modelData.realSize || "-"
                                color: Colors.textMuted
                                font.family: Colors.fontFamily
                                font.pixelSize: 10
                                Layout.preferredWidth: 60
                                horizontalAlignment: Text.AlignRight
                            }

                            // Remove item button
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 4
                                color: removeMouse.containsMouse ? Qt.rgba(0.9, 0.3, 0.3, 0.15) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "\ue5cd"
                                    font.family: materialIcons.name
                                    font.pixelSize: 12
                                    color: removeMouse.containsMouse ? "#ff6b6b" : Colors.textMuted
                                }

                                MouseArea {
                                    id: removeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: treeComp.itemRemoved(modelData)
                                }
                            }
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (modelData.isFolder) {
                                    parent.parent.isOpen = !parent.parent.isOpen;
                                }
                            }
                        }
                    }

                    Loader {
                        width: parent.width
                        visible: modelData.isFolder && parent.isOpen
                        active: modelData.isFolder && parent.isOpen
                        sourceComponent: createTreeDirViewComp
                        onLoaded: {
                            item.nodes = modelData.children || []
                            item.depth = treeComp.depth + 1
                            item.itemRemoved.connect((node) => treeComp.itemRemoved(node))
                        }
                    }
                }
            }
        }
    }

    // --- Main Dialog Layout with ScrollView ---
    contentItem: ScrollView {
        id: scrollArea
        clip: true
        contentWidth: availableWidth
        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: scrollArea.availableWidth
            spacing: 12

            // ==========================================
            // --- Header: Icon, Title & Close Button ---
            // ==========================================
            RowLayout {
                Layout.fillWidth: true

                RowLayout {
                    spacing: 8
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: Colors.goldLight
                        border.color: Colors.goldBorderHi
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "\ue145" // add icon
                            font.family: materialIcons.name
                            font.pixelSize: 18
                            color: Colors.goldHover
                        }
                    }

                    ColumnLayout {
                        spacing: 1
                        Text {
                            text: "Create Archive"
                            font.family: Colors.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: Colors.textMain
                        }
                        Text {
                            text: "Configure parameters and assemble files"
                            font.family: Colors.fontFamily
                            font.pixelSize: 11
                            color: Colors.textMuted
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Close Button
                Rectangle {
                    width: 26; height: 26; radius: 13
                    color: closeMouse.containsMouse ? Qt.rgba(0.9, 0.3, 0.3, 0.2) : "transparent"
                    border.color: closeMouse.containsMouse ? "#d9534f" : Colors.goldBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "\ue5cd"
                        font.family: materialIcons.name
                        font.pixelSize: 14
                        color: closeMouse.containsMouse ? "#ff6b6b" : Colors.textMuted
                    }
                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            createDialog.closeRequested()
                            createDialog.close()
                        }
                    }
                }
            }

            // ==========================================
            // --- Archive Name Input ---
            // ==========================================
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 64
                color: Colors.bgCard
                radius: 10
                border.color: Colors.goldBorder
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    Text {
                        text: "ARCHIVE NAME"
                        font.family: Colors.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: Colors.goldPrimary
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 6
                        color: Colors.bgInput
                        border.color: archiveNameInput.activeFocus ? Colors.goldBorderHi : Colors.borderSubtle
                        border.width: 1

                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Text {
                                text: "folder_zip"
                                font.family: materialIcons.name
                                font.pixelSize: 16
                                color: Colors.goldPrimary
                            }

                            TextField {
                                id: archiveNameInput
                                Layout.fillWidth: true
                                text: "NewArchive.tr"
                                color: Colors.textMain
                                font.family: Colors.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                background: null
                                selectByMouse: true
                            }
                        }
                    }
                }
            }

            // ==========================================
            // --- Drop Area & Hierarchical File Tree View ---
            // ==========================================
            Rectangle {
                id: filesContainer
                Layout.fillWidth: true
                implicitHeight: 200
                color: Colors.bgCard
                radius: 10
                border.color: fileDropArea.containsDrag ? Colors.goldPrimary : Colors.goldBorder
                border.width: fileDropArea.containsDrag ? 2 : 1

                Behavior on border.color { ColorAnimation { duration: 150 } }
                Behavior on border.width { NumberAnimation { duration: 150 } }

                property var queuedNodes: [
                    {
                        name: "Source Code",
                        isFolder: true,
                        expanded: true,
                        children: [
                            { name: "source_bundle.zip", isFolder: false, filePath: "C:/Projects/source_bundle.zip", realSize: "1.4 MB" },
                            { name: "assets_manifest.json", isFolder: false, filePath: "C:/Projects/assets_manifest.json", realSize: "12 KB" }
                        ]
                    },
                    {
                        name: "Documentation",
                        isFolder: true,
                        expanded: false,
                        children: [
                            { name: "Release_Notes.pdf", isFolder: false, filePath: "C:/Projects/Release_Notes.pdf", realSize: "210 KB" },
                            { name: "License.txt", isFolder: false, filePath: "C:/Projects/License.txt", realSize: "4 KB" }
                        ]
                    }
                ]

                function countFiles(nodesList) {
                    let total = 0;
                    if (!nodesList) return 0;
                    for (let i = 0; i < nodesList.length; ++i) {
                        if (nodesList[i].isFolder) {
                            total += countFiles(nodesList[i].children);
                        } else {
                            total += 1;
                        }
                    }
                    return total;
                }

                function collectPaths(nodesList) {
                    let paths = [];
                    if (!nodesList) return paths;
                    for (let i = 0; i < nodesList.length; ++i) {
                        if (nodesList[i].isFolder) {
                            paths = paths.concat(collectPaths(nodesList[i].children));
                        } else {
                            paths.push(nodesList[i].filePath || nodesList[i].name);
                        }
                    }
                    return paths;
                }

                function removeNodeRecursive(nodesList, target) {
                    let updated = [];
                    for (let i = 0; i < nodesList.length; ++i) {
                        let node = nodesList[i];
                        if (node === target) continue;
                        if (node.isFolder && node.children) {
                            let newNode = Object.assign({}, node);
                            newNode.children = removeNodeRecursive(node.children, target);
                            updated.push(newNode);
                        } else {
                            updated.push(node);
                        }
                    }
                    return updated;
                }

                function handleRemove(target) {
                    queuedNodes = removeNodeRecursive(queuedNodes, target);
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "\ue2c8" // folder icon
                            font.family: materialIcons.name
                            font.pixelSize: 14
                            color: Colors.goldPrimary
                        }

                        Text {
                            text: "ARCHIVE CONTENTS"
                            font.family: Colors.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: Colors.goldPrimary
                            Layout.fillWidth: true
                        }

                        Text {
                            text: filesContainer.countFiles(filesContainer.queuedNodes) + " files queued"
                            font.family: Colors.fontFamily
                            font.pixelSize: 10
                            color: Colors.textMuted
                        }
                    }

                    // Table Column Header
                    Rectangle {
                        Layout.fillWidth: true
                        height: 24
                        color: Colors.bgElevated
                        border.color: Colors.borderSubtle
                        border.width: 1
                        radius: 4

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            Text {
                                text: "Name"
                                color: Colors.textMuted
                                font.family: Colors.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                Layout.fillWidth: true
                            }

                            Rectangle { width: 1; height: 12; color: Colors.divider }

                            Text {
                                text: "Size"
                                color: Colors.textMuted
                                font.family: Colors.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                Layout.preferredWidth: 60
                                horizontalAlignment: Text.AlignRight
                            }

                            Item { Layout.preferredWidth: 20 }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 6
                        color: Colors.bgInput
                        border.color: Colors.borderSubtle
                        border.width: 1
                        clip: true

                        ScrollView {
                            id: treeScrollView
                            anchors.fill: parent
                            anchors.margins: 4
                            clip: true
                            contentWidth: availableWidth

                            ScrollBar.vertical: ScrollBar {
                                parent: treeScrollView
                                x: treeScrollView.width - width - 2
                                y: 2
                                height: treeScrollView.height - 4
                                policy: ScrollBar.AsNeeded
                                width: 5

                                contentItem: Rectangle {
                                    implicitWidth: 5
                                    radius: 2.5
                                    color: parent.pressed ? Colors.goldHover
                                         : parent.hovered ? Colors.goldPrimary
                                         : (Colors.isDarkMode ? Qt.rgba(0.9, 0.76, 0.35, 0.35) : Qt.rgba(0.69, 0.51, 0.12, 0.35))

                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                background: Rectangle {
                                    implicitWidth: 5
                                    color: "transparent"
                                }
                            }

                            Loader {
                                id: treeLoader
                                width: parent.width
                                sourceComponent: createTreeDirViewComp
                                property var currentNodes: filesContainer.queuedNodes
                                onCurrentNodesChanged: {
                                    if (item) {
                                        item.nodes = currentNodes;
                                    }
                                }
                                onLoaded: {
                                    item.nodes = currentNodes;
                                    item.depth = 0;
                                    item.itemRemoved.connect(filesContainer.handleRemove);
                                }
                            }
                        }
                    }
                }

                // Drop Area matching MainWindow
                DropArea {
                    id: fileDropArea
                    anchors.fill: parent
                    onEntered: (drag) => { if (drag.hasUrls) drag.acceptProposedAction(); }
                    onDropped: (drop) => {
                        if (drop.hasUrls) {
                            let newItems = [];
                            for (let i = 0; i < drop.urls.length; ++i) {
                                let rawUrl = drop.urls[i].toString();
                                let fullPath = rawUrl;
                                if (fullPath.startsWith("file:///")) {
                                    if (fullPath.length >= 10 && fullPath.charAt(9) === ':') {
                                        fullPath = fullPath.substring(8);
                                    } else {
                                        fullPath = fullPath.substring(7);
                                    }
                                } else if (fullPath.startsWith("file://")) {
                                    fullPath = fullPath.substring(7);
                                }
                                fullPath = decodeURIComponent(fullPath);
                                let name = fullPath.split("/").pop().split("\\").pop();
                                let isDir = !name.includes(".");
                                newItems.push({
                                    name: name,
                                    filePath: fullPath,
                                    isFolder: isDir,
                                    expanded: true,
                                    realSize: isDir ? "-" : "128 KB",
                                    children: []
                                });
                            }
                            let current = filesContainer.queuedNodes.slice();
                            filesContainer.queuedNodes = current.concat(newItems);
                            drop.acceptProposedAction();
                        }
                    }
                }

                // Animated Drag Overlay matching MainWindow
                Rectangle {
                    id: fileDragOverlay
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: 9
                    color: Colors.isDarkMode ? Qt.rgba(0.08, 0.09, 0.12, 0.92) : Qt.rgba(0.95, 0.95, 0.97, 0.92)
                    border.color: Colors.goldHover
                    border.width: 1

                    visible: opacity > 0
                    opacity: fileDropArea.containsDrag ? 1.0 : 0.0

                    Behavior on opacity {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 40, 280)
                        height: 120
                        radius: 12
                        color: Colors.bgSurface
                        border.color: Colors.goldBorderHi
                        border.width: 1

                        scale: fileDropArea.containsDrag ? 1.0 : 0.88
                        Behavior on scale {
                            NumberAnimation { duration: 200; easing.type: Easing.OutBack }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 44
                                height: 44
                                radius: 22
                                color: Colors.goldLight
                                border.color: Colors.goldPrimary
                                border.width: 1.5

                                Text {
                                    anchors.centerIn: parent
                                    text: "\ue2c6" // file_upload icon
                                    font.family: materialIcons.name
                                    font.pixelSize: 24
                                    color: Colors.goldHover
                                }
                            }

                            ColumnLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 2

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "Drop files to add"
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    color: Colors.goldHover
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "Release to queue into archive"
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 10
                                    color: Colors.textMuted
                                }
                            }
                        }
                    }
                }
            }

            // ==========================================
            // --- Compression & Security Settings ---
            // ==========================================
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: settingsCol.implicitHeight + 20
                color: Colors.bgCard
                radius: 10
                border.color: Colors.goldBorder
                border.width: 1

                ColumnLayout {
                    id: settingsCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Text {
                        text: "COMPRESSION LEVEL"
                        font.family: Colors.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: Colors.goldPrimary
                    }

                    TripleToggle {
                        id: compTripleToggle
                        Layout.fillWidth: true
                        currentIndex: 1
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Colors.divider }

                    GridLayout {
                        columns: 2
                        columnSpacing: 16
                        rowSpacing: 10
                        Layout.fillWidth: true

                        GoldSwitch {
                            id: encSwitch
                            text: "AES-256 Encryption"
                            checked: true
                            Layout.fillWidth: true
                        }

                        GoldSwitch {
                            id: solidSwitch
                            text: "Solid Block Mode"
                            checked: false
                            Layout.fillWidth: true
                        }

                        GoldCheckBox {
                            id: permCheck
                            text: "Preserve Permissions"
                            checked: true
                            Layout.fillWidth: true
                        }

                        GoldCheckBox {
                            id: verifyCheck
                            text: "Integrity Verification"
                            checked: true
                            Layout.fillWidth: true
                        }
                    }
                }
            }
            Rectangle {
                id: passwordContainer
                Layout.fillWidth: true
                implicitHeight: 140
                color: Colors.bgCard
                radius: 10
                border.color: fileDropArea.containsDrag ? Colors.goldPrimary : Colors.goldBorder
                border.width: fileDropArea.containsDrag ? 2 : 1

                Behavior on border.color { ColorAnimation { duration: 150 } }
                Behavior on border.width { NumberAnimation { duration: 150 } }

                ListModel {
                    id: passwords
                    ListElement { password_hash: "ad9a67fefa847de87753df6794a0ae466431e76ad1fb4db58fbbe836d1dde0e7" }
                    ListElement { password_hash: "2285dd09ea6ccd0ec7e7253d2f7dc10810608d45609a902b5094176974eafc44" }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "key"
                            font.family: materialIcons.name
                            font.pixelSize: 14
                            color: Colors.goldPrimary
                        }

                        Text {
                            text: "Passwords"
                            font.family: Colors.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: Colors.goldPrimary
                            Layout.fillWidth: true
                        }

                        Text {
                            text: "info"
                            font.family: materialIcons.name
                            font.pixelSize: 10
                            color: Colors.textMuted
                            MouseArea{
                                anchors.fill: parent
                                onClicked:{
                                    ToolTip.show("Your archives can have multiple passcodes\nbut its necessary to put atleast one to continue.")
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 6
                        color: Colors.bgInput
                        border.color: Colors.borderSubtle
                        border.width: 1
                        ListView {
                            id: passwordListView
                            anchors.fill: parent
                            anchors.margins: 4
                            clip: true
                            spacing: 2
                            model: passwords

                            delegate: Rectangle {
                                width: passwordContainer.width
                                height: 28
                                radius: 4
                                color: Colors.bgHover

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Text {
                                        text: "key"
                                        font.family: materialIcons.name
                                        font.pixelSize: 14
                                        color: Colors.textMuted
                                    }

                                    Text {
                                        text: model.password_hash
                                        color: Colors.textMain
                                        font.family: Colors.fontFamily
                                        font.pixelSize: 11
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    // Remove password icon button
                                    Item {
                                        width: 18; height: 18
                                        Text {
                                            anchors.centerIn: parent
                                            text: "\ue5cd"
                                            font.family: materialIcons.name
                                            font.pixelSize: 12
                                            color: removePassMouse.containsMouse ? "#ff6b6b" : Colors.textMuted
                                        }
                                        MouseArea {
                                            id: removePassMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: passwords.remove(index)
                                        }
                                    }
                                }
                            }
                        }

                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            height: 32
                            radius: 6
                            color: Colors.bgInput
                            border.color: passInput.activeFocus ? Colors.goldBorderHi : Colors.borderSubtle
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 6

                                TextField {
                                    id: passInput
                                    Layout.fillWidth: true
                                    placeholderText: "Enter archive password..."
                                    placeholderTextColor: Colors.textSubtle
                                    color: Colors.textMain
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 12
                                    property bool showPassword: false
                                    echoMode: showPassword ? TextInput.Normal : TextInput.Password
                                    background: null
                                    selectByMouse: true
                                    onAccepted: {
                                        if (passInput.text.length > 0) {
                                            passwords.append({ password_hash: passInput.text });
                                            passInput.text = "";
                                        }
                                    }
                                }

                                Item {
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24

                                    Text {
                                        anchors.centerIn: parent
                                        text: passInput.showPassword ? "\ue8f5" : "\ue8f4"
                                        font.family: materialIcons.name
                                        font.pixelSize: 16
                                        color: eyeMouse.containsMouse ? Colors.goldHover : Colors.textMuted
                                    }

                                    MouseArea {
                                        id: eyeMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: passInput.showPassword = !passInput.showPassword
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 6
                            color: addPassMouse.containsMouse ? Colors.goldLightHover : Colors.goldLight
                            border.color: Colors.goldBorderHi
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                font.family: materialIcons.name
                                font.pixelSize: 18
                                color: Colors.goldPrimary
                                text: "\ue145" // add '+'
                            }

                            MouseArea {
                                id: addPassMouse
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (passInput.text.length > 0) {
                                        passwords.append({ password_hash: passInput.text });
                                        passInput.text = "";
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ==========================================
            // --- Action Buttons: Cancel & Create ---
            // ==========================================
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Item { Layout.fillWidth: true }

                // Cancel Button
                Rectangle {
                    implicitWidth: 100
                    implicitHeight: 34
                    radius: 6
                    color: cancelBtnMouse.containsMouse ? Colors.bgHover : "transparent"
                    border.color: Colors.goldBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        font.family: Colors.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: Colors.textMuted
                    }

                    MouseArea {
                        id: cancelBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            createDialog.closeRequested()
                            createDialog.close()
                        }
                    }
                }

                // Save / Create Button
                Rectangle {
                    implicitWidth: 140
                    implicitHeight: 34
                    radius: 6
                    color: saveBtnMouse.containsPress ? Qt.darker(Colors.goldPrimary, 1.15)
                         : (saveBtnMouse.containsMouse ? Colors.goldHover : Colors.goldPrimary)

                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: "\ue145" // '+' icon
                            font.family: materialIcons.name
                            font.pixelSize: 16
                            color: Colors.textOnGold
                        }

                        Text {
                            text: "Create Archive"
                            font.family: Colors.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: Colors.textOnGold
                        }
                    }

                    MouseArea {
                        id: saveBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            let filesList = filesContainer.collectPaths(filesContainer.queuedNodes);
                            let archiveData = {
                                name: archiveNameInput.text,
                                compression: compTripleToggle.options[compTripleToggle.currentIndex],
                                encryption: encSwitch.checked,
                                solidMode: solidSwitch.checked,
                                preservePermissions: permCheck.checked,
                                integrityCheck: verifyCheck.checked,
                                files: filesList
                            };
                            console.log("CreateArchive - Created new archive: " + archiveData.name + " (" + filesList.length + " files)");
                            createDialog.archiveCreated(archiveData);
                            createDialog.close();
                        }
                    }
                }
            }
        }
    }

    onOpened: {
        archiveNameInput.forceActiveFocus()
    }
}
