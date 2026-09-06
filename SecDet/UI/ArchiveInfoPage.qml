import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import UI

Page {
    id: root
    width: 580
    implicitWidth: 580
    Layout.preferredWidth: 580
    Layout.minimumWidth: 520
    Layout.maximumWidth: 680
    Layout.fillWidth: false

    background: Rectangle {
        color: "transparent"
    }

    signal closeRequested()
    signal regionSelected(var region, int index)

    // ==========================================
    // --- Public API for File Map & Shannon Entropy ---
    // ==========================================
    property var fileMapRegions: defaultRegions

    // Built-in presets to easily demo / test dynamic byte scaling across different scales
    readonly property var defaultRegions: [
        { name: "Archive Header",          size: 512,        entropy: 2.15, crc32: "0x8A10F4D2", type: "header" },
        { name: "Metadata Directory",      size: 16384,      entropy: 4.62, crc32: "0x3F88B110", type: "metadata" },
        { name: "LZMA Stream #1",          size: 14889779,   entropy: 7.85, crc32: "0xD415982B", type: "compressed" },
        { name: "AES-256 Vault Payload",   size: 50331648,   entropy: 7.99, crc32: "0x77EE01C9", type: "encrypted" },
        { name: "File Index Table",        size: 4096,       entropy: 5.10, crc32: "0x12C0DE9A", type: "index" },
        { name: "Digital Sig & Hashes",    size: 256,        entropy: 6.90, crc32: "0xFA990311", type: "signature" },
        { name: "Archive Footer (EOCD)",   size: 128,        entropy: 1.40, crc32: "0x0B52AC71", type: "footer" }
    ]

    readonly property var presetGigabyte: [
        { name: "Boot Block / MBR",        size: 512,        entropy: 1.80, crc32: "0x2A4C9100", type: "header" },
        { name: "Allocation Table",        size: 67108864,   entropy: 4.20, crc32: "0x7E3100AF", type: "index" },
        { name: "Encrypted Volume",        size: 4831838208, entropy: 7.99, crc32: "0x99CD5412", type: "encrypted" },
        { name: "ECC Parity Blocks",       size: 293601280,  entropy: 6.15, crc32: "0x489BEE22", type: "parity" },
        { name: "Journal Checkpoint",      size: 131072,     entropy: 3.45, crc32: "0x10A97C55", type: "metadata" },
        { name: "Volume Trailer",          size: 256,        entropy: 1.10, crc32: "0x88FE1299", type: "footer" }
    ]

    readonly property var presetKilobyte: [
        { name: "Magic Header",            size: 16,         entropy: 2.80, crc32: "0x53454344", type: "header" },
        { name: "Config Schema JSON",      size: 1840,       entropy: 4.35, crc32: "0x8192ABCD", type: "metadata" },
        { name: "State Blob (Zstd)",       size: 33177,      entropy: 7.60, crc32: "0x66554433", type: "compressed" },
        { name: "HMAC Auth Token",         size: 256,        entropy: 6.70, crc32: "0xFEEDFACE", type: "security" },
        { name: "Checksum Postscript",     size: 4,          entropy: 0.50, crc32: "0xC001D00D", type: "footer" }
    ]

    readonly property var presetFragmented: [
        { name: "Master Header",           size: 256,        entropy: 2.05, crc32: "0xA1B2C3D4", type: "header" },
        { name: "Dictionary Index",        size: 8192,       entropy: 5.30, crc32: "0xB2C3D4E5", type: "index" },
        { name: "Segment #1 (Raw)",        size: 524288,     entropy: 3.75, crc32: "0xC3D4E5F6", type: "raw" },
        { name: "Segment #2 (LZ4)",        size: 4194304,    entropy: 7.10, crc32: "0xD4E5F6A7", type: "compressed" },
        { name: "Checkpoint Chunk",        size: 64,         entropy: 1.20, crc32: "0xE5F6A7B8", type: "checkpoint" },
        { name: "Segment #3 (ChaCha20)",   size: 18874368,   entropy: 7.99, crc32: "0xF6A7B8C9", type: "encrypted" },
        { name: "Padding Zeroes",          size: 1024,       entropy: 0.05, crc32: "0x00000000", type: "padding" },
        { name: "Segment #4 (Media)",      size: 8388608,    entropy: 6.45, crc32: "0xA7B8C9D0", type: "media" },
        { name: "Security Certificate",    size: 2048,       entropy: 6.85, crc32: "0xB8C9D0E1", type: "security" },
        { name: "Manifest & End Record",   size: 128,        entropy: 1.50, crc32: "0xC9D0E1F2", type: "footer" }
    ]

    FontLoader {
        id: materialIcons
        source: "Fonts/MaterialIconsRound-Regular.otf"
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
                    text: "Archive Info"
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
        // --- SECTION 3: Shannon Entropy File Map ---
        // ==========================================
        Rectangle {
            id: entropyCard
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 280
            color: Colors.bgSurface
            radius: 10
            border.color: Colors.goldBorder
            border.width: 1
            clip: true

            // State & Configuration
            property bool adaptiveScaling: true
            property int hoveredIndex: -1
            property int selectedIndex: 3
            readonly property int activeIndex: hoveredIndex >= 0 ? hoveredIndex : (selectedIndex >= 0 && selectedIndex < computedRegions.length ? selectedIndex : 0)
            property int currentPresetIndex: 0
            readonly property var presetList: [root.defaultRegions, root.presetGigabyte, root.presetKilobyte, root.presetFragmented]
            readonly property var presetNames: ["SecDet (MB)", "Large (GB)", "Config (KB)", "Fragments (10)"]
            property bool copyFeedback: false

            // Hidden clipboard helper for CRC32 & region data copy
            TextInput {
                id: clipboardHelper
                visible: false
            }

            Timer {
                id: copyFeedbackTimer
                interval: 1400
                repeat: false
                onTriggered: entropyCard.copyFeedback = false
            }

            function copyToClipboard(text) {
                clipboardHelper.text = text;
                clipboardHelper.selectAll();
                clipboardHelper.copy();
                entropyCard.copyFeedback = true;
                copyFeedbackTimer.restart();
            }

            // Distinguishable Sleek Color Palette (Cyan, Emerald, Amber, Violet, Rose, Blue, Orange, Magenta, Mint, Lime)
            readonly property var colorPalette: [
                "#00d2ff", // Neon Cyan
                "#10b981", // Emerald Tech Green
                "#f59e0b", // Imperial Amber
                "#8b5cf6", // Electric Violet
                "#f43f5e", // Crimson Rose
                "#0ea5e9", // Sky Blue
                "#fb923c", // Vibrant Tangerine
                "#e879f9", // Neon Orchid
                "#14b8a6", // Mint Teal
                "#84cc16"  // Electric Lime
            ]

            function getRegionColor(index, region) {
                if (region && region.color) return region.color;
                return colorPalette[index % colorPalette.length];
            }

            // Dynamic Byte Formatter (Byte -> KB -> MB -> GB -> TB)
            function formatBytes(bytes) {
                if (bytes === undefined || bytes === null || isNaN(bytes)) return "0 B";
                if (bytes <= 0) return "0 B";
                if (bytes < 1024) return Math.round(bytes) + " B";
                var k = 1024;
                var sizes = ["B", "KB", "MB", "GB", "TB"];
                var i = Math.floor(Math.log(bytes) / Math.log(k));
                i = Math.max(0, Math.min(sizes.length - 1, i));
                var val = bytes / Math.pow(k, i);
                var decimals = (val >= 100 || i === 0) ? 0 : (val >= 10 ? 1 : 2);
                return val.toFixed(decimals) + " " + sizes[i];
            }

            function formatHex(val) {
                if (val === undefined || val === null) return "0x00000000";
                if (typeof val === "string") {
                    if (val.startsWith("0x") || val.startsWith("0X")) return val.toUpperCase();
                    var num = parseInt(val, 16);
                    if (!isNaN(num)) val = num;
                }
                var hex = Number(val).toString(16).toUpperCase();
                while (hex.length < 8) hex = "0" + hex;
                return "0x" + hex;
            }

            function getEntropyCategory(h) {
                if (h >= 7.75) return { label: "Encrypted / Max Random", color: "#10b981", icon: "\ue897" }; // lock
                if (h >= 6.4)  return { label: "Compressed / High", color: "#00d2ff", icon: "\ue871" }; // view_quilt
                if (h >= 4.0)  return { label: "Structured / Medium", color: "#f59e0b", icon: "\ue869" }; // build / code
                if (h >= 1.5)  return { label: "Text / Low Entropy", color: "#38bdf8", icon: "\ue873" }; // description
                return { label: "Uniform / Null Padding", color: "#8e919e", icon: "\ue836" }; // radio_button_unchecked
            }

            // Total File Size & Weighted Average Entropy
            readonly property real totalFileSize: {
                var r = root.fileMapRegions;
                if (!r || r.length === 0) return 0;
                var tot = 0;
                for (var i = 0; i < r.length; ++i) tot += Math.max(0, r[i].size || 0);
                return tot;
            }

            readonly property real averageEntropy: {
                var r = root.fileMapRegions;
                if (!r || r.length === 0) return 0.0;
                var tot = 0;
                var sumEnt = 0;
                for (var i = 0; i < r.length; ++i) {
                    var s = Math.max(0, r[i].size || 0);
                    tot += s;
                    sumEnt += Math.max(0.0, Math.min(8.0, r[i].entropy || 0.0)) * s;
                }
                return tot > 0 ? (sumEnt / tot) : 0.0;
            }

            // Region layout computation with adaptive small-section magnification
            readonly property var computedRegions: {
                var raw = root.fileMapRegions;
                var availW = Math.max(20, plotContainer.width);
                var isAdaptive = entropyCard.adaptiveScaling;

                if (!raw || raw.length === 0) return [];
                var N = raw.length;
                var totalBytes = entropyCard.totalFileSize;
                if (totalBytes <= 0) totalBytes = 1;

                var items = [];
                var curOffset = 0;
                var weightSum = 0;

                for (var j = 0; j < N; ++j) {
                    var r = raw[j];
                    var s = Math.max(0, r.size || 0);
                    var ent = Math.max(0.0, Math.min(8.0, r.entropy !== undefined ? r.entropy : 0.0));
                    var crc = formatHex(r.crc32);
                    var col = getRegionColor(j, r);
                    var startOff = curOffset;
                    var endOff = curOffset + s;
                    curOffset = endOff;

                    // Power weight to compress scale differences while preserving dominance
                    var w = Math.pow(s > 0 ? s : 1, 0.45);
                    weightSum += w;

                    items.push({
                        name: r.name || ("Region #" + (j + 1)),
                        size: s,
                        entropy: ent,
                        crc32: crc,
                        color: col,
                        type: r.type || "chunk",
                        startOffset: startOff,
                        endOffset: endOff,
                        linearRatio: s / totalBytes,
                        sqrtWeight: w
                    });
                }

                var result = [];
                if (isAdaptive) {
                    // Small section enlargement: guaranteed minimum visual width
                    var minW = Math.min(36, Math.max(24, Math.floor((availW * 0.42) / N)));
                    var baseTotal = N * minW;
                    var flexW = Math.max(0, availW - baseTotal);

                    var currentX = 0;
                    for (var k = 0; k < N; ++k) {
                        var it = items[k];
                        var flexShare = weightSum > 0 ? (it.sqrtWeight / weightSum) * flexW : 0;
                        var wActual = minW + flexShare;

                        // Ensure last item completes the container width exactly
                        if (k === N - 1) {
                            wActual = Math.max(minW, availW - currentX);
                        }

                        var linW = it.linearRatio * availW;
                        var isEnlarged = (wActual > linW * 1.5) && (it.size < totalBytes * 0.15);

                        result.push({
                            index: k,
                            name: it.name,
                            size: it.size,
                            entropy: it.entropy,
                            crc32: it.crc32,
                            color: it.color,
                            type: it.type,
                            startOffset: it.startOffset,
                            endOffset: it.endOffset,
                            percent: (it.linearRatio * 100).toFixed(1),
                            visualX: currentX,
                            visualWidth: wActual,
                            isEnlarged: isEnlarged,
                            enlargeRatio: linW > 0 ? (wActual / linW).toFixed(1) : "1.0"
                        });
                        currentX += wActual;
                    }
                } else {
                    // True Scale: Linear byte ratio
                    var curX = 0;
                    for (var m = 0; m < N; ++m) {
                        var item = items[m];
                        var wLin = Math.max(3, item.linearRatio * availW);
                        if (m === N - 1) {
                            wLin = Math.max(3, availW - curX);
                        }
                        result.push({
                            index: m,
                            name: item.name,
                            size: item.size,
                            entropy: item.entropy,
                            crc32: item.crc32,
                            color: item.color,
                            type: item.type,
                            startOffset: item.startOffset,
                            endOffset: item.endOffset,
                            percent: (item.linearRatio * 100).toFixed(1),
                            visualX: curX,
                            visualWidth: wLin,
                            isEnlarged: false,
                            enlargeRatio: "1.0"
                        });
                        curX += wLin;
                    }
                }
                return result;
            }

            readonly property var activeRegion: {
                var list = computedRegions;
                var idx = activeIndex;
                if (list && list.length > 0 && idx >= 0 && idx < list.length) {
                    return list[idx];
                }
                return null;
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                // ==========================================
                // --- Top Header: Title, Metric Badge & Controls ---
                // ==========================================
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        spacing: 6
                        Text {
                            text: "\ue880" // analytics
                            font.family: materialIcons.name
                            font.pixelSize: 16
                            color: Colors.goldPrimary
                        }
                        Text {
                            text: "FILE MAP & SHANNON ENTROPY"
                            font.family: Colors.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: Colors.goldPrimary
                        }
                    }

                    // Summary Badge (File size & Average Entropy)
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
                            spacing: 5
                            Rectangle { width: 6; height: 6; radius: 3; color: "#4ade80" }
                            Text {
                                text: entropyCard.formatBytes(entropyCard.totalFileSize) + " • Avg: " + entropyCard.averageEntropy.toFixed(2) + " Bits/B"
                                font.family: Colors.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                color: Colors.goldHover
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Preset Switcher Pill (Cycle demo presets across B/KB/MB/GB)
                    Rectangle {
                        implicitWidth: presetRow.implicitWidth + 10
                        implicitHeight: 22
                        radius: 5
                        color: presetMouse.containsPress ? Qt.darker(Colors.bgInput, 1.1) : (presetMouse.containsMouse ? Colors.bgHover : Colors.bgInput)
                        border.color: Colors.goldBorder
                        border.width: 1

                        RowLayout {
                            id: presetRow
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: "\ue53b" // layers
                                font.family: materialIcons.name
                                font.pixelSize: 11
                                color: Colors.goldPrimary
                            }
                            Text {
                                text: entropyCard.presetNames[entropyCard.currentPresetIndex]
                                font.family: Colors.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.Medium
                                color: Colors.textMain
                            }
                        }

                        MouseArea {
                            id: presetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                entropyCard.currentPresetIndex = (entropyCard.currentPresetIndex + 1) % entropyCard.presetList.length;
                                root.fileMapRegions = entropyCard.presetList[entropyCard.currentPresetIndex];
                                entropyCard.hoveredIndex = -1;
                                entropyCard.selectedIndex = 0;
                            }
                        }
                    }

                    // Adaptive vs True Scale View Toggle
                    Rectangle {
                        implicitWidth: modeRow.implicitWidth + 10
                        implicitHeight: 22
                        radius: 5
                        color: modeMouse.containsMouse ? Colors.bgHover : (entropyCard.adaptiveScaling ? Colors.goldLight : Colors.bgInput)
                        border.color: entropyCard.adaptiveScaling ? Colors.goldBorderHi : Colors.goldBorder
                        border.width: 1

                        RowLayout {
                            id: modeRow
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: entropyCard.adaptiveScaling ? "\ue429" : "\ue8ee" // tune / aspect_ratio
                                font.family: materialIcons.name
                                font.pixelSize: 11
                                color: entropyCard.adaptiveScaling ? Colors.goldHover : Colors.textMuted
                            }
                            Text {
                                text: entropyCard.adaptiveScaling ? "Adaptive" : "True Scale"
                                font.family: Colors.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                color: entropyCard.adaptiveScaling ? Colors.goldHover : Colors.textMuted
                            }
                        }

                        MouseArea {
                            id: modeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                entropyCard.adaptiveScaling = !entropyCard.adaptiveScaling;
                            }
                        }
                    }
                }

                // ==========================================
                // --- Central Plot: Shannon Entropy Y-Axis & File Map Bars ---
                // ==========================================
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 125
                    spacing: 6

                    // Y-Axis Labels Column (Shannon Entropy 0.0 to 8.0 bits/byte)
                    Item {
                        id: yAxisColumn
                        Layout.preferredWidth: 32
                        Layout.fillHeight: true

                        Text {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            text: "8.0"
                            font.family: Colors.fontFamily
                            font.pixelSize: 8
                            font.weight: Font.Bold
                            color: Colors.textMuted
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: -parent.height * 0.25
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            text: "6.0"
                            font.family: Colors.fontFamily
                            font.pixelSize: 8
                            color: Colors.textSubtle
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            text: "4.0"
                            font.family: Colors.fontFamily
                            font.pixelSize: 8
                            color: Colors.textSubtle
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: parent.height * 0.25
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            text: "2.0"
                            font.family: Colors.fontFamily
                            font.pixelSize: 8
                            color: Colors.textSubtle
                        }

                        Text {
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            text: "0.0"
                            font.family: Colors.fontFamily
                            font.pixelSize: 8
                            font.weight: Font.Bold
                            color: Colors.textMuted
                        }
                    }

                    // Main Plot Area
                    Item {
                        id: plotContainer
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        // Plot Background Frame
                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: Colors.isDarkMode ? "#0d0f15" : "#f6f7fa"
                            border.color: Colors.goldBorder
                            border.width: 1
                        }

                        // Horizontal Reference Guidelines (8.0, 6.0, 4.0, 2.0, 0.0)
                        Column {
                            anchors.fill: parent
                            anchors.margins: 1
                            spacing: (parent.height - 4) / 4
                            Repeater {
                                model: 5
                                Rectangle {
                                    width: plotContainer.width
                                    height: 1
                                    color: index === 0 || index === 4 ? Colors.divider : Qt.rgba(1, 1, 1, 0.04)
                                }
                            }
                        }

                        // Stepped Plateaus / Bars for each Region
                        Repeater {
                            model: entropyCard.computedRegions

                            Item {
                                id: barWrapper
                                x: modelData.visualX
                                y: 1
                                width: Math.max(2, modelData.visualWidth)
                                height: plotContainer.height - 2

                                readonly property bool isCurrent: entropyCard.activeIndex === index
                                readonly property bool hasFocus: entropyCard.hoveredIndex >= 0 ? isCurrent : true

                                Rectangle {
                                    id: barPlateau
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: Math.max(4, (modelData.entropy / 8.0) * parent.height)
                                    radius: 2

                                    // Distinguished color fill with sleek vertical gradient
                                    gradient: Gradient {
                                        GradientStop {
                                            position: 0.0
                                            color: {
                                                var c = Qt.color(modelData.color);
                                                return barWrapper.isCurrent ? Qt.rgba(c.r, c.g, c.b, 0.70)
                                                                            : (barWrapper.hasFocus ? Qt.rgba(c.r, c.g, c.b, 0.38)
                                                                                                    : Qt.rgba(c.r, c.g, c.b, 0.18));
                                            }
                                        }
                                        GradientStop {
                                            position: 1.0
                                            color: {
                                                var c = Qt.color(modelData.color);
                                                return barWrapper.isCurrent ? Qt.rgba(c.r, c.g, c.b, 0.28)
                                                                            : (barWrapper.hasFocus ? Qt.rgba(c.r, c.g, c.b, 0.12)
                                                                                                    : Qt.rgba(c.r, c.g, c.b, 0.04));
                                            }
                                        }
                                    }

                                    // Glowing Top Capline (Exact Entropy Level Indicator)
                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: barWrapper.isCurrent ? 3 : 2
                                        color: barWrapper.isCurrent ? "#ffffff" : modelData.color
                                        radius: 1

                                        Behavior on height { NumberAnimation { duration: 120 } }
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                    }

                                    // Right Boundary Divider separating each region distinctly
                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        anchors.right: parent.right
                                        width: 1
                                        color: Qt.rgba(1, 1, 1, 0.18)
                                    }

                                    // In-Bar Label (Displays Entropy & Name if width allows)
                                    Item {
                                        anchors.fill: parent
                                        visible: modelData.visualWidth >= 38 && barPlateau.height >= 26

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 1

                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: modelData.entropy.toFixed(1)
                                                font.family: Colors.fontFamily
                                                font.pixelSize: 9
                                                font.weight: Font.Bold
                                                color: barWrapper.isCurrent ? "#ffffff" : modelData.color
                                            }

                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: modelData.name
                                                font.family: Colors.fontFamily
                                                font.pixelSize: 8
                                                color: Colors.textMuted
                                                elide: Text.ElideRight
                                                Layout.maximumWidth: barWrapper.width - 6
                                                visible: modelData.visualWidth >= 60 && barPlateau.height >= 40
                                            }
                                        }
                                    }
                                }

                                // Interactive Click & Hover Area for Bar
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: entropyCard.hoveredIndex = index
                                    onExited: {
                                        if (entropyCard.hoveredIndex === index) {
                                            entropyCard.hoveredIndex = -1;
                                        }
                                    }
                                    onClicked: {
                                        entropyCard.selectedIndex = index;
                                        root.regionSelected(modelData, index);
                                    }
                                }
                            }
                        }
                    }
                }

                // ==========================================
                // --- Dynamic X-Axis Byte Scale Bar ---
                // ==========================================
                Item {
                    id: xAxisRuler
                    Layout.fillWidth: true
                    height: 20

                    RowLayout {
                        anchors.fill: parent
                        spacing: 0

                        // Spacer matching Y-axis column width
                        Item {
                            Layout.preferredWidth: 32
                            Layout.fillHeight: true
                            Text {
                                anchors.centerIn: parent
                                text: "Bytes"
                                font.family: Colors.fontFamily
                                font.pixelSize: 8
                                color: Colors.textSubtle
                            }
                        }

                        // Graduated Byte Axis
                        Item {
                            id: xAxisScale
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            // Baseline Axis Line
                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 1
                                color: Colors.divider
                            }

                            // Dynamic byte ticks at region boundaries
                            Repeater {
                                model: entropyCard.computedRegions

                                Item {
                                    x: modelData.visualX
                                    y: 0
                                    width: modelData.visualWidth
                                    height: xAxisScale.height

                                    readonly property bool isHovered: entropyCard.activeIndex === index
                                    readonly property bool showLabel: index === 0 || modelData.visualWidth >= 44 || index === entropyCard.computedRegions.length - 1 || isHovered

                                    // Boundary Tick Mark
                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        width: 1
                                        height: 4
                                        color: isHovered ? Colors.goldHover : Colors.divider
                                    }

                                    // Dynamic Byte Value Label (B, KB, MB, GB)
                                    Text {
                                        anchors.top: parent.top
                                        anchors.topMargin: 5
                                        anchors.left: parent.left
                                        anchors.leftMargin: index === 0 ? 2 : -10
                                        text: entropyCard.formatBytes(modelData.startOffset)
                                        font.family: Colors.fontFamily
                                        font.pixelSize: 8
                                        font.weight: isHovered ? Font.Bold : Font.Normal
                                        color: isHovered ? Colors.goldHover : Colors.textMuted
                                        visible: showLabel
                                    }
                                }
                            }

                            // Final End Boundary Tick Mark (Total File Size)
                            Rectangle {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                width: 1
                                height: 5
                                color: Colors.goldBorderHi
                            }

                            Text {
                                anchors.top: parent.top
                                anchors.topMargin: 5
                                anchors.right: parent.right
                                text: entropyCard.formatBytes(entropyCard.totalFileSize)
                                font.family: Colors.fontFamily
                                font.pixelSize: 8
                                font.weight: Font.Bold
                                color: Colors.goldHover
                            }
                        }
                    }
                }

                // ==========================================
                // --- Region Inspector Card: Name, Size, Entropy & CRC32 ---
                // ==========================================
                Rectangle {
                    id: inspectorCard
                    Layout.fillWidth: true
                    implicitHeight: 82
                    radius: 8
                    color: Colors.bgCard
                    border.color: entropyCard.activeRegion ? entropyCard.activeRegion.color : Colors.goldBorder
                    border.width: 1

                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    // Left Accent Pill showing Region Color
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 4
                        radius: 2
                        color: entropyCard.activeRegion ? entropyCard.activeRegion.color : Colors.goldPrimary
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        anchors.topMargin: 8
                        anchors.bottomMargin: 8
                        spacing: 6

                        // Row 1: Region Name & Security Classification
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Rectangle {
                                width: 8; height: 8; radius: 4
                                color: entropyCard.activeRegion ? entropyCard.activeRegion.color : Colors.goldPrimary
                            }

                            Text {
                                text: entropyCard.activeRegion ? entropyCard.activeRegion.name : "No Region Selected"
                                font.family: Colors.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: Colors.textMain
                                elide: Text.ElideRight
                                Layout.maximumWidth: 260
                            }

                            // Magnification Status (Inform user why tiny sections are visible)
                            Rectangle {
                                visible: entropyCard.activeRegion && entropyCard.activeRegion.isEnlarged
                                implicitWidth: magText.implicitWidth + 8
                                implicitHeight: 16
                                radius: 4
                                color: Qt.rgba(1, 0.8, 0, 0.12)
                                border.color: Colors.goldBorder
                                border.width: 1

                                Text {
                                    id: magText
                                    anchors.centerIn: parent
                                    text: "✦ Magnified (" + (entropyCard.activeRegion ? entropyCard.activeRegion.percent : "0") + "% actual)"
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 8
                                    font.weight: Font.Medium
                                    color: Colors.goldHover
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Category Tag (Encrypted / Compressed / Structured)
                            RowLayout {
                                spacing: 4
                                readonly property var cat: entropyCard.getEntropyCategory(entropyCard.activeRegion ? entropyCard.activeRegion.entropy : 0)

                                Text {
                                    text: parent.cat.icon
                                    font.family: materialIcons.name
                                    font.pixelSize: 12
                                    color: parent.cat.color
                                }
                                Text {
                                    text: parent.cat.label
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                    color: parent.cat.color
                                }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: Colors.divider }

                        // Row 2: 4-Column Detailed Metrics (Entropy, Size, Offset, CRC32)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            // Col 1: Shannon Entropy
                            ColumnLayout {
                                spacing: 1
                                Layout.fillWidth: true

                                Text {
                                    text: "ENTROPY"
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 8
                                    color: Colors.textMuted
                                    font.weight: Font.Bold
                                }
                                Text {
                                    text: entropyCard.activeRegion ? (entropyCard.activeRegion.entropy.toFixed(2) + " Bits/B") : "0.00"
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: entropyCard.activeRegion ? entropyCard.activeRegion.color : Colors.textMain
                                }
                            }

                            // Col 2: Size & Percentage
                            ColumnLayout {
                                spacing: 1
                                Layout.fillWidth: true

                                Text {
                                    text: "SIZE"
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 8
                                    color: Colors.textMuted
                                    font.weight: Font.Bold
                                }
                                Text {
                                    text: entropyCard.activeRegion ? (entropyCard.formatBytes(entropyCard.activeRegion.size) + " (" + entropyCard.activeRegion.percent + "%)") : "0 B"
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: Colors.textMain
                                }
                            }

                            // Col 3: Byte Range Offsets (Hex & Humanized)
                            ColumnLayout {
                                spacing: 1
                                Layout.fillWidth: true

                                Text {
                                    text: "OFFSET RANGE"
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 8
                                    color: Colors.textMuted
                                    font.weight: Font.Bold
                                }
                                Text {
                                    text: entropyCard.activeRegion ? (entropyCard.formatHex(entropyCard.activeRegion.startOffset) + " → " + entropyCard.formatHex(entropyCard.activeRegion.endOffset)) : "0x0 - 0x0"
                                    font.family: "Consolas, Segoe UI, monospace"
                                    font.pixelSize: 9
                                    color: Colors.textMain
                                }
                            }

                            // Col 4: CRC-32 Checksum with Copy Button
                            ColumnLayout {
                                spacing: 1
                                Layout.preferredWidth: 95

                                Text {
                                    text: "CRC-32"
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 8
                                    color: Colors.textMuted
                                    font.weight: Font.Bold
                                }

                                RowLayout {
                                    spacing: 4

                                    Text {
                                        text: entropyCard.activeRegion ? entropyCard.activeRegion.crc32 : "0x00000000"
                                        font.family: "Consolas, Segoe UI, monospace"
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: Colors.goldPrimary
                                    }

                                    Rectangle {
                                        width: 18; height: 18; radius: 4
                                        color: copyMouse.containsMouse ? Colors.bgHover : "transparent"
                                        border.color: Colors.goldBorder
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: entropyCard.copyFeedback ? "\ue877" : "\ue14d" // check or copy
                                            font.family: materialIcons.name
                                            font.pixelSize: 11
                                            color: entropyCard.copyFeedback ? "#4ade80" : Colors.goldPrimary
                                        }

                                        MouseArea {
                                            id: copyMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (entropyCard.activeRegion) {
                                                    entropyCard.copyToClipboard(entropyCard.activeRegion.crc32);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ==========================================
                // --- Region Legend Chips & Quick Navigation ---
                // ==========================================
                Flickable {
                    id: legendFlick
                    Layout.fillWidth: true
                    height: 26
                    contentWidth: legendRow.implicitWidth
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    RowLayout {
                        id: legendRow
                        spacing: 6

                        Repeater {
                            model: entropyCard.computedRegions

                            Rectangle {
                                implicitWidth: chipRow.implicitWidth + 10
                                implicitHeight: 24
                                radius: 4
                                color: entropyCard.activeIndex === index ? Qt.rgba(1, 1, 1, 0.08) : Colors.bgInput
                                border.color: entropyCard.activeIndex === index ? modelData.color : Colors.divider
                                border.width: 1

                                Behavior on border.color { ColorAnimation { duration: 120 } }

                                RowLayout {
                                    id: chipRow
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Rectangle {
                                        width: 6; height: 6; radius: 3
                                        color: modelData.color
                                    }

                                    Text {
                                        text: modelData.name
                                        font.family: Colors.fontFamily
                                        font.pixelSize: 9
                                        font.weight: entropyCard.activeIndex === index ? Font.Bold : Font.Medium
                                        color: Colors.textMain
                                    }

                                    Text {
                                        text: entropyCard.formatBytes(modelData.size)
                                        font.family: Colors.fontFamily
                                        font.pixelSize: 8
                                        color: Colors.textMuted
                                    }

                                    Text {
                                        text: modelData.entropy.toFixed(1) + "H"
                                        font.family: Colors.fontFamily
                                        font.pixelSize: 8
                                        font.weight: Font.Bold
                                        color: modelData.color
                                    }

                                    Text {
                                        text: modelData.crc32
                                        font.family: "Consolas, monospace"
                                        font.pixelSize: 8
                                        color: Colors.goldPrimary
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: entropyCard.hoveredIndex = index
                                    onExited: {
                                        if (entropyCard.hoveredIndex === index) {
                                            entropyCard.hoveredIndex = -1;
                                        }
                                    }
                                    onClicked: {
                                        entropyCard.selectedIndex = index;
                                        root.regionSelected(modelData, index);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
