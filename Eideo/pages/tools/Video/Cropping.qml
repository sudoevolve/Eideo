import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import EvolveUI

ColumnLayout {
    anchors.fill: parent
    anchors.margins: 20
    spacing: 20

    Label {
        text: "Cropping"
        font.pixelSize: 24
        font.bold: true
        color: theme.textColor
        Layout.alignment: Qt.AlignHCenter
    }
    
    Label {
        text: "Functionality for Cropping goes here."
        color: theme.textColor
        Layout.alignment: Qt.AlignHCenter
    }

    Item { Layout.fillHeight: true }
}