import QtQuick
import EvolveUI

Item {
    id: control
    property var theme

    property real from: 0
    property real to: 1
    property real value: 0
    property real padding: 0

    property real normalized: (to - from) !== 0 ? (Math.max(from, Math.min(to, value)) - from) / (to - from) : 0
    implicitWidth: 200
    implicitHeight: 6
    clip: true

    Rectangle {
        anchors.fill: parent
        color: (control.theme && control.theme.isDark) ? "#333333" : "#e6e6e6"
        radius: 3
    }

    Rectangle {
        x: padding
        y: padding
        height: Math.max(2, control.height - padding * 2)
        width: Math.max(0, control.normalized * (control.width - padding * 2))
        radius: 2
        color: control.theme ? control.theme.focusColor : "#00C4B3"
    }
}
