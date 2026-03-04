import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import EvolveUI
import EvolveUI.Utils 1.0

Item {
    id: root
    anchors.fill: parent
    
    EToast {
        id: toast
        anchors.centerIn: parent
    }
    
    // FFmpeg Runner
    FFmpegRunner {
        id: runner
        onConversionStarted: {
            logArea.append("Conversion started...")
            convertButton.enabled = false
        }
        onConversionFinished: (success, message) => {
            convertButton.enabled = true
            logArea.append(message)
            if (success) {
                toast.show("Conversion Successful")
            } else {
                toast.show("Conversion Failed: " + message)
            }
        }
        onOutputLog: (log) => {
            if (logArea.length > 20000) {
                logArea.remove(0, logArea.length - 15000)
            }
            logArea.append(log)
            logArea.cursorPosition = logArea.length
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

        Text {
            text: "Video Format Conversion"
            font.pixelSize: 24
            font.bold: true
            color: typeof theme !== "undefined" ? theme.textColor : "#000000"
        }

        ECard {
            Layout.fillWidth: true
            
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                
                EInput {
                    id: filePathInput
                    Layout.fillWidth: true
                    placeholderText: "Select a video file..."
                    readOnly: true
                }
                
                EButton {
                    text: "Browse"
                    iconCharacter: "\uf07c" // Folder icon
                    onClicked: fileDialog.open()
                }
            }
            
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 10
                spacing: 10
                
                Text {
                    text: "Output Format:"
                    color: typeof theme !== "undefined" ? theme.textColor : "#000000"
                    font.pixelSize: 16
                }
                
                EDropdown {
                    id: formatDropdown
                    width: 150
                    model: [
                        {text: "mp4"},
                        {text: "avi"},
                        {text: "mkv"},
                        {text: "mov"},
                        {text: "wmv"},
                        {text: "flv"},
                        {text: "gif"}
                    ]
                    selectedIndex: 0
                }

                Text {
                    text: "Quality:"
                    color: typeof theme !== "undefined" ? theme.textColor : "#000000"
                    font.pixelSize: 16
                }

                EDropdown {
                    id: qualityDropdown
                    width: 150
                    model: [
                        {text: "Medium"},
                        {text: "High"},
                        {text: "Low"}
                    ]
                    selectedIndex: 0
                }
                
                Item { Layout.fillWidth: true } // Spacer
                
                EButton {
                    id: convertButton
                    text: "Start Conversion"
                    iconCharacter: "\uf021" // Refresh/Exchange icon
                    buttonColor: typeof theme !== "undefined" ? theme.focusColor : "#00C4B3"
                    onClicked: {
                        if (filePathInput.text === "") {
                            toast.show("Please select a file first.")
                            return
                        }
                        var format = formatDropdown.model[formatDropdown.selectedIndex].text
                        var quality = qualityDropdown.model[qualityDropdown.selectedIndex].text
                        runner.convertVideo(filePathInput.text, format, quality)
                    }
                }
            }
        }
        
        ECard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            Text {
                text: "Log"
                font.pixelSize: 18
                font.bold: true
                color: typeof theme !== "undefined" ? theme.textColor : "#000000"
            }
            
            ScrollView {
                id: logScrollView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                
                TextArea {
                    id: logArea
                    readOnly: true
                    color: typeof theme !== "undefined" ? theme.textColor : "#000000"
                    font.family: "Consolas"
                    background: null
                    wrapMode: TextEdit.NoWrap
                }
            }
        }
    }
    
    FileDialog {
        id: fileDialog
        title: "Select Video File"
        nameFilters: ["Video files (*.mp4 *.avi *.mkv *.mov *.wmv *.flv)", "All files (*)"]
        onAccepted: {
            filePathInput.text = selectedFile
        }
    }
}
