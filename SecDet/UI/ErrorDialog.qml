import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import UI

Dialog {
    id: errorDialog
    anchors.centerIn: parent
    width: parent ? Math.min(parent.width - 40, 460) : 460
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding: 18

    property string errorTitle: "Archive Operation Error"
    property string errorMessage: ""
    property bool copyFeedback: false
    property bool showRecoveryButton: false
    property string recoveryFilePath: ""

    signal recoveryRequested(string filePath)

    function showError(title, message, canRecover, filePath) {
        errorTitle = (title && title.length > 0) ? title : "Archive Operation Error";
        errorMessage = (message && message.length > 0) ? message : "An unknown error occurred.";
        copyFeedback = false;
        showRecoveryButton = (canRecover === true);
        recoveryFilePath = (canRecover && filePath) ? filePath : "";
        open();
    }

    function showErrorWithRecovery(title, message, filePath) {
        showError(title, message, true, filePath);
    }

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
        border.color: Colors.isDarkMode ? Qt.rgba(0.9, 0.32, 0.32, 0.5) : Qt.rgba(0.85, 0.25, 0.25, 0.6)
        border.width: 1.5

        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on border.color { ColorAnimation { duration: 200 } }

        // Subtle top warning accent glow bar
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            height: 2.5
            radius: 1.25
            color: "#e05353"
        }
    }

    // Hidden clipboard helper
    TextInput {
        id: clipboardHelper
        visible: false
    }

    Timer {
        id: copyFeedbackTimer
        interval: 1600
        repeat: false
        onTriggered: errorDialog.copyFeedback = false
    }

    contentItem: ColumnLayout {
        spacing: 14

        // ==========================================
        // --- Header: Icon Badge, Title & Close ---
        // ==========================================
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                width: 40
                height: 40
                radius: 20
                color: Colors.isDarkMode ? Qt.rgba(0.9, 0.32, 0.32, 0.16) : Qt.rgba(0.88, 0.25, 0.25, 0.12)
                border.color: Colors.isDarkMode ? Qt.rgba(0.9, 0.32, 0.32, 0.4) : Qt.rgba(0.88, 0.25, 0.25, 0.3)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "\ue000" // error / warning round icon
                    font.family: materialIcons.name
                    font.pixelSize: 22
                    color: "#e05353"
                }
            }

            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true

                Text {
                    text: errorDialog.errorTitle
                    font.family: Colors.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    color: Colors.textMain
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: "libsecdet reported an operation failure"
                    font.family: Colors.fontFamily
                    font.pixelSize: 11
                    color: Colors.textMuted
                }
            }

            // Close button (X)
            Rectangle {
                width: 26
                height: 26
                radius: 13
                color: closeMouse.containsMouse ? Qt.rgba(0.9, 0.3, 0.3, 0.2) : "transparent"
                border.color: closeMouse.containsMouse ? "#d9534f" : Colors.borderSubtle
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
                    onClicked: errorDialog.close()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Colors.divider
        }

        // ==========================================
        // --- Detailed Error Message Box ---
        // ==========================================
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: detailCol.implicitHeight + 18
            radius: 8
            color: Colors.bgInput
            border.color: Colors.isDarkMode ? Qt.rgba(0.9, 0.32, 0.32, 0.25) : Colors.borderSubtle
            border.width: 1

            ColumnLayout {
                id: detailCol
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "ERROR DETAILS"
                        font.family: Colors.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        color: "#e05353"
                        Layout.fillWidth: true
                    }

                    // Copy button
                    Item {
                        implicitWidth: copyRow.implicitWidth
                        implicitHeight: copyRow.implicitHeight
                        opacity: copyMouse.containsMouse ? 1.0 : 0.75

                        RowLayout {
                            id: copyRow
                            anchors.fill: parent
                            spacing: 4

                            Text {
                                text: errorDialog.copyFeedback ? "\ue876" : "\ue14d" // checkmark or content_copy
                                font.family: materialIcons.name
                                font.pixelSize: 12
                                color: errorDialog.copyFeedback ? "#4ade80" : Colors.textMuted
                            }

                            Text {
                                text: errorDialog.copyFeedback ? "Copied" : "Copy"
                                font.family: Colors.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                color: errorDialog.copyFeedback ? "#4ade80" : Colors.textMuted
                            }
                        }

                        MouseArea {
                            id: copyMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                clipboardHelper.text = errorDialog.errorMessage;
                                clipboardHelper.selectAll();
                                clipboardHelper.copy();
                                errorDialog.copyFeedback = true;
                                copyFeedbackTimer.restart();
                            }
                        }
                    }
                }

                Text {
                    id: errorMsgText
                    text: errorDialog.errorMessage
                    color: Colors.textMain
                    font.family: "Cascadia Code, Consolas, Courier New, monospace"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    Layout.fillWidth: true
                    lineHeight: 1.2
                }
            }
        }

        // ==========================================
        // --- Recovery Recommendation Callout ---
        // ==========================================
        Rectangle {
            visible: errorDialog.showRecoveryButton
            Layout.fillWidth: true
            implicitHeight: recCalloutRow.implicitHeight + 16
            radius: 8
            color: Colors.isDarkMode ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.12) : Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.08)
            border.color: Colors.isDarkMode ? Qt.rgba(52 / 255, 211 / 255, 153 / 255, 0.4) : Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.35)
            border.width: 1

            RowLayout {
                id: recCalloutRow
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: Colors.isDarkMode ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.25) : Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.18)
                    Layout.alignment: Qt.AlignTop

                    Text {
                        anchors.centerIn: parent
                        text: "\ue869" // build / repair tool icon
                        font.family: materialIcons.name
                        font.pixelSize: 15
                        color: Colors.isDarkMode ? "#34d399" : "#059669"
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Archive Recovery Available"
                        font.family: Colors.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: Colors.isDarkMode ? "#34d399" : "#059669"
                    }

                    Text {
                        text: "The Table of Contents is damaged or invalid. You can inspect raw payload streams and salvage files using Archive Recovery Tools."
                        font.family: Colors.fontFamily
                        font.pixelSize: 11
                        color: Colors.textMain
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }
        }

        // ==========================================
        // --- Footer: Action Buttons ---
        // ==========================================
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Item { Layout.fillWidth: true }

            // Recovery Action Button (Only visible when Error is invalid Toc during archive load)
            Rectangle {
                id: recoveryBtnRect
                visible: errorDialog.showRecoveryButton
                implicitWidth: recoveryRow.implicitWidth + 24
                implicitHeight: 34
                radius: 6
                color: recMouse.containsPress
                    ? (Colors.isDarkMode ? "#047857" : "#065f46")
                    : (recMouse.containsMouse ? (Colors.isDarkMode ? "#10b981" : "#059669") : (Colors.isDarkMode ? "#059669" : "#047857"))
                border.color: Colors.isDarkMode ? Qt.rgba(52 / 255, 211 / 255, 153 / 255, 0.6) : Qt.rgba(5 / 255, 150 / 255, 105 / 255, 0.5)
                border.width: 1

                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                    id: recoveryRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "\ue869" // build / wrench tool icon
                        font.family: materialIcons.name
                        font.pixelSize: 14
                        color: "#ffffff"
                    }

                    Text {
                        text: "Open Recovery"
                        font.family: Colors.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: "#ffffff"
                    }
                }

                MouseArea {
                    id: recMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        let path = errorDialog.recoveryFilePath;
                        errorDialog.close();
                        errorDialog.recoveryRequested(path);
                    }
                }
            }

            // Dismiss Button
            Rectangle {
                implicitWidth: 100
                implicitHeight: 34
                radius: 6
                color: okMouse.containsPress ? Qt.darker("#e05353", 1.2)
                     : (okMouse.containsMouse ? "#eb6b6b" : "#e05353")

                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "\ue5ca" // check
                        font.family: materialIcons.name
                        font.pixelSize: 14
                        color: "#ffffff"
                    }

                    Text {
                        text: "Dismiss"
                        font.family: Colors.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: "#ffffff"
                    }
                }

                MouseArea {
                    id: okMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: errorDialog.close()
                }
            }
        }
    }
}
