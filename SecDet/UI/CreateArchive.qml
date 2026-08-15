import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import UI

Dialog {
    id: createDialog
    parent: Overlay.overlay
    x: parent ? Math.round((parent.width - width) / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0
    width: parent ? Math.min(parent.width - 40, 540) : 540
    height: parent ? Math.min(parent.height - 40, 660) : 660
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding: 16

    signal archiveCreated(var archiveInfo)
    signal closeRequested()

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
        border.color: Colors.goldBorderHi
        border.width: 1

        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on border.color { ColorAnimation { duration: 200 } }
    }

    // ==========================================
    // --- Custom Component: Fluent Gold CheckBox ---
    // ==========================================
    component GoldCheckBox : Item {
        id: cbRoot
        property string text: ""
        property bool checked: false
        signal toggled(bool isChecked)

        implicitWidth: cbRow.implicitWidth
        implicitHeight: Math.max(20, cbRow.implicitHeight)

        RowLayout {
            id: cbRow
            anchors.fill: parent
            spacing: 10

            Rectangle {
                id: box
                width: 18
                height: 18
                radius: 4
                Layout.alignment: Qt.AlignVCenter
                color: cbRoot.checked ? Colors.goldPrimary : "transparent"
                border.color: cbRoot.checked ? Colors.goldHover : (cbArea.containsMouse ? Colors.goldBorderHi : Colors.goldBorder)
                border.width: 1

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "\ue5ca" // check mark
                    font.family: materialIcons.name
                    font.pixelSize: 14
                    color: Colors.textOnGold
                    visible: cbRoot.checked
                }
            }

            Text {
                text: cbRoot.text
                color: Colors.textMain
                font.family: Colors.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: cbArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                cbRoot.checked = !cbRoot.checked
                cbRoot.toggled(cbRoot.checked)
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
        signal toggled(bool isChecked)

        implicitWidth: swRow.implicitWidth
        implicitHeight: Math.max(22, swRow.implicitHeight)

        RowLayout {
            id: swRow
            anchors.fill: parent
            spacing: 12

            Text {
                text: swRoot.text
                color: Colors.textMain
                font.family: Colors.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                elide: Text.ElideRight
            }

            Rectangle {
                id: track
                width: 38
                height: 20
                radius: 10
                Layout.alignment: Qt.AlignVCenter
                color: swRoot.checked ? Colors.goldLightHover : Colors.bgInput
                border.color: swRoot.checked ? Colors.goldBorderHi : Colors.goldBorder
                border.width: 1

                Behavior on color { ColorAnimation { duration: 150 } }

                Rectangle {
                    id: thumb
                    width: 14
                    height: 14
                    radius: 7
                    anchors.verticalCenter: parent.verticalCenter
                    x: swRoot.checked ? parent.width - width - 3 : 3
                    color: swRoot.checked ? Colors.goldPrimary : Colors.textMuted

                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }
        }

        MouseArea {
            id: swArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                swRoot.checked = !swRoot.checked
                swRoot.toggled(swRoot.checked)
            }
        }
    }

    // ==========================================
    // --- Custom Component: Fluent Segmented Toggle ---
    // ==========================================
    component TripleToggle : Rectangle {
        id: toggleRoot
        property int currentIndex: 1 // 0: Fast, 1: Balanced, 2: Ultra
        property var options: ["Fast (Store)", "Balanced (Deflate)", "Ultra (LZMA2)"]
        signal selected(int index)

        implicitWidth: 320
        implicitHeight: 34
        radius: 8
        color: Colors.bgInput
        border.color: Colors.goldBorder
        border.width: 1

        Rectangle {
            id: activePill
            width: (toggleRoot.width - 6) / 3
            height: toggleRoot.height - 6
            y: 3
            x: 3 + toggleRoot.currentIndex * width
            radius: 6
            color: Colors.goldLight
            border.color: Colors.goldBorderHi
            border.width: 1

            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
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
                        font.pixelSize: 11
                        font.weight: toggleRoot.currentIndex === index ? Font.Bold : Font.Medium
                        color: toggleRoot.currentIndex === index ? Colors.goldHover : Colors.textMuted

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            toggleRoot.currentIndex = index
                            toggleRoot.selected(index)
                        }
                    }
                }
            }
        }
    }

    // --- Main Dialog Layout with ScrollView ---
    contentItem: ScrollView {
        id: scrollArea
        clip: true
        contentWidth: availableWidth

        ColumnLayout {
            width: scrollArea.availableWidth
            spacing: 12

            // ==========================================
            // --- Header: Icon, Title & Close Button ---
            // ==========================================
            RowLayout {
                Layout.fillWidth: true

                RowLayout {
                    spacing: 8
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: Colors.goldLight
                        border.color: Colors.goldBorderHi
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "\ue145" // add icon
                            font.family: materialIcons.name
                            font.pixelSize: 18
                            color: Colors.goldHover
                        }
                    }

                    ColumnLayout {
                        spacing: 1
                        Text {
                            text: "Create Archive"
                            font.family: Colors.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: Colors.textMain
                        }
                        Text {
                            text: "Configure parameters and assemble files"
                            font.family: Colors.fontFamily
                            font.pixelSize: 11
                            color: Colors.textMuted
                        }
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
                        onClicked: {
                            createDialog.closeRequested()
                            createDialog.close()
                        }
                    }
                }
            }

            // ==========================================
            // --- Archive Name Input ---
            // ==========================================
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 64
                color: Colors.bgCard
                radius: 10
                border.color: Colors.goldBorder
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    Text {
                        text: "ARCHIVE NAME"
                        font.family: Colors.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: Colors.goldPrimary
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 6
                        color: Colors.bgInput
                        border.color: archiveNameInput.activeFocus ? Colors.goldBorderHi : Colors.borderSubtle
                        border.width: 1

                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Text {
                                text: "folder_zip"
                                font.family: materialIcons.name
                                font.pixelSize: 16
                                color: Colors.goldPrimary
                            }

                            TextField {
                                id: archiveNameInput
                                Layout.fillWidth: true
                                text: "NewArchive.tr"
                                color: Colors.textMain
                                font.family: Colors.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                background: null
                                selectByMouse: true
                            }
                        }
                    }
                }
            }

            // ==========================================
            // --- Drop Area & File List View ---
            // ==========================================
            Rectangle {
                id: filesContainer
                Layout.fillWidth: true
                implicitHeight: 140
                color: Colors.bgCard
                radius: 10
                border.color: fileDropArea.containsDrag ? Colors.goldPrimary : Colors.goldBorder
                border.width: fileDropArea.containsDrag ? 2 : 1

                Behavior on border.color { ColorAnimation { duration: 150 } }
                Behavior on border.width { NumberAnimation { duration: 150 } }

                ListModel {
                    id: droppedFilesModel
                    ListElement { fileName: "source_bundle.zip"; filePath: "C:/Projects/source_bundle.zip"; fileSize: "1.4 MB" }
                    ListElement { fileName: "assets_manifest.json"; filePath: "C:/Projects/assets_manifest.json"; fileSize: "12 KB" }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "\ue2c8" // folder icon
                            font.family: materialIcons.name
                            font.pixelSize: 14
                            color: Colors.goldPrimary
                        }

                        Text {
                            text: "ARCHIVE CONTENTS"
                            font.family: Colors.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: Colors.goldPrimary
                            Layout.fillWidth: true
                        }

                        Text {
                            text: droppedFilesModel.count + " files queued"
                            font.family: Colors.fontFamily
                            font.pixelSize: 10
                            color: Colors.textMuted
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 6
                        color: Colors.bgInput
                        border.color: Colors.borderSubtle
                        border.width: 1

                        ListView {
                            id: filesListView
                            anchors.fill: parent
                            anchors.margins: 4
                            clip: true
                            spacing: 2
                            model: droppedFilesModel

                            delegate: Rectangle {
                                width: filesListView.width
                                height: 28
                                radius: 4
                                color: rowMouse.containsMouse ? Colors.bgHover : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Text {
                                        text: "\ue873" // file icon
                                        font.family: materialIcons.name
                                        font.pixelSize: 14
                                        color: Colors.textMuted
                                    }

                                    Text {
                                        text: model.fileName
                                        color: Colors.textMain
                                        font.family: Colors.fontFamily
                                        font.pixelSize: 11
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: model.fileSize
                                        color: Colors.textMuted
                                        font.family: Colors.fontFamily
                                        font.pixelSize: 10
                                    }

                                    // Remove file icon button
                                    Item {
                                        width: 18; height: 18
                                        Text {
                                            anchors.centerIn: parent
                                            text: "\ue5cd"
                                            font.family: materialIcons.name
                                            font.pixelSize: 12
                                            color: removeMouse.containsMouse ? "#ff6b6b" : Colors.textMuted
                                        }
                                        MouseArea {
                                            id: removeMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: droppedFilesModel.remove(index)
                                        }
                                    }
                                }

                                MouseArea {
                                    id: rowMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }
                            }
                        }
                    }
                }

                DropArea {
                    id: fileDropArea
                    anchors.fill: parent
                    onEntered: (drag) => { if (drag.hasUrls) drag.acceptProposedAction(); }
                    onDropped: (drop) => {
                        if (drop.hasUrls) {
                            for (let i = 0; i < drop.urls.length; ++i) {
                                let rawUrl = drop.urls[i].toString();
                                let fullPath = rawUrl.replace(/^file:\/\/\/?/, "");
                                fullPath = decodeURIComponent(fullPath);
                                let name = fullPath.split("/").pop().split("\\").pop();
                                droppedFilesModel.append({ fileName: name, filePath: fullPath, fileSize: "100 KB" });
                            }
                            drop.acceptProposedAction();
                        }
                    }
                }
            }

            // ==========================================
            // --- Compression & Security Settings ---
            // ==========================================
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: settingsCol.implicitHeight + 20
                color: Colors.bgCard
                radius: 10
                border.color: Colors.goldBorder
                border.width: 1

                ColumnLayout {
                    id: settingsCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Text {
                        text: "COMPRESSION LEVEL"
                        font.family: Colors.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: Colors.goldPrimary
                    }

                    TripleToggle {
                        id: compTripleToggle
                        Layout.fillWidth: true
                        currentIndex: 1
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Colors.divider }

                    GridLayout {
                        columns: 2
                        columnSpacing: 16
                        rowSpacing: 10
                        Layout.fillWidth: true

                        GoldSwitch {
                            id: encSwitch
                            text: "AES-256 Encryption"
                            checked: true
                            Layout.fillWidth: true
                        }

                        GoldSwitch {
                            id: solidSwitch
                            text: "Solid Block Mode"
                            checked: false
                            Layout.fillWidth: true
                        }

                        GoldCheckBox {
                            id: permCheck
                            text: "Preserve Permissions"
                            checked: true
                            Layout.fillWidth: true
                        }

                        GoldCheckBox {
                            id: verifyCheck
                            text: "Integrity Verification"
                            checked: true
                            Layout.fillWidth: true
                        }
                    }
                }
            }
            Rectangle {
                id: passwordContainer
                Layout.fillWidth: true
                implicitHeight: 140
                color: Colors.bgCard
                radius: 10
                border.color: fileDropArea.containsDrag ? Colors.goldPrimary : Colors.goldBorder
                border.width: fileDropArea.containsDrag ? 2 : 1

                Behavior on border.color { ColorAnimation { duration: 150 } }
                Behavior on border.width { NumberAnimation { duration: 150 } }

                ListModel {
                    id: passwords
                    ListElement { password_hash: "ad9a67fefa847de87753df6794a0ae466431e76ad1fb4db58fbbe836d1dde0e7" }
                    ListElement { password_hash: "2285dd09ea6ccd0ec7e7253d2f7dc10810608d45609a902b5094176974eafc44" }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "key"
                            font.family: materialIcons.name
                            font.pixelSize: 14
                            color: Colors.goldPrimary
                        }

                        Text {
                            text: "Passwords"
                            font.family: Colors.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: Colors.goldPrimary
                            Layout.fillWidth: true
                        }

                        Text {
                            text: "info"
                            font.family: materialIcons.name
                            font.pixelSize: 10
                            color: Colors.textMuted
                            MouseArea{
                                anchors.fill: parent
                                onClicked:{
                                    ToolTip.show("Your archives can have multiple passcodes\nbut its necessary to put atleast one to continue.")
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 6
                        color: Colors.bgInput
                        border.color: Colors.borderSubtle
                        border.width: 1
                        ListView {
                            id: passwordListView
                            anchors.fill: parent
                            anchors.margins: 4
                            clip: true
                            spacing: 2
                            model: passwords

                            delegate: Rectangle {
                                width: passwordContainer.width
                                height: 28
                                radius: 4
                                color: Colors.bgHover

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Text {
                                        text: "key"
                                        font.family: materialIcons.name
                                        font.pixelSize: 14
                                        color: Colors.textMuted
                                    }

                                    Text {
                                        text: model.password_hash
                                        color: Colors.textMain
                                        font.family: Colors.fontFamily
                                        font.pixelSize: 11
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }

                    }
                    RowLayout{
                        TextField {
                            id: passInput
                            Layout.fillWidth: true
                            placeholderText: "Enter password..."
                            placeholderTextColor: Colors.textSubtle
                            color: Colors.textMain
                            font.family: Colors.fontFamily
                            font.pixelSize: 13
                            echoMode: showPassBtn.showPassword ? TextInput.Normal : TextInput.Password
                            background: null
                            onAccepted: {
                                if (passInput.text.length > 0) {
                                    passwordDialog.acceptedPassword(passInput.text)
                                    passwordDialog.close()
                                }
                            }
                        }
                        Text{
                            font.family: materialIcons.name
                            font.pixelSize: 16
                            color: Colors.goldBorder
                            text: "add"
                        }
                    }
                }
            }

            // ==========================================
            // --- Action Buttons: Cancel & Create ---
            // ==========================================
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Item { Layout.fillWidth: true }

                // Cancel Button
                Rectangle {
                    implicitWidth: 100
                    implicitHeight: 34
                    radius: 6
                    color: cancelBtnMouse.containsMouse ? Colors.bgHover : "transparent"
                    border.color: Colors.goldBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        font.family: Colors.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: Colors.textMuted
                    }

                    MouseArea {
                        id: cancelBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            createDialog.closeRequested()
                            createDialog.close()
                        }
                    }
                }

                // Save / Create Button
                Rectangle {
                    implicitWidth: 140
                    implicitHeight: 34
                    radius: 6
                    color: saveBtnMouse.containsPress ? Qt.darker(Colors.goldPrimary, 1.15)
                         : (saveBtnMouse.containsMouse ? Colors.goldHover : Colors.goldPrimary)

                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: "\ue145" // '+' icon
                            font.family: materialIcons.name
                            font.pixelSize: 16
                            color: Colors.textOnGold
                        }

                        Text {
                            text: "Create Archive"
                            font.family: Colors.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: Colors.textOnGold
                        }
                    }

                    MouseArea {
                        id: saveBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            let filesList = [];
                            for (let i = 0; i < droppedFilesModel.count; ++i) {
                                filesList.push(droppedFilesModel.get(i).filePath);
                            }
                            let archiveData = {
                                name: archiveNameInput.text,
                                compression: compTripleToggle.options[compTripleToggle.currentIndex],
                                encryption: encSwitch.checked,
                                solidMode: solidSwitch.checked,
                                preservePermissions: permCheck.checked,
                                integrityCheck: verifyCheck.checked,
                                files: filesList
                            };
                            console.log("CreateArchive - Created new archive: " + archiveData.name + " (" + filesList.length + " files)");
                            createDialog.archiveCreated(archiveData);
                            createDialog.close();
                        }
                    }
                }
            }
        }
    }

    onOpened: {
        archiveNameInput.forceActiveFocus()
    }
}
