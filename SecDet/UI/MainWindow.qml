import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import UI

Window {
    id: window
    width: 800
    height: 780
    minimumWidth: 600
    minimumHeight: 500
    visible: true
    title: "SecDet"

    FontLoader {
        id: materialIcons
        source: "Fonts/MaterialIconsRound-Regular.otf"
    }

    component IslandButton : Item {
        id: iconBtn
        property string iconText: ""
        property string labelText: ""
        signal clicked()

        implicitWidth: 36
        implicitHeight: 32

        Rectangle {
            id: iconBg
            anchors.fill: parent
            radius: iconBg.width/2
            color: mouseArea.containsPress ? Qt.rgba(0.9, 0.76, 0.35, 0.25)
                 : mouseArea.containsMouse ? Qt.rgba(0.9, 0.76, 0.35, 0.12)
                 : "transparent"

            border.color: mouseArea.containsMouse ? Colors.goldBorderHi : "transparent"
            border.width: 1

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: iconBtn.iconText
                font.family: materialIcons.name
                font.pixelSize: 18
                color: mouseArea.containsMouse ? Colors.goldHover : Colors.goldPrimary

                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }

        ToolTip.visible: mouseArea.containsMouse && labelText !== ""
        ToolTip.delay: 400
        ToolTip.text: labelText

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: iconBtn.clicked()
            scale: containsPress ? 0.94 : 1.0
            Behavior on scale { NumberAnimation { duration: 100 } }
        }
    }

    // --- Component: Premium Gold Progress Bar ---
    component SleekProgressBar : Item {
        id: pBar
        property real value: 0.0

        Layout.fillWidth: true
        implicitHeight: 3

        Rectangle {
            anchors.fill: parent
            radius: 1.5
            color: "#181a20"

            Rectangle {
                width: parent.width * Math.max(0, Math.min(pBar.value, 1.0))
                height: parent.height
                radius: 1.5

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#a88638" }
                    GradientStop { position: 1.0; color: Colors.goldHover }
                }

                Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            }
        }
    }

    // --- Component: Directory Tree View ---
    Component {
        id: treeDirectoryViewComp

        Column {
            id: treeComp
            property var nodes: []
            property int depth: 0
            signal itemSelected(string name)

            spacing: 2
            width: parent ? parent.width : 0

            // ==========================================
            // --- Excel-Style Header (Root Level Only) ---
            // ==========================================
            Rectangle {
                visible: treeComp.depth === 0
                width: parent.width
                height: 28
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(1, 1, 1, 0.1)
                border.width: 1
                radius: 4

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: "Name"
                        color: Colors.textMuted
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        Layout.fillWidth: true
                    }

                    // Vertical Grid Divider
                    Rectangle { width: 1; height: 14; color: Qt.rgba(1, 1, 1, 0.1) }

                    Text {
                        text: "Compressed"
                        color: Colors.textMuted
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        Layout.preferredWidth: 80
                        horizontalAlignment: Text.AlignRight
                    }

                    // Vertical Grid Divider
                    Rectangle { width: 1; height: 14; color: Qt.rgba(1, 1, 1, 0.1) }

                    Text {
                        text: "Real Size"
                        color: Colors.textMuted
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        Layout.preferredWidth: 80
                        horizontalAlignment: Text.AlignRight
                    }

                    // Vertical Grid Divider
                    Rectangle { width: 1; height: 14; color: Qt.rgba(1, 1, 1, 0.1) }

                    Text {
                        text: "Ratio"
                        color: Colors.textMuted
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        Layout.preferredWidth: 50
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            // ==========================================
            // --- Tree View Rows ---
            // ==========================================
            Repeater {
                model: treeComp.nodes

                delegate: Column {
                    width: parent.width
                    property bool isOpen: modelData.expanded || false

                    Rectangle {
                        width: parent.width
                        height: 32
                        radius: 6
                        color: itemMouse.containsPress ? Qt.rgba(0.9, 0.76, 0.35, 0.15)
                            : itemMouse.containsMouse ? Qt.rgba(0.9, 0.76, 0.35, 0.06)
                            : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: (treeComp.depth * 16) + 10
                            anchors.rightMargin: 10
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
                                    onClicked: parent.parent.parent.parent.isOpen = !parent.parent.parent.parent.isOpen
                                }
                            }

                            // Icon (Folder / File)
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
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            // --- Column 1: Compressed Size ---
                            Text {
                                text: modelData.compressedSize !== undefined ? modelData.compressedSize : "-"
                                color: Colors.textMuted
                                font.pixelSize: 11
                                Layout.preferredWidth: 80
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                            }

                            // --- Column 2: Real Size ---
                            Text {
                                text: modelData.realSize !== undefined ? modelData.realSize : "-"
                                color: Colors.textMuted
                                font.pixelSize: 11
                                Layout.preferredWidth: 80
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                            }

                            // --- Column 3: Compression Ratio ---
                            Text {
                                text: modelData.ratio !== undefined ? modelData.ratio : "-"
                                color: Colors.goldPrimary || Colors.textMain
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                Layout.preferredWidth: 50
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
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
                                treeComp.itemSelected(modelData.name);
                            }
                        }
                    }

                    // Recursive Sub-tree Loader
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
    
    PasswordDialog{
        id: passIn
        anchors.centerIn: parent
    }

    Rectangle {
        id: mainContainer
        anchors.fill: parent
        color: Colors.bgMain
        border.color: Colors.goldBorder
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 0

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                height: 38
                z: 2

                Rectangle {
                    id: islandContainer
                    anchors.left: parent.left
                    anchors.leftMargin: 0
                    anchors.bottom: parent.bottom
                    height: 38
                    width: islandRow.implicitWidth + 20

                    color: Colors.bgSurface
                    border.color: Colors.goldBorder
                    border.width: 1

                    topLeftRadius: 12
                    topRightRadius: 12
                    bottomLeftRadius: 0
                    bottomRightRadius: 0

                    RowLayout {
                        id: islandRow
                        anchors.centerIn: parent
                        spacing: 4
                        
                        Text{
                            text: "folder_zip"
                            font.family: materialIcons.name
                            font.pixelSize: 12
                            color: Colors.textMuted
                        }

                        Text{
                            text: "ArchiveName.tr"
                            font.pixelSize: 12
                            color: Colors.textMain
                        }

                        Rectangle {
                            width: 1
                            height: 16
                            Layout.leftMargin: 2
                            color: Colors.goldBorder
                            Layout.alignment: Qt.AlignVCenter
                        }

                        IslandButton {
                            iconText: "add_circle"
                            labelText: "Add to Archive"
                            onClicked: {
                                statusText.text = "Add file to archive..."
                                pBar.value = 0.3
                                passIn.open()
                            }
                        }

                        IslandButton {
                            iconText: "unarchive"
                            labelText: "Extract All"
                            onClicked: {
                                statusText.text = "Extracting all into a folder..."
                                pBar.value = 0.6
                            }
                        }
                        
                        IslandButton {
                            iconText: "\ue8b8" // settings
                            labelText: "Settings"
                            onClicked: {
                                statusText.text = "Opening preferences..."
                            }
                        }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 1
                        anchors.rightMargin: 1
                        height: 1
                        color: Colors.bgSurface
                    }
                }
                Shape {
                    anchors.left: islandContainer.right
                    anchors.bottom: islandContainer.bottom
                    width: 12
                    height: 12

                    ShapePath {
                        fillColor: Colors.bgSurface
                        strokeColor: Colors.goldBorder
                        strokeWidth: 1

                        PathMove { x: 0; y: 12 }
                        PathArc {
                            x: 12
                            y: 0
                            radiusX: 12
                            radiusY: 12
                            direction: PathArc.CounterClockwise
                        }
                        PathLine { x: 0; y: 0 }
                        PathLine { x: 0; y: 12 }
                    }

                    // Covers top & left inner stroke lines so fill joins cleanly
                    Rectangle {
                        width: 12
                        height: 1
                        color: Colors.bgSurface
                        anchors.top: parent.top
                    }
                    Rectangle {
                        width: 1
                        height: 12
                        color: Colors.bgSurface
                        anchors.left: parent.left
                    }
                }
            }

            RowLayout{
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 420
                    Layout.minimumWidth: 260
                    color: Colors.bgSurface
                    
                    topLeftRadius: 0
                    topRightRadius: 12
                    bottomLeftRadius: 12
                    bottomRightRadius: 12

                    border.color: Colors.goldBorder
                    border.width: 1

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 8
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
                }

                Loader {
                    id: infoPageLoader
                    Layout.fillHeight: true
                    Layout.fillWidth: false
                    Layout.preferredWidth: 400
                    Layout.minimumWidth: 400
                    Layout.maximumWidth: 400
                    
                    source: "ArchiveInfoPage.qml"
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Item { 
                Layout.fillWidth: true
                Layout.preferredHeight: 6 
                height: 6
            }

            SleekProgressBar {
                id: pBar
                Layout.fillWidth: true
                value: 0.4
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                height: 28
                color: Colors.bgSurface
                radius: 8
                border.color: Qt.rgba(0.24, 0.2, 0.13, 0.5)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12

                    Text {
                        id: statusText
                        text: "Ready • 8 files loaded (12.4 MB)"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: Colors.textMuted
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Text {
                        text: Math.round(pBar.value * 100) + "%"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: Colors.goldPrimary
                    }
                }
            }
        }
    }
}