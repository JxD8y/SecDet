import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import UI

Page {
    id: root
    width: 500
    implicitWidth: 500
    Layout.preferredWidth: 500
    Layout.minimumWidth: 500
    Layout.maximumWidth: 500
    Layout.fillWidth: false
    signal closeRequested()
    signal saveRequested()

    FontLoader {
        id: materialIcons
        source: "Fonts/MaterialIconsRound-Regular.otf"
    }

    component GoldCheckBox : RowLayout {
        id: cbRoot
        property string text: ""
        property bool checked: false
        signal toggled(bool isChecked)

        spacing: 10

        Rectangle {
            id: box
            width: 18
            height: 18
            radius: 4
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
                color: "#0d0e11"
                visible: cbRoot.checked
            }
        }

        Text {
            text: cbRoot.text
            color: Colors.textMain
            font.pixelSize: 12
            font.weight: Font.Medium
            Layout.fillWidth: true
            elide: Text.ElideRight
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

    // --- Custom Gold Toggle Switch ---
    component GoldSwitch : RowLayout {
        id: swRoot
        property string text: ""
        property bool checked: false
        signal toggled(bool isChecked)

        spacing: 12

        Text {
            text: swRoot.text
            color: Colors.textMain
            font.pixelSize: 12
            font.weight: Font.Medium
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        Rectangle {
            id: track
            width: 38
            height: 20
            radius: 10
            color: swRoot.checked ? Qt.rgba(0.9, 0.76, 0.35, 0.25) : "#101217"
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

    component TripleToggle : Rectangle {
        id: toggleRoot
        property int currentIndex: 1 // 0: Fast, 1: Balanced, 2: Ultra
        property var options: ["Fast (Store)", "Balanced (Deflate)", "Ultra (LZMA2)"]
        signal selected(int index)

        implicitWidth: 320
        implicitHeight: 34
        radius: 8
        color: Colors.bgMain
        border.color: Colors.goldBorder
        border.width: 1

        // Animated Active Pill Background
        Rectangle {
            id: activePill
            width: (toggleRoot.width - 6) / 3
            height: toggleRoot.height - 6
            y: 3
            x: 3 + toggleRoot.currentIndex * width
            radius: 6
            color: Qt.rgba(0.9, 0.76, 0.35, 0.18)
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

    Rectangle {
        id: dialogFrame
        anchors.fill: parent
        color: Colors.bgCard
        radius: 16
        border.color: Colors.goldBorder
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14

        RowLayout {
            Layout.fillWidth: true

            RowLayout {
                spacing: 8
                Text {
                    text: "info"
                    font.family: materialIcons.name
                    font.pixelSize: 22
                    color: Colors.goldPrimary
                }

                Text {
                    text: "Archive info"
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    color: Colors.textMain
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
                    onClicked: root.closeRequested()
                }
            }
        }

        // --- SECTION 1: COMPRESSION RATIO TRIPLE TOGGLE & OPTIONS ---
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: compColumn.implicitHeight + 24
            color: Colors.bgSurface
            radius: 12
            border.color: Colors.goldBorder
            border.width: 1

            ColumnLayout {
                id: compColumn
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                Text {
                    text: "COMPRESSION LEVEL"
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    color: Colors.goldPrimary
                }

                TripleToggle {
                    Layout.fillWidth: true
                    currentIndex: 1
                    onSelected: (idx) => console.log("Compression preset:", options[idx])
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(0.24, 0.2, 0.13, 0.4) }

                // Switches & Checkboxes Grid
                GridLayout {
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 10
                    Layout.fillWidth: true

                    GoldSwitch {
                        text: "AES-256 Encryption"
                        checked: true
                        Layout.fillWidth: true
                    }

                    GoldSwitch {
                        text: "Solid Block Mode"
                        checked: false
                        Layout.fillWidth: true
                    }

                    GoldCheckBox {
                        text: "Preserve Permissions"
                        checked: true
                        Layout.fillWidth: true
                    }

                    GoldCheckBox {
                        text: "Integrity Verification Check"
                        checked: true
                        Layout.fillWidth: true
                    }
                }
            }
        }

        // --- SECTION 2: ARCHIVE README MANIFEST (LIST VIEW) ---
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 110
            color: Colors.bgSurface
            radius: 12
            border.color: Colors.goldBorder
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "\ue873" // description
                        font.family: materialIcons.name
                        font.pixelSize: 14
                        color: Colors.goldPrimary
                    }
                    Text {
                        text: "ARCHIVE README.TXT"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: Colors.goldPrimary
                        Layout.fillWidth: true
                    }
                    Text {
                        text: "328 Bytes"
                        font.pixelSize: 10
                        color: Colors.textMuted
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Colors.bgMain
                    radius: 6
                    border.color: Qt.rgba(0.24, 0.2, 0.13, 0.5)

                    ListView {
                        anchors.fill: parent
                        anchors.margins: 6
                        clip: true
                        spacing: 4

                        model: ListModel {
                            ListElement { sectionTitle: "Project"; lineContent: "Dark Gold Engine v2.4 Release Build" }
                            ListElement { sectionTitle: "Author"; lineContent: "Core UI/UX Engineering Team" }
                            ListElement { sectionTitle: "Checksum"; lineContent: "SHA256: e3b0c44298fc1c149afbf4c8996fb924" }
                            ListElement { sectionTitle: "Notice"; lineContent: "Encrypted payload requires key verification on extract." }
                        }

                        delegate: RowLayout {
                            width: ListView.view ? ListView.view.width : parent.width
                            spacing: 8

                            Text {
                                text: model.sectionTitle + ":"
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: Colors.goldHover
                                Layout.preferredWidth: 65
                            }
                            Text {
                                text: model.lineContent
                                font.pixelSize: 11
                                color: Colors.textMain
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }

        // --- SECTION 3: ADVANCED ENTROPY VIEW (FEATURED COMPONENT) ---
        Rectangle {
            id: entropyCard
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Colors.bgSurface
            radius: 12
            border.color: Colors.goldBorder
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // Header & Live Bits/Byte Indicator
                RowLayout {
                    Layout.fillWidth: true

                    RowLayout {
                        spacing: 6
                        Text {
                            text: "\ue880" // analytics / timeline
                            font.family: materialIcons.name
                            font.pixelSize: 16
                            color: Colors.goldPrimary
                        }
                        Text {
                            text: "SHANNON ENTROPY MATRIX"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: Colors.goldPrimary
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // High Entropy Warning Badge
                    Rectangle {
                        implicitWidth: badgeRow.implicitWidth + 12
                        implicitHeight: 20
                        radius: 10
                        color: Qt.rgba(0.9, 0.76, 0.35, 0.15)
                        border.color: Colors.goldBorderHi
                        border.width: 1

                        RowLayout {
                            id: badgeRow
                            anchors.centerIn: parent
                            spacing: 4
                            Rectangle { width: 6; height: 6; radius: 3; color: "#4ade80" }
                            Text {
                                text: "Avg: 7.84 Bits/Byte (High Density)"
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: Colors.goldHover
                            }
                        }
                    }
                }

                // --- HISTOGRAM CANVAS VIEW ---
                Item {
                    id: histogramContainer
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    implicitHeight: 100

                    // Entropy Dataset representing 36 archive chunks (0.0 to 8.0 bits)
                    readonly property var entropyData: [
                        2.1, 3.4, 4.2, 5.8, 7.2, 7.8, 7.9, 7.95, 7.9, 7.88, 
                        7.5, 6.2, 4.1, 7.9, 7.92, 7.98, 7.95, 7.89, 7.92, 7.91, 
                        7.85, 7.9, 7.95, 6.0, 3.1, 2.0, 7.9, 7.95, 7.98, 8.0, 
                        7.8, 7.9, 7.85, 7.1, 5.2, 3.0
                    ]

                    // Range selection values (normalized 0.0 to 1.0)
                    property real rangeStart: 0.20 // 20%
                    property real rangeEnd: 0.80   // 80%

                    // Background Grid Lines
                    Column {
                        anchors.fill: parent
                        spacing: (parent.height - 3) / 3
                        Repeater {
                            model: 3
                            Rectangle {
                                width: histogramContainer.width
                                height: 1
                                color: Qt.rgba(0.24, 0.2, 0.13, 0.25)
                            }
                        }
                    }

                    // Histogram Bars
                    RowLayout {
                        anchors.fill: parent
                        anchors.topMargin: 4
                        anchors.bottomMargin: 4
                        spacing: 3

                        Repeater {
                            model: histogramContainer.entropyData

                            Item {
                                id: barItem
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                property real barNormalizedX: index / histogramContainer.entropyData.length
                                property bool inRange: barNormalizedX >= histogramContainer.rangeStart && barNormalizedX <= histogramContainer.rangeEnd

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.width
                                    height: Math.max(4, (modelData / 8.0) * parent.height)
                                    radius: 2

                                    color: barItem.inRange ? Colors.goldPrimary : "#24211a"
                                    border.color: barItem.inRange ? Colors.goldHover : "transparent"
                                    border.width: barItem.inRange ? 1 : 0

                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    // Top Glow Accent for High Entropy (>7.5) within selected range
                                    Rectangle {
                                        width: parent.width
                                        height: 2
                                        anchors.top: parent.top
                                        color: modelData > 7.5 ? "#ffffff" : Colors.goldHover
                                        visible: barItem.inRange
                                    }
                                }
                            }
                        }
                    }
                }

                // --- ADVANCED RANGE SLIDER WITH DUAL THUMBS ---
                Item {
                    id: rangeSlider
                    Layout.fillWidth: true
                    height: 24

                    readonly property real trackWidth: width - 16

                    // Start Thumb Drag Handler
                    Item {
                        id: startThumb
                        width: 16; height: 16
                        y: 4
                        x: Math.max(0, Math.min(rangeSlider.trackWidth, histogramContainer.rangeStart * rangeSlider.trackWidth))

                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: startMouse.containsPress ? Colors.goldHover : Colors.goldPrimary
                            border.color: "#ffffff"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "\ue5c4" // arrow back
                                font.family: materialIcons.name
                                font.pixelSize: 10
                                color: "#0d0e11"
                            }
                        }

                        MouseArea {
                            id: startMouse
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.SizeHorCursor
                            property real dragStartX: 0
                            property real initialRangeStart: 0

                            onPressed: (mouse) => {
                                dragStartX = mouse.x
                                initialRangeStart = histogramContainer.rangeStart
                            }

                            onPositionChanged: (mouse) => {
                                if (pressed && rangeSlider.trackWidth > 0) {
                                    var deltaNorm = (mouse.x - dragStartX) / rangeSlider.trackWidth
                                    var newStart = Math.max(0.0, Math.min(histogramContainer.rangeEnd - 0.05, initialRangeStart + deltaNorm))
                                    histogramContainer.rangeStart = newStart
                                }
                            }
                        }
                    }

                    // End Thumb Drag Handler
                    Item {
                        id: endThumb
                        width: 16; height: 16
                        y: 4
                        x: Math.max(0, Math.min(rangeSlider.trackWidth, histogramContainer.rangeEnd * rangeSlider.trackWidth))

                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: endMouse.containsPress ? Colors.goldHover : Colors.goldPrimary
                            border.color: "#ffffff"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "\ue5c8" // arrow forward
                                font.family: materialIcons.name
                                font.pixelSize: 10
                                color: "#0d0e11"
                            }
                        }

                        MouseArea {
                            id: endMouse
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.SizeHorCursor
                            property real dragStartX: 0
                            property real initialRangeEnd: 0

                            onPressed: (mouse) => {
                                dragStartX = mouse.x
                                initialRangeEnd = histogramContainer.rangeEnd
                            }

                            onPositionChanged: (mouse) => {
                                if (pressed && rangeSlider.trackWidth > 0) {
                                    var deltaNorm = (mouse.x - dragStartX) / rangeSlider.trackWidth
                                    var newEnd = Math.max(histogramContainer.rangeStart + 0.05, Math.min(1.0, initialRangeEnd + deltaNorm))
                                    histogramContainer.rangeEnd = newEnd
                                }
                            }
                        }
                    }

                    // Active Range Highlight Track
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: startThumb.x + 8
                        width: Math.max(0, endThumb.x - startThumb.x)
                        height: 3
                        radius: 1.5
                        color: Colors.goldPrimary
                        z: -1
                    }

                    // Background Track Bar
                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 10.5
                        anchors.bottomMargin: 10.5
                        radius: 1.5
                        color: "#181a20"
                        z: -2
                    }
                }

                // Range Metrics Readout
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Start Offset: " + Math.round(histogramContainer.rangeStart * 512) + " MB"
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: Colors.textMuted
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "Span: " + Math.round((histogramContainer.rangeEnd - histogramContainer.rangeStart) * 512) + " MB"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: Colors.goldHover
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "End Offset: " + Math.round(histogramContainer.rangeEnd * 512) + " MB"
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: Colors.textMuted
                    }
                }
            }
        }

        // --- DIALOG ACTION BUTTONS ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Item { Layout.fillWidth: true }

            // Cancel Button
            Rectangle {
                implicitWidth: 100
                implicitHeight: 34
                radius: 8
                color: cancelArea.containsMouse ? Qt.rgba(1,1,1,0.06) : "transparent"
                border.color: Colors.goldBorder
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "Cancel"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Colors.textMuted
                }

                MouseArea {
                    id: cancelArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.closeRequested()
                }
            }

            // Save / Apply Button
            Rectangle {
                implicitWidth: 130
                implicitHeight: 34
                radius: 8
                color: saveArea.containsPress ? Qt.rgba(0.9, 0.76, 0.35, 0.8) : (saveArea.containsMouse ? Colors.goldHover : Colors.goldPrimary)

                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: "\ue877" // check_circle
                        font.family: materialIcons.name
                        font.pixelSize: 16
                        color: "#0d0e11"
                    }
                    Text {
                        text: "Save Settings"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: "#0d0e11"
                    }
                }

                MouseArea {
                    id: saveArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.saveRequested()
                }
            }
        }
    }
}