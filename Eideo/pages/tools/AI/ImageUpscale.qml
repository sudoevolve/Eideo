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
    
    RealESRGANRunner {
        id: runner
        onStarted: {
            logArea.append("Upscaling started... Check Task Queue for progress.")
            upscaleButton.enabled = false
        }
        onFinished: (success, message) => {
            upscaleButton.enabled = true
            logArea.append(message)
            if (success) {
                toast.show("Upscaling Successful")
            } else {
                toast.show("Upscaling Failed: " + message)
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
            text: "Image Upscale (Real-ESRGAN)"
            font.pixelSize: 24
            font.bold: true
            color: typeof theme !== "undefined" ? theme.textColor : "#000000"
        }

        ECard {
            Layout.fillWidth: true
            
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 16

                // File Selection
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    
                    EInput {
                        id: filePathInput
                        Layout.fillWidth: true
                        placeholderText: "Select an image file..."
                        readOnly: true
                    }
                    
                    EButton {
                        text: "Browse"
                        iconCharacter: "\uf07c"
                        onClicked: fileDialog.open()
                    }
                }
                
                // Settings
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 20
                    
                    Text {
                        text: "Model:"
                        color: typeof theme !== "undefined" ? theme.textColor : "#000000"
                        font.pixelSize: 16
                    }
                    
                    EDropdown {
                        id: modelDropdown
                        width: 250
                        // Map string list to object list with 'text' property for EDropdown compatibility
                        model: runner.modelList.map(name => ({text: name}))
                        selectedIndex: 0
                    }

                    Text {
                        text: "Scale:"
                        color: typeof theme !== "undefined" ? theme.textColor : "#000000"
                        font.pixelSize: 16
                    }

                    EDropdown {
                        id: scaleDropdown
                        width: 100
                        model: [
                            {text: "2x", value: 2},
                            {text: "3x", value: 3},
                            {text: "4x", value: 4}
                        ]
                        selectedIndex: 2 // Default 4x
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    EButton {
                        id: upscaleButton
                        text: "Start Upscale"
                        iconCharacter: "\uf424"
                        buttonColor: typeof theme !== "undefined" ? theme.focusColor : "#00C4B3"
                        onClicked: {
                            if (filePathInput.text === "") {
                                toast.show("Please select a file first.")
                                return
                            }
                            if (modelDropdown.model.length === 0) {
                                toast.show("No models found.")
                                return
                            }
                            // Access the 'text' property of the selected item
                            var model = modelDropdown.model[modelDropdown.selectedIndex].text
                            var scale = scaleDropdown.model[scaleDropdown.selectedIndex].value
                            runner.upscaleImage(filePathInput.text, model, scale)
                        }
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
        title: "Select Image"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.bmp *.webp)", "All files (*)"]
        onAccepted: {
            filePathInput.text = selectedFile
        }
    }
}
