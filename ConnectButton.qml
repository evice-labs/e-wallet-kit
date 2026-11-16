import QtQuick
import QtQuick.Layouts
import "Client.js" as Client

Item {
    id: control

    required property var provider
    property var connectModal: null
    property bool autoPromptModal: true

    implicitHeight: 34
    implicitWidth: contentRow.implicitWidth

    Theme {
        id: theme
    }

    RowLayout {
        id: contentRow
        anchors.fill: parent
        spacing: theme.spacingSmall

        // STATE 1 & 2: DISCONNECTED / CONNECTING
        Rectangle {
            id: connectBtnRect
            visible: !control.provider.isConnected
            implicitHeight: 32
            implicitWidth: btnText.implicitWidth + 24
            radius: theme.radiusButton
            color: connectMouseArea.pressed ? theme.btnPrimaryPressed : (connectMouseArea.containsMouse ? theme.btnPrimaryHoverTop : theme.btnPrimaryTop)

            RowLayout {
                anchors.centerIn: parent
                spacing: 6

                // Connecting pulse dot
                Rectangle {
                    visible: control.provider.isConnecting
                    width: 6
                    height: 6
                    radius: 3
                    color: "#FFFFFF"
                    SequentialAnimation on opacity {
                        running: control.provider.isConnecting
                        loops: Animation.Infinite
                        NumberAnimation {
                            from: 0.3
                            to: 1.0
                            duration: 400
                        }
                        NumberAnimation {
                            from: 1.0
                            to: 0.3
                            duration: 400
                        }
                    }
                }

                Text {
                    id: btnText
                    text: control.provider.isConnecting ? "Connecting..." : "Connect Wallez"
                    color: theme.textPrimary
                    font.family: theme.fontFamily
                    font.pixelSize: theme.primaryText
                    font.weight: Font.DemiBold
                }
            }

            MouseArea {
                id: connectMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (control.autoPromptModal && control.connectModal) {
                        control.connectModal.open();
                    } else {
                        control.provider.connect();
                    }
                }
            }
        }

        // STATE 3: CONNECTED BADGE & ACCOUNT DISPLAY
        RowLayout {
            visible: control.provider.isConnected
            spacing: 8

            // Connected Account Pill
            Rectangle {
                implicitHeight: 32
                implicitWidth: accountRow.implicitWidth + 20
                radius: theme.radiusButton
                color: theme.bgSurface
                border.color: theme.btnSecondaryBorderSides
                border.width: 1

                RowLayout {
                    id: accountRow
                    anchors.centerIn: parent

                    // Truncated Address Text
                    Text {
                        text: Client.truncateAddress(control.provider.activeAddress, 11, 4)
                        color: theme.textPrimary
                        font.family: theme.fontMono
                        font.pixelSize: theme.secondaryText
                        font.weight: Font.Medium
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked:
                    // Toggle info / copy address if needed
                    {}
                }
            }

            // Disconnect Button
            Rectangle {
                implicitHeight: 32
                implicitWidth: disconnectText.implicitWidth + 18
                radius: theme.radiusButton
                color: disconnectMouseArea.pressed ? "#7F1D1D" : (disconnectMouseArea.containsMouse ? "#B91C1C" : theme.btnSecondaryTop)
                border.color: disconnectMouseArea.containsMouse ? "#DC2626" : theme.btnSecondaryBorderSides
                border.width: 1

                Text {
                    id: disconnectText
                    anchors.centerIn: parent
                    text: "Disconnect"
                    color: disconnectMouseArea.containsMouse ? "#FFFFFF" : theme.textSecondary
                    font.family: theme.fontFamily
                    font.pixelSize: theme.secondaryText
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: disconnectMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: control.provider.disconnect()
                }
            }
        }
    }
}
