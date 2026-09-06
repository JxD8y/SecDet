import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import UI

Dialog {
    id: settingsDialog
    parent: Overlay.overlay
    x: parent ? Math.round((parent.width - width) / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0
    width: parent ? Math.min(parent.width - 40, 520) : 520
    implicitHeight: Math.min(parent ? parent.height - 40 : 640, contentCol.implicitHeight + 36)
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding: 16

    signal saveRequested()
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
        property bool isControlEnabled: true
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
                color: cbRoot.checked ? (cbRoot.isControlEnabled ? Colors.goldPrimary : Colors.borderSubtle) : "transparent"
                border.color: cbRoot.checked
                            ? (cbRoot.isControlEnabled ? Colors.goldHover : Colors.borderSubtle)
                            : (cbRoot.isControlEnabled && cbArea.containsMouse ? Colors.goldBorderHi : Colors.goldBorder)
                border.width: 1

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "\ue5ca" // check mark
                    font.family: materialIcons.name
                    font.pixelSize: 14
                    color: cbRoot.isControlEnabled ? Colors.textOnGold : Colors.textMuted
                    visible: cbRoot.checked
                }
            }

            Text {
                text: cbRoot.text
                color: cbRoot.isControlEnabled ? Colors.textMain : Colors.textSubtle
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
            enabled: cbRoot.isControlEnabled
            hoverEnabled: cbRoot.isControlEnabled
            cursorShape: cbRoot.isControlEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
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
        property bool isControlEnabled: true
        signal toggled(bool isChecked)

        implicitWidth: swRow.implicitWidth
        implicitHeight: Math.max(22, swRow.implicitHeight)

        RowLayout {
            id: swRow
            anchors.fill: parent
            spacing: 12

            Text {
                text: swRoot.text
                color: swRoot.isControlEnabled ? Colors.textMain : Colors.textSubtle
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
                color: swRoot.checked
                     ? (swRoot.isControlEnabled ? Colors.goldLightHover : Qt.rgba(1, 1, 1, 0.08))
                     : Colors.bgInput
                border.color: swRoot.checked
                            ? (swRoot.isControlEnabled ? Colors.goldBorderHi : Colors.borderSubtle)
                            : (swRoot.isControlEnabled ? Colors.goldBorder : Colors.borderSubtle)
                border.width: 1

                Behavior on color { ColorAnimation { duration: 150 } }

                Rectangle {
                    id: thumb
                    width: 14
                    height: 14
                    radius: 7
                    anchors.verticalCenter: parent.verticalCenter
                    x: swRoot.checked ? parent.width - width - 3 : 3
                    color: swRoot.checked
                         ? (swRoot.isControlEnabled ? Colors.goldPrimary : Colors.textSubtle)
                         : Colors.textMuted

                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }
        }

        MouseArea {
            id: swArea
            anchors.fill: parent
            enabled: swRoot.isControlEnabled
            hoverEnabled: swRoot.isControlEnabled
            cursorShape: swRoot.isControlEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
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
        property int currentIndex: 1
        property var options: ["Fast (Store)", "Balanced", "Ultra"]
        property bool isControlEnabled: true
        signal selected(int index)

        implicitWidth: 320
        implicitHeight: 34
        radius: 8
        color: isControlEnabled ? Colors.bgInput : Qt.rgba(0.1, 0.1, 0.12, 0.6)
        border.color: isControlEnabled ? Colors.goldBorder : Colors.borderSubtle
        border.width: 1

        Rectangle {
            id: activePill
            width: (toggleRoot.width - 6) / Math.max(1, toggleRoot.options.length)
            height: toggleRoot.height - 6
            y: 3
            x: 3 + toggleRoot.currentIndex * width
            radius: 6
            color: toggleRoot.isControlEnabled ? Colors.goldLight : Qt.rgba(1, 1, 1, 0.06)
            border.color: toggleRoot.isControlEnabled ? Colors.goldBorderHi : Colors.borderSubtle
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
                        color: toggleRoot.currentIndex === index
                             ? (toggleRoot.isControlEnabled ? Colors.goldHover : Colors.textSubtle)
                             : Colors.textMuted

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: toggleRoot.isControlEnabled
                        cursorShape: toggleRoot.isControlEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            toggleRoot.currentIndex = index
                            toggleRoot.selected(index)
                        }
                    }
                }
            }
        }
    }

    contentItem: ScrollView {
        id: scrollContainer
        clip: true
        contentWidth: availableWidth

        ColumnLayout {
            id: contentCol
            width: scrollContainer.availableWidth
            spacing: 14

            // ==========================================
            // --- Dialog Header ---
            // ==========================================
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    width: 38
                    height: 38
                    radius: 19
                    color: Colors.goldLight
                    border.color: Colors.goldBorderHi
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "\ue8b8" // settings
                        font.family: materialIcons.name
                        font.pixelSize: 20
                        color: Colors.goldPrimary
                    }
                }

                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true

                    Text {
                        text: "Archive Settings"
                        font.family: Colors.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        color: Colors.textMain
                    }

                    Text {
                        text: "Compression profiles, block presets, and data recovery"
                        font.family: Colors.fontFamily
                        font.pixelSize: 11
                        color: Colors.textMuted
                    }
                }

                // Close (X) Button
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: closeMouse.containsMouse ? Qt.rgba(0.9, 0.3, 0.3, 0.2) : "transparent"
                    border.color: closeMouse.containsMouse ? "#d9534f" : Colors.goldBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "\ue5cd" // close
                        font.family: materialIcons.name
                        font.pixelSize: 15
                        color: closeMouse.containsMouse ? "#ff6b6b" : Colors.textMuted
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            settingsDialog.closeRequested()
                            settingsDialog.close()
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.divider
            }

            // ==========================================
            // --- BOX 1: Compression Settings ---
            // ==========================================
            Rectangle {
                id: compBox
                Layout.fillWidth: true
                implicitHeight: compBoxCol.implicitHeight + 24
                color: Colors.bgCard
                radius: 10
                border.color: Colors.goldBorder
                border.width: 1

                ColumnLayout {
                    id: compBoxCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    // Title Header Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "\ue871" // view_quilt / layers
                            font.family: materialIcons.name
                            font.pixelSize: 16
                            color: Colors.goldPrimary
                        }

                        Text {
                            text: "COMPRESSION LEVEL & OPTIONS"
                            font.family: Colors.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: Colors.goldPrimary
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            implicitWidth: 80
                            implicitHeight: 20
                            radius: 4
                            color: Colors.goldLight
                            border.color: Colors.goldBorderHi
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "LZMA2 / ZSTD"
                                font.family: Colors.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                color: Colors.goldHover
                            }
                        }
                    }

                    // Segmented Toggle
                    TripleToggle {
                        Layout.fillWidth: true
                        currentIndex: 1
                        options: ["Fast (Store)", "Balanced", "Ultra"]
                        onSelected: (idx) => console.log("Selected compression preset:", options[idx])
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Colors.divider
                    }

                    // Switches
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        GoldSwitch {
                            text: "Preserve File Attributes & Timestamps"
                            checked: true
                            Layout.fillWidth: true
                        }

                        GoldSwitch {
                            text: "Solid Block Compression (Improves Ratio)"
                            checked: true
                            Layout.fillWidth: true
                        }

                        GoldSwitch {
                            text: "Multi-threaded Compression (Auto-detect Cores)"
                            checked: true
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            // ==========================================
            // --- BOX 2: Recovery Settings (Disabled Look) ---
            // ==========================================
            Rectangle {
                id: recoveryBox
                Layout.fillWidth: true
                implicitHeight: recoveryBoxCol.implicitHeight + 24
                color: Colors.bgCard
                radius: 10
                border.color: Colors.borderSubtle
                border.width: 1

                ColumnLayout {
                    id: recoveryBoxCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    // Title Header Row with Disabled Badge
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "\ue8e8" // healing / health_and_safety / shield
                            font.family: materialIcons.name
                            font.pixelSize: 16
                            color: Colors.textMuted
                        }

                        Text {
                            text: "RECOVERY SETTINGS & REDUNDANCY"
                            font.family: Colors.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: Colors.textMuted
                        }

                        Item { Layout.fillWidth: true }

                        // Disabled Status Pill Badge
                        Rectangle {
                            implicitWidth: badgeRow.implicitWidth + 12
                            implicitHeight: 20
                            radius: 4
                            color: Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.05)
                            border.color: Colors.borderSubtle
                            border.width: 1

                            RowLayout {
                                id: badgeRow
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    text: "\ue897" // lock
                                    font.family: materialIcons.name
                                    font.pixelSize: 11
                                    color: Colors.textSubtle
                                }

                                Text {
                                    text: "INACTIVE PROFILE"
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                    color: Colors.textSubtle
                                }
                            }
                        }
                    }

                    // Disabled Content Container with proper muted styling
                    ColumnLayout {
                        id: disabledContentGroup
                        Layout.fillWidth: true
                        spacing: 12
                        opacity: 0.45

                        // 1. Dummy Recovery Switch
                        GoldSwitch {
                            text: "Enable Reed-Solomon Recovery Record (ECC)"
                            checked: false
                            isControlEnabled: false
                            Layout.fillWidth: true
                        }

                        // 2. Dummy Parity Level Toggle
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: "REDUNDANCY / PARITY LEVEL"
                                font.family: Colors.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: Colors.textSubtle
                            }

                            TripleToggle {
                                Layout.fillWidth: true
                                currentIndex: 1
                                isControlEnabled: false
                                options: ["3% (Standard)", "5% (Enhanced)", "10% (Maximum)"]
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Colors.divider
                        }

                        // 3. Dummy Checkbox Options
                        GridLayout {
                            columns: 1
                            rowSpacing: 8
                            Layout.fillWidth: true

                            GoldCheckBox {
                                text: "Distribute parity blocks across file boundaries"
                                checked: false
                                isControlEnabled: false
                                Layout.fillWidth: true
                            }

                            GoldCheckBox {
                                text: "Generate external recovery volumes (.rev files)"
                                checked: false
                                isControlEnabled: false
                                Layout.fillWidth: true
                            }
                        }
                    }

                    // Informational Notice Banner with subtle lock/info indicator
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: noticeRow.implicitHeight + 14
                        radius: 6
                        color: Colors.isDarkMode ? Qt.rgba(0.12, 0.12, 0.15, 0.5) : Qt.rgba(0.0, 0.0, 0.0, 0.03)
                        border.color: Colors.borderSubtle
                        border.width: 1

                        RowLayout {
                            id: noticeRow
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Text {
                                text: "\ue88f" // info_outline
                                font.family: materialIcons.name
                                font.pixelSize: 15
                                color: Colors.textSubtle
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Recovery parity generation requires the Reed-Solomon engine add-on. This module is currently unavailable."
                                font.family: Colors.fontFamily
                                font.pixelSize: 11
                                color: Colors.textMuted
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }

                // Disabled Cursor Overlay on Recovery Box
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.ForbiddenCursor
                    acceptedButtons: Qt.NoButton
                }
            }

            // ==========================================
            // --- BOX 3: Save and Cancel Box ---
            // ==========================================
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 12

                Item { Layout.fillWidth: true }

                // Cancel Button
                Rectangle {
                    implicitWidth: 100
                    implicitHeight: 36
                    radius: 6
                    color: cancelArea.containsMouse ? Colors.bgHover : "transparent"
                    border.color: Colors.goldBorder
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 120 } }

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
                        onClicked: {
                            settingsDialog.closeRequested()
                            settingsDialog.close()
                        }
                    }
                }

                // Save Settings Button
                Rectangle {
                    implicitWidth: 140
                    implicitHeight: 36
                    radius: 6
                    color: saveArea.containsPress
                         ? Qt.darker(Colors.goldPrimary, 1.15)
                         : (saveArea.containsMouse ? Colors.goldHover : Colors.goldPrimary)

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
                        onClicked: {
                            settingsDialog.saveRequested()
                            settingsDialog.close()
                        }
                    }
                }
            }
        }
    }
}
