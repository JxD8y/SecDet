import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import UI

Window {
    id: progressWindow
    title: "Creating archive ..."
    width: 420
    height: 446
    minimumWidth: 420
    maximumWidth: 420
    minimumHeight: 446
    maximumHeight: 446
    flags: Qt.Window | Qt.WindowTitleHint | Qt.WindowCloseButtonHint | Qt.WindowMinimizeButtonHint | Qt.CustomizeWindowHint
    color: Colors.bgMain
    visible: false

    // ==========================================
    // --- Progress & Operation State Properties ---
    // ==========================================
    property var backend: (typeof archiveInterface !== "undefined" && archiveInterface) ? archiveInterface : null

    property string currentFilePath: ""
    property string currentFileName: ""
    property real fileProgress: 0.0          // 0.0 to 1.0
    property real overallProgress: 0.0       // 0.0 to 1.0
    readonly property real displayOverallProgress: {
        if (overallProgress > 0.0) return overallProgress;
        if (typeof multiPartProgress !== "undefined" && multiPartProgress && multiPartProgress.calculatedOverallProgress > 0.0) {
            return multiPartProgress.calculatedOverallProgress;
        }
        if (backend && backend.overallProgress > 0.0) {
            return backend.overallProgress;
        }
        return 0.0;
    }
    property int processedFiles: 0
    property int totalFiles: 0
    property real processedSizeMB: 0.0
    property real totalSizeMB: 0.0
    property real speedMBs: 0.0
    property real smoothedSpeedMBs: 0.0

    // Timing Properties (in seconds)
    property int elapsedSeconds: 0
    property int remainingSeconds: 0
    property real lastObservedProgress: 0.0
    property var lastProgressChangeTime: 0
    property bool isPaused: false
    property bool isCanceling: false
    property bool isCompleted: false
    property bool isFailed: false
    readonly property bool isOperationDone: isCanceling || isCompleted || isFailed

    // Byte Tracking for Speed Calculation
    property real lastCompressedBytes: 0
    property real lastProcessedBytes: 0
    property var lastSampleTime: 0

    // Signals
    signal pauseToggled(bool paused)
    signal canceled()
    signal completed()

    onPauseToggled: function(paused) {
        if (backend) {
            backend.setOperationPaused(paused);
        }
    }

    function resetProgressState() {
        isCompleted = false;
        isFailed = false;
        isCanceling = false;
        isPaused = false;
        elapsedSeconds = 0;
        remainingSeconds = 0;
        lastObservedProgress = backend ? backend.overallProgress : 0.0;
        lastProgressChangeTime = Date.now();
        speedMBs = 0.0;
        smoothedSpeedMBs = 0.0;
        lastSampleTime = Date.now();
        lastCompressedBytes = backend ? backend.totalCompressedBytes : 0;
        lastProcessedBytes = backend ? backend.totalProcessedBytes : 0;
        speedGraph.reset();
        testCloseTimer.stop();
        if (typeof testOkDialog !== "undefined" && testOkDialog) {
            testOkDialog.close();
        }
        if (typeof errorDialog !== "undefined" && errorDialog) {
            errorDialog.close();
        }
        if (typeof cancelConfirmDialog !== "undefined" && cancelConfirmDialog) {
            cancelConfirmDialog.close();
        }
    }

    function showError(title, message) {
        isFailed = true;
        progressTimer.stop();
        timeLeftTimer.stop();
        closeAndResetTimer.stop();
        testCloseTimer.stop();
        if (typeof testOkDialog !== "undefined" && testOkDialog) {
            testOkDialog.close();
        }
        if (progressWindow.visible) {
            errorDialog.showError(title, message);
        }
    }

    onVisibleChanged: {
        if (visible) {
            isCanceling = false;
            isCompleted = false;
            isFailed = false;
            var hasActiveTask = (backend && backend.isBusy);
            if (hasActiveTask) {
                // Synchronize live progress and pause state with running background task
                progressWindow.isPaused = backend.isPaused;
                progressWindow.overallProgress = backend.overallProgress;
                progressWindow.fileProgress = backend.fileProgress;
                if (backend.totalFiles > 0) {
                    progressWindow.processedFiles = backend.processedFiles;
                    progressWindow.totalFiles = backend.totalFiles;
                }
                if (backend.currentFileName && backend.currentFileName.length > 0) {
                    progressWindow.currentFileName = backend.currentFileName;
                    progressWindow.currentFilePath = backend.currentFileName;
                }
                if (backend.currentOperationName && backend.currentOperationName.length > 0) {
                    progressWindow.title = backend.currentOperationName;
                }
                if (backend.totalBytes > 0) {
                    progressWindow.totalSizeMB = backend.totalBytes / (1024.0 * 1024.0);
                } else if (backend.jobModel && backend.jobModel.totalBytes > 0) {
                    progressWindow.totalSizeMB = backend.jobModel.totalBytes / (1024.0 * 1024.0);
                } else if (backend.totalArchiveSize > 0) {
                    progressWindow.totalSizeMB = backend.totalArchiveSize / (1024.0 * 1024.0);
                }
                var initProcBytes = backend.totalProcessedBytes;
                if (initProcBytes > 0) {
                    progressWindow.processedSizeMB = initProcBytes / (1024.0 * 1024.0);
                } else if (progressWindow.totalSizeMB > 0) {
                    var curPct = progressWindow.displayOverallProgress;
                    if (curPct > 0) {
                        progressWindow.processedSizeMB = progressWindow.totalSizeMB * curPct;
                    }
                }
                progressWindow.lastSampleTime = Date.now();
                progressWindow.lastCompressedBytes = backend.totalCompressedBytes;
                progressWindow.lastProcessedBytes = backend.totalProcessedBytes;
                progressWindow.lastObservedProgress = backend.overallProgress;
                progressWindow.lastProgressChangeTime = Date.now();
            } else {
                resetProgressState();
            }
        } else {
            progressTimer.stop();
            timeLeftTimer.stop();
            closeAndResetTimer.stop();
            testCloseTimer.stop();
            if (typeof testOkDialog !== "undefined" && testOkDialog) {
                testOkDialog.close();
            }
            if (typeof errorDialog !== "undefined" && errorDialog) {
                errorDialog.close();
            }
            if (backend && !backend.isBusy && typeof backend.syncJobsList === "function") {
                backend.syncJobsList();
            }
        }
    }

    onClosing: function(close) {
        // Closing the progress window does NOT cancel the active task!
        if (typeof cancelConfirmDialog !== "undefined" && cancelConfirmDialog) {
            cancelConfirmDialog.close();
        }
        if (backend && !backend.isBusy && typeof backend.syncJobsList === "function") {
            resetProgressState();
            backend.syncJobsList();
        }
    }

    onCanceled: {
        isCanceling = true;
        if (backend) {
            backend.cancelCurrentOperation();
        }
    }

    Connections {
        target: progressWindow.backend
        function onIsPausedChanged() {
            if (backend) {
                progressWindow.isPaused = backend.isPaused;
                if (!progressWindow.isPaused) {
                    progressWindow.lastProgressChangeTime = Date.now();
                    progressWindow.lastSampleTime = Date.now();
                }
            }
        }
        function onProgressChanged() {
            if (backend) {
                if (backend.isBusy && (progressWindow.isCompleted || progressWindow.isFailed)) {
                    progressWindow.isCompleted = false;
                    progressWindow.isFailed = false;
                }
                progressWindow.overallProgress = backend.overallProgress;
                progressWindow.fileProgress = backend.fileProgress;
                if (backend.totalFiles > 0) {
                    progressWindow.processedFiles = backend.processedFiles;
                    progressWindow.totalFiles = backend.totalFiles;
                }
                if (backend.currentFileName && backend.currentFileName.length > 0) {
                    progressWindow.currentFileName = backend.currentFileName;
                    progressWindow.currentFilePath = backend.currentFileName;
                }
                if (backend.currentOperationName && backend.currentOperationName.length > 0) {
                    progressWindow.title = backend.currentOperationName;
                }
                if (backend.totalBytes > 0) {
                    progressWindow.totalSizeMB = backend.totalBytes / (1024.0 * 1024.0);
                } else if (backend.jobModel && backend.jobModel.totalBytes > 0) {
                    progressWindow.totalSizeMB = backend.jobModel.totalBytes / (1024.0 * 1024.0);
                } else if (backend.totalArchiveSize > 0) {
                    progressWindow.totalSizeMB = backend.totalArchiveSize / (1024.0 * 1024.0);
                }
                var liveProcBytes = backend.totalProcessedBytes;
                if (liveProcBytes > 0) {
                    progressWindow.processedSizeMB = liveProcBytes / (1024.0 * 1024.0);
                } else if (progressWindow.totalSizeMB > 0) {
                    var curPct = progressWindow.displayOverallProgress;
                    if (curPct > 0) {
                        progressWindow.processedSizeMB = progressWindow.totalSizeMB * curPct;
                    }
                }
            }
        }
        function onOperationCompleted(op, success, msg) {
            var isCancel = isCanceling || (msg && msg.toLowerCase().indexOf("cancel") !== -1);
            if (isCancel) {
                isCanceling = false;
                isCompleted = false;
                isFailed = false;
                if (typeof testOkDialog !== "undefined" && testOkDialog) {
                    testOkDialog.close();
                }
                testCloseTimer.stop();
                progressTimer.stop();
                timeLeftTimer.stop();
                closeAndResetTimer.stop();
                progressWindow.close();
                progressWindow.resetProgressState();
                return;
            }
            if (success) {
                progressWindow.isCompleted = true;
                progressWindow.isFailed = false;
                progressWindow.overallProgress = 1.0;
                progressWindow.fileProgress = 1.0;
                progressWindow.remainingSeconds = 0;
                timeLeftTimer.stop();
                progressWindow.completed();
                if (op === "Test File" || op === "Test Archive" || op === "Recovery CRC Check") {
                    testOkDialog.showTestOk(
                        (op === "Test Archive" || op === "Recovery CRC Check") ? "Archive is OK" : "File is OK",
                        (op === "Test Archive" || op === "Recovery CRC Check") ? "Integrity verification passed" : "CRC32 checksum verified",
                        msg ? msg : ((op === "Test Archive") ? "All archive files and data blocks verified successfully!\nCRC32 checksums match TOC records." : "File data decrypted and verified successfully!\nCRC32 checksum matches archive entry."),
                        (op === "Test Archive" || op === "Recovery CRC Check") ? "\ue8e8" : "\ue86c"
                    );
                    testCloseTimer.restart();
                } else {
                    // Watch when the job is done and close the window and reset the timers
                    closeAndResetTimer.restart();
                }
            } else {
                progressWindow.isFailed = true;
                progressTimer.stop();
                timeLeftTimer.stop();
                testCloseTimer.stop();
                if (typeof testOkDialog !== "undefined" && testOkDialog) {
                    testOkDialog.close();
                }
                progressWindow.showError(op + " Failed", msg);
            }
        }
    }

    Timer {
        id: testCloseTimer
        interval: 3500
        repeat: false
        onTriggered: {
            if (typeof testOkDialog !== "undefined" && testOkDialog) {
                testOkDialog.close();
            }
            progressWindow.close();
            progressWindow.resetProgressState();
            if (backend && typeof backend.syncJobsList === "function") {
                backend.syncJobsList();
            }
        }
    }

    Timer {
        id: closeAndResetTimer
        interval: 600
        repeat: false
        onTriggered: {
            progressWindow.close();
            progressWindow.resetProgressState();
            if (backend && typeof backend.syncJobsList === "function") {
                backend.syncJobsList();
            }
        }
    }

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
    // --- Live Timer (Elapsed Time & Speed Graph) ---
    // ==========================================
    Timer {
        id: progressTimer
        interval: 1000
        running: progressWindow.visible && !progressWindow.isPaused
        repeat: true
        onTriggered: {
            progressWindow.elapsedSeconds += 1;

            if (progressWindow.remainingSeconds > 0) {
                progressWindow.remainingSeconds -= 1;
            }

            var now = Date.now();
            var dt = (progressWindow.lastSampleTime > 0) ? ((now - progressWindow.lastSampleTime) / 1000.0) : 1.0;
            if (dt <= 0.05) dt = 1.0;
            progressWindow.lastSampleTime = now;

            var hasActiveBackend = (backend && backend.isBusy);
            if (hasActiveBackend) {
                var curComp = backend.totalCompressedBytes;
                var curProc = backend.totalProcessedBytes;

                // Resilient fallback: If backend byte counters are zero but overallProgress and totalBytes exist,
                // derive processed bytes from overall progress
                var totB = backend.totalBytes;
                if (totB <= 0 && backend.jobModel && backend.jobModel.totalBytes > 0) {
                    totB = backend.jobModel.totalBytes;
                }
                if (totB <= 0 && backend.totalArchiveSize > 0) {
                    totB = backend.totalArchiveSize;
                }

                var activePct = progressWindow.displayOverallProgress;
                if (curProc <= 0 && curComp <= 0 && totB > 0 && activePct > 0) {
                    curProc = activePct * totB;
                }

                var deltaComp = (curComp >= progressWindow.lastCompressedBytes) ? (curComp - progressWindow.lastCompressedBytes) : curComp;
                var deltaProc = (curProc >= progressWindow.lastProcessedBytes) ? (curProc - progressWindow.lastProcessedBytes) : curProc;

                progressWindow.lastCompressedBytes = curComp;
                progressWindow.lastProcessedBytes = curProc;

                // Active throughput (raw bytes processed or written)
                var deltaBytes = Math.max(deltaProc, deltaComp);
                var curSpeed = (deltaBytes / (1024.0 * 1024.0)) / dt;

                progressWindow.speedMBs = curSpeed;
                speedGraph.addData(curSpeed);

                // Smoothed speed using exponential moving average
                if (progressWindow.smoothedSpeedMBs <= 0.01) {
                    progressWindow.smoothedSpeedMBs = curSpeed;
                } else if (curSpeed > 0.01) {
                    progressWindow.smoothedSpeedMBs = 0.70 * progressWindow.smoothedSpeedMBs + 0.30 * curSpeed;
                }
            } else {
                progressWindow.speedMBs = 0.0;
                speedGraph.addData(0.0);
            }
        }
    }

    // ==========================================
    // --- Time Left Calculation Timer (Every 5s) ---
    // Watches how long it takes for overall percentage to change,
    // avoiding UI lag caused by rapid progress bursts.
    // ==========================================
    Timer {
        id: timeLeftTimer
        interval: 5000
        running: progressWindow.visible && !progressWindow.isPaused && !progressWindow.isOperationDone
        repeat: true
        onTriggered: {
            var curProgress = progressWindow.displayOverallProgress;
            if (curProgress >= 0.999) {
                progressWindow.remainingSeconds = 0;
                return;
            }

            var now = Date.now();
            if (!progressWindow.lastProgressChangeTime || progressWindow.lastProgressChangeTime <= 0) {
                progressWindow.lastProgressChangeTime = now;
                progressWindow.lastObservedProgress = curProgress;
                return;
            }

            var deltaProgress = curProgress - progressWindow.lastObservedProgress;

            // If progress was reset backwards, re-synchronize baseline
            if (deltaProgress < 0) {
                progressWindow.lastObservedProgress = curProgress;
                progressWindow.lastProgressChangeTime = now;
                return;
            }

            // If the overall percentage has changed, calculate remaining time based on time taken
            if (deltaProgress > 0) {
                var timeElapsedSec = (now - progressWindow.lastProgressChangeTime) / 1000.0;
                if (timeElapsedSec > 0.05) {
                    var rate = deltaProgress / timeElapsedSec;
                    var remainingFraction = Math.max(0.0, 1.0 - curProgress);
                    var estRemaining = Math.round(remainingFraction / rate);
                    if (isFinite(estRemaining) && estRemaining >= 0) {
                        progressWindow.remainingSeconds = estRemaining;
                    }
                }
                // Percentage changed: update baseline to watch the next change
                progressWindow.lastObservedProgress = curProgress;
                progressWindow.lastProgressChangeTime = now;
            }
            // If deltaProgress <= 0:
            // The percentage has not changed yet. We keep watching and do NOT reset
            // lastObservedProgress or lastProgressChangeTime so the accumulated elapsed time is preserved.
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
                        font.weight: Font.DemiBold
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
                        text: Math.round(progressWindow.displayOverallProgress * 100) + "%"
                        font.family: Colors.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: progressWindow.seaGreenLight
                    }
                }

                // =========================================================
                // --- High-Performance Multi-Part Progress Bar ---
                // =========================================================
                MultiPartProgressBar {
                    id: multiPartProgress
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    implicitHeight: 32
                    forceText: true
                    flyoutDownward: true
                    customOverallProgress: (progressWindow.overallProgress > 0) ? progressWindow.overallProgress : -1.0
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
                Layout.preferredHeight: 74
                elapsedSeconds: progressWindow.elapsedSeconds
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
                    readonly property bool btnEnabled: !progressWindow.isOperationDone
                    opacity: btnEnabled ? 1.0 : 0.38
                    color: !btnEnabled ? Colors.bgElevated
                         : pauseMouse.containsPress ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.10))
                         : pauseMouse.containsMouse ? Colors.goldLightHover
                         : (progressWindow.isPaused ? Colors.goldLight : Colors.bgElevated)
                    border.color: !btnEnabled ? Colors.borderSubtle : (progressWindow.isPaused ? Colors.goldHover : Colors.goldBorder)
                    border.width: progressWindow.isPaused ? 1.5 : 1

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                    Behavior on opacity {
                        enabled: !progressWindow.isPaused
                        NumberAnimation { duration: 150 }
                    }

                    // Pulsing / blinking animation when operation is paused so user immediately notices
                    SequentialAnimation {
                        id: pauseBlinkAnim
                        running: progressWindow.isPaused && pauseBtn.btnEnabled && progressWindow.visible
                        loops: Animation.Infinite
                        NumberAnimation {
                            target: pauseBtn
                            property: "opacity"
                            from: 1.0
                            to: 0.30
                            duration: 550
                            easing.type: Easing.InOutQuad
                        }
                        NumberAnimation {
                            target: pauseBtn
                            property: "opacity"
                            from: 0.30
                            to: 1.0
                            duration: 550
                            easing.type: Easing.InOutQuad
                        }
                        onStopped: {
                            pauseBtn.opacity = pauseBtn.btnEnabled ? 1.0 : 0.38;
                        }
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: progressWindow.isPaused ? "\ue037" : "\ue034" // play_arrow / pause
                            font.family: materialIcons.name
                            font.pixelSize: 15
                            color: pauseBtn.btnEnabled ? (progressWindow.isPaused ? Colors.goldHover : Colors.goldPrimary) : Colors.textMuted
                        }

                        Text {
                            text: progressWindow.isPaused ? "Resume" : "Pause"
                            font.family: Colors.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: pauseBtn.btnEnabled ? (progressWindow.isPaused ? Colors.goldHover : Colors.textMain) : Colors.textMuted
                        }
                    }

                    MouseArea {
                        id: pauseMouse
                        anchors.fill: parent
                        enabled: pauseBtn.btnEnabled
                        hoverEnabled: pauseBtn.btnEnabled
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
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
                    readonly property bool btnEnabled: !progressWindow.isOperationDone
                    opacity: btnEnabled ? 1.0 : 0.38
                    color: !btnEnabled ? Colors.bgCard
                         : cancelMouse.containsPress ? Qt.rgba(0.88, 0.33, 0.33, 0.25)
                         : cancelMouse.containsMouse ? Qt.rgba(0.88, 0.33, 0.33, 0.14)
                         : Colors.bgCard
                    border.color: !btnEnabled ? Colors.borderSubtle : (cancelMouse.containsMouse ? "#e05353" : (Colors.isDarkMode ? Qt.rgba(0.88, 0.33, 0.33, 0.35) : Qt.rgba(0.88, 0.33, 0.33, 0.45)))
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: progressWindow.isCanceling ? "\ue5d5" : "\ue5cd" // refresh or close
                            font.family: materialIcons.name
                            font.pixelSize: 15
                            color: !cancelBtn.btnEnabled ? Colors.textMuted : (cancelMouse.containsMouse ? "#ef4444" : "#e05353")
                        }

                        Text {
                            text: progressWindow.isCanceling ? "Canceling..." : "Cancel"
                            font.family: Colors.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: !cancelBtn.btnEnabled ? Colors.textMuted : (cancelMouse.containsMouse ? "#ef4444" : Colors.textMain)
                        }
                    }

                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        enabled: cancelBtn.btnEnabled
                        hoverEnabled: cancelBtn.btnEnabled
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (cancelBtn.btnEnabled) {
                                cancelConfirmDialog.open()
                            }
                        }
                        scale: containsPress ? 0.96 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }
                    }
                }
            }
        }

        // =========================================================
        // --- Test Verification Dialog (Styled like ErrorDialog in Green) ---
        // =========================================================
        Dialog {
            id: testOkDialog
            anchors.centerIn: parent
            width: parent ? Math.min(parent.width - 36, 384) : 384
            modal: true
            focus: true
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
            padding: 16

            property string okTitle: "Archive is OK"
            property string okCategory: "Integrity verification passed"
            property string okDetail: "All archive files and data blocks verified successfully!\nCRC32 checksums match TOC records."
            property string okIcon: "\ue8e8" // verified_user / shield_check
            property bool copyFeedback: false

            function showTestOk(title, category, detail, iconGlyph) {
                okTitle = (title && title.length > 0) ? title : "Archive is OK";
                okCategory = (category && category.length > 0) ? category : "Integrity verification passed";
                okDetail = (detail && detail.length > 0) ? detail : "Verification completed successfully.";
                okIcon = (iconGlyph && iconGlyph.length > 0) ? iconGlyph : "\ue8e8";
                copyFeedback = false;
                open();
            }

            function dismissAndClose() {
                testCloseTimer.stop();
                testOkDialog.close();
                progressWindow.close();
                progressWindow.resetProgressState();
                if (typeof archiveInterface !== "undefined" && archiveInterface) {
                    archiveInterface.syncJobsList();
                }
            }

            onClosed: {
                testCloseTimer.stop();
                if (progressWindow.isCompleted && progressWindow.visible) {
                    progressWindow.close();
                    progressWindow.resetProgressState();
                    if (typeof archiveInterface !== "undefined" && archiveInterface) {
                        archiveInterface.syncJobsList();
                    }
                }
            }

            Overlay.modal: Rectangle {
                color: Colors.overlayModal
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            background: Rectangle {
                color: Colors.bgSurface
                radius: 14
                border.color: Colors.isDarkMode ? Qt.rgba(progressWindow.seaGreenLight.r, progressWindow.seaGreenLight.g, progressWindow.seaGreenLight.b, 0.5)
                                                : Qt.rgba(progressWindow.seaGreenPrimary.r, progressWindow.seaGreenPrimary.g, progressWindow.seaGreenPrimary.b, 0.55)
                border.width: 1.5

                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }

                // Top SeaGreen accent glow bar (matching ErrorDialog)
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    height: 2.5
                    radius: 1.25
                    color: progressWindow.seaGreenLight
                }
            }

            // Hidden clipboard helper
            TextInput {
                id: testOkClipboardHelper
                visible: false
            }

            Timer {
                id: testOkCopyFeedbackTimer
                interval: 1600
                repeat: false
                onTriggered: testOkDialog.copyFeedback = false
            }

            contentItem: ColumnLayout {
                spacing: 14

                // ==========================================
                // --- Header: Test Icon Badge, Title & Close ---
                // ==========================================
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Circular green test icon badge
                    Rectangle {
                        width: 40
                        height: 40
                        radius: 20
                        color: Colors.isDarkMode ? Qt.rgba(progressWindow.seaGreenLight.r, progressWindow.seaGreenLight.g, progressWindow.seaGreenLight.b, 0.16)
                                                 : Qt.rgba(progressWindow.seaGreenPrimary.r, progressWindow.seaGreenPrimary.g, progressWindow.seaGreenPrimary.b, 0.12)
                        border.color: Colors.isDarkMode ? Qt.rgba(progressWindow.seaGreenLight.r, progressWindow.seaGreenLight.g, progressWindow.seaGreenLight.b, 0.45)
                                                        : Qt.rgba(progressWindow.seaGreenPrimary.r, progressWindow.seaGreenPrimary.g, progressWindow.seaGreenPrimary.b, 0.35)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: testOkDialog.okIcon
                            font.family: materialIcons.name
                            font.pixelSize: 22
                            color: progressWindow.seaGreenLight
                        }
                    }

                    ColumnLayout {
                        spacing: 2
                        Layout.fillWidth: true

                        Text {
                            text: testOkDialog.okTitle
                            font.family: Colors.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: Colors.textMain
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: testOkDialog.okCategory
                            font.family: Colors.fontFamily
                            font.pixelSize: 11
                            color: Colors.textMuted
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Close button (X)
                    Rectangle {
                        width: 26
                        height: 26
                        radius: 13
                        color: testOkCloseMouse.containsMouse ? Qt.rgba(progressWindow.seaGreenLight.r, progressWindow.seaGreenLight.g, progressWindow.seaGreenLight.b, 0.18) : "transparent"
                        border.color: testOkCloseMouse.containsMouse ? progressWindow.seaGreenLight : Colors.borderSubtle
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "\ue5cd"
                            font.family: materialIcons.name
                            font.pixelSize: 14
                            color: testOkCloseMouse.containsMouse ? progressWindow.seaGreenLight : Colors.textMuted
                        }

                        MouseArea {
                            id: testOkCloseMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: testCloseTimer.stop()
                            onClicked: testOkDialog.dismissAndClose()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Colors.divider
                }

                // ==========================================
                // --- Detailed Verification Info Box ---
                // ==========================================
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: testOkDetailCol.implicitHeight + 18
                    radius: 8
                    color: Colors.bgInput
                    border.color: Colors.isDarkMode ? Qt.rgba(progressWindow.seaGreenLight.r, progressWindow.seaGreenLight.g, progressWindow.seaGreenLight.b, 0.25) : Colors.borderSubtle
                    border.width: 1

                    ColumnLayout {
                        id: testOkDetailCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: progressWindow.seaGreenLight
                            }

                            Text {
                                text: "VERIFICATION DETAILS"
                                font.family: Colors.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                color: progressWindow.seaGreenLight
                                Layout.fillWidth: true
                            }

                            // Copy report button (exact pattern from ErrorDialog)
                            Item {
                                implicitWidth: testOkCopyRow.implicitWidth
                                implicitHeight: testOkCopyRow.implicitHeight
                                opacity: testOkCopyMouse.containsMouse ? 1.0 : 0.75

                                RowLayout {
                                    id: testOkCopyRow
                                    anchors.fill: parent
                                    spacing: 4

                                    Text {
                                        text: testOkDialog.copyFeedback ? "\ue876" : "\ue14d" // checkmark or content_copy
                                        font.family: materialIcons.name
                                        font.pixelSize: 12
                                        color: testOkDialog.copyFeedback ? progressWindow.seaGreenLight : Colors.textMuted
                                    }

                                    Text {
                                        text: testOkDialog.copyFeedback ? "Copied" : "Copy"
                                        font.family: Colors.fontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                        color: testOkDialog.copyFeedback ? progressWindow.seaGreenLight : Colors.textMuted
                                    }
                                }

                                MouseArea {
                                    id: testOkCopyMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: testCloseTimer.stop()
                                    onClicked: {
                                        testOkClipboardHelper.text = testOkDialog.okDetail;
                                        testOkClipboardHelper.selectAll();
                                        testOkClipboardHelper.copy();
                                        testOkDialog.copyFeedback = true;
                                        testOkCopyFeedbackTimer.restart();
                                    }
                                }
                            }
                        }

                        Text {
                            id: testOkDetailText
                            text: testOkDialog.okDetail
                            color: Colors.textMain
                            font.family: "Cascadia Code, Consolas, Courier New, monospace"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            Layout.fillWidth: true
                            lineHeight: 1.25
                        }
                    }
                }

                // ==========================================
                // --- Footer: Action Button (OK) ---
                // ==========================================
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        implicitWidth: 110
                        implicitHeight: 34
                        radius: 6
                        color: testOkBtnMouse.containsPress ? Qt.darker(progressWindow.seaGreenPrimary, 1.2)
                             : (testOkBtnMouse.containsMouse ? progressWindow.seaGreenLight : progressWindow.seaGreenPrimary)

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
                                text: "OK"
                                font.family: Colors.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                color: "#ffffff"
                            }
                        }

                        MouseArea {
                            id: testOkBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: testCloseTimer.stop()
                            onClicked: testOkDialog.dismissAndClose()
                        }
                    }
                }
            }
        }

        ErrorDialog {
            id: errorDialog
            anchors.centerIn: parent
        }

        // =========================================================
        // --- Cancel Confirmation Dialog (Styled like ErrorDialog) ---
        // =========================================================
        Dialog {
            id: cancelConfirmDialog
            anchors.centerIn: parent
            width: parent ? Math.min(parent.width - 40, 440) : 440
            modal: true
            focus: true
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
            padding: 18

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

            contentItem: ColumnLayout {
                spacing: 14

                // Header: Warning Icon Badge, Title & Close Button
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
                            text: "\ue002" // warning icon
                            font.family: materialIcons.name
                            font.pixelSize: 22
                            color: "#e05353"
                        }
                    }

                    ColumnLayout {
                        spacing: 2
                        Layout.fillWidth: true

                        Text {
                            text: "Cancel Operation?"
                            font.family: Colors.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: Colors.textMain
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: "Active background task will be aborted"
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
                        color: cancelCloseMouse.containsMouse ? Qt.rgba(0.9, 0.3, 0.3, 0.2) : "transparent"
                        border.color: cancelCloseMouse.containsMouse ? "#d9534f" : Colors.borderSubtle
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "\ue5cd"
                            font.family: materialIcons.name
                            font.pixelSize: 14
                            color: cancelCloseMouse.containsMouse ? "#ff6b6b" : Colors.textMuted
                        }

                        MouseArea {
                            id: cancelCloseMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: cancelConfirmDialog.close()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Colors.divider
                }

                // Warning Message Box
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: cancelDetailCol.implicitHeight + 20
                    radius: 8
                    color: Colors.bgInput
                    border.color: Colors.isDarkMode ? Qt.rgba(0.9, 0.32, 0.32, 0.25) : Colors.borderSubtle
                    border.width: 1

                    ColumnLayout {
                        id: cancelDetailCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6

                        RowLayout {
                            spacing: 5
                            Text {
                                text: "\ue000" // error / alert
                                font.family: materialIcons.name
                                font.pixelSize: 13
                                color: "#e05353"
                            }
                            Text {
                                text: "CONFIRMATION REQUIRED"
                                font.family: Colors.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                color: "#e05353"
                            }
                        }

                        Text {
                            text: "Are you sure you want to cancel the current operation? The ongoing task will be immediately stopped, and any partial, uncommitted progress will be discarded."
                            color: Colors.textMain
                            font.family: Colors.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Normal
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            Layout.fillWidth: true
                            lineHeight: 1.25
                        }
                    }
                }

                // Footer: Action Buttons (No / Yes)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Item { Layout.fillWidth: true }

                    // No / Keep Running Button
                    Rectangle {
                        implicitWidth: 120
                        implicitHeight: 34
                        radius: 6
                        color: noCancelMouse.containsPress ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.12))
                             : (noCancelMouse.containsMouse ? Colors.bgHover : Colors.bgElevated)
                        border.color: noCancelMouse.containsMouse ? Colors.goldBorderHi : Colors.borderSubtle
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: "\ue5cd" // close
                                font.family: materialIcons.name
                                font.pixelSize: 14
                                color: Colors.textMuted
                            }

                            Text {
                                text: "No, Continue"
                                font.family: Colors.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: Colors.textMain
                            }
                        }

                        MouseArea {
                            id: noCancelMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: cancelConfirmDialog.close()
                        }
                    }

                    // Yes / Cancel Button
                    Rectangle {
                        implicitWidth: 120
                        implicitHeight: 34
                        radius: 6
                        color: yesCancelMouse.containsPress ? Qt.darker("#e05353", 1.25)
                             : (yesCancelMouse.containsMouse ? "#eb6b6b" : "#e05353")

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
                                text: "Yes, Cancel"
                                font.family: Colors.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                color: "#ffffff"
                            }
                        }

                        MouseArea {
                            id: yesCancelMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                cancelConfirmDialog.close();
                                progressWindow.isCanceling = true;
                                progressWindow.canceled();
                            }
                        }
                    }
                }
            }
        }
    }
}
