import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import EvolveUI

ColumnLayout {
    anchors.fill: parent
    anchors.margins: 20
    spacing: 20

    Label {
        text: "Video Stabilization"
        font.pixelSize: 24
        font.bold: true
        color: theme.textColor
        Layout.alignment: Qt.AlignHCenter
    }
    
    Label {
        text: "Functionality for Video Stabilization goes here."
        color: theme.textColor
        Layout.alignment: Qt.AlignHCenter
    }

    Item { Layout.fillHeight: true }
}