// EDropdown.qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Basic as Basic
import QtQuick.Effects

Item {
    id: root

    // === 基础属性 ===
    property string title: "请选择"
    property bool opened: false
    property var model: []
    property int selectedIndex: -1
    signal selectionChanged(int index, var item)

    // === 样式属性 ===
    property bool backgroundVisible: true
    property real radius: 20
    property color headerColor: theme.secondaryColor
    property color textColor: theme.textColor
    property color shadowColor: theme.shadowColor
    property bool shadowEnabled: true
    property int fontSize: 16
    property color hoverColor: Qt.darker(headerColor, 1.2)
    property int headerHeight: 44
    property int popupMaxHeight: 300
    property int horizontalPadding: 12
    property real pressedScale: 0.96
    property int popupSpacing: 6

    // === 弹出动画参数 ===
    property int popupEnterDuration: 260
    property int popupExitDuration: 200
    property real popupSlideOffset: -12
    property real popupScaleFrom: 0.98

    property int popupDirection: 0 // 0: Down, 1: Up

    width: 200
    height: headerHeight

    Item {
        id: headerContainer
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.headerHeight

        MultiEffect {
            source: headerBackground
            anchors.fill: headerBackground
            visible: root.shadowEnabled
            shadowEnabled: true
            shadowColor: root.shadowColor
            shadowBlur: theme.shadowBlur
            shadowVerticalOffset: theme.shadowYOffset
            shadowHorizontalOffset: theme.shadowXOffset
        }

        Rectangle {
            id: headerBackground
            anchors.fill: parent
            radius: root.radius
            color: root.backgroundVisible ? root.headerColor : "transparent"
            border.color: root.backgroundVisible ? "transparent" : root.textColor
            border.width: root.backgroundVisible ? 0 : 1
            visible: root.backgroundVisible || root.shadowEnabled
        }

        Item {
            anchors.fill: parent

            transform: Scale {
                id: headerScale
                origin.x: width / 2
                origin.y: height / 2
            }

            ParallelAnimation {
                id: restoreHeaderAnimation
                SpringAnimation { target: headerScale; property: "xScale"; spring: 2.5; damping: 0.25 }
                SpringAnimation { target: headerScale; property: "yScale"; spring: 2.5; damping: 0.25 }
            }

            Item {
                anchors.fill: parent
                anchors.leftMargin: root.horizontalPadding
                anchors.rightMargin: root.horizontalPadding

                Text {
                    id: headerText
                    anchors.left: parent.left
                    anchors.right: arrowIcon.left
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter

                    text: root.selectedIndex >= 0 ? root.model[root.selectedIndex].text : root.title
                    color: root.textColor
                    font.pixelSize: root.fontSize
                    font.bold: true
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    id: arrowIcon
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    text: "\uf054"
                    font.family: "Font Awesome 6 Free"
                    font.pixelSize: 16
                    color: theme.focusColor
                    rotation: root.opened ? (root.popupDirection === 1 ? -90 : 90) : 0

                    Behavior on rotation { RotationAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: {
                    headerScale.xScale = root.pressedScale
                    headerScale.yScale = root.pressedScale
                }
                onReleased: restoreHeaderAnimation.start()
                onCanceled: restoreHeaderAnimation.start()
                onClicked: root.opened = !root.opened
            }
        }
    }

    Popup {
        id: dropdownPopup
        x: 0
        y: root.popupDirection === 1 ? -height - root.popupSpacing : root.headerHeight + root.popupSpacing
        width: root.width
        height: Math.min(contentListView.contentHeight + 10, root.popupMaxHeight)
        
        visible: root.opened
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onClosed: root.opened = false
        
        padding: 0
        margins: 0
        
        background: Item {
            MultiEffect {
                source: popupBgRect
                anchors.fill: popupBgRect
                visible: root.shadowEnabled
                shadowEnabled: true
                shadowColor: root.shadowColor
                shadowBlur: theme.shadowBlur
                shadowVerticalOffset: theme.shadowYOffset
                shadowHorizontalOffset: theme.shadowXOffset
            }
            
            Rectangle {
                id: popupBgRect
                anchors.fill: parent
                radius: root.radius
                color: root.backgroundVisible ? root.headerColor : "transparent"
                border.color: root.backgroundVisible ? "transparent" : root.textColor
                border.width: root.backgroundVisible ? 0 : 1
            }
        }

        contentItem: ListView {
            id: contentListView
            clip: true
            spacing: 6
            topMargin: 4
            bottomMargin: 4
            model: root.model
            
            // Fix for ListView in Popup: ensure it takes the size
            width: dropdownPopup.availableWidth
            height: dropdownPopup.availableHeight

            delegate: Item {
                width: contentListView.width - 8
                height: 48
                anchors.horizontalCenter: parent.horizontalCenter

                // Animation for item appearance
                opacity: 1 // Simplified for Popup (entire popup fades)
                
                Rectangle {
                    id: itemBg
                    anchors.fill: parent
                    radius: 6

                    property bool hovered: false
                    color: !root.backgroundVisible ? "transparent" : (hovered ? root.hoverColor : Qt.rgba(root.hoverColor.r, root.hoverColor.g, root.hoverColor.b, 0))
                    Behavior on color { ColorAnimation { duration: 150 } }
                    
                    transform: Scale {
                        id: itemScale
                        origin.x: width / 2
                        origin.y: height / 2
                    }
                    
                    ParallelAnimation {
                        id: restoreItemAnimation
                        SpringAnimation { target: itemScale; property: "xScale"; spring: 2.5; damping: 0.25 }
                        SpringAnimation { target: itemScale; property: "yScale"; spring: 2.5; damping: 0.25 }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            itemScale.xScale = root.pressedScale
                            itemScale.yScale = root.pressedScale
                        }
                        onReleased: restoreItemAnimation.start()
                        onCanceled: restoreItemAnimation.start()
                        onClicked: {
                            root.selectedIndex = index
                            root.opened = false
                            root.selectionChanged(index, modelData)
                        }
                        onEntered: itemBg.hovered = true
                        onExited: itemBg.hovered = false
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: root.horizontalPadding - 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.text
                    font.pixelSize: root.fontSize
                    font.bold: false
                    color: root.textColor
                    visible: true
                }
            }

            ScrollBar.vertical: Basic.ScrollBar {
                width: 4
                policy: ScrollBar.AsNeeded
                active: contentListView.moving || contentListView.dragging

                contentItem: Rectangle {
                    implicitWidth: 4
                    implicitHeight: 100
                    radius: 2
                    color: root.textColor
                    opacity: 0.3
                }
                background: Rectangle {
                    implicitWidth: 4
                    implicitHeight: 100
                    color: "transparent"
                }
            }
        }

        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: root.popupEnterDuration }
                NumberAnimation { property: "scale"; from: root.popupScaleFrom; to: 1.0; duration: root.popupEnterDuration }
            }
        }

        exit: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: root.popupExitDuration }
                NumberAnimation { property: "scale"; from: 1.0; to: root.popupScaleFrom; duration: root.popupExitDuration }
            }
        }
    }
}
