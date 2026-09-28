import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Dialogs
import UI

Page {
    id: root
    width: 580
    implicitWidth: 580
    Layout.preferredWidth: 580
    Layout.minimumWidth: 520
    Layout.maximumWidth: 680
    Layout.fillHeight: true
    Layout.fillWidth: false

    background: Rectangle {
        color: "transparent"
    }

    // Signals
    signal closeRequested
    signal itemSelected(var item)

    // Fonts
    FontLoader {
        id: materialIcons
        source: "Fonts/MaterialIconsRound-Regular.otf"
    }

    // Independent Recovery State (bound to recoveryInterface)
    readonly property var backend: (typeof recoveryInterface !== "undefined" && recoveryInterface) ? recoveryInterface : null

    readonly property bool hasActiveArchive: backend ? backend.hasArchive : false
    readonly property string archiveFilePath: backend ? backend.archiveFilePath : ""
    readonly property string archiveFileName: backend ? backend.archiveFileName : ""
    property var selectedItem: null

    // Metadata & TOC Diagnostic State
    readonly property string metadataHealthState: backend ? backend.metadataHealthState : ""
    readonly property string metadataDetails: backend ? backend.metadataDetails : ""
    readonly property bool isMetadataHealthy: backend ? backend.isMetadataHealthy : false

    readonly property string tocHealthState: backend ? backend.tocHealthState : ""
    readonly property string tocDetails: backend ? backend.tocDetails : ""
    readonly property bool isTocHealthy: backend ? backend.isTocHealthy : false

    // Precalculated recovery state counters directly from C++ background worker
    readonly property int okCount: backend ? backend.okCount : 0
    readonly property int foundOkCount: backend ? backend.foundOkCount : 0
    readonly property int truncatedCount: backend ? backend.truncatedCount : 0
    readonly property int notFoundCount: backend ? backend.notFoundCount : 0

    // Recovery Tree Find / Filter State & Shortcut
    property string recoveryFindQuery: ""

    Shortcut {
        sequence: "Ctrl+F"
        enabled: root.visible && root.hasActiveArchive
        onActivated: {
            if (stickyRecoveryHeaderFindBar) {
                stickyRecoveryHeaderFindBar.openFind();
            }
        }
    }

    Connections {
        target: root.backend
        function onRecoveryItemsChanged() {
            root.populateRecoveryData();
        }
        function onRecoveryCompleted(success, message) {
            if (!success) {
                errorDialog.showError("Recovery Analysis Failed", message);
            }
        }
    }
    readonly property color colorSeaGreen: "#10B981"
    readonly property color colorSeaGreenBg: Colors.isDarkMode ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.20) : Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.14)
    readonly property color colorSeaGreenBorder: Colors.isDarkMode ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.45) : Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.35)

    readonly property color colorTruncatedHatch: Colors.isDarkMode ? Qt.rgba(0.55, 0.58, 0.68, 0.30) : Qt.rgba(0.40, 0.45, 0.55, 0.24)
    readonly property color colorTruncatedBg: Colors.isDarkMode ? Qt.rgba(0.35, 0.38, 0.45, 0.14) : Qt.rgba(0.50, 0.55, 0.65, 0.10)
    readonly property color colorTruncatedBorder: Colors.isDarkMode ? Qt.rgba(0.55, 0.58, 0.68, 0.40) : Qt.rgba(0.40, 0.45, 0.55, 0.30)

    readonly property color colorNotFoundHatch: Colors.isDarkMode ? Qt.rgba(0.95, 0.30, 0.30, 0.35) : Qt.rgba(0.85, 0.20, 0.20, 0.28)
    readonly property color colorNotFoundBg: Colors.isDarkMode ? Qt.rgba(0.90, 0.20, 0.20, 0.16) : Qt.rgba(0.90, 0.15, 0.15, 0.08)
    readonly property color colorNotFoundBorder: Colors.isDarkMode ? Qt.rgba(0.95, 0.30, 0.30, 0.45) : Qt.rgba(0.85, 0.20, 0.20, 0.35)

   
    TextInput {
        id: clipboardHelper
        visible: false
    }

    property bool copyFeedback: false
    Timer {
        id: copyFeedbackTimer
        interval: 1500
        repeat: false
        onTriggered: root.copyFeedback = false
    }

    function copyToClipboard(text) {
        clipboardHelper.text = text;
        clipboardHelper.selectAll();
        clipboardHelper.copy();
        root.copyFeedback = true;
        copyFeedbackTimer.restart();
    }

    property string pendingRecoveryFilePath: ""

    
    function loadArchive(filePath) {
        if (!filePath || filePath.length === 0) return;

        let cleanPath = filePath;
        if (cleanPath.startsWith("file:///")) {
            if (cleanPath.length >= 10 && cleanPath.charAt(9) === ':')
                cleanPath = cleanPath.substring(8);
            else
                cleanPath = cleanPath.substring(7);
        } else if (cleanPath.startsWith("file://")) {
            cleanPath = cleanPath.substring(7);
        }
        cleanPath = decodeURIComponent(cleanPath);

        if (!cleanPath.toLowerCase().endsWith(".sda")) {
            let fName = cleanPath.split("/").pop().split("\\").pop();
            errorDialog.showError("Invalid Archive File", "The file '" + fName + "' is not a valid SecDet Archive (.sda).\n\nPlease choose a file with the .sda extension for recovery analysis.");
            return;
        }

        root.pendingRecoveryFilePath = cleanPath;
        passwordDialog.titleText = "Archive Recovery Password";
        passwordDialog.reasonDescription = "Enter password to decrypt and salvage archive entries:";
        passwordDialog.errorMessage = "";
        passwordDialog.open();
    }

    function unloadArchive() {
        root.pendingRecoveryFilePath = "";
        root.selectedItem = null;
        recoveryListModel.clear();
        root.selectedItemsCount = 0;
        if (root.backend) {
            root.backend.unloadArchive();
        }
    }

    function promptCloseSession() {
        if (root.hasActiveArchive) {
            closeRecoveryConfirmDialog.open();
        } else {
            root.closeRequested();
        }
    }

    property int selectedItemsCount: 0

    function updateSelectedItemsCount() {
        let cnt = 0;
        for (let i = 0; i < recoveryListModel.count; ++i) {
            if (recoveryListModel.get(i).checked) cnt++;
        }
        root.selectedItemsCount = cnt;
    }

    // Populate recovery state items from backend
    function populateRecoveryData() {
        recoveryListModel.clear();
        if (!root.backend) return;
        let items = root.backend.recoveryItems;
        if (!items) return;

        let selCount = 0;
        for (let i = 0; i < items.length; ++i) {
            let it = items[i];
            if (it.checked) selCount++;
            recoveryListModel.append({
                name: it.name,
                path: it.path,
                isFolder: it.isFolder,
                state: it.state,
                compSize: it.compSize,
                realSize: it.realSize,
                crc: it.crc,
                share: it.share,
                checked: it.checked
            });
        }
        root.selectedItemsCount = selCount;

        if (recoveryListModel.count > 0) {
            root.selectedItem = recoveryListModel.get(0);
        } else {
            root.selectedItem = null;
        }
    }

    ListModel {
        id: recoveryListModel
    }

    // Toggle all checkboxes
    function toggleSelectAll(selectAll) {
        for (let i = 0; i < recoveryListModel.count; ++i) {
            recoveryListModel.setProperty(i, "checked", selectAll);
        }
        root.selectedItemsCount = selectAll ? recoveryListModel.count : 0;
    }

    readonly property bool allItemsChecked: (recoveryListModel.count > 0) && (selectedItemsCount === recoveryListModel.count)

    // Batch Action: Extract Selected
    function executeBatchExtract() {
        if (selectedItemsCount === 0) {
            errorDialog.showError("No Files Selected", "Please select at least one file from the list to extract.");
            return;
        }

        let extractable = [];
        let missingCount = 0;

        for (let i = 0; i < recoveryListModel.count; ++i) {
            let it = recoveryListModel.get(i);
            if (it.checked) {
                if (it.state === "Not Found") {
                    missingCount++;
                } else {
                    extractable.push(it.path);
                }
            }
        }

        if (extractable.length === 0) {
            errorDialog.showError("Extraction Impossible", "All " + missingCount + " selected files are marked as 'Not Found' in the archive streams.\n\nNo valid payload blocks could be located for extraction.");
            return;
        }

        recoveryBatchFolderDialog.pendingPaths = extractable;
        recoveryBatchFolderDialog.open();
    }

    // Batch Action: CRC-32 Check
    function executeBatchCrcCheck() {
        if (selectedItemsCount === 0) {
            errorDialog.showError("No Files Selected", "Please select at least one file from the list to check CRC-32.");
            return;
        }

        let pathsToCheck = [];
        for (let i = 0; i < recoveryListModel.count; ++i) {
            let it = recoveryListModel.get(i);
            if (it.checked) {
                pathsToCheck.push(it.path);
            }
        }

        progressWindow.show();
        if (root.backend) {
            root.backend.testRecoveryBatch(pathsToCheck);
        }
    }

    // ==========================================
    // --- File Dialog for Independent Loading ---
    // ==========================================
    FileDialog {
        id: openRecoveryFileDialog
        title: "Open SecDet Archive for Recovery Analysis"
        nameFilters: ["SecDet Archive (*.sda)", "All Files (*.*)"]
        onAccepted: {
            root.loadArchive(selectedFile.toString());
        }
    }

    FolderDialog {
        id: recoveryBatchFolderDialog
        title: "Select Destination Directory for Recovery Extraction"
        property var pendingPaths: []
        onAccepted: {
            let outDir = selectedFolder.toString();
            progressWindow.show();
            if (root.backend) {
                root.backend.extractRecoveryBatch(pendingPaths, outDir);
            }
        }
    }

    // ==========================================
    // --- Global DropArea for .sda Files ---
    // ==========================================
    DropArea {
        id: pageDropArea
        anchors.fill: parent
        z: 50

        function isEventSupported(dragObj) {
            if (!dragObj) return false;
            return Boolean(dragObj.hasUrls);
        }

        onEntered: drag => {
            if (isEventSupported(drag)) {
                drag.acceptProposedAction();
            }
        }

        onPositionChanged: drag => {
            if (isEventSupported(drag)) {
                drag.acceptProposedAction();
            }
        }

        onDropped: drop => {
            if (drop.hasUrls && drop.urls.length > 0) {
                drop.acceptProposedAction();
                root.loadArchive(drop.urls[0].toString());
            }
        }
    }

    // Sleek Drag-Drop Overlay Banner
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12
        height: 42
        radius: 8
        z: 90
        color: Colors.isDarkMode ? Qt.rgba(0.10, 0.12, 0.16, 0.96) : Qt.rgba(0.98, 0.98, 0.99, 0.96)
        border.color: root.colorSeaGreen
        border.width: 1.5
        visible: pageDropArea.containsDrag
        opacity: pageDropArea.containsDrag ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 8

            Text {
                text: "\ue2c6" // file_upload
                font.family: materialIcons.name
                font.pixelSize: 18
                color: root.colorSeaGreen
            }

            Text {
                text: "Drop (.sda) file here to inspect in Recovery Tools"
                font.family: Colors.fontFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: Colors.textMain
                Layout.fillWidth: true
                elide: Text.ElideMiddle
            }

            Rectangle {
                implicitWidth: 96
                implicitHeight: 22
                radius: 4
                color: root.colorSeaGreen

                Text {
                    anchors.centerIn: parent
                    text: "Release to Open"
                    font.family: Colors.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    color: "#ffffff"
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10


        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: Colors.isDarkMode ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.18) : Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.14)
                border.color: root.colorSeaGreen
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "\ue869" // build / repair tool icon
                    font.family: materialIcons.name
                    font.pixelSize: 17
                    color: root.colorSeaGreen
                }
            }

            ColumnLayout {
                spacing: 1
                Layout.fillWidth: true

                Text {
                    text: root.hasActiveArchive ? ("Archive Recovery Tools • " + root.archiveFileName) : "Archive Recovery Tools"
                    font.family: Colors.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    color: Colors.textMain
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            // Quick Unload / Change Archive button
            Rectangle {
                visible: root.hasActiveArchive
                width: 26
                height: 26
                radius: 6
                color: changeMouse.containsMouse ? Colors.bgHover : "transparent"
                border.color: Colors.borderSubtle
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "\ue2c7" // folder_open
                    font.family: materialIcons.name
                    font.pixelSize: 14
                    color: changeMouse.containsMouse ? Colors.goldPrimary : Colors.textMuted
                }

                MouseArea {
                    id: changeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: openRecoveryFileDialog.open()
                }

                ToolTip.visible: changeMouse.containsMouse
                ToolTip.text: "Open another archive"
                ToolTip.delay: 400
            }

            // Close Page Button
            Rectangle {
                width: 26
                height: 26
                radius: 13
                color: closeMouse.containsMouse ? Qt.rgba(0.9, 0.3, 0.3, 0.2) : "transparent"
                border.color: closeMouse.containsMouse ? "#d9534f" : Colors.goldBorder
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "\ue5cd" // close
                    font.family: materialIcons.name
                    font.pixelSize: 14
                    color: closeMouse.containsMouse ? "#ff6b6b" : Colors.textMuted
                }
                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.promptCloseSession()
                }

                ToolTip.visible: closeMouse.containsMouse
                ToolTip.text: root.hasActiveArchive ? "Close recovery session" : "Close recovery"
                ToolTip.delay: 400
            }
        }
        
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.hasActiveArchive
            color: Colors.bgSurface
            radius: 10
            border.color: pageDropArea.containsDrag ? root.colorSeaGreen : Colors.borderSubtle
            border.width: pageDropArea.containsDrag ? 2 : 1

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 16
                width: Math.min(parent.width - 48, 360)

                // Large decorative badge
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 72
                    height: 72
                    radius: 36
                    color: Colors.isDarkMode ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.12) : Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.08)
                    border.color: root.colorSeaGreen
                    border.width: 1.5

                    Text {
                        anchors.centerIn: parent
                        text: "\ue869" // build
                        font.family: materialIcons.name
                        font.pixelSize: 34
                        color: root.colorSeaGreen
                    }
                }

                ColumnLayout {
                    spacing: 4
                    Layout.fillWidth: true

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Load an Archive for Recovery"
                        font.family: Colors.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        color: Colors.textMain
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Drag and drop a (.sda) file here or select one to reconstruct damaged or missing items."
                        font.family: Colors.fontFamily
                        font.pixelSize: 11
                        color: Colors.textMuted
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }

                // Load Archive Button
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 150
                    implicitHeight: 34
                    radius: 6
                    color: loadBtnMouse.containsPress ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.85) : loadBtnMouse.containsMouse ? root.colorSeaGreen : (Colors.isDarkMode ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.22) : Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.16))
                    border.color: root.colorSeaGreen
                    border.width: 1

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: "\ue2c7" // folder_open
                            font.family: materialIcons.name
                            font.pixelSize: 16
                            color: loadBtnMouse.containsMouse ? "#ffffff" : root.colorSeaGreen
                        }

                        Text {
                            text: "Load Archive (.sda)"
                            font.family: Colors.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: loadBtnMouse.containsMouse ? "#ffffff" : Colors.textMain
                        }
                    }

                    MouseArea {
                        id: loadBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: openRecoveryFileDialog.open()
                    }
                }
            }
        }
        

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8
            visible: root.hasActiveArchive

            // =========================================================
            // --- Diagnostic Health Banner: Metadata & TOC States ---
            // =========================================================
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 52
                radius: 8
                color: Colors.bgCard
                border.color: Colors.borderSubtle
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    // 1. Metadata Health
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            width: 28
                            height: 28
                            radius: 14
                            color: root.isMetadataHealthy ? (Colors.isDarkMode ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.20) : Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.14))
                                                          : (Colors.isDarkMode ? Qt.rgba(0.9, 0.2, 0.2, 0.20) : Qt.rgba(0.9, 0.2, 0.2, 0.14))
                            border.color: root.isMetadataHealthy ? root.colorSeaGreen : "#ef4444"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: root.isMetadataHealthy ? "\ue86c" : "\ue000" // check_circle or error
                                font.family: materialIcons.name
                                font.pixelSize: 16
                                color: root.isMetadataHealthy ? root.colorSeaGreen : "#ef4444"
                            }
                        }

                        ColumnLayout {
                            spacing: 1
                            Layout.fillWidth: true

                            RowLayout {
                                spacing: 6
                                Text {
                                    text: "METADATA HEADER"
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                    color: Colors.textMuted
                                }
                                Rectangle {
                                    implicitWidth: 54
                                    implicitHeight: 14
                                    radius: 3
                                    color: root.isMetadataHealthy ? (Colors.isDarkMode ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.25) : Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.18))
                                                                  : (Colors.isDarkMode ? Qt.rgba(0.9, 0.2, 0.2, 0.25) : Qt.rgba(0.9, 0.2, 0.2, 0.18))
                                    Text {
                                        anchors.centerIn: parent
                                        text: root.isMetadataHealthy ? "HEALTHY" : "CORRUPT"
                                        font.family: Colors.fontFamily
                                        font.pixelSize: 8
                                        font.weight: Font.Bold
                                        color: root.isMetadataHealthy ? root.colorSeaGreen : "#ef4444"
                                    }
                                }
                            }

                            Text {
                                text: root.metadataDetails
                                font.family: Colors.fontFamily
                                font.pixelSize: 11
                                color: Colors.textMain
                                elide: Text.ElideRight
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                        }
                    }

                    // Divider between Metadata and TOC
                    Rectangle {
                        width: 1
                        height: 32
                        color: Colors.divider
                    }

                    // 2. TOC Health
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            width: 28
                            height: 28
                            radius: 14
                            color: root.isTocHealthy ? (Colors.isDarkMode ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.20) : Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.14))
                                                     : (Colors.isDarkMode ? Qt.rgba(245 / 255, 158 / 255, 11 / 255, 0.20) : Qt.rgba(217 / 255, 119 / 255, 6 / 255, 0.14))
                            border.color: root.isTocHealthy ? root.colorSeaGreen : (Colors.isDarkMode ? "#fbbf24" : "#d97706")
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: root.isTocHealthy ? "\ue86c" : "\ue002" // check_circle or warning
                                font.family: materialIcons.name
                                font.pixelSize: 16
                                color: root.isTocHealthy ? root.colorSeaGreen : (Colors.isDarkMode ? "#fbbf24" : "#d97706")
                            }
                        }

                        ColumnLayout {
                            spacing: 1
                            Layout.fillWidth: true

                            RowLayout {
                                spacing: 6
                                Text {
                                    text: "TABLE OF CONTENTS"
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                    color: Colors.textMuted
                                }
                                Rectangle {
                                    implicitWidth: 66
                                    implicitHeight: 14
                                    radius: 3
                                    color: root.isTocHealthy ? (Colors.isDarkMode ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.25) : Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.18))
                                                             : (Colors.isDarkMode ? Qt.rgba(245 / 255, 158 / 255, 11 / 255, 0.25) : Qt.rgba(217 / 255, 119 / 255, 6 / 255, 0.18))
                                    Text {
                                        anchors.centerIn: parent
                                        text: root.isTocHealthy ? "VALID" : "TRUNCATED"
                                        font.family: Colors.fontFamily
                                        font.pixelSize: 8
                                        font.weight: Font.Bold
                                        color: root.isTocHealthy ? root.colorSeaGreen : (Colors.isDarkMode ? "#fbbf24" : "#d97706")
                                    }
                                }
                            }

                            Text {
                                text: root.tocDetails
                                font.family: Colors.fontFamily
                                font.pixelSize: 11
                                color: Colors.textMain
                                elide: Text.ElideRight
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            // Recovery Status Pill Summary Strip
            Rectangle {
                Layout.fillWidth: true
                height: 32
                radius: 6
                color: Colors.bgCard
                border.color: Colors.borderSubtle
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 12

                    // OK count
                    RowLayout {
                        spacing: 4
                        Rectangle { width: 6; height: 6; radius: 3; color: Colors.goldPrimary }
                        Text { text: "Ok: " + root.okCount; font.family: Colors.fontFamily; font.pixelSize: 10; font.weight: Font.DemiBold; color: Colors.textMain }
                    }
                    Rectangle { width: 1; height: 12; color: Colors.divider }

                    // Found OK count
                    RowLayout {
                        spacing: 4
                        Rectangle { width: 6; height: 6; radius: 3; color: root.colorSeaGreen }
                        Text { text: "Found OK: " + root.foundOkCount; font.family: Colors.fontFamily; font.pixelSize: 10; font.weight: Font.DemiBold; color: root.colorSeaGreen }
                    }
                    Rectangle { width: 1; height: 12; color: Colors.divider }

                    // Found Truncated count
                    RowLayout {
                        spacing: 4
                        Rectangle { width: 6; height: 6; radius: 3; color: Colors.textMuted }
                        Text { text: "Truncated: " + root.truncatedCount; font.family: Colors.fontFamily; font.pixelSize: 10; font.weight: Font.DemiBold; color: Colors.textMuted }
                    }
                    Rectangle { width: 1; height: 12; color: Colors.divider }

                    // Not Found count
                    RowLayout {
                        spacing: 4
                        Rectangle { width: 6; height: 6; radius: 3; color: "#ef4444" }
                        Text { text: "Not Found: " + root.notFoundCount; font.family: Colors.fontFamily; font.pixelSize: 10; font.weight: Font.DemiBold; color: "#ef4444" }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "Selected: " + root.selectedItemsCount + " / " + recoveryListModel.count
                        font.family: Colors.fontFamily
                        font.pixelSize: 10
                        color: Colors.textMuted
                    }
                }
            }

            // ==========================================
            // --- 1. Recovery File Tree View Card ---
            // ==========================================
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8
                color: Colors.bgSurface
                border.color: Colors.borderSubtle
                border.width: 1
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    // Sticky Tree Header
                    Rectangle {
                        id: stickyRecoveryHeader
                        Layout.fillWidth: true
                        height: 28
                        color: Colors.bgElevated
                        radius: 5
                        border.color: Colors.borderSubtle
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            // Header Select-All Checkbox
                            Rectangle {
                                width: 14
                                height: 14
                                radius: 3
                                color: root.allItemsChecked ? Colors.goldPrimary : (headerCheckMouse.containsMouse ? Colors.bgHover : "transparent")
                                border.color: root.allItemsChecked ? Colors.goldPrimary : Colors.goldBorder
                                border.width: 1
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    anchors.centerIn: parent
                                    visible: root.allItemsChecked
                                    text: "\ue876" // checkmark
                                    font.family: materialIcons.name
                                    font.pixelSize: 10
                                    color: Colors.textOnGold
                                    font.weight: Font.Bold
                                }

                                MouseArea {
                                    id: headerCheckMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.toggleSelectAll(!root.allItemsChecked);
                                    }
                                }
                            }

                            // Header: Name
                            Text {
                                text: "File Name"
                                color: Colors.textMuted
                                font.family: Colors.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                Layout.fillWidth: true
                            }

                            Rectangle { width: 1; height: 12; color: Colors.divider }

                            // Header: Status
                            Text {
                                text: "Status"
                                color: Colors.textMuted
                                font.family: Colors.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                Layout.preferredWidth: 100
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Rectangle { width: 1; height: 12; color: Colors.divider }

                            // Header: Size
                            Text {
                                text: "Real Size"
                                color: Colors.textMuted
                                font.family: Colors.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                Layout.preferredWidth: 70
                                horizontalAlignment: Text.AlignRight
                            }

                            Rectangle { width: 1; height: 12; color: Colors.divider }

                            // Header: CRC
                            Text {
                                text: "CRC-32"
                                color: Colors.textMuted
                                font.family: Colors.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                Layout.preferredWidth: 75
                                horizontalAlignment: Text.AlignRight
                            }

                            // Reserved space slot for circular find button
                            Item {
                                Layout.preferredWidth: 26
                                Layout.fillHeight: true
                            }
                        }

                        // Circular Find Button (Morphs into width-expanding text input)
                        Rectangle {
                            id: stickyRecoveryHeaderFindBar
                            anchors.right: parent.right
                            anchors.rightMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            z: 20

                            property bool isOpen: false
                            width: isOpen ? 230 : 24
                            height: 24
                            radius: 12

                            color: isOpen ? Colors.bgElevated : (recFindBtnMouse.containsMouse ? Colors.bgHover : Colors.bgSurface)
                            border.color: isOpen ? Colors.goldPrimary : (recFindBtnMouse.containsMouse ? Colors.goldPrimary : Colors.borderSubtle)
                            border.width: isOpen ? 1.5 : 1

                            Behavior on width {
                                NumberAnimation {
                                    duration: 220
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            MouseArea {
                                id: recFindBtnMouse
                                anchors.fill: parent
                                enabled: !stickyRecoveryHeaderFindBar.isOpen
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    stickyRecoveryHeaderFindBar.openFind();
                                }
                            }

                            ToolTip.visible: recFindBtnMouse.containsMouse && !stickyRecoveryHeaderFindBar.isOpen
                            ToolTip.delay: 400
                            ToolTip.text: "Find files (Ctrl+F)"

                            function openFind() {
                                isOpen = true;
                                Qt.callLater(function() {
                                    recFindInput.forceActiveFocus();
                                    recFindInput.selectAll();
                                });
                            }

                            function closeFind() {
                                recFindInput.text = "";
                                root.recoveryFindQuery = "";
                                isOpen = false;
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: stickyRecoveryHeaderFindBar.isOpen ? 7 : 5
                                anchors.rightMargin: stickyRecoveryHeaderFindBar.isOpen ? 4 : 5
                                spacing: 4

                                Text {
                                    text: "\ue8b6"
                                    font.family: materialIcons.name
                                    font.pixelSize: 13
                                    color: stickyRecoveryHeaderFindBar.isOpen ? Colors.goldPrimary : (recFindBtnMouse.containsMouse ? Colors.goldPrimary : Colors.textMuted)
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.preferredWidth: 14
                                    horizontalAlignment: Text.AlignHCenter

                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: stickyRecoveryHeaderFindBar.isOpen
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            recFindInput.forceActiveFocus();
                                            recFindInput.accepted();
                                        }
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    visible: stickyRecoveryHeaderFindBar.isOpen || stickyRecoveryHeaderFindBar.width > 35
                                    clip: true

                                    TextInput {
                                        id: recFindInput
                                        anchors.fill: parent
                                        verticalAlignment: TextInput.AlignVCenter
                                        font.family: Colors.fontFamily
                                        font.pixelSize: 11
                                        color: Colors.textMain
                                        selectionColor: Colors.goldPrimary
                                        selectedTextColor: Colors.textOnGold
                                        selectByMouse: true
                                        activeFocusOnTab: true

                                        onAccepted: {
                                            root.recoveryFindQuery = text;
                                        }

                                        onTextChanged: {
                                            if (text.trim().length === 0 && root.recoveryFindQuery.length > 0) {
                                                root.recoveryFindQuery = "";
                                            }
                                        }

                                        Keys.onEscapePressed: {
                                            if (text.length > 0) {
                                                text = "";
                                                root.recoveryFindQuery = "";
                                            } else {
                                                stickyRecoveryHeaderFindBar.closeFind();
                                            }
                                        }
                                    }

                                    Text {
                                        anchors.fill: parent
                                        verticalAlignment: Text.AlignVCenter
                                        visible: !recFindInput.text && !recFindInput.activeFocus
                                        text: "Filter files..."
                                        color: Colors.textMuted
                                        font.family: Colors.fontFamily
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }
                                }

                                Rectangle {
                                    visible: stickyRecoveryHeaderFindBar.isOpen
                                    Layout.preferredWidth: 16
                                    Layout.preferredHeight: 16
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: 8
                                    color: recCloseMouse.containsMouse ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.08)) : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\ue5cd"
                                        font.family: materialIcons.name
                                        font.pixelSize: 12
                                        color: recCloseMouse.containsMouse ? Colors.goldPrimary : Colors.textMuted
                                    }

                                    MouseArea {
                                        id: recCloseMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (recFindInput.text.length > 0) {
                                                recFindInput.text = "";
                                                root.recoveryFindQuery = "";
                                                recFindInput.forceActiveFocus();
                                            } else {
                                                stickyRecoveryHeaderFindBar.closeFind();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Virtualized File Tree ListView
                    ListView {
                        id: recoveryTreeListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: (root.recoveryFindQuery.trim().length > 0) ? 0 : 2
                        boundsBehavior: Flickable.StopAtBounds
                        model: recoveryListModel

                        ScrollBar.vertical: Basic.ScrollBar {
                            active: recoveryTreeListView.moving || recoveryTreeListView.flicking
                            policy: ScrollBar.AsNeeded
                            contentItem: Rectangle {
                                implicitWidth: 5
                                radius: 2.5
                                color: parent.pressed ? Colors.goldPrimary : parent.hovered ? Colors.goldHover : (Colors.isDarkMode ? Qt.rgba(0.9, 0.76, 0.35, 0.35) : Qt.rgba(0.69, 0.51, 0.12, 0.35))
                            }
                        }

                        delegate: Item {
                            id: rowDelegate
                            width: recoveryTreeListView.width
                            readonly property string itemName: model.name || ""
                            readonly property string itemPath: model.path || ""
                            readonly property bool isSearching: root.recoveryFindQuery.trim().length > 0
                            readonly property bool matchesFilter: {
                                if (!isSearching) return true;
                                let q = root.recoveryFindQuery.trim().toLowerCase();
                                let nameMatch = itemName.toLowerCase().indexOf(q) !== -1;
                                let pathMatch = itemPath.toLowerCase().indexOf(q) !== -1;
                                return nameMatch || pathMatch;
                            }
                            readonly property bool isRowVisible: matchesFilter

                            height: isRowVisible ? 34 : 0
                            visible: isRowVisible
                            clip: true

                            readonly property string itemState: model.state || "Ok"
                            readonly property bool isSelected: (root.selectedItem && root.selectedItem.path === model.path)
                            readonly property bool isChecked: model.checked

                            Rectangle {
                                id: rowBackground
                                anchors.fill: parent
                                anchors.bottomMargin: (root.recoveryFindQuery.trim().length > 0) ? 2 : 0
                                radius: 6
                                clip: true

                                // Base background color depending on state
                                color: {
                                    if (rowDelegate.itemState === "Found OK") {
                                        return root.colorSeaGreenBg;
                                    } else if (rowDelegate.itemState === "Found Truncated") {
                                        return root.colorTruncatedBg;
                                    } else if (rowDelegate.itemState === "Not Found") {
                                        return root.colorNotFoundBg;
                                    } else {
                                        // "Ok" state
                                        return rowDelegate.isSelected ? (Colors.isDarkMode ? Qt.rgba(0.32, 0.36, 0.44, 0.70) : Qt.rgba(0.55, 0.58, 0.65, 0.70))
                                                                      : rowMouse.containsPress ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.08))
                                                                      : rowMouse.containsMouse ? Colors.bgHover : "transparent";
                                    }
                                }

                                border.color: {
                                    if (rowDelegate.isSelected) {
                                        return Colors.goldPrimary;
                                    } else if (rowDelegate.itemState === "Found OK") {
                                        return root.colorSeaGreenBorder;
                                    } else if (rowDelegate.itemState === "Found Truncated") {
                                        return root.colorTruncatedBorder;
                                    } else if (rowDelegate.itemState === "Not Found") {
                                        return root.colorNotFoundBorder;
                                    } else {
                                        return "transparent";
                                    }
                                }
                                border.width: rowDelegate.isSelected ? 1.5 : (rowDelegate.itemState !== "Ok" ? 1 : 0)

                                Behavior on color { ColorAnimation { duration: 120 } }
                                Behavior on border.color { ColorAnimation { duration: 120 } }

                                // Diagonal Hatchery Pattern Canvas for "Found Truncated" and "Not Found"
                                Canvas {
                                    id: hatchCanvas
                                    anchors.fill: parent
                                    visible: (rowDelegate.itemState === "Found Truncated" || rowDelegate.itemState === "Not Found")
                                    renderTarget: Canvas.Image

                                    onPaint: {
                                        let ctx = getContext("2d");
                                        ctx.clearRect(0, 0, width, height);

                                        if (rowDelegate.itemState === "Found Truncated") {
                                            ctx.strokeStyle = root.colorTruncatedHatch;
                                        } else if (rowDelegate.itemState === "Not Found") {
                                            ctx.strokeStyle = root.colorNotFoundHatch;
                                        } else {
                                            return;
                                        }

                                        ctx.lineWidth = 1.5;
                                        ctx.beginPath();
                                        let step = 11;
                                        let h = height;
                                        let w = width;

                                        // Draw 45 degree parallel diagonal stripes
                                        for (let x = -h; x <= w + step; x += step) {
                                            ctx.moveTo(x, h);
                                            ctx.lineTo(x + h, 0);
                                        }
                                        ctx.stroke();
                                    }

                                    onWidthChanged: requestPaint()
                                    onHeightChanged: requestPaint()

                                    Connections {
                                        target: Colors
                                        function onIsDarkModeChanged() {
                                            hatchCanvas.requestPaint();
                                        }
                                    }
                                }

                                // Selection Left Border Accent
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 4
                                    width: 3
                                    radius: 1.5
                                    color: {
                                        if (rowDelegate.itemState === "Found OK") return root.colorSeaGreen;
                                        if (rowDelegate.itemState === "Not Found") return "#ef4444";
                                        if (rowDelegate.itemState === "Found Truncated") return "#94a3b8";
                                        return Colors.goldPrimary;
                                    }
                                    visible: rowDelegate.isSelected
                                }

                                // Row Contents
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    // Most Left Checkbox Container
                                    Item {
                                        width: 22
                                        height: 22
                                        Layout.alignment: Qt.AlignVCenter
                                        z: 10

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 14
                                            height: 14
                                            radius: 3
                                            color: model.checked ? Colors.goldPrimary : (checkMouse.containsMouse ? Colors.bgHover : "transparent")
                                            border.color: model.checked ? Colors.goldPrimary : Colors.goldBorder
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                visible: Boolean(model.checked)
                                                text: "\ue876" // checkmark
                                                font.family: materialIcons.name
                                                font.pixelSize: 10
                                                color: Colors.textOnGold
                                                font.weight: Font.Bold
                                            }
                                        }

                                        MouseArea {
                                            id: checkMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            z: 10
                                            preventStealing: true
                                            onClicked: mouse => {
                                                mouse.accepted = true;
                                                let nextVal = !Boolean(model.checked);
                                                recoveryListModel.setProperty(index, "checked", nextVal);
                                                if (nextVal) root.selectedItemsCount++; else root.selectedItemsCount--;
                                                if (root.selectedItem && root.selectedItem.path === model.path) {
                                                    root.selectedItem.checked = nextVal;
                                                }
                                            }
                                        }
                                    }

                                    // File / Folder Icon
                                    Text {
                                        text: model.isFolder ? "\ue2c7" : "\ue873"
                                        font.family: materialIcons.name
                                        font.pixelSize: 16
                                        color: {
                                            if (rowDelegate.itemState === "Found OK") return root.colorSeaGreen;
                                            if (rowDelegate.itemState === "Not Found") return "#ef4444";
                                            if (rowDelegate.itemState === "Found Truncated") return Colors.textMuted;
                                            return Colors.goldPrimary;
                                        }
                                        Layout.preferredWidth: 16
                                    }

                                    // File Name
                                    Text {
                                        text: model.name || ""
                                        font.family: Colors.fontFamily
                                        font.pixelSize: 11
                                        font.weight: rowDelegate.isSelected ? Font.Bold : Font.Medium
                                        color: Colors.textMain
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    // Finding Match Badge
                                    Rectangle {
                                        visible: rowDelegate.isSearching && rowDelegate.matchesFilter
                                        Layout.preferredHeight: 18
                                        Layout.preferredWidth: 64
                                        radius: 9
                                        color: Colors.isDarkMode ? Qt.rgba(0.9, 0.76, 0.35, 0.18) : Qt.rgba(0.69, 0.51, 0.12, 0.14)
                                        border.color: Colors.goldBorder
                                        border.width: 1

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 3
                                            Text {
                                                text: "\ue8b6"
                                                font.family: materialIcons.name
                                                font.pixelSize: 10
                                                color: Colors.goldPrimary
                                            }
                                            Text {
                                                text: "1 match"
                                                font.family: Colors.fontFamily
                                                font.pixelSize: 10
                                                font.weight: Font.DemiBold
                                                color: Colors.goldPrimary
                                            }
                                        }
                                    }

                                    // Status Badge Pill
                                    Rectangle {
                                        Layout.preferredWidth: 100
                                        Layout.preferredHeight: 19
                                        radius: 4
                                        color: {
                                            if (rowDelegate.itemState === "Found OK") return Colors.isDarkMode ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.28) : Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.20);
                                            if (rowDelegate.itemState === "Not Found") return Colors.isDarkMode ? Qt.rgba(0.9, 0.2, 0.2, 0.28) : Qt.rgba(0.9, 0.2, 0.2, 0.18);
                                            if (rowDelegate.itemState === "Found Truncated") return Colors.isDarkMode ? Qt.rgba(0.4, 0.45, 0.55, 0.26) : Qt.rgba(0.4, 0.45, 0.55, 0.18);
                                            return Colors.goldLight;
                                        }
                                        border.color: {
                                            if (rowDelegate.itemState === "Found OK") return root.colorSeaGreen;
                                            if (rowDelegate.itemState === "Not Found") return "#ef4444";
                                            if (rowDelegate.itemState === "Found Truncated") return "#94a3b8";
                                            return Colors.goldBorder;
                                        }
                                        border.width: 1

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 3

                                            Text {
                                                text: {
                                                    if (rowDelegate.itemState === "Found OK") return "\ue86c"; // check_circle
                                                    if (rowDelegate.itemState === "Not Found") return "\ue5c9"; // cancel
                                                    if (rowDelegate.itemState === "Found Truncated") return "\ue002"; // warning
                                                    return "\ue876"; // checkmark
                                                }
                                                font.family: materialIcons.name
                                                font.pixelSize: 10
                                                color: {
                                                    if (rowDelegate.itemState === "Found OK") return root.colorSeaGreen;
                                                    if (rowDelegate.itemState === "Not Found") return "#ef4444";
                                                    if (rowDelegate.itemState === "Found Truncated") return "#94a3b8";
                                                    return Colors.goldPrimary;
                                                }
                                            }

                                            Text {
                                                text: model.state.toUpperCase()
                                                font.family: Colors.fontFamily
                                                font.pixelSize: 8
                                                font.weight: Font.Bold
                                                color: {
                                                    if (rowDelegate.itemState === "Found OK") return root.colorSeaGreen;
                                                    if (rowDelegate.itemState === "Not Found") return "#ef4444";
                                                    if (rowDelegate.itemState === "Found Truncated") return Colors.isDarkMode ? "#cbd5e1" : "#475569";
                                                    return Colors.goldPrimary;
                                                }
                                            }
                                        }
                                    }

                                    // Real Size Column
                                    Text {
                                        text: model.realSize || "-"
                                        font.family: Colors.fontFamily
                                        font.pixelSize: 10
                                        color: Colors.textMuted
                                        Layout.preferredWidth: 70
                                        horizontalAlignment: Text.AlignRight
                                        elide: Text.ElideRight
                                    }

                                    // CRC-32 Column
                                    Text {
                                        text: model.crc || "-"
                                        font.family: "Consolas, Segoe UI, monospace"
                                        font.pixelSize: 9
                                        color: (model.crc && model.crc !== "N/A") ? Colors.goldPrimary : Colors.textMuted
                                        Layout.preferredWidth: 75
                                        horizontalAlignment: Text.AlignRight
                                        elide: Text.ElideRight
                                    }
                                }

                                // MouseArea: Selection, Drag options (empty handlers for now), and Right-Click Context Menu
                                MouseArea {
                                    id: rowMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.OpenHandCursor

                                    // Preserved drag initiation tracking (handlers empty for now)
                                    property real pressX: -9999
                                    property real pressY: -9999
                                    property bool dragTriggered: false

                                    onPressed: mouse => {
                                        if (mouse.button === Qt.LeftButton) {
                                            if (mouse.x <= 34) return;
                                            pressX = mouse.x;
                                            pressY = mouse.y;
                                            dragTriggered = false;
                                        }
                                    }

                                    onPositionChanged: mouse => {
                                        if (pressed && (mouse.buttons & Qt.LeftButton) && pressX >= 0 && !dragTriggered) {
                                            let dist = Math.sqrt(Math.pow(mouse.x - pressX, 2) + Math.pow(mouse.y - pressY, 2));
                                            if (dist > 8) {
                                                dragTriggered = true;
                                                // Keep drag options on this file tree but for now let the drag handlers be empty
                                                // [Drag Handler Stubbed for Future Implementation]
                                            }
                                        }
                                    }

                                    onReleased: mouse => {
                                        pressX = -9999;
                                        pressY = -9999;
                                        dragTriggered = false;
                                    }

                                    onClicked: mouse => {
                                        if (dragTriggered) {
                                            dragTriggered = false;
                                            return;
                                        }

                                        if (mouse.x <= 34 && mouse.button === Qt.LeftButton) {
                                            let nextVal = !Boolean(model.checked);
                                            recoveryListModel.setProperty(index, "checked", nextVal);
                                            if (nextVal) root.selectedItemsCount++; else root.selectedItemsCount--;
                                            if (root.selectedItem && root.selectedItem.path === model.path) {
                                                root.selectedItem.checked = nextVal;
                                            }
                                            return;
                                        }

                                        let currentData = {
                                            name: model.name,
                                            path: model.path,
                                            isFolder: model.isFolder,
                                            state: model.state,
                                            compSize: model.compSize,
                                            realSize: model.realSize,
                                            crc: model.crc,
                                            share: model.share,
                                            checked: model.checked
                                        };

                                        root.selectedItem = currentData;
                                        root.itemSelected(currentData);

                                        if (mouse.button === Qt.RightButton) {
                                            recoveryContextMenu.targetItem = currentData;
                                            let globalPt = mapToItem(root, mouse.x, mouse.y);
                                            recoveryContextMenu.x = Math.min(globalPt.x, root.width - recoveryContextMenu.width - 8);
                                            recoveryContextMenu.y = Math.min(globalPt.y, root.height - recoveryContextMenu.height - 8);
                                            recoveryContextMenu.open();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // =========================================================
            // --- Batch Action Buttons Row (Just Below File Tree) ---
            // =========================================================
            RowLayout {
                Layout.fillWidth: true
                height: 32
                spacing: 8

                // 1. Extract Selected Button
                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    radius: 6
                    readonly property bool isActionEnabled: root.selectedItemsCount > 0
                    color: !isActionEnabled ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(0, 0, 0, 0.04))
                                            : extractBatchMouse.containsPress ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.9)
                                            : extractBatchMouse.containsMouse ? root.colorSeaGreen
                                            : (Colors.isDarkMode ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.22) : Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.16))
                    border.color: !isActionEnabled ? Colors.borderSubtle : root.colorSeaGreen
                    border.width: 1
                    opacity: isActionEnabled ? 1.0 : 0.45

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: "\ue2c4" // file_download / extract
                            font.family: materialIcons.name
                            font.pixelSize: 15
                            color: (!parent.parent.isActionEnabled) ? Colors.textMuted
                                                                   : extractBatchMouse.containsMouse ? "#ffffff" : root.colorSeaGreen
                        }

                        Text {
                            text: root.selectedItemsCount > 0 ? ("Extract Selected (" + root.selectedItemsCount + ")") : "Extract Selected"
                            font.family: Colors.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: (!parent.parent.isActionEnabled) ? Colors.textMuted
                                                                   : extractBatchMouse.containsMouse ? "#ffffff" : Colors.textMain
                        }
                    }

                    MouseArea {
                        id: extractBatchMouse
                        anchors.fill: parent
                        enabled: parent.isActionEnabled
                        hoverEnabled: enabled
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.executeBatchExtract()
                    }
                }

                // 2. Deselect / Select All Button
                Rectangle {
                    implicitWidth: 105
                    height: 32
                    radius: 6
                    readonly property bool hasAnySelected: root.selectedItemsCount > 0
                    color: deselectBatchMouse.containsPress ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.10))
                                                           : deselectBatchMouse.containsMouse ? Colors.bgHover : Colors.bgCard
                    border.color: Colors.borderSubtle
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: parent.parent.hasAnySelected ? "\ue5c9" : "\ue876" // cancel / check
                            font.family: materialIcons.name
                            font.pixelSize: 14
                            color: parent.parent.hasAnySelected ? Colors.textMuted : Colors.goldPrimary
                        }

                        Text {
                            text: parent.parent.hasAnySelected ? "Deselect" : "Select All"
                            font.family: Colors.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: Colors.textMain
                        }
                    }

                    MouseArea {
                        id: deselectBatchMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (parent.hasAnySelected) {
                                root.toggleSelectAll(false);
                            } else {
                                root.toggleSelectAll(true);
                            }
                        }
                    }
                }

                // 3. CRC-32 Check Button
                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    radius: 6
                    readonly property bool isActionEnabled: root.selectedItemsCount > 0
                    color: !isActionEnabled ? (Colors.isDarkMode ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(0, 0, 0, 0.04))
                                            : crcBatchMouse.containsPress ? (Colors.isDarkMode ? Qt.rgba(0.9, 0.76, 0.35, 0.35) : Qt.rgba(0.69, 0.51, 0.12, 0.30))
                                            : crcBatchMouse.containsMouse ? Colors.goldLightHover : Colors.goldLight
                    border.color: !isActionEnabled ? Colors.borderSubtle : Colors.goldBorder
                    border.width: 1
                    opacity: isActionEnabled ? 1.0 : 0.45

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: "\ue8e8" // verified_user
                            font.family: materialIcons.name
                            font.pixelSize: 15
                            color: (!parent.parent.isActionEnabled) ? Colors.textMuted : Colors.goldPrimary
                        }

                        Text {
                            text: root.selectedItemsCount > 0 ? ("CRC-32 Check (" + root.selectedItemsCount + ")") : "CRC-32 Check"
                            font.family: Colors.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: (!parent.parent.isActionEnabled) ? Colors.textMuted : Colors.textMain
                        }
                    }

                    MouseArea {
                        id: crcBatchMouse
                        anchors.fill: parent
                        enabled: parent.isActionEnabled
                        hoverEnabled: enabled
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.executeBatchCrcCheck()
                    }
                }
            }

            // =========================================================
            // --- 2. Inspector Card Below File Tree (Replicates Archive Info) ---
            // =========================================================
            Rectangle {
                id: inspectorCard
                Layout.fillWidth: true
                implicitHeight: 78
                radius: 8
                color: Colors.bgCard
                border.color: {
                    if (!root.selectedItem) return Colors.goldBorder;
                    if (root.selectedItem.state === "Found OK") return root.colorSeaGreen;
                    if (root.selectedItem.state === "Not Found") return "#ef4444";
                    if (root.selectedItem.state === "Found Truncated") return "#94a3b8";
                    return Colors.goldBorder;
                }
                border.width: 1

                // Left Accent Indicator Strip
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 4
                    radius: 2
                    color: {
                        if (!root.selectedItem) return Colors.goldPrimary;
                        if (root.selectedItem.state === "Found OK") return root.colorSeaGreen;
                        if (root.selectedItem.state === "Not Found") return "#ef4444";
                        if (root.selectedItem.state === "Found Truncated") return "#94a3b8";
                        return Colors.goldPrimary;
                    }
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
                            color: {
                                if (!root.selectedItem) return Colors.goldPrimary;
                                if (root.selectedItem.state === "Found OK") return root.colorSeaGreen;
                                if (root.selectedItem.state === "Not Found") return "#ef4444";
                                if (root.selectedItem.state === "Found Truncated") return "#94a3b8";
                                return Colors.goldPrimary;
                            }
                        }

                        Text {
                            text: root.selectedItem ? root.selectedItem.name : "Select an item to inspect"
                            font.family: Colors.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: Colors.textMain
                            elide: Text.ElideRight
                            Layout.maximumWidth: 300
                        }

                        Text {
                            text: {
                                if (!root.selectedItem) return "";
                                if (root.selectedItem.isFolder) return "[FOLDER]";
                                return "[" + root.selectedItem.state.toUpperCase() + "]";
                            }
                            font.family: Colors.fontFamily
                            font.pixelSize: 8
                            font.weight: Font.Bold
                            color: {
                                if (!root.selectedItem) return Colors.textMuted;
                                if (root.selectedItem.state === "Found OK") return root.colorSeaGreen;
                                if (root.selectedItem.state === "Not Found") return "#ef4444";
                                if (root.selectedItem.state === "Found Truncated") return "#94a3b8";
                                return Colors.textMuted;
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            visible: root.selectedItem !== null
                            text: root.selectedItem ? (root.selectedItem.path || "") : ""
                            font.family: Colors.fontFamily
                            font.pixelSize: 8
                            color: Colors.textMuted
                            elide: Text.ElideMiddle
                            Layout.maximumWidth: 150
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

                        // Col 1: Recovery Status
                        ColumnLayout {
                            spacing: 1
                            Layout.fillWidth: true
                            Text {
                                text: "RECOVERY STATUS"
                                font.family: Colors.fontFamily
                                font.pixelSize: 8
                                color: Colors.textMuted
                                font.weight: Font.Bold
                            }
                            Text {
                                text: root.selectedItem ? root.selectedItem.state : "IDLE"
                                font.family: Colors.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: {
                                    if (!root.selectedItem) return Colors.textMain;
                                    if (root.selectedItem.state === "Found OK") return root.colorSeaGreen;
                                    if (root.selectedItem.state === "Not Found") return "#ef4444";
                                    if (root.selectedItem.state === "Found Truncated") return Colors.isDarkMode ? "#cbd5e1" : "#475569";
                                    return Colors.goldPrimary;
                                }
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
                                text: root.selectedItem ? (root.selectedItem.realSize + " / " + root.selectedItem.compSize) : "0 B / 0 B"
                                font.family: Colors.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: Colors.textMain
                            }
                        }

                        // Col 3: Share of Archive
                        ColumnLayout {
                            spacing: 1
                            Layout.fillWidth: true
                            Text {
                                text: "SHARE OF ARCHIVE"
                                font.family: Colors.fontFamily
                                font.pixelSize: 8
                                color: Colors.textMuted
                                font.weight: Font.Bold
                            }
                            Text {
                                text: root.selectedItem ? root.selectedItem.share : "0.0%"
                                font.family: Colors.fontFamily
                                font.pixelSize: 10
                                color: Colors.textMain
                            }
                        }

                        // Col 4: CRC-32 with Copy Button
                        ColumnLayout {
                            spacing: 1
                            Layout.preferredWidth: 110
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
                                    text: root.selectedItem ? root.selectedItem.crc : "N/A"
                                    font.family: "Consolas, Segoe UI, monospace"
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: (root.selectedItem && root.selectedItem.crc && root.selectedItem.crc !== "N/A") ? Colors.goldPrimary : Colors.textMuted
                                }
                                Rectangle {
                                    visible: root.selectedItem && root.selectedItem.crc && root.selectedItem.crc !== "N/A"
                                    width: 16
                                    height: 16
                                    radius: 3
                                    color: copyMouse.containsMouse ? Colors.bgHover : "transparent"
                                    border.color: Colors.goldBorder
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.copyFeedback ? "\ue876" : "\ue14d" // checkmark or content_copy
                                        font.family: materialIcons.name
                                        font.pixelSize: 10
                                        color: root.copyFeedback ? root.colorSeaGreen : Colors.textMuted
                                    }

                                    MouseArea {
                                        id: copyMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (root.selectedItem && root.selectedItem.crc) {
                                                root.copyToClipboard(root.selectedItem.crc);
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

    // =========================================================
    // --- Context Menu for File Tree: ONLY Extract and CRC Check ---
    // =========================================================
    Popup {
        id: recoveryContextMenu
        width: 190
        padding: 6
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property var targetItem: null

        background: Rectangle {
            color: Colors.bgElevated
            radius: 8
            border.color: Colors.goldBorderHi
            border.width: 1

            Rectangle {
                anchors.fill: parent
                anchors.margins: -1
                radius: 9
                color: "transparent"
                border.color: Colors.shadowColor
                border.width: 1
                z: -1
            }
        }

        contentItem: ColumnLayout {
            spacing: 2
            width: parent.width

            // Context target indicator header
            Rectangle {
                Layout.fillWidth: true
                height: 22
                radius: 4
                color: Colors.bgHover

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6

                    Text {
                        text: "\ue873"
                        font.family: materialIcons.name
                        font.pixelSize: 12
                        color: Colors.goldPrimary
                    }
                    Text {
                        text: recoveryContextMenu.targetItem ? recoveryContextMenu.targetItem.name : "Item"
                        font.family: Colors.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: Colors.textMain
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.divider
            }

            // 1. Context Action: Extract
            Rectangle {
                Layout.fillWidth: true
                height: 28
                radius: 4
                color: extractMouse.containsMouse ? Colors.bgHover : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    Text {
                        text: "\ue2c4" // file_download / extract
                        font.family: materialIcons.name
                        font.pixelSize: 14
                        color: Colors.textMain
                    }

                    Text {
                        text: "Extract"
                        font.family: Colors.fontFamily
                        font.pixelSize: 11
                        color: Colors.textMain
                        Layout.fillWidth: true
                    }
                }

                MouseArea {
                    id: extractMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        let item = recoveryContextMenu.targetItem;
                        recoveryContextMenu.close();
                        if (item) {
                            if (item.state === "Not Found") {
                                errorDialog.showError("Cannot Extract Item", "The item '" + item.name + "' was not found in the archive table of contents or data streams.\n\nReconstruction could not locate valid data blocks.");
                                return;
                            }
                            recoveryBatchFolderDialog.pendingPaths = [item.path];
                            recoveryBatchFolderDialog.open();
                        }
                    }
                }
            }

            // 2. Context Action: CRC Check
            Rectangle {
                Layout.fillWidth: true
                height: 28
                radius: 4
                color: crcMouse.containsMouse ? Colors.bgHover : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    Text {
                        text: "\ue8e8" // verified_user / shield_check
                        font.family: materialIcons.name
                        font.pixelSize: 14
                        color: root.colorSeaGreen
                    }

                    Text {
                        text: "CRC Check"
                        font.family: Colors.fontFamily
                        font.pixelSize: 11
                        color: Colors.textMain
                        Layout.fillWidth: true
                    }
                }

                MouseArea {
                    id: crcMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        let item = recoveryContextMenu.targetItem;
                        recoveryContextMenu.close();
                        if (item) {
                            if (item.state === "Not Found") {
                                errorDialog.showError("CRC Check Failed", "Item '" + item.name + "' is missing from the archive stream. Checksum cannot be calculated.");
                                return;
                            }

                            progressWindow.show();
                            if (root.backend) {
                                root.backend.testRecoveryItem(item.path);
                            }
                        }
                    }
                }
            }
        }
    }

    // =========================================================
    // --- Test Success Dialog (Matched from ProgressWindow) ---
    // =========================================================
    Dialog {
        id: testSuccessDialog
        anchors.centerIn: parent
        width: Math.min(parent.width - 36, 400)
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 16

        property string okTitle: "Verification Succeeded"
        property string okCategory: "Integrity check passed"
        property string okDetail: "All payload blocks verified successfully."
        property string okIcon: "\ue8e8"

        function showTestOk(title, category, detail, iconGlyph) {
            okTitle = (title && title.length > 0) ? title : "Verification Succeeded";
            okCategory = (category && category.length > 0) ? category : "Integrity check passed";
            okDetail = (detail && detail.length > 0) ? detail : "Verification completed successfully.";
            okIcon = (iconGlyph && iconGlyph.length > 0) ? iconGlyph : "\ue8e8";
            open();
        }

        Overlay.modal: Rectangle {
            color: Colors.overlayModal
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        background: Rectangle {
            color: Colors.bgSurface
            radius: 14
            border.color: root.colorSeaGreenBorder
            border.width: 1.5

            // Top SeaGreen accent glow bar
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                height: 2.5
                radius: 1.25
                color: root.colorSeaGreen
            }
        }

        contentItem: ColumnLayout {
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    width: 40
                    height: 40
                    radius: 20
                    color: Colors.isDarkMode ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.16) : Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.12)
                    border.color: root.colorSeaGreen
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: testSuccessDialog.okIcon
                        font.family: materialIcons.name
                        font.pixelSize: 22
                        color: root.colorSeaGreen
                    }
                }

                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true

                    Text {
                        text: testSuccessDialog.okTitle
                        font.family: Colors.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        color: Colors.textMain
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: testSuccessDialog.okCategory
                        font.family: Colors.fontFamily
                        font.pixelSize: 11
                        color: Colors.textMuted
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    width: 26
                    height: 26
                    radius: 13
                    color: testCloseMouse.containsMouse ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.18) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "\ue5cd"
                        font.family: materialIcons.name
                        font.pixelSize: 14
                        color: Colors.textMuted
                    }

                    MouseArea {
                        id: testCloseMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: testSuccessDialog.close()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.divider
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: detailText.implicitHeight + 16
                radius: 8
                color: Colors.bgCard
                border.color: Colors.borderSubtle
                border.width: 1

                Text {
                    id: detailText
                    anchors.fill: parent
                    anchors.margins: 10
                    text: testSuccessDialog.okDetail
                    font.family: Colors.fontFamily
                    font.pixelSize: 11
                    color: Colors.textMain
                    wrapMode: Text.WordWrap
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Item { Layout.fillWidth: true }

                Rectangle {
                    implicitWidth: 90
                    implicitHeight: 30
                    radius: 6
                    color: root.colorSeaGreen

                    Text {
                        anchors.centerIn: parent
                        text: "Done"
                        font.family: Colors.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: "#ffffff"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: testSuccessDialog.close()
                    }
                }
            }
        }
    }

    // =========================================================
    // --- Close Recovery Confirmation Dialog ---
    // =========================================================
    Dialog {
        id: closeRecoveryConfirmDialog
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 440)
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape
        padding: 20

        Overlay.modal: Rectangle {
            color: Colors.overlayModal
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        background: Rectangle {
            color: Colors.bgSurface
            radius: 14
            border.color: Colors.goldBorder
            border.width: 1.5

            // Top gold/amber warning accent glow bar
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                height: 2.5
                radius: 1.25
                color: Colors.goldPrimary
            }
        }

        contentItem: ColumnLayout {
            spacing: 16

            RowLayout {
                spacing: 12
                Layout.fillWidth: true

                Rectangle {
                    width: 40
                    height: 40
                    radius: 20
                    color: Colors.goldLight
                    border.color: Colors.goldBorderHi
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "\ue002" // warning icon
                        font.family: materialIcons.name
                        font.pixelSize: 22
                        color: Colors.goldPrimary
                    }
                }

                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true

                    Text {
                        text: "Close Recovery Session?"
                        font.family: Colors.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        color: Colors.textMain
                    }

                    Text {
                        text: "Active archive recovery is currently loaded."
                        font.family: Colors.fontFamily
                        font.pixelSize: 11
                        color: Colors.textMuted
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.divider
            }

            Text {
                text: "Closing this session will unload the active recovery archive (" + (root.currentFileName || "selected archive") + ") and release file streams.\n\nAre you sure you want to exit recovery?"
                font.family: Colors.fontFamily
                font.pixelSize: 12
                color: Colors.textMain
                wrapMode: Text.WordWrap
                lineHeight: 1.2
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 10

                Item { Layout.fillWidth: true }

                // Cancel Button
                Rectangle {
                    implicitWidth: 90
                    implicitHeight: 34
                    radius: 6
                    color: cancelConfirmMouse.containsMouse ? Colors.bgHover : "transparent"
                    border.color: Colors.borderSubtle
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        font.family: Colors.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: Colors.textMain
                    }

                    MouseArea {
                        id: cancelConfirmMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: closeRecoveryConfirmDialog.close()
                    }
                }

                // Close & Unload Button (Danger style)
                Rectangle {
                    implicitWidth: 120
                    implicitHeight: 34
                    radius: 6
                    color: confirmCloseMouse.containsPress
                        ? Qt.darker("#e05353", 1.2)
                        : (confirmCloseMouse.containsMouse ? "#eb6b6b" : "#e05353")

                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: "\ue5cd" // close
                            font.family: materialIcons.name
                            font.pixelSize: 14
                            color: "#ffffff"
                        }

                        Text {
                            text: "Close Session"
                            font.family: Colors.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: "#ffffff"
                        }
                    }

                    MouseArea {
                        id: confirmCloseMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            closeRecoveryConfirmDialog.close();
                            root.unloadArchive();
                            root.closeRequested();
                        }
                    }
                }
            }
        }
    }

    ErrorDialog {
        id: errorDialog
        anchors.centerIn: parent
    }

    PasswordDialog {
        id: passwordDialog
        anchors.centerIn: parent
        onAcceptedPassword: password => {
            passwordDialog.close();
            let path = root.pendingRecoveryFilePath;
            root.pendingRecoveryFilePath = "";
            if (path && path.length > 0) {
                root.selectedItem = null;
                recoveryListModel.clear();
                root.selectedItemsCount = 0;
                if (root.backend) {
                    root.backend.loadArchive(path, password);
                }
            }
        }
        onRejected: {
            passwordDialog.close();
            root.pendingRecoveryFilePath = "";
        }
    }

    ProgressWindow {
        id: progressWindow
        backend: root.backend
    }

    // Loading overlay
    Rectangle {
        anchors.fill: parent
        color: Colors.isDarkMode ? Qt.rgba(0.06, 0.08, 0.11, 0.88) : Qt.rgba(0.96, 0.97, 0.99, 0.88)
        visible: root.backend ? root.backend.isLoading : false
        z: 100

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 14

            BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                running: root.backend ? root.backend.isLoading : false
            }

            ColumnLayout {
                spacing: 4
                Layout.alignment: Qt.AlignHCenter

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Analyzing & Reconstructing Archive..."
                    font.family: Colors.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: Colors.textMain
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Scanning archive payload..."
                    font.family: Colors.fontFamily
                    font.pixelSize: 11
                    color: Colors.textMuted
                }
            }
        }
    }
}
