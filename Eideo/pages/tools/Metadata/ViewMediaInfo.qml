import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import EvolveUI

ColumnLayout {
    anchors.fill: parent
    anchors.margins: 20
    spacing: 20

    Label {
        text: "View Media Info"
        font.pixelSize: 24
        font.bold: true
        color: theme.textColor
        Layout.alignment: Qt.AlignHCenter
    }
    
    Label {
        text: "Functionality for View Media Info goes here."
        color: theme.textColor
        Layout.alignment: Qt.AlignHCenter
    }

    Item { Layout.fillHeight: true }
}