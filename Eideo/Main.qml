import QtQuick 2.15
import QtQuick.Controls 2.15
import Eideo 1.0

ApplicationWindow {
    visible: true
    width: 360
    height: 240
    title: "简单录屏器"

    ScreenRecorder {
        id: recorder
        onRecordingStarted: statusLabel.text = "录屏中..."
        onRecordingStopped: statusLabel.text = "已停止"
    }

    Column {
        anchors.centerIn: parent
        spacing: 20

        Button {
            text: "开始录制"
            onClicked: recorder.startRecording()
        }

        Button {
            text: "停止录制"
            onClicked: recorder.stopRecording()
        }

        Label {
            id: statusLabel
            text: "准备录制"
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 18
        }
    }
}
