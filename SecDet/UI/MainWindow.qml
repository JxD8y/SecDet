import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import UI

Window {
    id: window
    width: 960
    height: 800
    minimumWidth: 640
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

    Component {
        id: treeDirectoryViewComp

        Column {
            id: treeComp
            property var nodes: []
            property int depth: 0
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
                        Layout.preferredWidth: 55
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            // --- Tree View Rows ---
            Repeater {
                model: treeComp.nodes

                delegate: Column {
                    width: parent.width
                    property bool isOpen: modelData.expanded || false

                    Rectangle {
                        width: parent.width
                        height: 34
                        radius: 6
                        color: itemMouse.containsPress ? Colors.goldLightHover
                            : itemMouse.containsMouse ? Colors.bgHover
                            : "transparent"

                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: (treeComp.depth * 18) + 10
                            anchors.rightMargin: 12
                            spacing: 8

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
                                    onClicked: parent.parent.parent.parent.isOpen = !parent.parent.parent.parent.isOpen
                                }
                            }

                            // Folder / File Icon
                            Text {
                                text: modelData.isFolder ? (isOpen ? "\ue2c8" : "\ue2c7") : "\ue873"
                                font.family: materialIcons.name
                                font.pixelSize: 18
                                color: modelData.isFolder ? Colors.goldPrimary : Colors.textMuted
                                Layout.preferredWidth: 18
                            }

                            // File / Folder Name
                            Text {
                                text: modelData.name || ""
                                color: Colors.textMain
                                font.family: Colors.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            // Column 1: Compressed Size
                            Text {
                                text: modelData.compressedSize !== undefined ? modelData.compressedSize : "-"
                                color: Colors.textMuted
                                font.family: Colors.fontFamily
                                font.pixelSize: 11
                                Layout.preferredWidth: 85
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                            }

                            // Column 2: Real Size
                            Text {
                                text: modelData.realSize !== undefined ? modelData.realSize : "-"
                                color: Colors.textMuted
                                font.family: Colors.fontFamily
                                font.pixelSize: 11
                                Layout.preferredWidth: 85
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                            }

                            // Column 3: Compression Ratio Badge
                            Rectangle {
                                Layout.preferredWidth: 55
                                Layout.preferredHeight: 20
                                radius: 4
                                color: modelData.ratio ? Colors.goldLight : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.ratio !== undefined ? modelData.ratio : "-"
                                    color: Colors.goldPrimary
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }
                            }
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.isFolder) {
                                    parent.parent.isOpen = !parent.parent.isOpen;
                                }
                                treeComp.itemSelected(modelData.name);
                            }
                        }
                    }

                    Loader {
                        width: parent.width
                        visible: modelData.isFolder && parent.isOpen
                        active: modelData.isFolder && parent.isOpen
                        sourceComponent: treeDirectoryViewComp
                        onLoaded: {
                            item.nodes = modelData.children || []
                            item.depth = treeComp.depth + 1
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

                // 3. Inspect / Settings Page
                IslandButton {
                    iconText: "\ue8b8" // settings
                    labelText: "Settings"
                    accentColor: Colors.textMuted
                    highlighted: infoPageLoader.visible
                    onClicked: {
                        infoPageLoader.visible = !infoPageLoader.visible
                    }
                }

                // 4. Delete / Purge Action (Matching Red Accent)
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

                // 5. Test (Dummy Button 1)
                IslandButton {
                    iconText: "\ue86c" // done_all / verified
                    labelText: "Test"
                    accentColor: Colors.textMuted
                    onClicked: {
                        statusText.text = "Testing archive integrity... OK"
                        pBar.value = 1.0
                    }
                }

                // 6. View / Info (Dummy Button 2 - Opens Progress Window)
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

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 10
                        clip: true
                        contentWidth: availableWidth

                        Loader {
                            width: parent.width
                            sourceComponent: treeDirectoryViewComp
                            onLoaded: {
                                item.nodes = [
                                    {
                                        name: "Project_Backup.zip",
                                        isFolder: true,
                                        expanded: true,
                                        children: [
                                            {
                                                name: "Source Code",
                                                isFolder: true,
                                                expanded: true,
                                                children: [
                                                    { name: "main.qml", isFolder: false, compressedSize: "12 KB", realSize: "28 KB", ratio: "42%" },
                                                    { name: "CMakeLists.txt", isFolder: false, compressedSize: "1.2 KB", realSize: "3.4 KB", ratio: "35%" },
                                                    { name: "app_icon.png", isFolder: false, compressedSize: "45 KB", realSize: "48 KB", ratio: "93%" }
                                                ]
                                            },
                                            {
                                                name: "Assets",
                                                isFolder: true,
                                                expanded: false,
                                                children: [
                                                    { name: "logo.svg", isFolder: false, compressedSize: "8 KB", realSize: "19 KB", ratio: "42%" },
                                                    { name: "theme.json", isFolder: false, compressedSize: "2 KB", realSize: "5 KB", ratio: "40%" }
                                                ]
                                            },
                                            { name: "README.md", isFolder: false, compressedSize: "1.1 KB", realSize: "2.8 KB", ratio: "39%" }
                                        ]
                                    },
                                    {
                                        name: "Documents",
                                        isFolder: true,
                                        expanded: false,
                                        children: [
                                            { name: "License.txt", isFolder: false, compressedSize: "1.0 KB", realSize: "2.1 KB", ratio: "48%" },
                                            { name: "Changelog.pdf", isFolder: false, compressedSize: "120 KB", realSize: "190 KB", ratio: "63%" }
                                        ]
                                    },
                                    { name: "archive_manifest.json", isFolder: false, compressedSize: "0.8 KB", realSize: "1.5 KB", ratio: "53%" }
                                ]
                                item.itemSelected.connect((name) => { statusText.text = "Selected: " + name })
                            }
                        }
                    }

                    // Drop Area
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
                                    console.log("Dropped file full path: " + fullPath);
                                }
                                drop.acceptProposedAction();
                            }
                        }
                    }

                    // Drag Overlay
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
                                        text: "Release to import into archive"
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
                    Layout.preferredWidth: 460
                    Layout.minimumWidth: 460
                    Layout.maximumWidth: 460

                    visible: false
                    source: "ArchiveInfoPage.qml"
                    onLoaded: {
                        item.closeRequested.connect(() => {
                            infoPageLoader.visible = false
                        });
                    }
                }
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
}