import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import EvolveUI
import EvolveUI.Utils 1.0

Item {
    id: root
    anchors.fill: parent
    
    property bool isRecording: false
    property int recordingTimer: 0
    
    EToast {
        id: toast
        anchors.centerIn: parent
    }
    
    FFmpegRunner {
        id: runner
        onConversionStarted: {
            logArea.append("Recording started...")
        }
        onConversionFinished: (success, message) => {
            root.isRecording = false
            timer.stop()
            logArea.append(message)
            if (success) {
                toast.show("Recording Saved Successfully")
            } else {
                toast.show("Recording Stopped/Failed: " + message)
            }
        }
        onOutputLog: (log) => {
            if (logArea.length > 20000) {
                logArea.remove(0, logArea.length - 15000)
            }
            logArea.append(log)
            logArea.cursorPosition = logArea.length
        }
        onAudioDevicesReady: (devices) => {
            var list = []
            for (var i = 0; i < devices.length; i++) {
                list.push({ text: devices[i].name, deviceId: devices[i].id })
            }
            list.unshift({ text: "None", deviceId: "None" })
            
            // Preserve selection if possible
            var currentId = audioDropdown.selectedIndex >= 0 && audioDropdown.selectedIndex < audioDropdown.model.length 
                            ? audioDropdown.model[audioDropdown.selectedIndex].deviceId 
                            : "None"
            
            audioDropdown.model = list
            
            // Restore selection
            var newIndex = 0
            for (var j = 0; j < list.length; j++) {
                if (list[j].deviceId === currentId) {
                    newIndex = j
                    break
                }
            }
            // If not found, try default logic (index 1 if available)
            if (newIndex === 0 && list.length > 1 && currentId === "None") {
                newIndex = 1
            }
            
            audioDropdown.selectedIndex = newIndex
        }
    }
    
    Timer {
        id: timer
        interval: 1000
        repeat: true
        onTriggered: root.recordingTimer++
    }
    
    function formatTime(seconds) {
        var m = Math.floor(seconds / 60);
        var s = seconds % 60;
        return (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s);
    }

    Component.onCompleted: {
        runner.refreshAudioDevices()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

        Text {
            text: "Screen Recording"
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
                        id: outputPathInput
                        Layout.fillWidth: true
                        placeholderText: "Save to..."
                        text: "" // Default empty, will auto-generate
                        enabled: !root.isRecording
                    }
                    
                    EButton {
                        text: "Browse"
                        iconCharacter: "\uf07c"
                        onClicked: folderDialog.open()
                        enabled: !root.isRecording
                    }
                }
                
                    // === Settings Grid ===
                    GridLayout {
                        columns: 2
                        columnSpacing: 20
                        rowSpacing: 15
                        Layout.fillWidth: true

                        // Framerate
                        RowLayout {
                            spacing: 10
                            Text { text: "Framerate:"; color: theme.textColor; font.pixelSize: 16 }
                        EDropdown {
                            id: fpsDropdown
                            width: 120
                            model: [{text: "30"}, {text: "60"}, {text: "24"}, {text: "120"}]
                            selectedIndex: 0
                            enabled: !root.isRecording
                        }
                        }

                        // Video Encoder
                        RowLayout {
                            spacing: 10
                            Text { text: "Encoder:"; color: theme.textColor; font.pixelSize: 16 }
                            EDropdown {
                                id: encoderDropdown
                                width: 220
                                model: [
                                    { text: "CPU (libx264)", codec: "libx264" },
                                    { text: "NVIDIA NVENC (H.264)", codec: "h264_nvenc" },
                                    { text: "Intel QSV (H.264)", codec: "h264_qsv" },
                                    { text: "AMD AMF (H.264)", codec: "h264_amf" }
                                ]
                                selectedIndex: 0
                                enabled: !root.isRecording
                            }
                        }

                        // Quality
                        RowLayout {
                            spacing: 10
                            Text { text: "Quality:"; color: theme.textColor; font.pixelSize: 16 }
                            EDropdown {
                                id: qualityDropdown
                                width: 120
                                model: [
                                    { text: "High" },
                                    { text: "Medium" },
                                    { text: "Low" }
                                ]
                                selectedIndex: 1 // Default Medium
                                enabled: !root.isRecording
                            }
                        }

                        // Capture Method
                        RowLayout {
                            spacing: 10
                            Text { text: "Capture:"; color: theme.textColor; font.pixelSize: 16 }
                            EDropdown {
                                id: captureDropdown
                                width: 180
                                model: [
                                    { text: "GDI (Standard)", method: "gdigrab" },
                                    { text: "DirectX (Fast)", method: "ddagrab" }
                                ]
                                selectedIndex: 0 // Default GDI
                                enabled: !root.isRecording
                            }
                        }

                    // Audio Device
                    RowLayout {
                        spacing: 10
                        Text { text: "Audio:"; color: theme.textColor; font.pixelSize: 16 }
                        EDropdown {
                            id: audioDropdown
                            width: 200
                            model: [{text: "None"}, {text: "System Audio (Stereo Mix)"}, {text: "Microphone"}]
                            selectedIndex: 0
                            enabled: !root.isRecording
                        }
                        Text {
                            text: "(Requires device name)"
                            color: theme.textColor
                            opacity: 0.5
                            font.pixelSize: 12
                        }
                    }
                }

                // --- Control Row ---
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 20

                    // Left Side: Timer and Info
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5
                        
                        RowLayout {
                            Layout.fillWidth: true
                            Text { 
                                text: "Duration: "
                                color: theme.textColor
                                font.pixelSize: 16
                            }
                            Text {
                                text: root.isRecording ? formatTime(root.recordingTimer) : "00:00"
                                color: root.isRecording ? "#ff4444" : theme.focusColor
                                font.bold: true
                                font.pixelSize: 16
                            }
                            Item { Layout.fillWidth: true }
                        }
                        
                        Text {
                            text: root.isRecording ? "Recording in progress..." : "Ready to record"
                            color: theme.textColor
                            opacity: 0.7
                            font.pixelSize: 12
                        }
                    }

                    // Right Side: Action Button
                    EButton {
                        id: recordButton
                        Layout.alignment: Qt.AlignVCenter
                        text: root.isRecording ? "Stop Recording" : "Start Recording"
                        iconCharacter: root.isRecording ? "\uf04d" : "\uf111"
                        buttonColor: root.isRecording ? "#ff4444" : theme.focusColor
                        onClicked: {
                            if (root.isRecording) {
                                runner.stopRecording()
                                root.isRecording = false
                                timer.stop()
                            } else {
                                var path = outputPathInput.text
                                // Path logic handled by C++ default if empty
                                
                                var fps = fpsDropdown.model[fpsDropdown.selectedIndex].text
                                var audio = audioDropdown.model[audioDropdown.selectedIndex].deviceId
                                var venc = encoderDropdown.model[encoderDropdown.selectedIndex].codec
                                var quality = qualityDropdown.model[qualityDropdown.selectedIndex].text
                                var method = captureDropdown.model[captureDropdown.selectedIndex].method

                                runner.startScreenRecording(path, fps, audio, venc, quality, method)
                                root.isRecording = true
                                root.recordingTimer = 0
                                timer.start()
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
    
    FolderDialog {
        id: folderDialog
        title: "Select Output Folder"
        onAccepted: {
             // We want a file path, but folder dialog gives folder. 
             // Let's append a default filename
             var folder = selectedFolder.toString()
             if (folder.startsWith("file:///")) folder = folder.substring(8)
             outputPathInput.text = folder + "/Eideo_" + new Date().getTime() + ".mp4"
        }
    }
}
