import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import UI

Rectangle {
    id: root

    property var speedData: []
    property int maxDataPoints: 20

    property real currentSpeed: speedData && speedData.length > 0 ? speedData[speedData.length - 1] : 0.0
    property real peakSpeed10s: 0.0
    property real yAxisMax: 10.0
    property int elapsedSeconds: 0

    // Coordinates of current speed tip on canvas
    property real tipX: 0
    property real tipY: 0

    // Colors: Vibrant Sea Green / Emerald Theme
    readonly property color themeColor: Colors.graphThemeColor
    readonly property color themeColorLight: Colors.graphThemeColorLight
    readonly property color themeColorAccent: Colors.graphThemeColorAccent

    // Animation progress for smooth transitions
    property real animProgress: 1.0
    onAnimProgressChanged: speedCanvas.requestPaint()

    implicitWidth: 380
    implicitHeight: 74
    radius: 6
    color: Colors.bgInput
    border.color: Colors.borderSubtle
    border.width: 1
    clip: true

    Behavior on color { ColorAnimation { duration: 200 } }
    Behavior on border.color { ColorAnimation { duration: 200 } }
    Behavior on yAxisMax { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

    FontLoader {
        id: materialIcons
        source: "Fonts/MaterialIconsRound-Regular.otf"
    }

    NumberAnimation {
        id: transitionAnim
        target: root
        property: "animProgress"
        from: 0.0
        to: 1.0
        duration: 300
        easing.type: Easing.OutCubic
    }
    
    function formatTimeSec(totalSecs) {
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
    
    readonly property int activeWindowSeconds: Math.min(root.elapsedSeconds, root.maxDataPoints)
    readonly property string startTimeText: root.formatTimeSec(Math.max(0, root.elapsedSeconds - root.activeWindowSeconds))
    readonly property string midTimeText: root.formatTimeSec(Math.max(0, root.elapsedSeconds - Math.floor(root.activeWindowSeconds / 2)))
    readonly property string currentTimeText: root.formatTimeSec(root.elapsedSeconds)

    // Reset graph datasets and indicators
    function reset() {
        speedData = [];
        currentSpeed = 0.0;
        peakSpeed10s = 0.0;
        yAxisMax = 10.0;
        tipX = 0;
        tipY = 0;
        animProgress = 1.0;
        speedCanvas.requestPaint();
    }

    // Append new live data point and adjust dynamic Y-axis scaling
    function addData(speedVal) {
        var sVal = Math.max(0.0, Number(speedVal) || 0.0);
        var sArr = speedData ? speedData.slice() : [];

        if (sArr.length === 0) {
            sArr.push(0.0);
        }

        sArr.push(sVal);
        if (sArr.length > maxDataPoints) {
            sArr.shift();
        }

        speedData = sArr;
        currentSpeed = sVal;

        // 1. Calculate max speed in the last 10 seconds of data
        var n = sArr.length;
        var startIdx = Math.max(0, n - 10);
        var max10 = 0.0;
        for (var i = startIdx; i < n; i++) {
            if (sArr[i] > max10) {
                max10 = sArr[i];
            }
        }
        peakSpeed10s = max10;

        var peakActive = Math.max(max10, sVal);
        var targetMax = Math.max(6.0, Math.ceil(peakActive * 2.0));

        if (targetMax > yAxisMax) {
            yAxisMax = targetMax;
        } else {
            yAxisMax = targetMax;
        }

        animProgress = 0.0;
        transitionAnim.restart();
        speedCanvas.requestPaint();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 5
        spacing: 2

        // ==========================================
        // --- Top Header: Speed & Dynamic Scale ---
        // ==========================================
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            // Live Speed Indicator
            RowLayout {
                spacing: 5

                Rectangle {
                    width: 7
                    height: 7
                    radius: 3.5
                    color: root.themeColorAccent
                    border.color: root.themeColorLight
                    border.width: 1
                }

                Text {
                    text: "Speed: " + root.currentSpeed.toFixed(1) + " MB/s"
                    font.family: Colors.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    color: root.themeColorLight
                }
            }
        }
        
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Canvas {
                id: speedCanvas
                anchors.fill: parent
                antialiasing: true

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                Connections {
                    target: Colors
                    function onIsDarkModeChanged() { speedCanvas.requestPaint(); }
                }

                onPaint: {
                    var ctx = getContext("2d");
                    if (typeof ctx.reset === "function") {
                        ctx.reset();
                    } else if (typeof ctx.resetTransform === "function") {
                        ctx.resetTransform();
                    }
                    var w = width;
                    var h = height;
                    if (w <= 0 || h <= 0) return;
                    ctx.clearRect(0, 0, w, h);

                    var maxVal = Math.max(6.0, root.yAxisMax);

                    // 1. Draw subtle horizontal grid lines (0%, 50% midpoint reference, 100%)
                    ctx.strokeStyle = Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.05);
                    ctx.lineWidth = 1;

                    // 50% midpoint reference line (where typical peak/bars hover)
                    ctx.beginPath();
                    var midY = Math.floor(h * 0.5);
                    ctx.moveTo(0, midY);
                    ctx.lineTo(w, midY);
                    ctx.stroke();

                    // 2. Render modern vertical bars & spline wave
                    var data = root.speedData;
                    if (!data || data.length === 0) return;

                    var n = data.length;
                    var slotCount = Math.max(root.maxDataPoints, n);
                    var slotWidth = w / slotCount;
                    var barWidth = Math.max(4, Math.floor(slotWidth * 0.70));
                    var barGap = slotWidth - barWidth;

                    // Collect bar center points for spline overlay
                    var pts = [];

                    for (var i = 0; i < n; i++) {
                        var val = data[i];
                        if (i === n - 1 && root.animProgress < 1.0) {
                            var prevVal = (n > 1) ? data[n - 2] : 0.0;
                            val = prevVal + (val - prevVal) * root.animProgress;
                        }

                        var barHeight = Math.max(2, (val / maxVal) * (h - 4));
                        var bx = Math.floor(i * slotWidth + barGap / 2);
                        var by = Math.floor(h - barHeight);

                        // Draw rounded vertical bar
                        ctx.beginPath();
                        var r = Math.min(3, Math.floor(barWidth / 2));
                        ctx.moveTo(bx + r, by);
                        ctx.lineTo(bx + barWidth - r, by);
                        ctx.arcTo(bx + barWidth, by, bx + barWidth, by + r, r);
                        ctx.lineTo(bx + barWidth, h);
                        ctx.lineTo(bx, h);
                        ctx.lineTo(bx, by + r);
                        ctx.arcTo(bx, by, bx + r, by, r);
                        ctx.closePath();

                        var barGrad = ctx.createLinearGradient(bx, by, bx, h);
                        barGrad.addColorStop(0, root.themeColorLight);
                        barGrad.addColorStop(1, Colors.isDarkMode ? Qt.rgba(0.18, 0.55, 0.34, 0.18) : Qt.rgba(0.14, 0.50, 0.28, 0.15));
                        ctx.fillStyle = barGrad;
                        ctx.fill();

                        pts.push({ x: bx + barWidth / 2, y: by });
                    }

                    // 3. Draw smooth accent spline connecting bar tops
                    if (pts.length > 1) {
                        ctx.beginPath();
                        ctx.moveTo(pts[0].x, pts[0].y);
                        for (var p = 1; p < pts.length; p++) {
                            var prev = pts[p - 1];
                            var cur = pts[p];
                            var cX = (prev.x + cur.x) / 2;
                            ctx.bezierCurveTo(cX, prev.y, cX, cur.y, cur.x, cur.y);
                        }
                        ctx.strokeStyle = root.themeColorAccent;
                        ctx.lineWidth = 1.5;
                        ctx.stroke();
                    }

                    // 4. Glowing tip point on the active head
                    var lastPt = pts[pts.length - 1];
                    root.tipX = lastPt.x;
                    root.tipY = lastPt.y;

                    // Outer halo glow
                    ctx.beginPath();
                    ctx.arc(lastPt.x, lastPt.y, 4.5, 0, 2 * Math.PI);
                    ctx.fillStyle = Colors.isDarkMode ? Qt.rgba(0.29, 0.87, 0.50, 0.35) : Qt.rgba(0.18, 0.55, 0.34, 0.25);
                    ctx.fill();

                    // Inner bright pip
                    ctx.beginPath();
                    ctx.arc(lastPt.x, lastPt.y, 2.5, 0, 2 * Math.PI);
                    ctx.fillStyle = root.themeColorAccent;
                    ctx.fill();
                }
            }
            
            Item {
                id: floatingTipBadge
                visible: root.speedData.length > 0 && root.currentSpeed > 0.01

                implicitWidth: tipBadgeRow.implicitWidth + 12
                implicitHeight: 18
                width: implicitWidth
                height: implicitHeight

                // Position badge cleanly offset from the active speed tip
                x: Math.max(2, Math.min(speedCanvas.width - width - 2,
                       (root.tipX + width + 8 <= speedCanvas.width) ? (root.tipX + 6) : (root.tipX - width - 6)))
                y: Math.max(2, Math.min(speedCanvas.height - height - 2, root.tipY - height / 2))

                Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                // Frosted / fuzzed pill badge background with subtle glow
                Rectangle {
                    anchors.fill: parent
                    radius: 9
                    color: Colors.isDarkMode ? Qt.rgba(0.08, 0.10, 0.14, 0.90) : Qt.rgba(1.0, 1.0, 1.0, 0.94)
                    border.color: root.themeColorLight
                    border.width: 1

                    // Subtle inner border glow
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: 8
                        color: "transparent"
                        border.color: Qt.rgba(0.29, 0.87, 0.50, 0.30)
                        border.width: 1
                    }
                }

                RowLayout {
                    id: tipBadgeRow
                    anchors.centerIn: parent
                    spacing: 4

                    // Glowing pulse pip
                    Rectangle {
                        width: 5
                        height: 5
                        radius: 2.5
                        color: root.themeColorAccent
                    }

                    Text {
                        text: root.currentSpeed.toFixed(1) + " MB/s"
                        font.family: Colors.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        color: Colors.textMain
                    }
                }
            }
        }

        // ==========================================
        // --- Bottom Timeline Axis ---
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
                    color: root.themeColor
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
