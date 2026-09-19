import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UI

Item {
    id: root

    property color colorIdle:     Colors.isDarkMode ? "#475569" : "#838b99"
    property color colorPending:  Colors.isDarkMode ? "#5c6b84" : "#64748b"
    property color colorRunning:  Colors.isDarkMode ? "#2e8b57" : "#228b50"
    property color colorPaused:   Colors.isDarkMode ? Colors.goldPrimary : Colors.goldHover
    property color colorAborted:  Colors.isDarkMode ? "#c86541" : "#b05232"
    property color colorFailed:   Colors.isDarkMode ? "#cd5c5c" : "#b23a3a"
    property color colorFinished: Colors.isDarkMode ? "#236d43" : "#1a6b3e"

    // Sleeker, standard 36px height for Fluent status bar aesthetic
    implicitHeight: 36
    Layout.fillWidth: true
    Layout.preferredHeight: 36

    // Minimal style toggle: automatically active when height < 35 unless forceText is true
    property bool forceMinimal: false
    property bool forceText: false
    readonly property bool isMinimal: (forceMinimal || (height < 35)) && !forceText

    // Flyout placement direction: if true, opens downwards (e.g. for ProgressWindow); otherwise opens upwards (MainWindow status bar)
    property bool flyoutDownward: false

    // Container styling
    property color containerBackgroundColor: Colors.bgInput
    property color cornerMaskColor: (parent && parent.color !== undefined && parent.color != "transparent")
                                    ? parent.color
                                    : (Colors.isDarkMode ? Colors.bgSurface : "#ffffff")

    // Lifecycle & suspension controls
    property bool isSuspended: false
    property bool isCollapsed: false
    property bool simulationActive: false

    // Signals
    signal removeRequested(int index, int jobId)
    signal retryRequested(int index, int jobId)
    signal progressClicked()
    signal optimizationSequenceCompleted()

    FontLoader {
        id: materialIcons
        source: "Fonts/MaterialIconsRound-Regular.otf"
    }

    readonly property var activeJobModel: (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.jobModel && archiveInterface.jobModel.count > 0)
                                          ? archiveInterface.jobModel
                                          : jobModel

    readonly property int currentJobCount: activeJobModel ? activeJobModel.count : 0

    property int internalRunningJobIndex: -1
    property int internalFailedJobIndex: -1

    readonly property int currentRunningJobIndex: {
        if (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.jobModel && archiveInterface.jobModel.count > 0) {
            return archiveInterface.jobModel.runningJobIndex;
        }
        return internalRunningJobIndex;
    }

    readonly property int currentFailedJobIndex: {
        if (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.jobModel && archiveInterface.jobModel.count > 0) {
            return archiveInterface.jobModel.failedJobIndex;
        }
        return internalFailedJobIndex;
    }

    ListModel {
        id: jobModel
    }

    readonly property int finishedCount: {
        if (activeJobModel && activeJobModel.finishedCount !== undefined) {
            return activeJobModel.finishedCount;
        }
        var count = 0;
        for (var i = 0; i < jobModel.count; ++i) {
            var st = jobModel.get(i).state;
            if (st === "finished" || st === "done") count++;
        }
        return count;
    }

    readonly property int failedCount: {
        if (activeJobModel && activeJobModel.failedCount !== undefined) {
            return activeJobModel.failedCount;
        }
        var count = 0;
        for (var i = 0; i < jobModel.count; ++i) {
            var st = jobModel.get(i).state;
            if (st === "failed") count++;
        }
        return count;
    }

    readonly property int runningCount: {
        if (activeJobModel && activeJobModel.runningCount !== undefined) {
            return activeJobModel.runningCount;
        }
        return (currentRunningJobIndex >= 0 && currentRunningJobIndex < currentJobCount) ? 1 : 0;
    }

    readonly property int pendingCount: Math.max(0, currentJobCount - (finishedCount + runningCount + failedCount))

    property real customOverallProgress: -1.0
    readonly property bool isBusyWithTask: (customOverallProgress >= 0.0) ||
                                           (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.isBusy)

    readonly property real calculatedOverallProgress: {
        if (typeof archiveInterface !== "undefined" && archiveInterface) {
            return archiveInterface.overallProgress;
        }
        return 0;
    }

    readonly property string overallState: {
        if (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.jobModel && archiveInterface.jobModel.count > 0) {
            return archiveInterface.jobModel.overallState;
        }
        if (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.isBusy) {
            if (archiveInterface.isPaused) return "paused";
            return "running";
        }
        if (customOverallProgress >= 0.0) {
            return (customOverallProgress >= 1.0) ? "finished" : "running";
        }
        if (currentJobCount === 0) return "idle";
        if (failedCount > 0 || internalFailedJobIndex >= 0) return "failed";
        if (runningCount > 0 || (internalRunningJobIndex >= 0 && internalRunningJobIndex < currentJobCount)) return "running";
        if (finishedCount === currentJobCount) return "finished";
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

    // Active running job metadata (reactively re-fetched via calculatedOverallProgress trigger)
    readonly property var currentRunningJobItem: {
        var _trigger = root.calculatedOverallProgress;
        if (currentRunningJobIndex >= 0 && currentRunningJobIndex < currentJobCount && activeJobModel) {
            return activeJobModel.get(currentRunningJobIndex);
        }
        return null;
    }
    readonly property string runningJobName: {
        if (currentRunningJobItem && currentRunningJobItem.name) return currentRunningJobItem.name;
        if (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.currentFileName.length > 0) {
            return archiveInterface.currentFileName;
        }
        return (currentRunningJobIndex >= 0) ? ("Job #" + (currentRunningJobIndex + 1)) : "";
    }
    readonly property real runningJobProgress: (currentRunningJobItem && currentRunningJobItem.progress !== undefined) ? currentRunningJobItem.progress : 0.0
    readonly property string runningJobDetail: {
        var overallPct = Math.round(root.calculatedOverallProgress * 100) + "%";
        if (currentRunningJobItem && currentRunningJobItem.detail) {
            return overallPct + " overall • " + currentRunningJobItem.detail;
        }
        if (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.isBusy) {
            if (archiveInterface.totalBytes > 0) {
                var procBytes = archiveInterface.totalProcessedBytes;
                if (procBytes <= 0 && root.calculatedOverallProgress > 0) {
                    procBytes = root.calculatedOverallProgress * archiveInterface.totalBytes;
                }
                return (procBytes / (1024 * 1024)).toFixed(1) + " MB / " +
                       (archiveInterface.totalBytes / (1024 * 1024)).toFixed(1) + " MB (" +
                       overallPct + " overall)";
            }
        }
        return overallPct + " overall";
    }

    // job <= 5
    readonly property bool isSegmentedMode: currentJobCount > 1 && currentJobCount <= 5


    property bool isOptimizingSequenceActive: false
    property string optimizationBannerText: ""
    property var optimizationCallback: null

    function playOptimizationDeletionSequence(deletedJobIds, onCompletedCallback) {
        if (!deletedJobIds || deletedJobIds.length === 0) {
            if (typeof onCompletedCallback === "function") {
                onCompletedCallback();
            }
            return;
        }
        var count = deletedJobIds.length;
        optimizationBannerText = "Optimizing archive • Eliminated " + count + " redundant operation" + (count > 1 ? "s" : "");
        isOptimizingSequenceActive = true;
        optimizationCallback = onCompletedCallback;
        optimizationTimer.restart();
    }

    Timer {
        id: optimizationTimer
        interval: 500
        repeat: false
        onTriggered: {
            root.isOptimizingSequenceActive = false;
            root.optimizationSequenceCompleted();
            var cb = root.optimizationCallback;
            root.optimizationCallback = null;
            if (typeof cb === "function") {
                cb();
            }
        }
    }

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
            case "idle":     return "\ue836";
            case "pending":  return "\ue8b5";
            case "running":  return "\ue86a";
            case "paused":   return "\ue034";
            case "aborted":  return "\ue5c9";
            case "failed":   return "\ue000";
            case "finished": return "\ue86c";
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
    
    function scrollToRunningJob(animated) {
        if (currentRunningJobIndex >= 0) {
            triggerRunningToolTip(currentRunningJobIndex);
        }
    }

    function scrollToFailedJob(animated) {
        if (currentFailedJobIndex >= 0) {
            triggerRunningToolTip(currentFailedJobIndex);
        } else if (failedCount > 0) {
            jobFlyout.openFlyout("failed");
        }
    }

    function seekToRunningJob() {
        scrollToRunningJob(true);
    }

    function seekToFailedJob() {
        scrollToFailedJob(true);
    }

    function triggerRunningToolTip(index) {
        if (index < 0 || index >= currentJobCount) return;
        var item = activeJobModel.get(index);
        if (!item) return;

        activeToolTip.targetIndex = index;
        activeToolTip.jobName = item.name || ("Job #" + (index + 1));
        activeToolTip.jobState = item.state || "idle";
        activeToolTip.jobProgress = item.progress !== undefined ? item.progress : 0.0;
        activeToolTip.jobDetail = item.detail || "";
        activeToolTip.open();
        toolTipTimer.restart();
    }

    Timer {
        id: toolTipTimer
        interval: 4000
        repeat: false
        onTriggered: activeToolTip.close()
    }

    // Job model manipulation helpers
    function addJob(name, state, progress, detail) {
        var isNewRunning = (state === "running");
        var newIdx = jobModel.count;
        jobModel.append({
            name: name || ("Job #" + (newIdx + 1)),
            state: state || "pending",
            progress: progress !== undefined ? progress : 0.0,
            detail: detail || "Added to queue"
        });
        if (isNewRunning) {
            internalRunningJobIndex = newIdx;
            triggerRunningToolTip(newIdx);
        }
    }

    function removeJob(index) {
        if (index < 0 || index >= currentJobCount) return;
        var item = activeJobModel ? activeJobModel.get(index) : null;
        var jobId = (item && item.id !== undefined) ? item.id : -1;
        removeRequested(index, jobId);
        if (typeof archiveInterface !== "undefined" && archiveInterface) {
            archiveInterface.removeJob(jobId, index);
        }
        if (jobModel && index >= 0 && index < jobModel.count) {
            jobModel.remove(index);
            if (internalRunningJobIndex === index) {
                internalRunningJobIndex = -1;
            } else if (internalRunningJobIndex > index) {
                internalRunningJobIndex--;
            }
        }
    }

    function pauseJob(index) {
        if (index >= 0 && index < jobModel.count) {
            jobModel.setProperty(index, "state", "paused");
        }
    }

    function resumeJob(index) {
        if (index >= 0 && index < jobModel.count) {
            jobModel.setProperty(index, "state", "running");
            internalRunningJobIndex = index;
            triggerRunningToolTip(index);
        }
    }

    function retryJob(index) {
        if (index < 0 || index >= currentJobCount) return;
        var item = activeJobModel ? activeJobModel.get(index) : null;
        var jobId = (item && item.id !== undefined) ? item.id : -1;

        if (jobModel && index >= 0 && index < jobModel.count) {
            jobModel.setProperty(index, "state", "running");
            jobModel.setProperty(index, "progress", 0.0);
            internalRunningJobIndex = index;
        }

        retryRequested(index, jobId);
        if (typeof archiveInterface !== "undefined" && archiveInterface) {
            archiveInterface.retryJob(jobId, index);
        }
    }

    function retryAllFailed() {
        for (var i = 0; i < currentJobCount; ++i) {
            var item = activeJobModel.get(i);
            if (item && item.state === "failed") {
                retryJob(i);
            }
        }
    }

    function openProgressWindowIfBusy() {
        if (!root.flyoutDownward && typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.isBusy) {
            root.progressClicked();
            if (typeof progressWindow !== "undefined" && progressWindow) {
                progressWindow.show();
                progressWindow.raise();
                progressWindow.requestActivate();
                return true;
            }
        }
        return false;
    }

    Rectangle {
        id: containerRect
        anchors.fill: parent
        radius: 6
        color: root.containerBackgroundColor
        clip: true


        Item {
            anchors.fill: parent
            visible: root.currentJobCount === 0 && !root.isBusyWithTask && !root.isCollapsed

            MouseArea {
                anchors.fill: parent
                cursorShape: (typeof archiveInterface !== "undefined" && archiveInterface && archiveInterface.isBusy) ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.openProgressWindowIfBusy()
            }

            RowLayout {
                anchors.centerIn: parent
                spacing: 6
                Text {
                    text: "\ue836"
                    font.family: materialIcons.name
                    font.pixelSize: root.isMinimal ? 11 : 13
                    color: Colors.textMuted
                    opacity: 0.7
                }
                Text {
                    text: root.isMinimal ? "Idle" : "No job is queued"
                    font.family: Colors.fontFamily
                    font.pixelSize: root.isMinimal ? 10 : 11
                    color: Colors.textMuted
                }
            }
        }

        // Segmented job view 1~8 jobs
        RowLayout {
            anchors.fill: parent
            anchors.margins: 2
            spacing: 2
            visible: root.isSegmentedMode && root.currentJobCount > 0 && !root.isCollapsed

            Repeater {
                model: root.isSegmentedMode ? root.activeJobModel : null

                delegate: Rectangle {
                    id: segmentCell
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 4
                    clip: true
                    color: Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(0, 0, 0, 0.03)

                    readonly property string cellState: (typeof model !== "undefined" && model && model.state) ? model.state : "idle"
                    readonly property real cellProgress: (typeof model !== "undefined" && model && model.progress !== undefined) ? model.progress : 0.0
                    readonly property string cellName: (typeof model !== "undefined" && model && model.name) ? model.name : ("Part " + (index + 1))
                    readonly property color cellColor: root.getStatusColor(cellState)
                    readonly property bool isCellRunning: cellState === "running"
                    readonly property bool isCellDone: cellState === "finished" || cellState === "done"

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: segmentCell.isCellDone ? parent.width : Math.max(0, parent.width * segmentCell.cellProgress)
                        radius: 3
                        color: segmentCell.cellColor
                        opacity: segmentCell.isCellDone ? 0.9 : 0.75

                        Behavior on width {
                            enabled: !root.isSuspended
                            NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
                        }
                    }

                    // Content row
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        spacing: 4

                        Text {
                            text: root.getStatusIcon(segmentCell.cellState)
                            font.family: materialIcons.name
                            font.pixelSize: 11
                            color: segmentCell.isCellDone || segmentCell.isCellRunning ? "#ffffff" : Colors.textMuted
                            Layout.alignment: Qt.AlignVCenter

                            RotationAnimation on rotation {
                                running: segmentCell.isCellRunning && root.visible
                                loops: Animation.Infinite
                                from: 0; to: 360; duration: 1200
                            }
                        }

                        Text {
                            text: segmentCell.cellName
                            font.family: Colors.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: segmentCell.isCellDone || segmentCell.isCellRunning ? "#ffffff" : Colors.textMain
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: segmentCell.isCellDone ? "Done" : (segmentCell.isCellRunning ? "Working" : "Queued")
                            font.family: Colors.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            color: segmentCell.isCellDone || segmentCell.isCellRunning ? "#ffffff" : Colors.textMuted
                            visible: segmentCell.width >= 70
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.RightButton) {
                                taskContextMenu.openForTask(index, model.name, model.state, (typeof model !== "undefined" && model && model.fileName) ? model.fileName : "");
                                taskContextMenu.popup(segmentCell, mouse.x, mouse.y);
                            } else {
                                if (!root.openProgressWindowIfBusy()) {
                                    root.triggerRunningToolTip(index);
                                }
                            }
                        }
                    }
                }
            }

            // right side percent
            Rectangle {
                Layout.preferredWidth: overallSegBadgeRow.implicitWidth + 14
                Layout.fillHeight: true
                radius: 4
                color: Colors.isDarkMode ? Qt.rgba(0, 0, 0, 0.35) : Qt.rgba(255, 255, 255, 0.45)

                RowLayout {
                    id: overallSegBadgeRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: Math.round(root.calculatedOverallProgress * 100) + "%"
                        font.family: Colors.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: root.overallState === "failed" ? root.colorFailed : root.colorRunning
                    }
                }
            }
        }

        Item {
            anchors.fill: parent
            anchors.margins: 2
            visible: (!root.isSegmentedMode && (root.currentJobCount > 0 || root.isBusyWithTask)) && !root.isCollapsed

            Item {
                anchors.fill: parent
                clip: true

                Rectangle {
                    id: finishedTrack
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(0, parent.width * (root.currentJobCount > 0 ? (root.finishedCount / Math.max(1, root.currentJobCount)) : (root.calculatedOverallProgress >= 1.0 ? 1.0 : 0.0)))
                    radius: 3
                    color: Qt.rgba(root.colorFinished.r, root.colorFinished.g, root.colorFinished.b, Colors.isDarkMode ? 0.40 : 0.25)

                    Behavior on width {
                        enabled: !root.isSuspended
                        NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                    }
                }

                Rectangle {
                    id: activeTrack
                    anchors.left: finishedTrack.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: (root.runningCount > 0 || root.isBusyWithTask)
                           ? Math.min(parent.width - finishedTrack.width,
                                      Math.max(6, parent.width * (root.currentJobCount > 0 ? Math.max(0.0, root.calculatedOverallProgress - (root.finishedCount / Math.max(1, root.currentJobCount))) : root.calculatedOverallProgress)))
                           : 0
                    radius: 3
                    color: root.colorRunning
                    opacity: 0.85

                    Behavior on width {
                        enabled: !root.isSuspended
                        NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                    }

                    SequentialAnimation on opacity {
                        running: root.runningCount > 0 && root.visible && !root.isSuspended
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.65; to: 0.95; duration: 750; easing.type: Easing.InOutQuad }
                        NumberAnimation { from: 0.95; to: 0.65; duration: 750; easing.type: Easing.InOutQuad }
                    }
                }

                Rectangle {
                    id: failedTrack
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: (root.failedCount > 0)
                           ? Math.max(14, parent.width * (root.failedCount / Math.max(1, root.currentJobCount)))
                           : 0
                    radius: 3
                    color: Qt.rgba(root.colorFailed.r, root.colorFailed.g, root.colorFailed.b, 0.70)
                    visible: root.failedCount > 0
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8

                // Left: Active Task Indicator & Name
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 7

                    // Live Rotating Indicator or State Icon
                    

                    // Task name & status detail
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            text: root.runningJobName.length > 0
                                  ? root.runningJobName
                                  : (root.finishedCount === root.currentJobCount ? "All tasks completed successfully" : "Processing archive jobs")
                            font.family: Colors.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: Colors.textMain
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: root.runningJobDetail.length > 0
                                  ? root.runningJobDetail
                                  : ((root.currentJobCount > 0)
                                      ? (Math.round(root.calculatedOverallProgress * 100) + "% overall • " + root.finishedCount + " of " + root.currentJobCount + " completed")
                                      : (Math.round(root.calculatedOverallProgress * 100) + "% overall"))
                            font.family: Colors.fontFamily
                            font.pixelSize: 9
                            color: Colors.textMuted
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            visible: !root.isMinimal && (parent.height > 30)
                        }
                    }
                }

                // Center: Status Capsule Badges (Finished, Running, Queued, Failed)
                RowLayout {
                    spacing: 4
                    visible: !root.isMinimal && (containerRect.width >= 580)
                    Layout.alignment: Qt.AlignVCenter

                    // Finished badge
                    Rectangle {
                        height: 20
                        implicitWidth: doneRow.implicitWidth + 10
                        radius: 10
                        color: Qt.rgba(root.colorFinished.r, root.colorFinished.g, root.colorFinished.b, 0.18)
                        border.color: Qt.rgba(root.colorFinished.r, root.colorFinished.g, root.colorFinished.b, 0.45)
                        border.width: 1

                        RowLayout {
                            id: doneRow
                            anchors.centerIn: parent
                            spacing: 3
                            Text {
                                text: "\ue86c" // check_circle
                                font.family: materialIcons.name
                                font.pixelSize: 11
                                color: root.colorFinished
                            }
                            Text {
                                text: root.finishedCount + " Done"
                                font.family: Colors.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                color: Colors.isDarkMode ? "#cbd5e1" : "#334155"
                            }
                        }
                    }

                    // Queued badge
                    Rectangle {
                        height: 20
                        implicitWidth: queuedRow.implicitWidth + 10
                        radius: 10
                        color: Qt.rgba(root.colorPending.r, root.colorPending.g, root.colorPending.b, 0.15)
                        border.color: Qt.rgba(root.colorPending.r, root.colorPending.g, root.colorPending.b, 0.35)
                        border.width: 1
                        visible: root.pendingCount > 0

                        RowLayout {
                            id: queuedRow
                            anchors.centerIn: parent
                            spacing: 3
                            Text {
                                text: "\ue8b5" // schedule
                                font.family: materialIcons.name
                                font.pixelSize: 10
                                color: root.colorPending
                            }
                            Text {
                                text: root.pendingCount + " Queued"
                                font.family: Colors.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                color: Colors.textMuted
                            }
                        }
                    }

                    // Failed badge (Clickable to inspect / retry)
                    Rectangle {
                        id: failedBadge
                        height: 20
                        implicitWidth: failedRow.implicitWidth + 12
                        radius: 10
                        color: failedMouse.containsMouse
                               ? Qt.rgba(root.colorFailed.r, root.colorFailed.g, root.colorFailed.b, 0.35)
                               : Qt.rgba(root.colorFailed.r, root.colorFailed.g, root.colorFailed.b, 0.20)
                        border.color: root.colorFailed
                        border.width: 1
                        visible: root.failedCount > 0

                        RowLayout {
                            id: failedRow
                            anchors.centerIn: parent
                            spacing: 3
                            Text {
                                text: "\ue000" // error
                                font.family: materialIcons.name
                                font.pixelSize: 11
                                color: root.colorFailed
                            }
                            Text {
                                text: root.failedCount + " Failed • Retry"
                                font.family: Colors.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: root.colorFailed
                            }
                        }

                        MouseArea {
                            id: failedMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                jobFlyout.openFlyout("failed");
                            }
                        }
                    }
                }

                // Right: Overall Progress & Batch Position
                RowLayout {
                    spacing: 6
                    Layout.alignment: Qt.AlignVCenter

                    // Overall percentage badge
                    Text {
                        text: Math.round(root.calculatedOverallProgress * 100) + "%"
                        font.family: Colors.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: root.overallState === "failed" ? root.colorFailed : root.colorRunning
                    }

                    // Batch position: [ 451 / 1000 ]
                    Text {
                        text: "[" + (root.currentRunningJobIndex >= 0 ? (root.currentRunningJobIndex + 1) : root.finishedCount) + "/" + root.currentJobCount + "]"
                        font.family: Colors.fontFamily
                        font.pixelSize: 10
                        color: Colors.textMuted
                        visible: !root.isMinimal && (containerRect.width >= 400) && (root.currentJobCount > 0)
                    }

                    // Job Inspector Button
                    Rectangle {
                        id: flyoutBtn
                        height: 22
                        implicitWidth: flyoutBtnRow.implicitWidth + 12
                        radius: 11
                        color: flyoutBtnMouse.containsMouse
                               ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.08))
                               : (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.04))
                        border.color: flyoutBtnMouse.containsMouse ? Colors.goldPrimary : Colors.borderSubtle
                        border.width: 1

                        RowLayout {
                            id: flyoutBtnRow
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: "\ue8ee" // view_list / format_list_bulleted
                                font.family: materialIcons.name
                                font.pixelSize: 11
                                color: Colors.goldPrimary
                            }
                            Text {
                                text: "Tasks"
                                font.family: Colors.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                color: Colors.isDarkMode ? "#e2e8f0" : "#334155"
                                visible: containerRect.width >= 480
                            }
                        }

                        MouseArea {
                            id: flyoutBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!root.openProgressWindowIfBusy()) {
                                    jobFlyout.toggle();
                                }
                            }
                        }
                    }
                }
            }

            // Interactive click on the HUD to inspect tasks
            MouseArea {
                anchors.fill: parent
                z: -1
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!root.openProgressWindowIfBusy()) {
                        jobFlyout.toggle();
                    }
                }
            }
        }

        // =====================================================================
        // --- 4. Optimization Deletion Sequence Banner Overlay ---
        // =====================================================================
        Rectangle {
            anchors.fill: parent
            radius: 6
            color: Colors.goldPrimary
            opacity: root.isOptimizingSequenceActive ? 0.92 : 0.0
            visible: opacity > 0.0
            z: 80

            Behavior on opacity { NumberAnimation { duration: 180 } }

            RowLayout {
                anchors.centerIn: parent
                spacing: 8
                Text {
                    text: "\ue872" // delete
                    font.family: materialIcons.name
                    font.pixelSize: 14
                    color: Colors.textOnGold
                }
                Text {
                    text: root.optimizationBannerText
                    font.family: Colors.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: Colors.textOnGold
                }
            }
        }

        // =====================================================================
        // --- 5. Border Overlay (Always renders on top of tracks, HUD & overlays) ---
        // =====================================================================
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.color: root.overallBorderColor
            border.width: root.overallState === "running" ? 1.5 : 1.0
            z: 100

            Behavior on border.color { ColorAnimation { duration: 200 } }
        }
    }

    // =========================================================================
    // --- Interactive Job Inspector Flyout / Popover ---
    // Zero background overhead: only renders virtual items when opened!
    // =========================================================================
    Popup {
        id: jobFlyout
        parent: containerRect
        x: Math.max(0, (containerRect.width - width) / 2)
        y: root.flyoutDownward ? (containerRect.height + 6) : (-height - 8)
        width: Math.min(480, Math.max(340, containerRect.width - 20))
        height: Math.min(root.flyoutDownward ? 235 : 360, (root.flyoutDownward ? 120 : 200) + Math.min(4, Math.max(1, root.currentJobCount)) * 34)
        padding: 0
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

        property string filterMode: "all" // all, running, failed, pending, finished
        property string searchKeyword: ""

        function openFlyout(mode) {
            filterMode = mode || "all";
            open();
        }

        function toggle() {
            if (visible) close();
            else openFlyout("all");
        }

        background: Rectangle {
            color: Colors.bgSurface
            radius: 8
            clip: true
        }

        contentItem: Item {
            clip: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Flyout Header
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    radius: 8
                    color: Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(0, 0, 0, 0.03)

                    // Square off bottom corners so only top corners are rounded
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 8
                        color: parent.color
                    }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    spacing: 8

                    Text {
                        text: "Task Inspector (" + root.currentJobCount + ")"
                        font.family: Colors.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: Colors.textMain
                    }

                    // Search input
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        radius: 4
                        color: Colors.bgInput
                        border.color: searchInput.activeFocus ? Colors.goldPrimary : Colors.borderSubtle
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            spacing: 4

                            Text {
                                text: "\ue8b6" // search
                                font.family: materialIcons.name
                                font.pixelSize: 12
                                color: Colors.textMuted
                            }

                            TextInput {
                                id: searchInput
                                Layout.fillWidth: true
                                font.family: Colors.fontFamily
                                font.pixelSize: 10
                                color: Colors.textMain
                                clip: true
                                onTextChanged: jobFlyout.searchKeyword = text.toLowerCase()
                            }
                        }
                    }

                    // Close button
                    Rectangle {
                        width: 22
                        height: 22
                        radius: 11
                        color: closeFlyoutMouse.containsMouse ? Colors.bgHover : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "\ue5cd" // close
                            font.family: materialIcons.name
                            font.pixelSize: 14
                            color: Colors.textMuted
                        }
                        MouseArea {
                            id: closeFlyoutMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: jobFlyout.close()
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.divider
            }

            // Virtualized Job List
            ListView {
                id: flyoutListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                reuseItems: true
                model: jobFlyout.visible ? root.activeJobModel : null

                delegate: Rectangle {
                    id: flyoutRow
                    width: flyoutListView.width
                    height: matchesFilter ? 34 : 0
                    visible: matchesFilter
                    color: rowMouse.containsMouse ? Colors.bgHover : "transparent"

                    readonly property string jState: (typeof model !== "undefined" && model && model.state) ? model.state : "idle"
                    readonly property string jName: (typeof model !== "undefined" && model && model.name) ? model.name : ("Job #" + (index + 1))
                    readonly property real jProgress: (typeof model !== "undefined" && model && model.progress !== undefined) ? model.progress : 0.0

                    readonly property bool matchesFilter: {
                        if (jobFlyout.filterMode === "failed" && jState !== "failed") return false;
                        if (jobFlyout.filterMode === "running" && jState !== "running") return false;
                        if (jobFlyout.searchKeyword.length > 0 && jName.toLowerCase().indexOf(jobFlyout.searchKeyword) === -1) return false;
                        return true;
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Text {
                            text: root.getStatusIcon(flyoutRow.jState)
                            font.family: materialIcons.name
                            font.pixelSize: 13
                            color: root.getStatusColor(flyoutRow.jState)
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: flyoutRow.jName
                            font.family: Colors.fontFamily
                            font.pixelSize: 11
                            color: Colors.textMain
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Mini progress fill
                        Rectangle {
                            Layout.preferredWidth: 60
                            Layout.preferredHeight: 4
                            radius: 2
                            color: Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(0, 0, 0, 0.08)
                            Layout.alignment: Qt.AlignVCenter

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: parent.width * Math.max(0, Math.min(1.0, flyoutRow.jProgress))
                                radius: 2
                                color: root.getStatusColor(flyoutRow.jState)
                            }
                        }

                        Text {
                            text: Math.round(flyoutRow.jProgress * 100) + "%"
                            font.family: Colors.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: root.getStatusColor(flyoutRow.jState)
                            Layout.preferredWidth: 32
                            horizontalAlignment: Text.AlignRight
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Quick Action (Retry / Pause)
                        Rectangle {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            radius: 4
                            color: actionMouse.containsMouse ? Colors.bgHover : "transparent"
                            visible: flyoutRow.jState === "failed" || flyoutRow.jState === "running" || flyoutRow.jState === "paused"
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                anchors.centerIn: parent
                                text: flyoutRow.jState === "failed" ? "\ue5d5" : (flyoutRow.jState === "running" ? "\ue034" : "\ue037")
                                font.family: materialIcons.name
                                font.pixelSize: 13
                                color: Colors.goldPrimary
                            }

                            MouseArea {
                                id: actionMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (flyoutRow.jState === "failed") root.retryJob(index);
                                    else if (flyoutRow.jState === "running") root.pauseJob(index);
                                    else root.resumeJob(index);
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            taskContextMenu.openForTask(index, flyoutRow.jName, flyoutRow.jState, (typeof model !== "undefined" && model && model.fileName) ? model.fileName : "");
                            taskContextMenu.popup(flyoutRow, mouse.x, mouse.y);
                        }
                    }
                }
            }

            // Divider above footer
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.divider
            }

            // Footer
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                radius: 8
                color: Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.03) : Qt.rgba(0, 0, 0, 0.02)

                // Square off top corners so only bottom corners are rounded
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 8
                    color: parent.color
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: root.failedCount > 0 ? (root.failedCount + " tasks failed") : "All systems normal"
                        font.family: Colors.fontFamily
                        font.pixelSize: 10
                        color: root.failedCount > 0 ? root.colorFailed : Colors.textMuted
                        Layout.fillWidth: true
                    }

                    // Retry all failed button
                    Rectangle {
                        Layout.preferredHeight: 20
                        implicitWidth: retryAllText.implicitWidth + 10
                        radius: 4
                        color: root.failedCount > 0 ? root.colorFailed : "transparent"
                        visible: root.failedCount > 0

                        Text {
                            id: retryAllText
                            anchors.centerIn: parent
                            text: "Retry Failed"
                            font.family: Colors.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            color: "#ffffff"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.retryAllFailed()
                        }
                    }
                }
            }
        }

        // Dedicated Border Overlay on top of all flyout content
        Rectangle {
            anchors.fill: parent
            radius: 8
            color: "transparent"
            border.color: Colors.goldBorder
            border.width: 1
            z: 99
        }
    }
}

    // =========================================================================
    // --- Unified ToolTip ---
    // =========================================================================
    ToolTip {
        id: activeToolTip
        parent: containerRect
        x: Math.max(10, Math.min(containerRect.width - width - 10, containerRect.width / 2 - width / 2))
        y: root.flyoutDownward ? (containerRect.height + 6) : (-height - 8)
        timeout: -1

        property int targetIndex: -1
        property var jobName: ""
        property var jobState: "idle"
        property real jobProgress: 0.0
        property var jobDetail: ""

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
                text: activeToolTip.jobDetail ? activeToolTip.jobDetail : "Archive operation"
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

    // =========================================================
    // --- Compact Theme-Matching Context Menu for Tasks ---
    // =========================================================
    Menu {
        id: taskContextMenu
        property int targetIndex: -1
        property string targetName: ""
        property string targetState: "idle"
        property string targetFileName: ""
        property string operationType: "add"
        property string operationIcon: "\ue145" // +
        property string displayName: ""

        function openForTask(index, name, state, fileName) {
            targetIndex = index;
            targetName = name || ("Job #" + (index + 1));
            targetState = state || "idle";
            targetFileName = fileName || "";

            var trimmed = targetName.trim();
            var lower = trimmed.toLowerCase();

            if (lower.indexOf("add ") === 0 || lower.indexOf("create ") === 0) {
                operationType = "add";
                operationIcon = "\ue145"; // + (add)
                displayName = trimmed.substring(trimmed.indexOf(" ") + 1);
            } else if (lower.indexOf("remove ") === 0 || lower.indexOf("delete ") === 0) {
                operationType = "remove";
                operationIcon = "\ue872"; // bin (delete)
                displayName = trimmed.substring(trimmed.indexOf(" ") + 1);
            } else if (lower.indexOf("extract ") === 0) {
                operationType = "extract";
                operationIcon = "\ue89e"; // open_in_new / extract
                displayName = trimmed.substring(trimmed.indexOf(" ") + 1);
            } else if (lower.indexOf("compress ") === 0 || lower.indexOf("change compression") === 0) {
                operationType = "compress";
                operationIcon = "\ue8b8"; // settings / compress
                var lvlName = targetFileName;
                if (lvlName === "1") lvlName = "Fast (Store)";
                else if (lvlName === "2") lvlName = "Balanced";
                else if (lvlName === "3") lvlName = "Ultra";

                if (lvlName && lvlName.length > 0) {
                    displayName = lvlName;
                } else if (trimmed.indexOf(":") !== -1) {
                    displayName = trimmed.substring(trimmed.indexOf(":") + 1).trim();
                } else {
                    displayName = trimmed;
                }
            } else if (lower.indexOf("move ") === 0) {
                operationType = "move";
                operationIcon = "\ue8d4"; // swap_horiz / move
                displayName = trimmed.substring(trimmed.indexOf(" ") + 1);
            } else if (lower.indexOf("test ") === 0 || lower.indexOf("verify ") === 0 || lower.indexOf("checksum ") === 0) {
                operationType = "test";
                operationIcon = "\ue876"; // check / verified
                displayName = trimmed.substring(trimmed.indexOf(" ") + 1);
            } else {
                if (targetFileName && targetFileName.length > 0) {
                    displayName = targetFileName;
                } else {
                    displayName = trimmed;
                }
                if (lower.indexOf("delete") !== -1 || lower.indexOf("remove") !== -1) {
                    operationType = "remove";
                    operationIcon = "\ue872"; // bin
                } else {
                    operationType = "add";
                    operationIcon = "\ue145"; // +
                }
            }
        }

        implicitWidth: 180
        width: 180
        padding: 3
        topPadding: 3
        bottomPadding: 3

        background: Rectangle {
            color: Colors.bgSurface
            radius: 6
            border.color: Colors.goldBorder
            border.width: 1
        }

        // Header Item: Operation Icon + File Name
        MenuItem {
            implicitWidth: 174
            implicitHeight: 32
            padding: 0
            leftPadding: 6
            rightPadding: 6
            topPadding: 3
            bottomPadding: 3
            enabled: false
            indicator: null

            contentItem: RowLayout {
                spacing: 6

                // Operation Badge (e.g. green + for Add, red bin for Remove)
                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    color: taskContextMenu.operationType === "remove"
                           ? Qt.rgba(root.colorFailed.r, root.colorFailed.g, root.colorFailed.b, 0.20)
                           : Qt.rgba(root.colorRunning.r, root.colorRunning.g, root.colorRunning.b, 0.20)
                    border.color: taskContextMenu.operationType === "remove" ? root.colorFailed : root.colorRunning
                    border.width: 1
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        anchors.centerIn: parent
                        text: taskContextMenu.operationIcon
                        font.family: materialIcons.name
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: taskContextMenu.operationType === "remove" ? root.colorFailed : root.colorRunning
                    }
                }

                // File Name & Status
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        text: taskContextMenu.displayName
                        font.family: Colors.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: Colors.textMain
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.getStatusLabel(taskContextMenu.targetState)
                        font.family: Colors.fontFamily
                        font.pixelSize: 8
                        color: root.getStatusColor(taskContextMenu.targetState)
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
            contentItem: Rectangle {
                implicitHeight: 1
                color: Colors.divider
            }
        }

        // Action 1: Run / Pause / Retry (interchangeable when job is in failed state)
        MenuItem {
            id: runOrRetryItem
            implicitWidth: 174
            implicitHeight: 26
            padding: 0
            leftPadding: 8
            rightPadding: 8
            indicator: null

            readonly property bool isFailedState: taskContextMenu.targetState === "failed" || taskContextMenu.targetState === "aborted"
            readonly property bool isRunningState: taskContextMenu.targetState === "running"

            text: isFailedState ? "Retry" : (isRunningState ? "Pause" : "Run")

            onTriggered: {
                if (isFailedState) {
                    root.retryJob(taskContextMenu.targetIndex);
                } else if (isRunningState) {
                    root.pauseJob(taskContextMenu.targetIndex);
                } else {
                    root.resumeJob(taskContextMenu.targetIndex);
                }
            }

            contentItem: RowLayout {
                spacing: 6
                Text {
                    text: runOrRetryItem.isFailedState
                          ? "\ue5d5" // refresh / retry
                          : (runOrRetryItem.isRunningState ? "\ue034" : "\ue037") // pause / run
                    font.family: materialIcons.name
                    font.pixelSize: 13
                    color: runOrRetryItem.isFailedState ? Colors.goldPrimary : (runOrRetryItem.isRunningState ? root.colorRunning : Colors.textMain)
                    Layout.alignment: Qt.AlignVCenter
                }
                Text {
                    text: runOrRetryItem.text
                    font.family: Colors.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    color: Colors.textMain
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            background: Rectangle {
                radius: 4
                color: runOrRetryItem.hovered ? Colors.bgHover : "transparent"
            }
        }

        // Action 2: Delete Job
        MenuItem {
            id: deleteJobItem
            implicitWidth: 174
            implicitHeight: 26
            padding: 0
            leftPadding: 8
            rightPadding: 8
            indicator: null

            text: "Delete Job"
            onTriggered: root.removeJob(taskContextMenu.targetIndex)

            contentItem: RowLayout {
                spacing: 6
                Text {
                    text: "\ue872" // delete / bin
                    font.family: materialIcons.name
                    font.pixelSize: 13
                    color: deleteJobItem.hovered ? root.colorFailed : Colors.textMuted
                    Layout.alignment: Qt.AlignVCenter
                }
                Text {
                    text: deleteJobItem.text
                    font.family: Colors.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    color: deleteJobItem.hovered ? root.colorFailed : Colors.textMain
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            background: Rectangle {
                radius: 4
                color: deleteJobItem.hovered
                       ? (Colors.isDarkMode ? Qt.rgba(0.9, 0.2, 0.2, 0.15) : Qt.rgba(0.9, 0.2, 0.2, 0.10))
                       : "transparent"
            }
        }
    }
}
