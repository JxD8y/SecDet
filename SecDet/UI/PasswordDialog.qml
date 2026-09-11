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

    property string titleText: "Enter Password"
    property string reasonDescription: "Enter the archive password to continue"
    property string errorMessage: ""

    signal acceptedPassword(string password)

    function submitPassword() {
        if (passInput.text.length > 0) {
            errorMessage = ""
            passwordDialog.acceptedPassword(passInput.text)
        } else {
            errorMessage = "Please enter password."
            focusInput()
        }
    }

    function focusInput() {
        passInput.forceActiveFocus()
        passInput.selectAll()
    }

    Overlay.modal: Rectangle {
        color: Colors.overlayModal
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    background: Rectangle {
        color: Colors.bgSurface
        radius: 12
        border.color: Colors.goldBorderHi
        border.width: 1

        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on border.color { ColorAnimation { duration: 200 } }
    }

    contentItem: ColumnLayout {
        spacing: 14

        // Header: Icon & Title
        RowLayout {
            spacing: 12
            Layout.fillWidth: true

            Rectangle {
                width: 38; height: 38; radius: 19
                color: Colors.goldLight
                border.color: Colors.goldBorderHi
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
                    text: passwordDialog.titleText
                    font.family: Colors.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    color: Colors.textMain
                }

                Text {
                    text: passwordDialog.reasonDescription
                    font.family: Colors.fontFamily
                    font.pixelSize: 11
                    color: Colors.textMuted
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }
            }
        }

        // Password Input Field
        Rectangle {
            Layout.fillWidth: true
            height: 40
            radius: 6
            color: Colors.bgInput
            border.color: passwordDialog.errorMessage.length > 0 ? "#e05353"
                        : passInput.activeFocus ? Colors.goldBorderHi : Colors.borderSubtle
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
                    placeholderTextColor: Colors.textSubtle
                    color: Colors.textMain
                    font.family: Colors.fontFamily
                    font.pixelSize: 13
                    echoMode: showPassBtn.showPassword ? TextInput.Normal : TextInput.Password
                    background: null
                    onAccepted: passwordDialog.submitPassword()
                    onTextChanged: {
                        if (passwordDialog.errorMessage.length > 0) {
                            passwordDialog.errorMessage = ""
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
                        cursorShape: Qt.PointingHandCursor
                        onClicked: showPassBtn.showPassword = !showPassBtn.showPassword
                    }
                }
            }
        }

        // Inline Error Message Banner
        Rectangle {
            id: errorBanner
            Layout.fillWidth: true
            implicitHeight: passwordDialog.errorMessage.length > 0 ? 30 : 0
            visible: passwordDialog.errorMessage.length > 0
            radius: 6
            color: Qt.rgba(0.9, 0.2, 0.2, 0.15)
            border.color: Qt.rgba(0.9, 0.2, 0.2, 0.4)
            border.width: 1
            clip: true

            Behavior on implicitHeight { NumberAnimation { duration: 120 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                Text {
                    text: "\ue000" // warning icon
                    font.family: materialIcons.name
                    font.pixelSize: 14
                    color: "#e05353"
                }

                Text {
                    text: passwordDialog.errorMessage
                    font.family: Colors.fontFamily
                    font.pixelSize: 11
                    color: "#e05353"
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }
        }

        // Action Buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Cancel Button
            Rectangle {
                Layout.fillWidth: true
                height: 36
                radius: 6
                color: cancelMouse.containsMouse ? Colors.bgHover : "transparent"
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
                    id: cancelMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        passwordDialog.rejected()
                        passwordDialog.close()
                    }
                }
            }

            // Unlock Button
            Rectangle {
                Layout.fillWidth: true
                height: 36
                radius: 6
                color: confirmMouse.containsPress ? Qt.darker(Colors.goldPrimary, 1.15)
                     : confirmMouse.containsMouse ? Colors.goldHover
                     : Colors.goldPrimary

                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "\ue897" // lock / unlock
                        font.family: materialIcons.name
                        font.pixelSize: 14
                        color: Colors.textOnGold
                    }

                    Text {
                        text: "Unlock"
                        font.family: Colors.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: Colors.textOnGold
                    }
                }

                MouseArea {
                    id: confirmMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: passwordDialog.submitPassword()
                }
            }
        }
    }

    onOpened: {
        passInput.text = ""
        errorMessage = ""
        showPassBtn.showPassword = false
        passInput.forceActiveFocus()
    }
}