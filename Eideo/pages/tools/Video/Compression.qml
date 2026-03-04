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
    
    FFmpegRunner {
        id: runner
        onConversionStarted: {
            logArea.append("Compression started...")
            compressButton.enabled = false
        }
        onConversionFinished: (success, message) => {
            compressButton.enabled = true
            logArea.append(message)
            if (success) {
                toast.show("Compression Successful")
            } else {
                toast.show("Compression Failed: " + message)
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
            text: "Video Compression"
            font.pixelSize: 24
            font.bold: true
            color: theme.textColor
        }

        ECard {
            Layout.fillWidth: true
            
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 15

                // File Selection
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
                        iconCharacter: "\uf07c"
                        onClicked: fileDialog.open()
                    }
                }
                
                // === Advanced Settings Grid ===
                GridLayout {
                    columns: 2
                    columnSpacing: 20
                    rowSpacing: 15
                    Layout.fillWidth: true

                    // --- Row 1: Codec & Resolution ---
                    RowLayout {
                        spacing: 10
                        Text { text: "Codec:"; color: theme.textColor; font.pixelSize: 16 }
                        EDropdown {
                            id: codecDropdown
                            width: 140
                            model: [{text: "h264"}, {text: "h265"}]
                            selectedIndex: 0
                        }
                    }

                    RowLayout {
                        spacing: 10
                        Text { text: "Resolution:"; color: theme.textColor; font.pixelSize: 16 }
                        EDropdown {
                            id: resolutionDropdown
                            width: 140
                            model: [{text: "Original"}, {text: "1080p"}, {text: "720p"}, {text: "480p"}]
                            selectedIndex: 0
                        }
                    }

                    // --- Row 2: Preset & Audio ---
                    RowLayout {
                        spacing: 10
                        Text { text: "Preset:"; color: theme.textColor; font.pixelSize: 16 }
                        EDropdown {
                            id: presetDropdown
                            width: 140
                            model: [
                                {text: "ultrafast"}, {text: "superfast"}, {text: "veryfast"},
                                {text: "faster"}, {text: "fast"}, {text: "medium"},
                                {text: "slow"}, {text: "slower"}, {text: "veryslow"}
                            ]
                            selectedIndex: 5 // medium
                        }
                    }

                    RowLayout {
                        spacing: 10
                        Text { text: "Audio:"; color: theme.textColor; font.pixelSize: 16 }
                        EDropdown {
                            id: audioDropdown
                            width: 140
                            model: [{text: "Original"}, {text: "128k"}, {text: "64k"}, {text: "Remove"}]
                            selectedIndex: 0
                        }
                    }
                }

                // --- CRF Slider & Action Button Row ---
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 20

                    // Left Side: Slider and Info
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5
                        
                        RowLayout {
                            Layout.fillWidth: true
                            Text { 
                                text: "Compression Level (CRF): " + Math.round(crfSlider.value)
                                color: theme.textColor
                                font.pixelSize: 16
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "Quality: " + (crfSlider.value < 18 ? "Lossless" : crfSlider.value < 24 ? "High" : crfSlider.value < 30 ? "Medium" : "Low")
                                color: theme.focusColor
                                font.bold: true
                            }
                        }

                        ESlider {
                            id: crfSlider
                            Layout.fillWidth: true
                            text: "" 
                            itemSpacing: 0
                            containerMargins: 5
                            minimumValue: 0
                            maximumValue: 51
                            value: 23
                            stepSize: 1
                            decimals: 0
                            showValueText: false
                        }
                        
                        Text {
                            text: "Tip: Lower CRF = Higher Quality (Larger Size). Standard range is 18-28."
                            color: theme.textColor
                            opacity: 0.7
                            font.pixelSize: 12
                        }
                    }

                    // Right Side: Action Button
                    EButton {
                        id: compressButton
                        Layout.alignment: Qt.AlignVCenter
                        text: "Start Compression"
                        iconCharacter: "\uf066"
                        buttonColor: theme.focusColor
                        onClicked: {
                            if (filePathInput.text === "") {
                                toast.show("Please select a file first.")
                                return
                            }
                            var crf = Math.round(crfSlider.value)
                            var preset = presetDropdown.model[presetDropdown.selectedIndex].text
                            var codec = codecDropdown.model[codecDropdown.selectedIndex].text
                            var resolution = resolutionDropdown.model[resolutionDropdown.selectedIndex].text
                            var audio = audioDropdown.model[audioDropdown.selectedIndex].text
                            
                            try {
                                runner.compressVideo(filePathInput.text, crf, preset, codec, resolution, audio)
                            } catch(e) {
                                 toast.show("Please rebuild the application.")
                                 logArea.append("Error: " + e)
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true; height: 10 } // Spacer
            }
        }
        
        // Log Area
        ECard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                Text {
                    text: "Log"
                    font.pixelSize: 18
                    font.bold: true
                    color: theme.textColor
                }
                
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    
                    TextArea {
                        id: logArea
                        readOnly: true
                        color: theme.textColor
                        font.family: "Consolas"
                        background: null
                        wrapMode: TextEdit.NoWrap
                        selectByMouse: true
                    }
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
