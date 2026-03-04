import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import EvolveUI
import "pages"

ApplicationWindow {
    id: mainWindow
    width: 1280
    height: 720
    visible: true
    title: "Eideo"

    color: theme.primaryColor

    FontLoader {
        id: iconFont
        source: "qrc:/new/prefix1/fonts/fontawesome-free-6.7.2-desktop/otfs/Font Awesome 6 Free-Solid-900.otf"
    }

    ETheme { id: theme }
    
    // Global Toast
    property alias globalToast: appToast
    EToast {
        id: appToast
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 60
        z: 9999
    }

    // Main Layout
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Top Bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            color: theme.secondaryColor
            
            // Bottom border for separation
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Qt.rgba(0,0,0,0.1)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 16

                // App Title
                Label {
                    text: "Eideo Toolbox"
                    font.bold: true
                    font.pixelSize: 16
                    color: theme.textColor
                    Layout.alignment: Qt.AlignVCenter
                }

                // Vertical Divider
                Rectangle {
                    Layout.fillHeight: true
                    Layout.topMargin: 12
                    Layout.bottomMargin: 12
                    width: 1
                    color: Qt.rgba(0,0,0,0.1)
                }

                // Menu Buttons
                Row {
                    spacing: 4
                    Layout.alignment: Qt.AlignVCenter
                    
                    Repeater {
                        model: ["File", "Edit", "View", "Help"]
                        EMenuButton {
                            text: modelData
                            menuModel: ["Option 1", "Option 2", "Option 3", "Settings", "Exit"]
                            backgroundVisible: false
                            hoverColor: Qt.rgba(0,0,0,0.05)
                            textColor: theme.textColor
                            
                            onItemClicked: (index, itemText) => {
                                console.log("Clicked", text, ":", itemText)
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true } // Spacer

                // Right-side controls (e.g., User Profile, Notifications)
                Row {
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter

                    EButton {
                        text: theme.isDark ? "white" : "dark"
                        iconCharacter: theme.isDark ? "\uf185" : "\uf186"
                        iconRotateOnClick: true
                        shadowEnabled: false
                        implicitHeight: 32
                        onClicked: theme.toggleTheme()
                    }
                    
                    EButton {
                        text: ""
                        iconCharacter: "\uf0f3" // Bell icon
                        width: 32
                        height: 32
                        radius: 16
                        backgroundVisible: false
                        hoverColor: Qt.rgba(0,0,0,0.05)
                        shadowEnabled: false
                    }
                    
                    EButton {
                        text: ""
                        iconCharacter: "\uf007" // User icon
                        width: 32
                        height: 32
                        radius: 16
                        backgroundVisible: false
                        hoverColor: Qt.rgba(0,0,0,0.05)
                        shadowEnabled: false
                    }
                }
            }
        }

        // Content Area with Sidebars
        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            handle: Rectangle {
                implicitWidth: 1
                color: Qt.rgba(0,0,0,0.1)
                
                Rectangle {
                    anchors.centerIn: parent
                    width: 1
                    height: parent.height
                    color: Qt.rgba(0,0,0,0.1)
                }
            }

            // Left Sidebar (Navigation)
            Pane {
                id: leftSidebar
                implicitWidth: 240
                SplitView.minimumWidth: 200
                SplitView.maximumWidth: 320
                padding: 0
                background: Rectangle {
                    color: theme.secondaryColor
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Sidebar Header/Section Title
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        
                        Label {
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            text: "MAIN MENU"
                            font.pixelSize: 11
                            font.bold: true
                            color: Qt.rgba(theme.textColor.r, theme.textColor.g, theme.textColor.b, 0.5)
                        }
                    }

                    // Navigation List
                    ListModel {
                        id: navModel
                        ListElement { display: "Video Processing"; iconChar: "\uf03d" }
                        ListElement { display: "Audio Processing"; iconChar: "\uf001" }
                        ListElement { display: "Image Tools"; iconChar: "\uf03e" }
                        ListElement { display: "Effects"; iconChar: "\uf0d0" }
                        ListElement { display: "Recording"; iconChar: "\uf111" }
                        ListElement { display: "Batch Tools"; iconChar: "\uf0c5" }
                        ListElement { display: "Metadata"; iconChar: "\uf05a" }
                        ListElement { display: "AI Tools"; iconChar: "\uf544" }
                    }

                    ListView {
                        id: navListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: navModel
                        clip: true
                        currentIndex: 0

                        delegate: Item {
                            id: navDelegate
                            width: ListView.view.width
                            height: 40
                            
                            property bool isSelected: ListView.view.currentIndex === index
                            property bool isHovered: false

                            scale: 1.0
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                            // Selection Background (fades in/out)
                            Rectangle {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                radius: 6
                                color: theme.primaryColor
                                opacity: isSelected ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }
                            
                            // Hover Background (fades in/out)
                            Rectangle {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                radius: 6
                                color: Qt.rgba(0,0,0,0.05)
                                opacity: isHovered && !isSelected ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                            // Selection indicator
                            Rectangle {
                                width: 3
                                height: isSelected ? 20 : 0
                                radius: 1.5
                                color: theme.focusColor
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                opacity: isSelected ? 1 : 0
                                
                                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 20
                                anchors.rightMargin: 16
                                spacing: 12

                                Text {
                                    text: model.iconChar
                                    font.family: iconFont.name
                                    font.pixelSize: 16
                                    color: isSelected ? theme.textColor : Qt.rgba(theme.textColor.r, theme.textColor.g, theme.textColor.b, 0.7)
                                    Layout.preferredWidth: 20
                                    horizontalAlignment: Text.AlignHCenter
                                    
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                Label {
                                    text: model.display
                                    color: isSelected ? theme.textColor : Qt.rgba(theme.textColor.r, theme.textColor.g, theme.textColor.b, 0.7)
                                    font.bold: isSelected
                                    Layout.fillWidth: true
                                    
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: navDelegate.isHovered = true
                                onExited: navDelegate.isHovered = false
                                onPressed: navDelegate.scale = 0.96
                                onReleased: navDelegate.scale = 1.0
                                onCanceled: navDelegate.scale = 1.0
                                onClicked: {
                                    navListView.currentIndex = index
                                    contentStack.currentIndex = index
                                }
                            }
                        }
                    }
                    
                    // Settings Link
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        
                        Rectangle {
                            anchors.top: parent.top
                            width: parent.width
                            height: 1
                            color: Qt.rgba(0,0,0,0.05)
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            
                            Text {
                                text: "\uf013" // cog
                                font.family: iconFont.name
                                font.pixelSize: 16
                                color: theme.textColor
                            }
                            
                            Label {
                                text: "Settings"
                                color: theme.textColor
                                Layout.fillWidth: true
                            }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                // Navigate to settings
                                contentStack.currentIndex = navModel.count // Assuming settings is last
                            }
                        }
                    }
                }
            }

            // Center Content Area
            Rectangle {
                SplitView.minimumWidth: 300
                SplitView.preferredWidth: 600
                SplitView.fillWidth: true
                Layout.fillHeight: true
                color: theme.primaryColor
                clip: true

                StackLayout {
                    id: contentStack
                    anchors.fill: parent
                    anchors.margins: 0 // Add padding around content
                    currentIndex: 0
                    
                    // 1. Video Processing
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        VideoProcessingPage { 
                            anchors.fill: parent
                        }
                    }

                    // 2. Audio Processing
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        AudioProcessingPage {
                            anchors.fill: parent
                        }
                    }

                    // 3. Image Tools
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        ImageToolsPage {
                            anchors.fill: parent
                        }
                    }

                    // 4. Effects
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        EffectsPage {
                            anchors.fill: parent
                        }
                    }
                    
                    // 5. Recording
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        RecordingPage {
                            anchors.fill: parent
                        }
                    }

                    // 6. Batch Tools
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        BatchToolsPage {
                            anchors.fill: parent
                        }
                    }

                    // 7. Metadata
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        MetadataPage {
                            anchors.fill: parent
                        }
                    }

                    // 8. AI Tools
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        AIToolsPage {
                            anchors.fill: parent
                        }
                    }

                    // 9. Settings (Accessed via bottom link)
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        SettingsPage { 
                            anchors.fill: parent
                            // animWindowRef: homePage.animatedWindow // removed dependency
                        }
                    }
                }
            }

            // Right Sidebar (Inspector/Details)
            Pane {
                id: rightSidebar
                implicitWidth: 240
                SplitView.minimumWidth: 200
                SplitView.maximumWidth: 400
                Layout.fillHeight: true
                padding: 0
                background: Rectangle {
                    color: theme.secondaryColor
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Header
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        color: "transparent"
                        
                        Label {
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            text: "TASK QUEUE"
                            font.bold: true
                            font.pixelSize: 12
                            color: theme.textColor
                        }

                        EButton {
                            anchors.right: parent.right
                            anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Clear"
                            implicitHeight: 24
                            implicitWidth: 50
                            backgroundVisible: false
                            onClicked: TaskManager.clearCompleted()
                        }
                        
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: Qt.rgba(0,0,0,0.05)
                        }
                    }

                    // Content
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: TaskManager.tasks
                        spacing: 8
                        topMargin: 16
                        bottomMargin: 16

                        delegate: Rectangle {
                            width: ListView.view.width - 32
                            height: 64
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Qt.rgba(0,0,0,0.03)
                            radius: 6
                            border.color: Qt.rgba(0,0,0,0.05)
                            property bool hovered: false
                            
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 4
                                
                                RowLayout {
                                    Layout.fillWidth: true
                                    Label { 
                                        text: model.modelData.name
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: theme.textColor
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                }
                                
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    
                                    EProgressBar {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 4
                                        from: 0
                                        to: 1
                                        value: model.modelData.progress
                                        visible: model.modelData.status === "Running"
                                    }
                                    
                                    Label {
                                        text: model.modelData.status === "Running" ? Math.round(model.modelData.progress * 100) + "%" : model.modelData.status
                                        font.pixelSize: 11
                                        color: {
                                            if (model.modelData.status === "Failed") return "red";
                                            if (model.modelData.status === "Completed") return "green";
                                            return Qt.rgba(theme.textColor.r, theme.textColor.g, theme.textColor.b, 0.6);
                                        }
                                    }
                                }

                                Label {
                                    text: model.modelData.details
                                    visible: model.modelData.details !== "" && model.modelData.status === "Running"
                                    font.pixelSize: 10
                                    color: Qt.rgba(theme.textColor.r, theme.textColor.g, theme.textColor.b, 0.5)
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }

                            // Hover overlay cancel area (red strip with white trash icon)
                            Rectangle {
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                width: (model.modelData.status === "Running" || model.modelData.status === "Pending") ? (parent.hovered ? 40 : 0) : 0
                                color: "#E53935" // Red
                                radius: 6
                                z: 10
                                visible: parent.hovered && (model.modelData.status === "Running" || model.modelData.status === "Pending")
                                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf1f8" // trash icon
                                    font.family: iconFont.name
                                    font.pixelSize: 16
                                    color: "#ffffff"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: model.modelData.cancel()
                                }
                            }

                            // Track hover on entire delegate
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                                onEntered: parent.hovered = true
                                onExited: parent.hovered = false
                            }
                        }

                        // Placeholder when empty
                        Text {
                            anchors.centerIn: parent
                            text: "No tasks running"
                            color: Qt.rgba(theme.textColor.r, theme.textColor.g, theme.textColor.b, 0.4)
                            visible: TaskManager.tasks.length === 0
                        }
                    }
                }
            }
        }
    }
}
