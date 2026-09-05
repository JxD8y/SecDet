import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UI

Item {
    id: root

    // =========================================================================
    // --- Configurable Status Colors (Separated at the top for easy modification) ---
    // =========================================================================
    property color colorIdle:     Colors.isDarkMode ? "#64748b" : "#94a3b8"  // Slate / Idle
    property color colorPending:  Colors.isDarkMode ? "#818cf8" : "#6366f1"  // Indigo / Queued
    property color colorRunning:  Colors.isDarkMode ? "#22c55e" : "#16a34a"  // Emerald Green / Running
    property color colorPaused:   Colors.isDarkMode ? "#f59e0b" : "#d97706"  // Amber / Paused
    property color colorAborted:  Colors.isDarkMode ? "#f97316" : "#ea580c"  // Orange / Aborted
    property color colorFailed:   Colors.isDarkMode ? "#ef4444" : "#dc2626"  // Crimson / Error
    property color colorFinished: Colors.isDarkMode ? "#0ea5e9" : "#0284c7"  // Sky Blue / Completed

    // Sleeker, reduced height for a refined Fluent status bar aesthetic
    implicitHeight: 34
    Layout.fillWidth: true
    Layout.preferredHeight: 34

    // Sizing constants
    property real runningWeight: 2.6
    property real normalWeight: 1.0
    property real minNormalWidth: 48
    property real minRunningWidth: 180

    // Simulation toggle (advances progress for demo purposes)
    property bool simulationActive: true

    FontLoader {
        id: materialIcons
        source: "Fonts/MaterialIconsRound-Regular.otf"
    }

    // =========================================================================
    // --- Data Model for Jobs ---
    // =========================================================================
    ListModel {
        id: jobModel

        ListElement {
            name: "Job #1 • Encrypting Vault"
            state: "running"
            progress: 0.68
            detail: "Writing payload: 142.5 MB / 340 MB"
        }
        ListElement {
            name: "Job #2 • Tree Structure"
            state: "finished"
            progress: 1.0
            detail: "32 files processed successfully"
        }
        ListElement {
            name: "Job #3 • SHA-256 Checksum"
            state: "paused"
            progress: 0.45
            detail: "Paused by user (chunk 45/100)"
        }
        ListElement {
            name: "Job #4 • Compressing Media"
            state: "pending"
            progress: 0.0
            detail: "Waiting for queue position"
        }
        ListElement {
            name: "Job #5 • Index Sync"
            state: "failed"
            progress: 0.22
            detail: "CRC32 checksum mismatch (0x9A4F)"
        }
    }

    // =========================================================================
    // --- Helper Functions & State Resolution ---
    // =========================================================================
    function getStatusColor(state) {
        switch (state) {
            case "idle":     return colorIdle;
            case "pending":  return colorPending;
            case "running":  return colorRunning;
            case "paused":   return colorPaused;
            case "aborted":  return colorAborted;
            case "failed":   return colorFailed;
            case "finished": return colorFinished;
            default:         return colorIdle;
        }
    }

    function getStatusIcon(state) {
        switch (state) {
            case "idle":     return "\ue836"; // radio_button_unchecked
            case "pending":  return "\ue8b5"; // schedule / clock
            case "running":  return "\ue037"; // play_arrow
            case "paused":   return "\ue034"; // pause
            case "aborted":  return "\ue5c9"; // cancel
            case "failed":   return "\ue000"; // error
            case "finished": return "\ue86c"; // check_circle
            default:         return "\ue836";
        }
    }

    function getStatusLabel(state) {
        switch (state) {
            case "idle":     return "Idle";
            case "pending":  return "Pending";
            case "running":  return "Running";
            case "paused":   return "Paused";
            case "aborted":  return "Aborted";
            case "failed":   return "Failed";
            case "finished": return "Finished";
            default:         return state;
        }
    }

    // Aggregate state for the overall structure border:
    // Priority: failed > aborted > running > paused > finished > idle
    readonly property string overallState: {
        var count = jobModel.count;
        if (count === 0) return "idle";

        var hasRunning = false;
        var hasPaused = false;
        var hasAborted = false;
        var hasFailed = false;
        var allFinished = true;

        var checkLimit = Math.min(count, 100);
        for (var i = 0; i < checkLimit; ++i) {
            var item = jobModel.get(i);
            var s = item.state;
            if (s === "failed") hasFailed = true;
            if (s === "aborted") hasAborted = true;
            if (s === "running") hasRunning = true;
            if (s === "paused") hasPaused = true;
            if (s !== "finished") allFinished = false;
        }

        if (hasFailed) return "failed";
        if (hasAborted) return "aborted";
        if (hasRunning) return "running";
        if (hasPaused) return "paused";
        if (allFinished) return "finished";
        return "idle";
    }

    readonly property color overallBorderColor: {
        switch (overallState) {
            case "failed":   return colorFailed;
            case "aborted":  return colorAborted;
            case "running":  return colorRunning;
            case "paused":   return colorPaused;
            case "finished": return colorFinished;
            default:         return Colors.goldBorder;
        }
    }

    // Can all parts fit inside the container without scrolling?
    readonly property bool canFitAll: {
        var count = jobModel.count;
        if (count <= 0) return true;
        if (count > 20) return false; // Early exit for performance

        var mw = 0;
        for (var i = 0; i < count; ++i) {
            var s = jobModel.get(i).state;
            mw += (s === "running" ? minRunningWidth : minNormalWidth);
        }
        return mw <= containerRect.width;
    }

    property real totalWeight: {
        var tw = 0;
        var count = jobModel.count;
        if (count > 20) return 1.0;
        for (var i = 0; i < count; ++i) {
            var s = jobModel.get(i).state;
            tw += (s === "running" ? runningWeight : normalWeight);
        }
        return Math.max(1.0, tw);
    }

    // Calculate individual delegate width
    function getDelegateWidth(index, state) {
        var count = jobModel.count;
        if (count <= 0) return 0;

        if (canFitAll) {
            var w = (state === "running" ? runningWeight : normalWeight);
            var portion = (w / totalWeight) * containerRect.width;
            return Math.max(minNormalWidth, portion);
        } else {
            return (state === "running" ? minRunningWidth : minNormalWidth);
        }
    }

    // -------------------------------------------------------------------------
    // --- ToolTip Display & Seek Functionality ---
    // -------------------------------------------------------------------------
    function getJobCenterX(targetIdx) {
        if (targetIdx < 0 || targetIdx >= jobModel.count) return containerRect.width / 2;

        if (canFitAll) {
            var accX = 0;
            for (var i = 0; i < targetIdx; ++i) {
                accX += getDelegateWidth(i, jobModel.get(i).state);
            }
            var itemW = getDelegateWidth(targetIdx, jobModel.get(targetIdx).state);
            return accX + itemW / 2;
        } else {
            var visualAccumX = 0;
            for (var j = 0; j < targetIdx; ++j) {
                visualAccumX += getDelegateWidth(j, jobModel.get(j).state);
            }
            var widthAtIdx = getDelegateWidth(targetIdx, jobModel.get(targetIdx).state);
            var screenX = visualAccumX - jobListView.contentX;
            return Math.max(80, Math.min(containerRect.width - 80, screenX + widthAtIdx / 2));
        }
    }

    function triggerRunningToolTip(index) {
        if (index < 0 || index >= jobModel.count) return;

        // Hide previous tooltip first
        activeToolTip.close();
        toolTipTimer.stop();

        // Update data
        var item = jobModel.get(index);
        activeToolTip.targetIndex = index;
        activeToolTip.jobName = item.name;
        activeToolTip.jobState = item.state;
        activeToolTip.jobProgress = item.progress;
        activeToolTip.jobDetail = item.detail || "";

        // Open and schedule 5-second auto-close
        activeToolTip.open();
        toolTipTimer.restart();
    }

    function seekToRunningJob() {
        var runningIdx = -1;
        for (var i = 0; i < jobModel.count; ++i) {
            if (jobModel.get(i).state === "running") {
                runningIdx = i;
                break;
            }
        }
        if (runningIdx !== -1) {
            if (!root.canFitAll) {
                jobListView.positionViewAtIndex(runningIdx, ListView.Center);
            }
            triggerRunningToolTip(runningIdx);
        }
    }

    // Public helper methods
    function addJob(name, state, progress, detail) {
        var isNewRunning = (state === "running");
        jobModel.append({
            name: name || ("Job #" + (jobModel.count + 1)),
            state: state || "pending",
            progress: progress !== undefined ? progress : 0.0,
            detail: detail || "Added to queue"
        });
        if (isNewRunning) {
            triggerRunningToolTip(jobModel.count - 1);
        }
    }

    function removeJob(index) {
        if (index >= 0 && index < jobModel.count) {
            if (activeToolTip.targetIndex === index) {
                activeToolTip.close();
                toolTipTimer.stop();
            }
            jobModel.remove(index);
        }
    }

    function pauseJob(index) {
        if (index >= 0 && index < jobModel.count) {
            jobModel.setProperty(index, "state", "paused");
            if (activeToolTip.targetIndex === index) {
                activeToolTip.close();
                toolTipTimer.stop();
            }
        }
    }

    function resumeJob(index) {
        if (index >= 0 && index < jobModel.count) {
            jobModel.setProperty(index, "state", "running");
            triggerRunningToolTip(index);
        }
    }

    function retryJob(index) {
        if (index >= 0 && index < jobModel.count) {
            jobModel.setProperty(index, "state", "running");
            jobModel.setProperty(index, "progress", 0.05);
            triggerRunningToolTip(index);
        }
    }

    function benchmark1000Jobs() {
        jobModel.clear();
        for (var i = 1; i <= 1000; ++i) {
            var st = "pending";
            var pr = 0.0;
            if (i === 1) {
                st = "running";
                pr = 0.62;
            } else if (i <= 40) {
                st = "finished";
                pr = 1.0;
            } else if (i === 41 || i === 42) {
                st = "paused";
                pr = 0.35;
            } else if (i === 43) {
                st = "failed";
                pr = 0.15;
            } else if (i === 44) {
                st = "aborted";
                pr = 0.08;
            }

            jobModel.append({
                name: "Job #" + i + " • Stream_Data_" + (i < 10 ? "00" : (i < 100 ? "0" : "")) + i + ".bin",
                state: st,
                progress: pr,
                detail: "Archive batch item " + i + " of 1000"
            });
        }
        jobListView.contentX = 0;
        jobListView.positionViewAtIndex(0, ListView.Beginning);
        triggerRunningToolTip(0);
    }

    function resetDefaultJobs() {
        jobModel.clear();
        jobModel.append({ name: "Job #1 • Encrypting Vault", state: "running", progress: 0.68, detail: "Writing payload: 142.5 MB / 340 MB" });
        jobModel.append({ name: "Job #2 • Tree Structure", state: "finished", progress: 1.0, detail: "32 files processed successfully" });
        jobModel.append({ name: "Job #3 • SHA-256 Checksum", state: "paused", progress: 0.45, detail: "Paused by user (chunk 45/100)" });
        jobModel.append({ name: "Job #4 • Compressing Media", state: "pending", progress: 0.0, detail: "Waiting for queue position" });
        jobModel.append({ name: "Job #5 • Index Sync", state: "failed", progress: 0.22, detail: "CRC32 checksum mismatch (0x9A4F)" });
        jobListView.contentX = 0;
        jobListView.positionViewAtIndex(0, ListView.Beginning);
        triggerRunningToolTip(0);
    }

    Component.onCompleted: {
        triggerRunningToolTip(0);
    }

    // =========================================================================
    // --- Live Demo Progress Simulator ---
    // =========================================================================
    Timer {
        id: simTimer
        interval: 750
        running: root.simulationActive && root.visible
        repeat: true
        onTriggered: {
            for (var i = 0; i < jobModel.count; ++i) {
                var item = jobModel.get(i);
                if (item.state === "running") {
                    if (item.progress < 0.98) {
                        jobModel.setProperty(i, "progress", Math.min(1.0, item.progress + 0.02));
                    } else {
                        jobModel.setProperty(i, "progress", 1.0);
                        jobModel.setProperty(i, "state", "finished");
                        for (var j = 0; j < jobModel.count; ++j) {
                            if (jobModel.get(j).state === "pending") {
                                jobModel.setProperty(j, "state", "running");
                                jobModel.setProperty(j, "progress", 0.04);
                                root.triggerRunningToolTip(j);
                                break;
                            }
                        }
                    }
                    break;
                }
            }
        }
    }

    // Timer to auto-hide tooltip after 5 seconds
    Timer {
        id: toolTipTimer
        interval: 5000
        repeat: false
        onTriggered: {
            activeToolTip.close();
        }
    }

    // =========================================================================
    // --- Outer Multi-Part Progress Container ---
    // =========================================================================
    Rectangle {
        id: containerRect
        anchors.fill: parent
        radius: 6
        color: Colors.bgSurface
        border.color: root.overallBorderColor
        border.width: root.overallState === "running" ? 1.5 : 1.0
        clip: true

        Behavior on border.color {
            ColorAnimation { duration: 250 }
        }

        SequentialAnimation on border.width {
            running: root.overallState === "running"
            loops: Animation.Infinite
            NumberAnimation { to: 2.0; duration: 900; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 1.2; duration: 900; easing.type: Easing.InOutQuad }
        }

        // Empty state indicator if all jobs removed
        Item {
            anchors.fill: parent
            visible: jobModel.count === 0

            RowLayout {
                anchors.centerIn: parent
                spacing: 8
                Text {
                    text: "\ue88e" // info
                    font.family: materialIcons.name
                    font.pixelSize: 14
                    color: Colors.textMuted
                }
                Text {
                    text: "No active background jobs • Right-click to add jobs or run 1,000-job benchmark"
                    font.family: Colors.fontFamily
                    font.pixelSize: 11
                    color: Colors.textMuted
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onClicked: (mouse) => {
                    emptyMenu.popup(containerRect, mouse.x, mouse.y);
                }
            }
        }

        // =====================================================================
        // --- Virtualized Horizontal ListView for 1000+ Parts Efficiency ---
        // =====================================================================
        ListView {
            id: jobListView
            anchors.fill: parent
            anchors.margins: 1
            orientation: ListView.Horizontal
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            spacing: 0

            model: jobModel

            WheelHandler {
                onWheel: (event) => {
                    jobListView.contentX = Math.max(0, Math.min(jobListView.contentWidth - jobListView.width,
                                                                jobListView.contentX - event.angleDelta.y * 1.5));
                    if (activeToolTip.visible) {
                        activeToolTip.x = root.getJobCenterX(activeToolTip.targetIndex) - activeToolTip.width / 2;
                    }
                }
            }

            add: Transition {
                NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
            }

            remove: Transition {
                NumberAnimation { property: "opacity"; to: 0.0; duration: 180; easing.type: Easing.InQuad }
            }

            displaced: Transition {
                NumberAnimation { properties: "x"; duration: 220; easing.type: Easing.OutCubic }
            }

            delegate: Item {
                id: partDelegate
                height: jobListView.height
                width: root.getDelegateWidth(index, model.state)

                Behavior on width {
                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                }

                readonly property color stateColor: root.getStatusColor(model.state)
                readonly property bool isRunning: model.state === "running"
                readonly property bool isCompact: width < 120

                // 1. Part Base Background (unfilled track portion, no bottom border)
                Rectangle {
                    anchors.fill: parent
                    radius: 0
                    border.width: 0
                    color: Qt.rgba(partDelegate.stateColor.r,
                                   partDelegate.stateColor.g,
                                   partDelegate.stateColor.b,
                                   Colors.isDarkMode ? 0.16 : 0.10)
                }

                // 2. Part Progress Fill Layer (the progress bar itself, no bottom border)
                Rectangle {
                    id: progressFill
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    border.width: 0
                    radius: 0
                    width: Math.max(0, Math.min(parent.width, parent.width * model.progress))

                    color: partDelegate.stateColor

                    Behavior on width {
                        NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
                    }

                    // Active animated shimmer effect for running part
                    Rectangle {
                        id: shimmerRect
                        anchors.fill: parent
                        border.width: 0
                        radius: 0
                        visible: partDelegate.isRunning

                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.28) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }

                        SequentialAnimation on opacity {
                            running: partDelegate.isRunning
                            loops: Animation.Infinite
                            NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 0.2; duration: 600; easing.type: Easing.InOutQuad }
                        }
                    }
                }

                // 3. Soft blend transition to adjacent part on the right (eliminates solid harsh borders)
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 7
                    border.width: 0
                    visible: index < jobModel.count - 1

                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Colors.isDarkMode ? Qt.rgba(0, 0, 0, 0.28) : Qt.rgba(0, 0, 0, 0.08) }
                    }
                }

                // 4. Soft blend transition from adjacent part on the left
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 4
                    border.width: 0
                    visible: index > 0

                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Colors.isDarkMode ? Qt.rgba(0, 0, 0, 0.20) : Qt.rgba(0, 0, 0, 0.06) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                // 5. Hover Highlight Overlay
                Rectangle {
                    anchors.fill: parent
                    radius: 0
                    border.width: 0
                    color: partMouseArea.containsMouse
                           ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06))
                           : "transparent"

                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                // 6. Part Content (Job Identifier text + icon + percentage)
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: partDelegate.isCompact ? 4 : 7
                    anchors.rightMargin: partDelegate.isCompact ? 4 : 7
                    spacing: 4

                    // Status icon
                    Text {
                        text: root.getStatusIcon(model.state)
                        font.family: materialIcons.name
                        font.pixelSize: partDelegate.isCompact ? 12 : 13
                        color: Colors.textMain
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Full Job Name & Identifier
                    Text {
                        id: jobTitleText
                        text: model.name
                        font.family: Colors.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: Colors.textMain
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        visible: !partDelegate.isCompact
                    }

                    // Progress Percentage or compact job index
                    Text {
                        text: partDelegate.isCompact
                              ? "#" + (index + 1)
                              : Math.round(model.progress * 100) + "%"
                        font.family: Colors.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: partDelegate.isRunning
                               ? (Colors.isDarkMode ? "#ffffff" : "#14532d")
                               : Colors.textMain
                        Layout.alignment: Qt.AlignVCenter
                        Layout.rightMargin: 1
                    }
                }

                // 7. Interactive Mouse Area: Click, Double-Click (seek running job), & Context Menu
                MouseArea {
                    id: partMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor

                    onDoubleClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            root.seekToRunningJob();
                        }
                    }

                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            partMenu.targetIndex = index;
                            partMenu.targetName = model.name;
                            partMenu.targetState = model.state;
                            partMenu.targetProgress = model.progress;
                            partMenu.targetDetail = model.detail || "";
                            partMenu.popup(partMouseArea, mouse.x, mouse.y);
                        } else if (mouse.button === Qt.LeftButton) {
                            if (!root.canFitAll) {
                                jobListView.positionViewAtIndex(index, ListView.Center);
                            }
                            root.triggerRunningToolTip(index);
                        }
                    }
                }
            }
        }

        // =====================================================================
        // --- 4 Corner Cutout Masks (Canvas) ---
        // Guarantees zero pixels/borders of scrolling items ever bleed past the 6px rounded corners
        // =====================================================================
        Canvas {
            id: cornerMaskCanvas
            anchors.fill: parent
            z: 50
            antialiasing: true

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                var r = containerRect.radius;
                var w = width;
                var h = height;

                ctx.fillStyle = Colors.bgMain;

                // Top-Left Corner wedge
                ctx.beginPath();
                ctx.moveTo(0, 0);
                ctx.lineTo(r, 0);
                ctx.arc(r, r, r, -Math.PI / 2, Math.PI, true);
                ctx.closePath();
                ctx.fill();

                // Top-Right Corner wedge
                ctx.beginPath();
                ctx.moveTo(w, 0);
                ctx.lineTo(w, r);
                ctx.arc(w - r, r, r, 0, -Math.PI / 2, true);
                ctx.closePath();
                ctx.fill();

                // Bottom-Right Corner wedge
                ctx.beginPath();
                ctx.moveTo(w, h);
                ctx.lineTo(w - r, h);
                ctx.arc(w - r, h - r, r, Math.PI / 2, 0, true);
                ctx.closePath();
                ctx.fill();

                // Bottom-Left Corner wedge
                ctx.beginPath();
                ctx.moveTo(0, h);
                ctx.lineTo(0, h - r);
                ctx.arc(r, h - r, r, Math.PI, Math.PI / 2, true);
                ctx.closePath();
                ctx.fill();
            }

            Connections {
                target: Colors
                function onIsDarkModeChanged() { cornerMaskCanvas.requestPaint(); }
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }

        // Top Overlay Border Rectangle (sits on top of the corner masks to draw a crisp border)
        Rectangle {
            anchors.fill: parent
            radius: containerRect.radius
            color: "transparent"
            border.color: root.overallBorderColor
            border.width: root.overallState === "running" ? 1.5 : 1.0
            z: 60
        }
    }

    // =========================================================================
    // --- Unified Fluent ToolTip for Running / Selected Job (5s auto-hide) ---
    // =========================================================================
    ToolTip {
        id: activeToolTip
        parent: containerRect
        x: root.getJobCenterX(activeToolTip.targetIndex) - width / 2
        y: -height - 8
        timeout: -1

        property int targetIndex: -1
        property string jobName: ""
        property string jobState: ""
        property real jobProgress: 0.0
        property string jobDetail: ""

        contentItem: ColumnLayout {
            spacing: 3
            RowLayout {
                spacing: 6
                Rectangle {
                    width: 7; height: 7; radius: 3.5
                    color: root.getStatusColor(activeToolTip.jobState)
                }
                Text {
                    text: activeToolTip.jobName
                    font.family: Colors.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: Colors.textMain
                }
            }
            Text {
                text: root.getStatusLabel(activeToolTip.jobState) + " • " + Math.round(activeToolTip.jobProgress * 100) + "%"
                font.family: Colors.fontFamily
                font.pixelSize: 10
                font.weight: Font.Medium
                color: root.getStatusColor(activeToolTip.jobState)
            }
            Text {
                text: activeToolTip.jobDetail ? activeToolTip.jobDetail : "Running archive task"
                font.family: Colors.fontFamily
                font.pixelSize: 10
                color: Colors.textMuted
                visible: text.length > 0
            }
        }

        background: Rectangle {
            color: Colors.bgSurface
            radius: 8
            border.color: Colors.goldBorderHi
            border.width: 1
        }
    }

    // =========================================================================
    // --- Part Interactive Context Menu (Fluent SecDet Style, Compact & Pixel-Perfect) ---
    // =========================================================================
    Menu {
        id: partMenu
        property int targetIndex: -1
        property string targetName: ""
        property string targetState: ""
        property real targetProgress: 0.0
        property string targetDetail: ""

        implicitWidth: 210
        width: 210
        topPadding: 4
        bottomPadding: 4
        leftPadding: 4
        rightPadding: 4

        background: Rectangle {
            color: Colors.bgSurface
            radius: 8
            border.color: Colors.goldBorder
            border.width: 1
        }

        // Header Item (Job Title & Status)
        MenuItem {
            implicitWidth: 202
            implicitHeight: 38
            padding: 0
            leftPadding: 8
            rightPadding: 8
            topPadding: 4
            bottomPadding: 4
            indicator: null
            enabled: false

            contentItem: ColumnLayout {
                spacing: 2
                Text {
                    text: partMenu.targetName
                    font.family: Colors.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: Colors.textMain
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                RowLayout {
                    spacing: 5
                    Rectangle {
                        width: 6; height: 6; radius: 3
                        color: root.getStatusColor(partMenu.targetState)
                    }
                    Text {
                        text: root.getStatusLabel(partMenu.targetState) + " • " + Math.round(partMenu.targetProgress * 100) + "%"
                        font.family: Colors.fontFamily
                        font.pixelSize: 10
                        color: root.getStatusColor(partMenu.targetState)
                        Layout.fillWidth: true
                    }
                }
            }
            background: Rectangle {
                color: Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(0, 0, 0, 0.03)
                radius: 4
            }
        }

        MenuSeparator {
            topPadding: 2
            bottomPadding: 2
            leftPadding: 4
            rightPadding: 4
            contentItem: Rectangle {
                implicitHeight: 1
                color: Colors.divider
            }
        }

        // Action 1: Pause / Resume / Start / Retry
        MenuItem {
            id: pauseAction
            implicitWidth: 202
            implicitHeight: 28
            padding: 0
            leftPadding: 8
            rightPadding: 8
            topPadding: 0
            bottomPadding: 0
            indicator: null

            text: partMenu.targetState === "running"
                  ? "Pause Job"
                  : (partMenu.targetState === "paused" ? "Resume Job" : (partMenu.targetState === "failed" || partMenu.targetState === "aborted" ? "Retry Job" : "Start Job"))

            onTriggered: {
                if (partMenu.targetState === "running") {
                    root.pauseJob(partMenu.targetIndex);
                } else if (partMenu.targetState === "paused") {
                    root.resumeJob(partMenu.targetIndex);
                } else if (partMenu.targetState === "failed" || partMenu.targetState === "aborted") {
                    root.retryJob(partMenu.targetIndex);
                } else {
                    root.resumeJob(partMenu.targetIndex);
                }
            }

            contentItem: RowLayout {
                spacing: 8
                Text {
                    text: partMenu.targetState === "running"
                          ? "\ue034" // pause
                          : (partMenu.targetState === "paused" || partMenu.targetState === "pending" || partMenu.targetState === "idle" ? "\ue037" : "\ue5d5")
                    font.family: materialIcons.name
                    font.pixelSize: 15
                    color: pauseAction.hovered ? root.colorRunning : Colors.textMain
                    Layout.alignment: Qt.AlignVCenter
                }
                Text {
                    text: pauseAction.text
                    font.family: Colors.fontFamily
                    font.pixelSize: 11
                    color: pauseAction.hovered ? root.colorRunning : Colors.textMain
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            background: Rectangle {
                radius: 4
                color: pauseAction.hovered ? Colors.bgHover : "transparent"
            }
        }

        // Action 2: Remove Job (smooth removing animation, adjacent parts merge)
        MenuItem {
            id: removeAction
            implicitWidth: 202
            implicitHeight: 28
            padding: 0
            leftPadding: 8
            rightPadding: 8
            topPadding: 0
            bottomPadding: 0
            indicator: null

            text: "Remove Job"
            onTriggered: {
                root.removeJob(partMenu.targetIndex);
            }

            contentItem: RowLayout {
                spacing: 8
                Text {
                    text: "\ue872" // delete
                    font.family: materialIcons.name
                    font.pixelSize: 15
                    color: removeAction.hovered ? root.colorFailed : Colors.textMuted
                    Layout.alignment: Qt.AlignVCenter
                }
                Text {
                    text: removeAction.text
                    font.family: Colors.fontFamily
                    font.pixelSize: 11
                    color: removeAction.hovered ? root.colorFailed : Colors.textMain
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            background: Rectangle {
                radius: 4
                color: removeAction.hovered ? (Colors.isDarkMode ? Qt.rgba(0.9, 0.2, 0.2, 0.15) : Qt.rgba(0.9, 0.2, 0.2, 0.10)) : "transparent"
            }
        }

        MenuSeparator {
            topPadding: 2
            bottomPadding: 2
            leftPadding: 4
            rightPadding: 4
            contentItem: Rectangle {
                implicitHeight: 1
                color: Colors.divider
            }
        }

        // Quick Benchmark Action: Test 1000 parts
        MenuItem {
            id: benchmarkAction
            implicitWidth: 202
            implicitHeight: 28
            padding: 0
            leftPadding: 8
            rightPadding: 8
            topPadding: 0
            bottomPadding: 0
            indicator: null

            text: "Benchmark 1,000 Jobs"
            onTriggered: {
                root.benchmark1000Jobs();
            }

            contentItem: RowLayout {
                spacing: 8
                Text {
                    text: "\ue85c" // speed
                    font.family: materialIcons.name
                    font.pixelSize: 15
                    color: benchmarkAction.hovered ? Colors.goldPrimary : Colors.textMuted
                    Layout.alignment: Qt.AlignVCenter
                }
                Text {
                    text: benchmarkAction.text
                    font.family: Colors.fontFamily
                    font.pixelSize: 11
                    color: benchmarkAction.hovered ? Colors.goldPrimary : Colors.textMain
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            background: Rectangle {
                radius: 4
                color: benchmarkAction.hovered ? Colors.bgHover : "transparent"
            }
        }

        // Reset to Default Demo Jobs
        MenuItem {
            id: resetAction
            implicitWidth: 202
            implicitHeight: 28
            padding: 0
            leftPadding: 8
            rightPadding: 8
            topPadding: 0
            bottomPadding: 0
            indicator: null

            text: "Reset Default Jobs"
            onTriggered: {
                root.resetDefaultJobs();
            }

            contentItem: RowLayout {
                spacing: 8
                Text {
                    text: "\ue5d5" // refresh
                    font.family: materialIcons.name
                    font.pixelSize: 15
                    color: resetAction.hovered ? Colors.goldPrimary : Colors.textMuted
                    Layout.alignment: Qt.AlignVCenter
                }
                Text {
                    text: resetAction.text
                    font.family: Colors.fontFamily
                    font.pixelSize: 11
                    color: resetAction.hovered ? Colors.goldPrimary : Colors.textMain
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            background: Rectangle {
                radius: 4
                color: resetAction.hovered ? Colors.bgHover : "transparent"
            }
        }
    }

    // Context Menu for Empty State
    Menu {
        id: emptyMenu
        implicitWidth: 188
        width: 188
        topPadding: 4
        bottomPadding: 4
        leftPadding: 4
        rightPadding: 4

        background: Rectangle {
            color: Colors.bgSurface
            radius: 8
            border.color: Colors.goldBorder
            border.width: 1
        }

        MenuItem {
            implicitWidth: 180
            implicitHeight: 28
            padding: 0
            leftPadding: 8
            rightPadding: 8
            indicator: null
            text: "Add New Job"
            onTriggered: root.addJob("New Archive Job", "running", 0.1)
        }
        MenuItem {
            implicitWidth: 180
            implicitHeight: 28
            padding: 0
            leftPadding: 8
            rightPadding: 8
            indicator: null
            text: "Benchmark 1,000 Jobs"
            onTriggered: root.benchmark1000Jobs()
        }
        MenuItem {
            implicitWidth: 180
            implicitHeight: 28
            padding: 0
            leftPadding: 8
            rightPadding: 8
            indicator: null
            text: "Reset Default Jobs"
            onTriggered: root.resetDefaultJobs()
        }
    }
}
