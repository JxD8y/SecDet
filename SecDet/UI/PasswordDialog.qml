import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import UI

Dialog {
    id: passwordDialog
    anchors.centerIn: parent
    width: 360
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    // Signal emitted when user submits the password
    signal acceptedPassword(string password)

    // Dark backdrop overlay matching theme
    Overlay.modal: Rectangle {
        color: "#b0000000"
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    background: Rectangle {
        color: Colors.bgSurface
        radius: 14
        border.color: Colors.goldBorderHi
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 16

        // --- Header: Icon & Title ---
        RowLayout {
            spacing: 12
            Layout.fillWidth: true

            Rectangle {
                width: 38; height: 38; radius: 19
                color: Qt.rgba(0.9, 0.76, 0.35, 0.1)
                border.color: Colors.goldBorder
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "\ue897" // lock icon
                    font.family: materialIcons.name
                    font.pixelSize: 20
                    color: Colors.goldPrimary
                }
            }

            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true

                Text {
                    text: "Password Required"
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    color: Colors.textMain
                }

                Text {
                    text: "Enter password to unlock or extract contents"
                    font.pixelSize: 11
                    color: Colors.textMuted
                }
            }
        }

        // --- Password Input Field ---
        Rectangle {
            Layout.fillWidth: true
            height: 40
            radius: 8
            color: Colors.bgMain
            border.color: passInput.activeFocus ? Colors.goldBorderHi : Colors.goldBorder
            border.width: 1

            Behavior on border.color { ColorAnimation { duration: 150 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 8
                spacing: 8

                TextField {
                    id: passInput
                    Layout.fillWidth: true
                    placeholderText: "Enter password..."
                    color: Colors.textMain
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

                // Show/Hide Toggle Button
                Item {
                    id: showPassBtn
                    property bool showPassword: false
                    implicitWidth: 28
                    implicitHeight: 28

                    Text {
                        anchors.centerIn: parent
                        text: showPassBtn.showPassword ? "\ue8f4" : "\ue8f5" // visibility / visibility_off
                        font.family: materialIcons.name
                        font.pixelSize: 18
                        color: eyeMouse.containsMouse ? Colors.goldHover : Colors.textMuted
                    }

                    MouseArea {
                        id: eyeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: showPassBtn.showPassword = !showPassBtn.showPassword
                    }
                }
            }
        }

        // --- Action Buttons ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Cancel Button
            Rectangle {
                Layout.fillWidth: true
                height: 36
                radius: 8
                color: cancelMouse.containsPress ? Qt.rgba(1, 1, 1, 0.08)
                     : cancelMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.04)
                     : "transparent"
                border.color: cancelMouse.containsMouse ? Colors.goldBorderHi : Colors.goldBorder
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "Cancel"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Colors.textMuted
                }

                MouseArea {
                    id: cancelMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: passwordDialog.close()
                }
            }

            // Unlock Button
            Rectangle {
                Layout.fillWidth: true
                height: 36
                radius: 8
                color: confirmMouse.containsPress ? Qt.darker(Colors.goldPrimary, 1.2)
                     : confirmMouse.containsMouse ? Colors.goldHover
                     : Colors.goldPrimary

                Text {
                    anchors.centerIn: parent
                    text: "Unlock"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: Colors.bgMain
                }

                MouseArea {
                    id: confirmMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (passInput.text.length > 0) {
                            passwordDialog.acceptedPassword(passInput.text)
                            passwordDialog.close()
                        }
                    }
                }
            }
        }
    }

    // Auto-focus and clear field when shown
    onOpened: {
        passInput.text = ""
        passInput.forceActiveFocus()
    }
}