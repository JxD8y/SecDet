import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import UI

Page {
    id: root
    width: 460
    implicitWidth: 460
    Layout.preferredWidth: 460
    Layout.minimumWidth: 460
    Layout.maximumWidth: 460
    Layout.fillWidth: false

    background: Rectangle {
        color: "transparent"
    }

    signal closeRequested()
    signal saveRequested()

    FontLoader {
        id: materialIcons
        source: "Fonts/MaterialIconsRound-Regular.otf"
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

    Rectangle {
        id: dialogFrame
        anchors.fill: parent
        color: Colors.bgCard
        radius: 12
        border.color: Colors.goldBorder
        border.width: 1

        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on border.color { ColorAnimation { duration: 200 } }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // ==========================================
        // --- Header: Title & Close Button ---
        // ==========================================
        RowLayout {
            Layout.fillWidth: true

            RowLayout {
                spacing: 8
                Text {
                    text: "info"
                    font.family: materialIcons.name
                    font.pixelSize: 20
                    color: Colors.goldPrimary
                }

                Text {
                    text: "Archive Info & Settings"
                    font.family: Colors.fontFamily
                    font.pixelSize: 14
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
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }

        // ==========================================
        // --- SECTION 1: Compression Preset & Options ---
        // ==========================================
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: compColumn.implicitHeight + 20
            color: Colors.bgSurface
            radius: 10
            border.color: Colors.goldBorder
            border.width: 1

            ColumnLayout {
                id: compColumn
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
                    Layout.fillWidth: true
                    currentIndex: 1
                    onSelected: (idx) => console.log("Compression preset:", options[idx])
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Colors.divider }

                GridLayout {
                    columns: 2
                    columnSpacing: 14
                    rowSpacing: 8
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
            border.color: Colors.goldBorder
            border.width: 1

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
                            }
                        }
                    }

                }
                RowLayout{
                    TextField {
                        id: passInput
                        Layout.fillWidth: true
                        placeholderText: "Enter password..."
                        placeholderTextColor: Colors.textSubtle
                        color: Colors.textMain
                        font.family: Colors.fontFamily
                        font.pixelSize: 13
                        echoMode: showPassBtn.showPassword ? TextInput.Normal : TextInput.Password
                        background: null
                        onAccepted: {
                            if (passInput.text.length > 0) {
                                passwordDialog.acceptedPassword(passInput.text)
                                passwordDialog.close()
                            }
                        }
                    }
                    Text{
                        font.family: materialIcons.name
                        font.pixelSize: 16
                        color: Colors.goldBorder
                        text: "add"
                    }
                }
            }
        }

        // ==========================================
        // --- SECTION 3: Shannon Entropy Matrix ---
        // ==========================================
        Rectangle {
            id: entropyCard
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Colors.bgSurface
            radius: 10
            border.color: Colors.goldBorder
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                // Header & Live Indicator
                RowLayout {
                    Layout.fillWidth: true

                    RowLayout {
                        spacing: 6
                        Text {
                            text: "\ue880" // analytics
                            font.family: materialIcons.name
                            font.pixelSize: 16
                            color: Colors.goldPrimary
                        }
                        Text {
                            text: "SHANNON ENTROPY MATRIX"
                            font.family: Colors.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: Colors.goldPrimary
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        implicitWidth: badgeRow.implicitWidth + 12
                        implicitHeight: 20
                        radius: 10
                        color: Colors.goldLight
                        border.color: Colors.goldBorderHi
                        border.width: 1

                        RowLayout {
                            id: badgeRow
                            anchors.centerIn: parent
                            spacing: 4
                            Rectangle { width: 6; height: 6; radius: 3; color: "#4ade80" }
                            Text {
                                text: "Avg: 7.84 Bits/Byte"
                                font.family: Colors.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: Colors.goldHover
                            }
                        }
                    }
                }

                // Histogram View
                Item {
                    id: histogramContainer
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    implicitHeight: 90

                    readonly property var entropyData: [
                        2.1, 3.4, 4.2, 5.8, 7.2, 7.8, 7.9, 7.95, 7.9, 7.88, 
                        7.5, 6.2, 4.1, 7.9, 7.92, 7.98, 7.95, 7.89, 7.92, 7.91, 
                        7.85, 7.9, 7.95, 6.0, 3.1, 2.0, 7.9, 7.95, 7.98, 8.0, 
                        7.8, 7.9, 7.85, 7.1, 5.2, 3.0
                    ]

                    property real rangeStart: 0.20
                    property real rangeEnd: 0.80

                    Column {
                        anchors.fill: parent
                        spacing: (parent.height - 3) / 3
                        Repeater {
                            model: 3
                            Rectangle {
                                width: histogramContainer.width
                                height: 1
                                color: Colors.divider
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.topMargin: 4
                        anchors.bottomMargin: 4
                        spacing: 2

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

                                    color: barItem.inRange ? Colors.goldPrimary : (Colors.isDarkMode ? "#222530" : "#e4e5eb")
                                    border.color: barItem.inRange ? Colors.goldHover : "transparent"
                                    border.width: barItem.inRange ? 1 : 0

                                    Behavior on color { ColorAnimation { duration: 120 } }

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

                // Dual Thumbs Range Slider
                Item {
                    id: rangeSlider
                    Layout.fillWidth: true
                    height: 22

                    readonly property real trackWidth: width - 16

                    Item {
                        id: startThumb
                        width: 16; height: 16
                        y: 3
                        x: Math.max(0, Math.min(rangeSlider.trackWidth, histogramContainer.rangeStart * rangeSlider.trackWidth))

                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: startMouse.containsPress ? Colors.goldHover : Colors.goldPrimary
                            border.color: Colors.goldBorderHi
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "\ue5c4" // arrow back
                                font.family: materialIcons.name
                                font.pixelSize: 10
                                color: Colors.textOnGold
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

                    Item {
                        id: endThumb
                        width: 16; height: 16
                        y: 3
                        x: Math.max(0, Math.min(rangeSlider.trackWidth, histogramContainer.rangeEnd * rangeSlider.trackWidth))

                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: endMouse.containsPress ? Colors.goldHover : Colors.goldPrimary
                            border.color: Colors.goldBorderHi
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "\ue5c8" // arrow forward
                                font.family: materialIcons.name
                                font.pixelSize: 10
                                color: Colors.textOnGold
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

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: startThumb.x + 8
                        width: Math.max(0, endThumb.x - startThumb.x)
                        height: 3
                        radius: 1.5
                        color: Colors.goldPrimary
                        z: -1
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 9.5
                        anchors.bottomMargin: 9.5
                        radius: 1.5
                        color: Colors.bgElevated
                        z: -2
                    }
                }

                // Range Metrics
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Start: " + Math.round(histogramContainer.rangeStart * 512) + " MB"
                        font.family: Colors.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: Colors.textMuted
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "Span: " + Math.round((histogramContainer.rangeEnd - histogramContainer.rangeStart) * 512) + " MB"
                        font.family: Colors.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: Colors.goldHover
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "End: " + Math.round(histogramContainer.rangeEnd * 512) + " MB"
                        font.family: Colors.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: Colors.textMuted
                    }
                }
            }
        }

        // ==========================================
        // --- Dialog Action Buttons ---
        // ==========================================
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Item { Layout.fillWidth: true }

            Rectangle {
                implicitWidth: 100
                implicitHeight: 34
                radius: 6
                color: cancelArea.containsMouse ? Colors.bgHover : "transparent"
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
                    id: cancelArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }

            Rectangle {
                implicitWidth: 130
                implicitHeight: 34
                radius: 6
                color: saveArea.containsPress ? Qt.darker(Colors.goldPrimary, 1.15) : (saveArea.containsMouse ? Colors.goldHover : Colors.goldPrimary)

                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: "\ue877" // check_circle
                        font.family: materialIcons.name
                        font.pixelSize: 16
                        color: Colors.textOnGold
                    }
                    Text {
                        text: "Save Settings"
                        font.family: Colors.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: Colors.textOnGold
                    }
                }

                MouseArea {
                    id: saveArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.saveRequested()
                }
            }
        }
    }
}