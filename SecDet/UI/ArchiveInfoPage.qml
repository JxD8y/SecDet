import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic as Basic
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

    signal closeRequested
    signal itemNavigated(string path, bool isFolder)

    property bool internalNavigationSync: false

    function notifyNavigation(path, isFolder) {
        if (internalNavigationSync) return;
        root.itemNavigated(path, isFolder);
    }

    function navigateToItem(itemPath, isFolder) {
        if (typeof sunburstCard !== "undefined" && sunburstCard) {
            internalNavigationSync = true;
            sunburstCard.navigateToFileMapItem(itemPath, isFolder);
            internalNavigationSync = false;
        }
    }

    readonly property bool hasActiveArchive: typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.hasArchive

    FontLoader {
        id: materialIcons
        source: "Fonts/MaterialIconsRound-Regular.otf"
    }

    // Settings State & Tracking
    property int pendingCompressionLevel: (hasActiveArchive && archiveInterface.metadata) ? archiveInterface.metadata.compressionLevel : 2
    property bool pendingPreserveMetadata: (hasActiveArchive && archiveInterface.metadata) ? archiveInterface.metadata.preserveMetadata : true
    property bool settingsSavedFeedback: false

    readonly property bool hasSettingsChanges: {
        if (!hasActiveArchive || !archiveInterface || !archiveInterface.metadata) return false;
        return (pendingCompressionLevel !== archiveInterface.metadata.compressionLevel) ||
               (pendingPreserveMetadata !== archiveInterface.metadata.preserveMetadata);
    }

    onVisibleChanged: {
        if (visible && hasActiveArchive && archiveInterface && archiveInterface.metadata) {
            root.reloadSettings();
            root.settingsSavedFeedback = false;
        }
    }

    function reloadSettings() {
        if (hasActiveArchive && archiveInterface && archiveInterface.metadata) {
            root.pendingCompressionLevel = archiveInterface.metadata.compressionLevel;
            root.pendingPreserveMetadata = archiveInterface.metadata.preserveMetadata;
            if (typeof compToggle !== "undefined" && compToggle) {
                compToggle.currentIndex = Math.max(0, Math.min(2, archiveInterface.metadata.compressionLevel - 1));
            }
        }
    }

    Connections {
        target: (hasActiveArchive && archiveInterface && archiveInterface.metadata) ? archiveInterface.metadata : null
        function onMetadataChanged() {
            root.reloadSettings();
        }
    }

    Timer {
        id: settingsFeedbackTimer
        interval: 2500
        repeat: false
        onTriggered: {
            root.settingsSavedFeedback = false;
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
        implicitHeight: 30
        radius: 6
        color: isControlEnabled ? Colors.bgInput : Qt.rgba(0.1, 0.1, 0.12, 0.6)
        border.color: isControlEnabled ? Colors.goldBorder : Colors.borderSubtle
        border.width: 1

        Rectangle {
            id: activePill
            width: (toggleRoot.width - 6) / Math.max(1, toggleRoot.options.length)
            height: toggleRoot.height - 6
            y: 3
            x: 3 + toggleRoot.currentIndex * width
            radius: 4
            color: toggleRoot.isControlEnabled ? Colors.goldLight : Qt.rgba(1, 1, 1, 0.06)
            border.color: toggleRoot.isControlEnabled ? Colors.goldBorderHi : Colors.borderSubtle
            border.width: 1

            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
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
                        font.pixelSize: 10
                        font.weight: toggleRoot.currentIndex === index ? Font.Bold : Font.Medium
                        color: toggleRoot.currentIndex === index
                             ? (toggleRoot.isControlEnabled ? Colors.goldHover : Colors.textSubtle)
                             : Colors.textMuted

                        Behavior on color { ColorAnimation { duration: 120 } }
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
        implicitHeight: Math.max(20, swRow.implicitHeight)

        RowLayout {
            id: swRow
            anchors.fill: parent
            spacing: 8

            Text {
                text: swRoot.text
                color: swRoot.isControlEnabled ? Colors.textMain : Colors.textSubtle
                font.family: Colors.fontFamily
                font.pixelSize: 11
                font.weight: Font.Medium
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                elide: Text.ElideRight
            }

            Rectangle {
                id: track
                width: 32
                height: 18
                radius: 9
                Layout.alignment: Qt.AlignVCenter
                color: swRoot.checked
                     ? (swRoot.isControlEnabled ? Colors.goldLightHover : Qt.rgba(1, 1, 1, 0.08))
                     : Colors.bgInput
                border.color: swRoot.checked
                            ? (swRoot.isControlEnabled ? Colors.goldBorderHi : Colors.borderSubtle)
                            : (swRoot.isControlEnabled ? Colors.goldBorder : Colors.borderSubtle)
                border.width: 1

                Behavior on color { ColorAnimation { duration: 120 } }

                Rectangle {
                    id: thumb
                    width: 12
                    height: 12
                    radius: 6
                    anchors.verticalCenter: parent.verticalCenter
                    x: swRoot.checked ? parent.width - width - 3 : 3
                    color: swRoot.checked
                         ? (swRoot.isControlEnabled ? Colors.goldPrimary : Colors.textSubtle)
                         : Colors.textMuted

                    Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                    Behavior on color { ColorAnimation { duration: 120 } }
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

    Rectangle {
        id: dialogFrame
        anchors.fill: parent
        color: Colors.bgCard
        radius: 12
        border.color: Colors.goldBorder
        border.width: 1

        Behavior on color {
            ColorAnimation {
                duration: 200
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: 200
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // ==========================================
        // --- Top Bar: Title & Close Button ---
        // ==========================================
        RowLayout {
            Layout.fillWidth: true

            RowLayout {
                spacing: 8
                Text {
                    text: "\ue88e" // info
                    font.family: materialIcons.name
                    font.pixelSize: 20
                    color: Colors.goldPrimary
                }

                Text {
                    text: root.hasActiveArchive ? ("Archive Info • " + archiveInterface.archiveFileName) : "Archive Info"
                    font.family: Colors.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    color: Colors.textMain
                }
            }

            Item {
                Layout.fillWidth: true
            }

            // Close Button
            Rectangle {
                width: 26
                height: 26
                radius: 13
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
        // --- Empty State: When no archive is loaded ---
        // ==========================================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.hasActiveArchive

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 14

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 68
                    height: 68
                    radius: 34
                    color: Colors.goldLight
                    border.color: Colors.goldBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "\ue2c7" // folder_open
                        font.family: materialIcons.name
                        font.pixelSize: 32
                        color: Colors.goldPrimary
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Load an archive first"
                    font.family: Colors.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    color: Colors.textMain
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Open or create an archive to inspect its metadata and space savings distribution."
                    font.family: Colors.fontFamily
                    font.pixelSize: 11
                    color: Colors.textMuted
                }
            }
        }

        // ==========================================
        // --- Archive Active State ---
        // ==========================================
        // Live Metadata Overview Strip
        Rectangle {
            Layout.fillWidth: true
            height: 36
            radius: 8
            color: Colors.bgCard
            border.color: Colors.borderSubtle
            border.width: 1
            visible: root.hasActiveArchive

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 12

                Text {
                    text: (root.hasActiveArchive && archiveInterface.metadata) ? ("Files: " + archiveInterface.metadata.fileCount) : "Files: 0"
                    font.family: Colors.fontFamily
                    font.pixelSize: 11
                    color: Colors.textMain
                }
                Rectangle {
                    width: 1
                    height: 14
                    color: Colors.divider
                }
                Text {
                    text: (root.hasActiveArchive && archiveInterface.metadata) ? ("Folders: " + archiveInterface.metadata.folderCount) : "Folders: 0"
                    font.family: Colors.fontFamily
                    font.pixelSize: 11
                    color: Colors.textMain
                }
                Rectangle {
                    width: 1
                    height: 14
                    color: Colors.divider
                }
                Text {
                    text: (root.hasActiveArchive && archiveInterface.metadata) ? ("Size: " + archiveInterface.metadata.formattedTotalRealSize) : "Size: 0 B"
                    font.family: Colors.fontFamily
                    font.pixelSize: 11
                    color: Colors.textMain
                }
                Rectangle {
                    width: 1
                    height: 14
                    color: Colors.divider
                }
                Text {
                    text: (root.hasActiveArchive && archiveInterface.metadata) ? ("Savings: " + archiveInterface.metadata.overallRatio) : "Savings: 0%"
                    font.family: Colors.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: Colors.goldPrimary
                }
                Rectangle {
                    width: 1
                    height: 14
                    color: Colors.divider
                }
                Text {
                    text: (root.hasActiveArchive && archiveInterface.metadata) ? ("Profile: " + archiveInterface.metadata.compressionPresetName) : "Profile: Standard"
                    font.family: Colors.fontFamily
                    font.pixelSize: 11
                    color: Colors.goldHover
                }
                Item {
                    Layout.fillWidth: true
                }
            }
        }

        // ==========================================
        // --- Radial Sunburst Donut File Map Card ---
        // ==========================================
        Rectangle {
            id: sunburstCard
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 280
            Layout.preferredHeight: 380
            color: Colors.bgSurface
            radius: 10
            border.color: Colors.goldBorder
            border.width: 1
            clip: true
            visible: root.hasActiveArchive

            // Navigation & Drill-Down State
            property string currentPath: "/"
            property var currentData: null
            property var hoveredSector: null
            property var selectedSector: null
            readonly property var activeItem: hoveredSector || selectedSector || (currentData ? currentData.hub : null)

            property bool copyFeedback: false

            TextInput {
                id: clipboardHelper
                visible: false
            }

            Timer {
                id: copyFeedbackTimer
                interval: 1400
                repeat: false
                onTriggered: sunburstCard.copyFeedback = false
            }

            function copyToClipboard(text) {
                clipboardHelper.text = text;
                clipboardHelper.selectAll();
                clipboardHelper.copy();
                sunburstCard.copyFeedback = true;
                copyFeedbackTimer.restart();
            }

            function refreshData() {
                if (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.hasArchive) {
                    currentData = archiveInterface.getSunburstData(currentPath);
                } else {
                    currentData = null;
                }
                sunburstCanvas.requestPaint();
            }

            function drillDown(targetPath) {
                if (!targetPath) return;
                currentPath = targetPath;
                hoveredSector = null;
                selectedSector = null;
                refreshData();
                root.notifyNavigation(targetPath, true);
            }

            function zoomOut() {
                if (currentData && currentData.hub && currentData.hub.parentPath !== undefined) {
                    currentPath = currentData.hub.parentPath || "/";
                } else {
                    currentPath = "/";
                }
                hoveredSector = null;
                selectedSector = null;
                refreshData();
                root.notifyNavigation(currentPath, true);
            }

            function navigateToFileMapItem(itemPath, isFolder) {
                if (!itemPath) return;
                var normPath = itemPath;
                if (!normPath.startsWith("/")) normPath = "/" + normPath;

                if (isFolder) {
                    if (!normPath.endsWith("/")) normPath = normPath + "/";
                    if (currentPath !== normPath) {
                        currentPath = normPath;
                        hoveredSector = null;
                        selectedSector = null;
                        refreshData();
                    }
                } else {
                    var lastSlash = normPath.lastIndexOf("/");
                    var parentFolder = (lastSlash <= 0) ? "/" : normPath.substring(0, lastSlash + 1);
                    if (currentPath !== parentFolder) {
                        currentPath = parentFolder;
                        hoveredSector = null;
                        selectedSector = null;
                        refreshData();
                    }

                    if (currentData) {
                        var found = null;
                        var r1 = currentData.ring1 || [];
                        for (var i = 0; i < r1.length; ++i) {
                            if (r1[i].path === normPath || r1[i].path === itemPath) {
                                found = r1[i];
                                break;
                            }
                        }
                        if (!found && currentData.ring2) {
                            var r2 = currentData.ring2;
                            for (var j = 0; j < r2.length; ++j) {
                                if (r2[j].path === normPath || r2[j].path === itemPath) {
                                    found = r2[j];
                                    break;
                                }
                            }
                        }
                        selectedSector = found;
                        sunburstCanvas.requestPaint();
                    }
                }
            }

            Component.onCompleted: {
                refreshData();
            }

            Connections {
                target: (typeof archiveInterface !== "undefined" && archiveInterface) ? archiveInterface : null
                function onArchiveTreeChanged() {
                    sunburstCard.refreshData();
                }
                function onArchiveLoadedChanged() {
                    sunburstCard.currentPath = "/";
                    sunburstCard.refreshData();
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                // Header Row: Title, Breadcrumb Pills, Reset to Root Button
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        spacing: 6
                        Text {
                            text: "\ue880" // analytics / pie
                            font.family: materialIcons.name
                            font.pixelSize: 16
                            color: Colors.goldPrimary
                        }
                        Text {
                            text: "RADIAL FILE MAP"
                            font.family: Colors.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: Colors.goldPrimary
                        }
                    }

                    // Breadcrumbs Flow / Row
                    Flickable {
                        id: breadcrumbFlickable
                        Layout.fillWidth: true
                        Layout.preferredHeight: 22
                        contentWidth: breadcrumbRow.implicitWidth
                        contentHeight: 22
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true

                        RowLayout {
                            id: breadcrumbRow
                            spacing: 4

                            Repeater {
                                model: (sunburstCard.currentData && sunburstCard.currentData.breadcrumbs) ? sunburstCard.currentData.breadcrumbs : []

                                Rectangle {
                                    implicitWidth: bText.implicitWidth + 12
                                    implicitHeight: 20
                                    radius: 4
                                    color: bMouse.containsMouse ? Colors.bgHover : (index === (sunburstCard.currentData.breadcrumbs.length - 1) ? Colors.goldLight : "transparent")
                                    border.color: index === (sunburstCard.currentData.breadcrumbs.length - 1) ? Colors.goldBorderHi : Colors.goldBorder
                                    border.width: 1

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 3
                                        Text {
                                            visible: index === 0
                                            text: "\ue88a" // home
                                            font.family: materialIcons.name
                                            font.pixelSize: 10
                                            color: Colors.goldPrimary
                                        }
                                        Text {
                                            id: bText
                                            text: modelData.name
                                            font.family: Colors.fontFamily
                                            font.pixelSize: 9
                                            font.weight: index === (sunburstCard.currentData.breadcrumbs.length - 1) ? Font.Bold : Font.Normal
                                            color: index === (sunburstCard.currentData.breadcrumbs.length - 1) ? Colors.goldHover : Colors.textMuted
                                        }
                                    }

                                    MouseArea {
                                        id: bMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            sunburstCard.drillDown(modelData.path);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Reset / Up Button
                    Rectangle {
                        visible: sunburstCard.currentPath !== "/" && sunburstCard.currentPath !== ""
                        implicitWidth: 22
                        implicitHeight: 22
                        radius: 4
                        color: upMouse.containsMouse ? Colors.bgHover : Colors.bgInput
                        border.color: Colors.goldBorder
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "\ue5d8" // arrow_upward
                            font.family: materialIcons.name
                            font.pixelSize: 13
                            color: Colors.goldPrimary
                        }

                        MouseArea {
                            id: upMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sunburstCard.zoomOut()
                        }
                    }
                }

                // Main Center Area: Sunburst Canvas
                Item {
                    id: canvasContainer
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 150

                    Canvas {
                        id: sunburstCanvas
                        anchors.fill: parent
                        renderStrategy: Canvas.Threaded
                        antialiasing: true

                        onPaint: {
                            var ctx = getContext("2d");
                            if (typeof ctx.reset === "function") {
                                ctx.reset();
                            } else if (typeof ctx.resetTransform === "function") {
                                ctx.resetTransform();
                            }
                            ctx.clearRect(0, 0, width, height);

                            var data = sunburstCard.currentData;
                            if (!data || !data.hub) {
                                return;
                            }

                            var cx = width / 2;
                            var cy = height / 2;
                            var maxR = Math.min(cx, cy) - 6;
                            if (maxR < 30) return;

                            var r0 = maxR * 0.32; // Center hub radius
                            var r1 = maxR * 0.36; // Ring 1 inner
                            var r2 = maxR * 0.65; // Ring 1 outer
                            var r3 = maxR * 0.69; // Ring 2 inner
                            var r4 = maxR * 0.98; // Ring 2 outer

                            var toRad = function(deg) {
                                return (deg - 90) * Math.PI / 180;
                            };

                            // --- 1. Draw Ring 2 (Grandchildren) ---
                            var r2Items = data.ring2 || [];
                            for (var j = 0; j < r2Items.length; ++j) {
                                var it2 = r2Items[j];
                                var sweep2 = it2.sweepAngle;
                                if (sweep2 <= 0.05) continue;
                                var gap2 = Math.min(0.35, sweep2 * 0.15);
                                var sA2 = toRad(it2.startAngle + gap2);
                                var eA2 = toRad(it2.endAngle - gap2);

                                var isHov2 = (sunburstCard.hoveredSector && sunburstCard.hoveredSector.path === it2.path);
                                var isSel2 = (sunburstCard.selectedSector && sunburstCard.selectedSector.path === it2.path);

                                ctx.beginPath();
                                ctx.arc(cx, cy, r4, sA2, eA2, false);
                                ctx.arc(cx, cy, r3, eA2, sA2, true);
                                ctx.closePath();

                                var baseColor2 = it2.color || "#64748B";
                                if (isHov2 || isSel2) {
                                    ctx.fillStyle = baseColor2;
                                    ctx.strokeStyle = "#ffffff";
                                    ctx.lineWidth = 1.5;
                                } else {
                                    ctx.fillStyle = Qt.rgba(Qt.color(baseColor2).r, Qt.color(baseColor2).g, Qt.color(baseColor2).b, 0.45);
                                    ctx.strokeStyle = Qt.rgba(0, 0, 0, 0.3);
                                    ctx.lineWidth = 0.5;
                                }
                                ctx.fill();
                                ctx.stroke();
                            }

                            // --- 2. Draw Ring 1 (Direct Children) ---
                            var r1Items = data.ring1 || [];
                            for (var i = 0; i < r1Items.length; ++i) {
                                var it1 = r1Items[i];
                                var sweep1 = it1.sweepAngle;
                                if (sweep1 <= 0.05) continue;
                                var gap1 = Math.min(0.45, sweep1 * 0.15);
                                var sA1 = toRad(it1.startAngle + gap1);
                                var eA1 = toRad(it1.endAngle - gap1);

                                var isHov1 = (sunburstCard.hoveredSector && sunburstCard.hoveredSector.path === it1.path);
                                var isSel1 = (sunburstCard.selectedSector && sunburstCard.selectedSector.path === it1.path);

                                ctx.beginPath();
                                ctx.arc(cx, cy, r2, sA1, eA1, false);
                                ctx.arc(cx, cy, r1, eA1, sA1, true);
                                ctx.closePath();

                                var baseColor1 = it1.color || "#D4AF37";
                                if (isHov1 || isSel1) {
                                    ctx.fillStyle = baseColor1;
                                    ctx.strokeStyle = "#ffffff";
                                    ctx.lineWidth = 2.0;
                                } else {
                                    ctx.fillStyle = Qt.rgba(Qt.color(baseColor1).r, Qt.color(baseColor1).g, Qt.color(baseColor1).b, 0.75);
                                    ctx.strokeStyle = Qt.rgba(0, 0, 0, 0.4);
                                    ctx.lineWidth = 1.0;
                                }
                                ctx.fill();
                                ctx.stroke();
                            }

                            // --- 3. Draw Center Hub ---
                            var isHubHov = sunburstCard.hoveredSector && sunburstCard.hoveredSector.path === data.hub.path;
                            ctx.beginPath();
                            ctx.arc(cx, cy, r0, 0, Math.PI * 2, false);
                            ctx.closePath();

                            var hubGrad = ctx.createRadialGradient(cx, cy, 5, cx, cy, r0);
                            hubGrad.addColorStop(0.0, isHubHov ? Qt.rgba(0.83, 0.69, 0.22, 0.25) : (Colors.isDarkMode ? "#171a24" : "#f1f3f9"));
                            hubGrad.addColorStop(1.0, Colors.isDarkMode ? "#0d0f15" : "#e5e8f0");
                            ctx.fillStyle = hubGrad;
                            ctx.fill();

                            ctx.strokeStyle = isHubHov ? Colors.goldHover : Colors.goldBorder;
                            ctx.lineWidth = isHubHov ? 2.0 : 1.0;
                            ctx.stroke();
                        }
                    }

                    // Center Hub HTML/QML Overlays (Icon, Name, Formatted Size, Savings)
                    Item {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) * 0.30
                        height: width
                        clip: true

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 1

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: (sunburstCard.currentData && sunburstCard.currentData.hub && sunburstCard.currentData.hub.parentPath !== "") ? "\ue5d8" : "\ue2c7"
                                font.family: materialIcons.name
                                font.pixelSize: 14
                                color: Colors.goldPrimary
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: (sunburstCard.currentData && sunburstCard.currentData.hub) ? sunburstCard.currentData.hub.name : "Archive"
                                font.family: Colors.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: Colors.textMain
                                elide: Text.ElideMiddle
                                Layout.maximumWidth: parent.width - 8
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: (sunburstCard.currentData && sunburstCard.currentData.hub) ? sunburstCard.currentData.hub.formattedSize : "0 B"
                                font.family: Colors.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                color: Colors.goldHover
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                visible: sunburstCard.currentPath !== "/"
                                text: "Click to zoom out"
                                font.family: Colors.fontFamily
                                font.pixelSize: 7
                                color: Colors.textSubtle
                            }
                        }
                    }

                    // Interactive Hit-Testing MouseArea
                    MouseArea {
                        id: canvasMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.ArrowCursor

                        function hitTest(mx, my) {
                            var data = sunburstCard.currentData;
                            if (!data || !data.hub) return null;

                            var cx = width / 2;
                            var cy = height / 2;
                            var dx = mx - cx;
                            var dy = my - cy;
                            var dist = Math.sqrt(dx * dx + dy * dy);

                            var maxR = Math.min(cx, cy) - 6;
                            var r0 = maxR * 0.32;
                            var r1 = maxR * 0.36;
                            var r2 = maxR * 0.65;
                            var r3 = maxR * 0.69;
                            var r4 = maxR * 0.98;

                            if (dist <= r0) {
                                return { type: "hub", item: data.hub };
                            }

                            // Calculate angle in degrees [0..360] where 0 is 12 o'clock
                            var rad = Math.atan2(dy, dx);
                            var deg = (rad * 180 / Math.PI) + 90;
                            if (deg < 0) deg += 360;
                            if (deg >= 360) deg -= 360;

                            if (dist >= r1 && dist <= r2 && data.ring1) {
                                for (var i = 0; i < data.ring1.length; ++i) {
                                    var it1 = data.ring1[i];
                                    if (deg >= it1.startAngle && deg <= it1.endAngle) {
                                        return { type: "ring1", item: it1 };
                                    }
                                }
                            }

                            if (dist >= r3 && dist <= r4 && data.ring2) {
                                for (var j = 0; j < data.ring2.length; ++j) {
                                    var it2 = data.ring2[j];
                                    if (deg >= it2.startAngle && deg <= it2.endAngle) {
                                        return { type: "ring2", item: it2 };
                                    }
                                }
                            }

                            return null;
                        }

                        onPositionChanged: (mouse) => {
                            var hit = hitTest(mouse.x, mouse.y);
                            if (hit) {
                                if (hit.type === "hub") {
                                    canvasMouse.cursorShape = (sunburstCard.currentPath !== "/") ? Qt.PointingHandCursor : Qt.ArrowCursor;
                                    sunburstCard.hoveredSector = hit.item;
                                } else {
                                    canvasMouse.cursorShape = (hit.item.isFolder && !hit.item.isOther) ? Qt.PointingHandCursor : Qt.ArrowCursor;
                                    sunburstCard.hoveredSector = hit.item;
                                }
                            } else {
                                canvasMouse.cursorShape = Qt.ArrowCursor;
                                sunburstCard.hoveredSector = null;
                            }
                            sunburstCanvas.requestPaint();
                        }

                        onExited: {
                            sunburstCard.hoveredSector = null;
                            canvasMouse.cursorShape = Qt.ArrowCursor;
                            sunburstCanvas.requestPaint();
                        }

                        onClicked: (mouse) => {
                            var hit = hitTest(mouse.x, mouse.y);
                            if (!hit) return;

                            if (hit.type === "hub") {
                                if (sunburstCard.currentPath !== "/") {
                                    sunburstCard.zoomOut();
                                }
                            } else if (hit.item.isFolder && !hit.item.isOther) {
                                sunburstCard.drillDown(hit.item.path);
                            } else {
                                sunburstCard.selectedSector = hit.item;
                                if (hit.item && hit.item.path && !hit.item.isOther) {
                                    root.notifyNavigation(hit.item.path, false);
                                }
                            }
                        }
                    }
                }

                // Inspector Card Below Donut
                Rectangle {
                    id: inspectorCard
                    Layout.fillWidth: true
                    implicitHeight: 78
                    radius: 8
                    color: Colors.bgCard
                    border.color: (sunburstCard.activeItem && sunburstCard.activeItem.color) ? sunburstCard.activeItem.color : Colors.goldBorder
                    border.width: 1

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 4
                        radius: 2
                        color: (sunburstCard.activeItem && sunburstCard.activeItem.color) ? sunburstCard.activeItem.color : Colors.goldPrimary
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        anchors.topMargin: 7
                        anchors.bottomMargin: 7
                        spacing: 5

                        // Row 1: Item Name, Path & Badge
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: (sunburstCard.activeItem && sunburstCard.activeItem.color) ? sunburstCard.activeItem.color : Colors.goldPrimary
                            }

                            Text {
                                text: sunburstCard.activeItem ? sunburstCard.activeItem.name : "Root Archive"
                                font.family: Colors.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: Colors.textMain
                                elide: Text.ElideRight
                                Layout.maximumWidth: 320
                            }

                            Text {
                                text: {
                                    if (!sunburstCard.activeItem) return "";
                                    if (sunburstCard.activeItem.isOther) return "[OTHER MERGED]";
                                    if (sunburstCard.activeItem.isFolder) {
                                        var fc = sunburstCard.activeItem.fileCount || 0;
                                        return "[" + fc + " FILES]";
                                    }
                                    return "[FILE]";
                                }
                                font.family: Colors.fontFamily
                                font.pixelSize: 8
                                font.weight: Font.Bold
                                color: Colors.textMuted
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                visible: sunburstCard.activeItem && sunburstCard.activeItem.isFolder && !sunburstCard.activeItem.isOther
                                text: "Click sector to drill down"
                                font.family: Colors.fontFamily
                                font.pixelSize: 8
                                color: Colors.goldHover
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Colors.divider
                        }

                        // Row 2: 4 Strict Metrics
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            // Col 1: Space Savings
                            ColumnLayout {
                                spacing: 1
                                Layout.fillWidth: true
                                Text {
                                    text: "SPACE SAVINGS"
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 8
                                    color: Colors.textMuted
                                    font.weight: Font.Bold
                                }
                                Text {
                                    text: {
                                        if (!sunburstCard.activeItem || sunburstCard.activeItem.savings === undefined) return "0.0%";
                                        return Number(sunburstCard.activeItem.savings).toFixed(1) + "%";
                                    }
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: (sunburstCard.activeItem && sunburstCard.activeItem.color) ? sunburstCard.activeItem.color : Colors.textMain
                                }
                            }

                            // Col 2: Size (Raw / Comp)
                            ColumnLayout {
                                spacing: 1
                                Layout.fillWidth: true
                                Text {
                                    text: "SIZE (RAW / COMP)"
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 8
                                    color: Colors.textMuted
                                    font.weight: Font.Bold
                                }
                                Text {
                                    text: sunburstCard.activeItem ? (sunburstCard.activeItem.formattedSize + " / " + sunburstCard.activeItem.formattedCompSize) : "0 B / 0 B"
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: Colors.textMain
                                }
                            }

                            // Col 3: Share of Directory
                            ColumnLayout {
                                spacing: 1
                                Layout.fillWidth: true
                                Text {
                                    text: "SHARE OF FOLDER"
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 8
                                    color: Colors.textMuted
                                    font.weight: Font.Bold
                                }
                                Text {
                                    text: {
                                        if (!sunburstCard.activeItem || sunburstCard.activeItem.sharePercent === undefined) return "100.0%";
                                        return Number(sunburstCard.activeItem.sharePercent).toFixed(1) + "%";
                                    }
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 10
                                    color: Colors.textMain
                                }
                            }

                            // Col 4: CRC32 / Count
                            ColumnLayout {
                                spacing: 1
                                Layout.preferredWidth: 105
                                Text {
                                    text: (sunburstCard.activeItem && !sunburstCard.activeItem.isFolder && !sunburstCard.activeItem.isOther) ? "CRC-32" : "FOLDER COUNT"
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 8
                                    color: Colors.textMuted
                                    font.weight: Font.Bold
                                }
                                RowLayout {
                                    spacing: 4
                                    Text {
                                        text: {
                                            if (!sunburstCard.activeItem) return "N/A";
                                            if (sunburstCard.activeItem.isFolder) {
                                                return (sunburstCard.activeItem.folderCount || 0) + " folders";
                                            }
                                            return sunburstCard.activeItem.crc32 || "N/A";
                                        }
                                        font.family: (sunburstCard.activeItem && !sunburstCard.activeItem.isFolder) ? "Consolas, Segoe UI, monospace" : Colors.fontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: Colors.goldPrimary
                                    }
                                    Rectangle {
                                        visible: sunburstCard.activeItem && !sunburstCard.activeItem.isFolder && !sunburstCard.activeItem.isOther && sunburstCard.activeItem.crc32 && sunburstCard.activeItem.crc32 !== "N/A"
                                        width: 16
                                        height: 16
                                        radius: 3
                                        color: copyMouse.containsMouse ? Colors.bgHover : "transparent"
                                        border.color: Colors.goldBorder
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: sunburstCard.copyFeedback ? "\ue877" : "\ue14d"
                                            font.family: materialIcons.name
                                            font.pixelSize: 10
                                            color: sunburstCard.copyFeedback ? "#4ade80" : Colors.goldPrimary
                                        }

                                        MouseArea {
                                            id: copyMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (sunburstCard.activeItem && sunburstCard.activeItem.crc32) {
                                                    sunburstCard.copyToClipboard(sunburstCard.activeItem.crc32);
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
        }

        // ==========================================
        // --- Compression Settings & Actions Box ---
        // ==========================================
        Rectangle {
            id: compSettingsBox
            Layout.fillWidth: true
            implicitHeight: compSettingsCol.implicitHeight + 18
            color: Colors.bgCard
            radius: 10
            border.color: root.hasSettingsChanges ? Colors.goldBorderHi : Colors.goldBorder
            border.width: 1
            visible: root.hasActiveArchive

            ColumnLayout {
                id: compSettingsCol
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                // Header Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "\ue871" // view_quilt
                        font.family: materialIcons.name
                        font.pixelSize: 15
                        color: Colors.goldPrimary
                    }

                    Text {
                        text: "COMPRESSION OPTIONS"
                        font.family: Colors.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: Colors.goldPrimary
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        implicitWidth: 76
                        implicitHeight: 18
                        radius: 4
                        color: Colors.goldLight
                        border.color: Colors.goldBorderHi
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "LZMA2 / ZSTD"
                            font.family: Colors.fontFamily
                            font.pixelSize: 8
                            font.weight: Font.Bold
                            color: Colors.goldHover
                        }
                    }
                }

                // Segmented Toggle
                TripleToggle {
                    id: compToggle
                    Layout.fillWidth: true
                    currentIndex: Math.max(0, Math.min(2, root.pendingCompressionLevel - 1))
                    options: ["Fast (Store)", "Balanced", "Ultra"]
                    onSelected: (idx) => {
                        root.pendingCompressionLevel = idx + 1;
                    }
                    Binding on currentIndex {
                        value: Math.max(0, Math.min(2, root.pendingCompressionLevel - 1))
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Colors.divider
                }

                // Options row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    GoldSwitch {
                        text: "Preserve Attributes & Timestamps"
                        checked: root.pendingPreserveMetadata
                        Layout.fillWidth: true
                        onToggled: (isChecked) => {
                            root.pendingPreserveMetadata = isChecked;
                        }
                    }
                }

                // Action Buttons: Cancel & Save Settings
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 8

                    // Feedback Indicator
                    RowLayout {
                        spacing: 4
                        visible: root.settingsSavedFeedback

                        Text {
                            text: "\ue877" // check_circle
                            font.family: materialIcons.name
                            font.pixelSize: 13
                            color: "#4ade80"
                        }
                        Text {
                            text: "Settings Saved"
                            font.family: Colors.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: "#4ade80"
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Cancel Button
                    Rectangle {
                        implicitWidth: 80
                        implicitHeight: 28
                        radius: 5
                        color: cancelSettingsMouse.containsMouse ? Colors.bgHover : "transparent"
                        border.color: root.hasSettingsChanges ? Colors.goldBorder : Colors.borderSubtle
                        border.width: 1
                        opacity: root.hasSettingsChanges ? 1.0 : 0.5

                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            font.family: Colors.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: Colors.textMuted
                        }

                        MouseArea {
                            id: cancelSettingsMouse
                            anchors.fill: parent
                            enabled: root.hasSettingsChanges
                            hoverEnabled: true
                            cursorShape: root.hasSettingsChanges ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                root.reloadSettings();
                            }
                        }
                    }

                    // Save Button
                    Rectangle {
                        implicitWidth: 110
                        implicitHeight: 28
                        radius: 5
                        color: !root.hasSettingsChanges ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.06))
                             : saveSettingsMouse.containsPress ? Qt.darker(Colors.goldPrimary, 1.15)
                             : (saveSettingsMouse.containsMouse ? Colors.goldHover : Colors.goldPrimary)
                        border.color: root.hasSettingsChanges ? Colors.goldBorderHi : Colors.borderSubtle
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: "\ue161" // save
                                font.family: materialIcons.name
                                font.pixelSize: 13
                                color: root.hasSettingsChanges ? Colors.textOnGold : Colors.textSubtle
                            }

                            Text {
                                text: "Save Settings"
                                font.family: Colors.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: root.hasSettingsChanges ? Colors.textOnGold : Colors.textSubtle
                            }
                        }

                        MouseArea {
                            id: saveSettingsMouse
                            anchors.fill: parent
                            enabled: root.hasSettingsChanges
                            hoverEnabled: true
                            cursorShape: root.hasSettingsChanges ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (typeof archiveInterface !== "undefined" && archiveInterface) {
                                    // Strictly validate compression level int (1: Fast, 2: Balanced, 3: Ultra) before queuing job
                                    if (root.pendingCompressionLevel >= 1 && root.pendingCompressionLevel <= 3) {
                                        archiveInterface.addCompressionLevelJob(root.pendingCompressionLevel);
                                    }
                                    archiveInterface.setPreserveMetadata(root.pendingPreserveMetadata);
                                    root.settingsSavedFeedback = true;
                                    settingsFeedbackTimer.restart();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
