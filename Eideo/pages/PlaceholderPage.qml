import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import EvolveUI
import "../components"

Page {
    id: root
    property string pageTitle: "Page Title"
    property string categoryPath: ""
    property var toolsList: []

    function iconFor(name) {
        switch (name) {
        case "Format Conversion": return "\uf021"
        case "Compression": return "\uf066"
        case "Cropping": return "\uf125"
        case "Resolution Adjustment": return "\uf065"
        case "Screenshot": return "\uf030"
        case "Merge/Join": return "\uf247"
        case "Video Comparison": return "\uf24e"
        case "Replace Audio / Add Music": return "\uf001"
        case "Extract Audio": return "\uf1c7"
        case "Audio Cutting": return "\uf0c4"
        case "Audio Transcoding": return "\uf028"
        case "Mixing / Merging": return "\uf1de"
        case "Brightness/Contrast Filters": return "\uf042"
        case "Remove Watermark": return "\uf12d"
        case "Video Stabilization": return "\uf13d"
        case "Denoise": return "\uf51a"
        case "Screen Recording": return "\uf108"
        case "Webcam Recording": return "\uf030"
        case "Batch Conversion": return "\uf0ae"
        case "Batch Audio Extraction": return "\uf1c7"
        case "Batch Rename": return "\uf304"
        case "View Media Info": return "\uf05a"
        case "Modify Metadata": return "\uf303"
        case "Speech to Subtitle": return "\uf20a"
        case "Burn Subtitles": return "\uf06d"
        case "Frame Interpolation": return "\uf051"
        case "Image Upscale": return "\uf424"
        case "Sequence To Video": return "\uf03e"
        default: return "\uf0ad"
        }
    }

    background: Rectangle {
        color: "transparent"
    }
    
    EAnimatedWindow {
        id: toolWindow
        dismissOnOverlay: false
        
        property string currentToolName: ""
        property var toolCache: ({})
        function ensureTool(name) {
            if (!name) return
            var key = name.replace(/ /g, "").replace(/\//g, "")
            var existing = toolCache[key]
            if (existing) {
                for (var i = 0; i < toolContainer.children.length; ++i) toolContainer.children[i].visible = false
                existing.visible = true
                existing.anchors.fill = toolContainer
                return
            }
            var path = "tools/" + root.categoryPath + "/" + key + ".qml"
            var comp = Qt.createComponent(path)
            if (comp.status === Component.Ready) {
                var obj = comp.createObject(toolContainer, {})
                toolCache[key] = obj
                for (var j = 0; j < toolContainer.children.length; ++j) toolContainer.children[j].visible = false
                obj.visible = true
                obj.anchors.fill = toolContainer
            } else if (comp.status === Component.Error) {
                console.warn("Failed to load tool component:", path, comp.errorString())
            }
        }
        onCurrentToolNameChanged: ensureTool(currentToolName)
        Item { id: toolContainer; anchors.fill: parent }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 24

        Label {
            text: root.pageTitle
            font.pixelSize: 24
            font.bold: true
            color: theme.textColor
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                width: parent.width
                model: root.toolsList
                delegate: ItemDelegate {
                    width: ListView.view.width
                    height: 50
                    padding: 8 // Add padding to the delegate

                    contentItem: Item {
                        anchors.fill: parent

                        RowLayout {
                            anchors.fill: parent
                            spacing: 16

                            Rectangle {
                                id: iconRect
                                Layout.alignment: Qt.AlignVCenter
                                width: 32
                                height: 32
                                radius: 4
                                color: Qt.rgba(theme.primaryColor.r, theme.primaryColor.g, theme.primaryColor.b, 0.1)

                                Text {
                                    anchors.centerIn: parent
                                    text: (typeof modelData === "object" && modelData.iconChar) ? modelData.iconChar : iconFor(typeof modelData === "object" && modelData.text ? modelData.text : modelData)
                                    font.family: iconFont.name
                                    color: theme.textColor
                                }
                            }

                            Label {
                                Layout.alignment: Qt.AlignVCenter
                                text: (typeof modelData === "object" && modelData.text) ? modelData.text : modelData
                                font.pixelSize: 16
                                color: theme.textColor
                                Layout.fillWidth: true
                            }

                            EButton {
                                id: openBtn
                                Layout.alignment: Qt.AlignVCenter
                                text: "Open"
                                shadowEnabled: false
                                implicitHeight: 36
                                onClicked: {
                                    toolWindow.currentToolName = (typeof modelData === "object" && modelData.text) ? modelData.text : modelData
                                    toolWindow.open(openBtn)
                                }
                            }
                        }
                    }

                    background: Rectangle {
                        color: "transparent"
                        radius: 10
                    }
                }
            }
        }
    }
}
