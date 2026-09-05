import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import UI

Rectangle {
    id: root

    // ==========================================
    // --- Public Properties & Datasets ---
    // ==========================================
    property var readData: [22.0, 35.5, 28.0, 48.0, 42.5, 58.0, 52.0, 68.5, 59.0, 64.0]
    property var writeData: [14.0, 26.0, 21.5, 38.0, 34.0, 49.5, 44.0, 58.0, 51.0, 56.5]
    property int maxDataPoints: 20

    property real currentReadSpeed: readData.length > 0 ? readData[readData.length - 1] : 0.0
    property real currentWriteSpeed: writeData.length > 0 ? writeData[writeData.length - 1] : 0.0
    property real peakSpeed: 75.0

    // Time Axis Labels (e.g., 00:00, 00:45, 01:32)
    property string startTimeText: "00:00"
    property string midTimeText: "00:45"
    property string currentTimeText: "01:32"

    // Visibility toggles (Read speed default invisible as requested)
    property bool showRead: false
    property bool showWrite: true

    // Colors: Sea Green for Write, Indian Red for Read
    readonly property color writeColor: Colors.isDarkMode ? "#2e8b57" : "#228b50" // Sea Green
    readonly property color readColor: Colors.isDarkMode ? "#cd5c5c" : "#b23a3a"  // Indian Red
    readonly property color writeColorLight: Colors.isDarkMode ? "#3cb371" : "#2e8b57"
    readonly property color readColorLight: Colors.isDarkMode ? "#e06c6c" : "#cd5c5c"

    // Animation progress for new point transitions
    property real animProgress: 1.0
    onAnimProgressChanged: speedCanvas.requestPaint()

    implicitWidth: 380
    implicitHeight: 72
    radius: 6
    color: Colors.bgInput
    border.color: Colors.borderSubtle
    border.width: 1
    clip: true

    Behavior on color { ColorAnimation { duration: 200 } }
    Behavior on border.color { ColorAnimation { duration: 200 } }

    FontLoader {
        id: materialIcons
        source: "Fonts/MaterialIconsRound-Regular.otf"
    }

    // Number animation for smooth curve transitions
    NumberAnimation {
        id: transitionAnim
        target: root
        property: "animProgress"
        from: 0.0
        to: 1.0
        duration: 350
        easing.type: Easing.OutCubic
    }

    // Append new live data points and trigger update animation
    function addData(readVal, writeVal) {
        var rArr = readData ? readData.slice() : [];
        var wArr = writeData ? writeData.slice() : [];

        rArr.push(readVal);
        wArr.push(writeVal);

        if (rArr.length > maxDataPoints) rArr.shift();
        if (wArr.length > maxDataPoints) wArr.shift();

        readData = rArr;
        writeData = wArr;
        currentReadSpeed = readVal;
        currentWriteSpeed = writeVal;

        if (readVal > peakSpeed) peakSpeed = Math.ceil(readVal * 1.15);
        if (writeVal > peakSpeed) peakSpeed = Math.ceil(writeVal * 1.15);

        animProgress = 0.0;
        transitionAnim.restart();
        speedCanvas.requestPaint();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 5
        spacing: 2

        // ==========================================
        // --- Top Legend Bar & Controls ---
        // ==========================================
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Write Speed Legend (Sea Green - Always visible)
            RowLayout {
                spacing: 4
                Rectangle {
                    width: 7
                    height: 7
                    radius: 3.5
                    color: root.writeColor
                    border.color: root.writeColorLight
                    border.width: 1
                }
                Text {
                    text: "Write: " + root.currentWriteSpeed.toFixed(1) + " MB/s"
                    font.family: Colors.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    color: root.writeColor
                }
            }

            // Read Speed Legend (Indian Red - Clickable Toggle Button)
            Rectangle {
                id: readLegendBtn
                implicitHeight: 18
                implicitWidth: readLegendRow.implicitWidth + 8
                radius: 4
                color: readMouse.containsMouse ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.04)) : "transparent"
                border.color: root.showRead ? (Colors.isDarkMode ? Qt.rgba(0.8, 0.36, 0.36, 0.4) : Qt.rgba(0.7, 0.23, 0.23, 0.3)) : "transparent"
                border.width: 1

                RowLayout {
                    id: readLegendRow
                    anchors.centerIn: parent
                    spacing: 4
                    opacity: root.showRead ? 1.0 : 0.45

                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    Rectangle {
                        width: 7
                        height: 7
                        radius: 3.5
                        color: root.showRead ? root.readColor : "transparent"
                        border.color: root.readColor
                        border.width: 1
                    }

                    Text {
                        text: "Read: " + root.currentReadSpeed.toFixed(1) + " MB/s" + (root.showRead ? "" : " (off)")
                        font.family: Colors.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.Medium
                        color: root.showRead ? root.readColor : Colors.textMuted
                    }

                    Text {
                        text: root.showRead ? "\ue8f4" : "\ue8f5" // visibility / visibility_off
                        font.family: materialIcons.name
                        font.pixelSize: 10
                        color: root.showRead ? root.readColor : Colors.textMuted
                    }
                }

                MouseArea {
                    id: readMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.showRead = !root.showRead;
                        speedCanvas.requestPaint();
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Peak Rate Indicator
            Text {
                text: "Peak " + Math.round(root.peakSpeed) + " MB/s"
                font.family: Colors.fontFamily
                font.pixelSize: 8
                color: Colors.textSubtle
            }
        }

        // ==========================================
        // --- Dual Speed Curves Canvas ---
        // ==========================================
        Canvas {
            id: speedCanvas
            Layout.fillWidth: true
            Layout.fillHeight: true
            antialiasing: true

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            Connections {
                target: Colors
                function onIsDarkModeChanged() { speedCanvas.requestPaint(); }
            }

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var w = width;
                var h = height;
                if (w <= 0 || h <= 0) return;

                var maxVal = Math.max(20.0, root.peakSpeed);

                // Draw background grid lines (horizontal & vertical ticks)
                ctx.strokeStyle = Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.05);
                ctx.lineWidth = 1;

                // Horizontal mid-grid
                ctx.beginPath();
                ctx.moveTo(0, Math.floor(h * 0.5));
                ctx.lineTo(w, Math.floor(h * 0.5));
                ctx.stroke();

                // Vertical midpoint reference
                ctx.beginPath();
                ctx.moveTo(Math.floor(w * 0.5), 0);
                ctx.lineTo(Math.floor(w * 0.5), h);
                ctx.stroke();

                // Helper to draw a smoothed line and filled area
                function drawWave(data, strokeColor, fillColorTop, strokeWidth) {
                    if (!data || data.length < 2) return;
                    var n = data.length;
                    var step = w / (n - 1);

                    // Area fill path
                    ctx.beginPath();
                    ctx.moveTo(0, h);

                    var firstY = h - Math.min(h - 4, (data[0] / maxVal) * (h - 4));
                    ctx.lineTo(0, firstY);

                    for (var i = 1; i < n; i++) {
                        var prevX = (i - 1) * step;
                        var prevY = h - Math.min(h - 4, (data[i - 1] / maxVal) * (h - 4));
                        var curX = i * step;
                        var curY = h - Math.min(h - 4, (data[i] / maxVal) * (h - 4));

                        // Animate last segment smoothly
                        if (i === n - 1 && root.animProgress < 1.0) {
                            curY = prevY + (curY - prevY) * root.animProgress;
                        }

                        var cX = (prevX + curX) / 2;
                        ctx.bezierCurveTo(cX, prevY, cX, curY, curX, curY);
                    }

                    ctx.lineTo(w, h);
                    ctx.closePath();

                    var grad = ctx.createLinearGradient(0, 0, 0, h);
                    grad.addColorStop(0, fillColorTop);
                    grad.addColorStop(1, "transparent");
                    ctx.fillStyle = grad;
                    ctx.fill();

                    // Stroke line
                    ctx.beginPath();
                    ctx.moveTo(0, firstY);

                    for (var j = 1; j < n; j++) {
                        var pX = (j - 1) * step;
                        var pY = h - Math.min(h - 4, (data[j - 1] / maxVal) * (h - 4));
                        var cX2 = j * step;
                        var cY2 = h - Math.min(h - 4, (data[j] / maxVal) * (h - 4));

                        if (j === n - 1 && root.animProgress < 1.0) {
                            cY2 = pY + (cY2 - pY) * root.animProgress;
                        }

                        var ctrlX = (pX + cX2) / 2;
                        ctx.bezierCurveTo(ctrlX, pY, ctrlX, cY2, cX2, cY2);
                    }

                    ctx.strokeStyle = strokeColor;
                    ctx.lineWidth = strokeWidth;
                    ctx.stroke();

                    // Glowing endpoint on current data point
                    var lastIndex = n - 1;
                    var lastPtX = w;
                    var lastPtY = h - Math.min(h - 4, (data[lastIndex] / maxVal) * (h - 4));
                    if (root.animProgress < 1.0 && n > 1) {
                        var prevPtY = h - Math.min(h - 4, (data[n - 2] / maxVal) * (h - 4));
                        lastPtY = prevPtY + (lastPtY - prevPtY) * root.animProgress;
                    }

                    ctx.beginPath();
                    ctx.arc(lastPtX - 2, lastPtY, 2.5, 0, 2 * Math.PI);
                    ctx.fillStyle = strokeColor;
                    ctx.fill();
                }

                // 1. Render Read Speed Wave if enabled (Indian Red)
                if (root.showRead) {
                    var readTopAlpha = Colors.isDarkMode ? Qt.rgba(0.80, 0.36, 0.36, 0.30) : Qt.rgba(0.70, 0.23, 0.23, 0.20);
                    drawWave(root.readData, root.readColor, readTopAlpha, 1.8);
                }

                // 2. Render Write Speed Wave if enabled (Sea Green)
                if (root.showWrite) {
                    var writeTopAlpha = Colors.isDarkMode ? Qt.rgba(0.18, 0.55, 0.34, 0.32) : Qt.rgba(0.14, 0.50, 0.28, 0.22);
                    drawWave(root.writeData, root.writeColor, writeTopAlpha, 1.8);
                }
            }
        }

        // ==========================================
        // --- Bottom Timeline Axis (e.g. 00:00, 00:45, 01:32) ---
        // ==========================================
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                text: root.startTimeText
                font.family: Colors.fontFamily
                font.pixelSize: 8
                color: Colors.textSubtle
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            Text {
                text: root.midTimeText
                font.family: Colors.fontFamily
                font.pixelSize: 8
                color: Colors.textSubtle
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            RowLayout {
                spacing: 3
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    width: 4
                    height: 4
                    radius: 2
                    color: root.writeColor
                }

                Text {
                    text: root.currentTimeText
                    font.family: Colors.fontFamily
                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                    color: Colors.textMuted
                }
            }
        }
    }
}
