import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import UI

Window {
    id: progressWindow
    title: "Creating archive ..."
    width: 420
    height: 420
    minimumWidth: 420
    maximumWidth: 420
    minimumHeight: 420
    maximumHeight: 420
    flags: Qt.Window | Qt.WindowTitleHint | Qt.WindowCloseButtonHint | Qt.WindowMinimizeButtonHint | Qt.CustomizeWindowHint
    color: Colors.bgMain
    visible: false

    // ==========================================
    // --- Progress & Operation State Properties ---
    // ==========================================
    property string currentFilePath: "C:/Users/Freddy/Documents/SecureVault/Archives/Project_Data_Stream.bin"
    property string currentFileName: "Project_Data_Stream.bin"
    property real fileProgress: 0.68          // 0.0 to 1.0
    property real overallProgress: 0.42       // 0.0 to 1.0
    property int processedFiles: 14
    property int totalFiles: 32
    property real processedSizeMB: 142.5
    property real totalSizeMB: 340.0
    property real readSpeedMBs: 48.5
    property real writeSpeedMBs: 32.4

    // Timing Properties (in seconds)
    property int elapsedSeconds: 42
    property int remainingSeconds: 58
    property bool isPaused: false

    // Signals
    signal pauseToggled(bool paused)
    signal canceled()
    signal completed()

    FontLoader {
        id: materialIcons
        source: "Fonts/MaterialIconsRound-Regular.otf"
    }

    // Time formatting helper: converts seconds to MM:SS or HH:MM:SS
    function formatTime(totalSecs) {
        var secs = Math.max(0, Math.floor(totalSecs));
        var h = Math.floor(secs / 3600);
        var m = Math.floor((secs % 3600) / 60);
        var s = secs % 60;
        var pad = function(n) { return (n < 10 ? "0" : "") + n; };
        if (h > 0) {
            return pad(h) + ":" + pad(m) + ":" + pad(s);
        }
        return pad(m) + ":" + pad(s);
    }

    // ==========================================
    // --- Live Timer (Progress & Speed Generator) ---
    // ==========================================
    Timer {
        id: progressTimer
        interval: 800
        running: progressWindow.visible && !progressWindow.isPaused
        repeat: true
        onTriggered: {
            progressWindow.elapsedSeconds += 1;
            if (progressWindow.remainingSeconds > 0) {
                progressWindow.remainingSeconds -= 1;
            }

            // Smooth demo progress simulation
            if (progressWindow.fileProgress < 0.98) {
                progressWindow.fileProgress = Math.min(1.0, progressWindow.fileProgress + 0.025);
            } else {
                progressWindow.fileProgress = 0.05;
                if (progressWindow.processedFiles < progressWindow.totalFiles) {
                    progressWindow.processedFiles += 1;
                    progressWindow.processedSizeMB = Math.min(progressWindow.totalSizeMB, progressWindow.processedSizeMB + 10.5);
                }
            }

            if (progressWindow.overallProgress < 0.99) {
                progressWindow.overallProgress = Math.min(1.0, progressWindow.overallProgress + 0.008);
            }

            // Live speed data generation and push to SpeedGraph
            var deltaR = (Math.random() * 16.0 - 7.5);
            var deltaW = (Math.random() * 12.0 - 5.5);
            var nextRead = Math.max(18.0, Math.min(85.0, progressWindow.readSpeedMBs + deltaR));
            var nextWrite = Math.max(12.0, Math.min(70.0, progressWindow.writeSpeedMBs + deltaW));

            progressWindow.readSpeedMBs = nextRead;
            progressWindow.writeSpeedMBs = nextWrite;
            speedGraph.addData(nextRead, nextWrite);
        }
    }

    // ==========================================
    // --- Reusable Sleek Components ---
    // ==========================================

    // SeaGreen theme tokens for Progress Bars
    readonly property color seaGreenPrimary: Colors.isDarkMode ? "#2e8b57" : "#228b50"
    readonly property color seaGreenLight: Colors.isDarkMode ? "#3cb371" : "#2e8b57"

    // Taller Sleek Progress Bar (Matching app style with SeaGreen gradient)
    component TallProgressBar : Item {
        id: pBar
        property real value: 0.0
        property int barHeight: 8

        Layout.fillWidth: true
        implicitHeight: barHeight

        Rectangle {
            anchors.fill: parent
            radius: pBar.barHeight / 2
            color: Colors.bgElevated
            border.color: Colors.borderSubtle
            border.width: 1

            Rectangle {
                width: parent.width * Math.max(0, Math.min(pBar.value, 1.0))
                height: parent.height
                radius: pBar.barHeight / 2

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: progressWindow.seaGreenPrimary }
                    GradientStop { position: 1.0; color: progressWindow.seaGreenLight }
                }

                Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            }
        }
    }

    // Sleek Horizontal Divider
    component SleekDivider : Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Colors.divider
    }

    // Section Header with Top-Left Icon Badge
    component SectionHeader : RowLayout {
        id: secHeader
        property string iconGlyph: ""
        property string titleText: ""
        property string extraText: ""

        Layout.fillWidth: true
        spacing: 8

        Rectangle {
            width: 24
            height: 24
            radius: 6
            color: Colors.goldLight
            border.color: Colors.goldBorder
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: secHeader.iconGlyph
                font.family: materialIcons.name
                font.pixelSize: 14
                color: Colors.goldPrimary
            }
        }

        Text {
            text: secHeader.titleText
            font.family: Colors.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: Colors.textMain
            Layout.alignment: Qt.AlignVCenter
        }

        Item { Layout.fillWidth: true }

        Text {
            visible: secHeader.extraText.length > 0
            text: secHeader.extraText
            font.family: Colors.fontFamily
            font.pixelSize: 11
            color: Colors.textMuted
            Layout.alignment: Qt.AlignVCenter
            elide: Text.ElideRight
        }
    }

    // ==========================================
    // --- Window Content Layout ---
    // ==========================================
    Rectangle {
        id: bgContainer
        anchors.fill: parent
        color: Colors.bgMain

        Behavior on color { ColorAnimation { duration: 200 } }
    }

    Rectangle {
        id: mainCard
        anchors.fill: parent
        anchors.margins: 12
        radius: 10
        color: Colors.bgSurface
        border.color: Colors.borderSubtle
        border.width: 1

        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on border.color { ColorAnimation { duration: 200 } }

        ColumnLayout {
            id: contentCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ==========================================
            // --- Section 1: File Path & File Progress ---
            // ==========================================
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5

                SectionHeader {
                    iconGlyph: "\ue2c7" // folder / file archive
                    titleText: "File Path"
                    extraText: progressWindow.isPaused ? "Paused" : "Active"
                }

                // <Icon><File Name> + <on the far right the progress percent>
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "\ue873" // file icon
                        font.family: materialIcons.name
                        font.pixelSize: 15
                        color: Colors.goldPrimary
                    }

                    Text {
                        text: progressWindow.currentFileName
                        font.family: Colors.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.SemiBold
                        color: Colors.textMain
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Text {
                        text: Math.round(progressWindow.fileProgress * 100) + "%"
                        font.family: Colors.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: progressWindow.seaGreenLight
                    }
                }

                // <Progress Bar>
                TallProgressBar {
                    value: progressWindow.fileProgress
                    barHeight: 8
                }

                // Sleek File Path Display
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24
                    radius: 5
                    color: Colors.bgInput
                    border.color: Colors.borderSubtle
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 200 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 6

                        Text {
                            text: "\ue873" // description
                            font.family: materialIcons.name
                            font.pixelSize: 12
                            color: Colors.goldPrimary
                        }

                        Text {
                            text: progressWindow.currentFilePath
                            font.family: Colors.fontFamily
                            font.pixelSize: 10
                            color: Colors.textMuted
                            Layout.fillWidth: true
                            elide: Text.ElideMiddle
                        }
                    }
                }
            }

            // Sleek Divider 1
            SleekDivider {}

            // ==========================================
            // --- Section 2: Overall Progress & SpeedGraph Component ---
            // ==========================================
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                // Overall progress header + percentage on the far right
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    SectionHeader {
                        iconGlyph: "\ue6dd" // analytics / progress graph
                        titleText: "Overall Progress"
                        extraText: progressWindow.processedFiles + "/" + progressWindow.totalFiles + " files (" + progressWindow.processedSizeMB.toFixed(1) + " MB)"
                        Layout.fillWidth: true
                    }

                    Text {
                        text: Math.round(progressWindow.overallProgress * 100) + "%"
                        font.family: Colors.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: progressWindow.seaGreenLight
                    }
                }

                TallProgressBar {
                    value: progressWindow.overallProgress
                    barHeight: 8
                }
            }

            // Sleek Divider 2
            SleekDivider {}

            // ==========================================
            // --- Section 3: Elapsed Time & Time Left ---
            // ==========================================
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5

                SectionHeader {
                    iconGlyph: "\ue8b5"
                    titleText: "Timing"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        radius: 6
                        color: Colors.bgCard
                        border.color: Colors.borderSubtle
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 200 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            Rectangle {
                                width: 26
                                height: 26
                                radius: 13
                                color: Colors.goldLight
                                border.color: Colors.goldBorder
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "\ue425" // timer
                                    font.family: materialIcons.name
                                    font.pixelSize: 14
                                    color: Colors.goldPrimary
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: "Elapsed"
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.Medium
                                    color: Colors.textMuted
                                }

                                Text {
                                    text: progressWindow.formatTime(progressWindow.elapsedSeconds)
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    color: Colors.textMain
                                }
                            }
                        }
                    }

                    // Time Left (Count down)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        radius: 6
                        color: Colors.bgCard
                        border.color: Colors.borderSubtle
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 200 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            Rectangle {
                                width: 26
                                height: 26
                                radius: 13
                                color: Colors.goldLight
                                border.color: Colors.goldBorder
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "\ue923" // hourglass_bottom
                                    font.family: materialIcons.name
                                    font.pixelSize: 14
                                    color: Colors.goldPrimary
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: "Time Left"
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.Medium
                                    color: Colors.textMuted
                                }

                                Text {
                                    text: progressWindow.formatTime(progressWindow.remainingSeconds)
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    color: Colors.goldPrimary
                                }
                            }
                        }
                    }
                }
            }

            // Sleek Divider 3
            SleekDivider {}
            SpeedGraph {
                id: speedGraph
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                currentTimeText: progressWindow.formatTime(progressWindow.elapsedSeconds)
                midTimeText: progressWindow.formatTime(Math.max(0, Math.floor(progressWindow.elapsedSeconds / 2)))
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Item { Layout.fillWidth: true }

                // <Pause Button>
                Rectangle {
                    id: pauseBtn
                    implicitWidth: 105
                    implicitHeight: 32
                    radius: 6
                    color: pauseMouse.containsPress ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.10))
                         : pauseMouse.containsMouse ? Colors.goldLightHover
                         : (progressWindow.isPaused ? Colors.goldLight : Colors.bgElevated)
                    border.color: progressWindow.isPaused ? Colors.goldBorderHi : Colors.goldBorder
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: progressWindow.isPaused ? "\ue037" : "\ue034" // play_arrow / pause
                            font.family: materialIcons.name
                            font.pixelSize: 15
                            color: Colors.goldPrimary
                        }

                        Text {
                            text: progressWindow.isPaused ? "Resume" : "Pause"
                            font.family: Colors.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: Colors.textMain
                        }
                    }

                    MouseArea {
                        id: pauseMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            progressWindow.isPaused = !progressWindow.isPaused
                            progressWindow.pauseToggled(progressWindow.isPaused)
                        }
                        scale: containsPress ? 0.96 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }
                    }
                }

                Rectangle {
                    id: cancelBtn
                    implicitWidth: 105
                    implicitHeight: 32
                    radius: 6
                    color: cancelMouse.containsPress ? Qt.rgba(0.88, 0.33, 0.33, 0.25)
                         : cancelMouse.containsMouse ? Qt.rgba(0.88, 0.33, 0.33, 0.14)
                         : Colors.bgCard
                    border.color: cancelMouse.containsMouse ? "#e05353" : Colors.borderSubtle
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: "\ue5cd" // close
                            font.family: materialIcons.name
                            font.pixelSize: 15
                            color: cancelMouse.containsMouse ? "#e05353" : Colors.textMuted
                        }

                        Text {
                            text: "Cancel"
                            font.family: Colors.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: cancelMouse.containsMouse ? "#e05353" : Colors.textMuted
                        }
                    }

                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            progressWindow.canceled()
                            progressWindow.close()
                        }
                        scale: containsPress ? 0.96 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }
                    }
                }
            }
        }
    }
}
