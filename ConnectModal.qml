import QtQuick
import QtQuick.Layouts

Item {
    id: modal

    anchors.fill: parent
    visible: opacity > 0
    opacity: 0
    z: 9999

    required property var provider

    Theme {
        id: theme
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutQuad
        }
    }

    function open() {
        if (modal.provider) {
            modal.provider.lastError = "";
            if (typeof modal.provider.warmup === "function") {
                modal.provider.warmup();
            }
        }
        modal.opacity = 1.0;
    }

    function close() {
        modal.opacity = 0.0;
    }

    // Dimmed Backdrop
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.02, 0.02, 0.03, 0.75)

        MouseArea {
            anchors.fill: parent
            onClicked: modal.close()
        }
    }

    // Modal Card Dialog
    Rectangle {
        id: dialogCard
        width: Math.min(parent.width - 32, 380)
        implicitHeight: dialogLayout.implicitHeight + 40
        anchors.centerIn: parent
        radius: theme.radiusCard
        color: theme.bgSurfaceElevated
        clip: true

        MouseArea {
            anchors.fill: parent
            onClicked: {} // Catch clicks inside
        }

        ColumnLayout {
            id: dialogLayout
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            // Modal Header: DApp Identity & Title
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // DApp Icon (Smart Hybrid: displays genuine dApp icon when valid; collapses cleanly when omitted or on error)
                Rectangle {
                    id: dappIconContainer
                    readonly property string iconSrc: modal.provider && modal.provider.dappIcon ? modal.provider.dappIcon.trim() : ""
                    readonly property bool hasIcon: iconSrc.length > 0
                    readonly property real iconSize: visible ? headerTextCol.implicitHeight : 0
                    visible: hasIcon && (dappImg.status === Image.Ready || dappImg.status === Image.Loading) && dappImg.status !== Image.Error
                    Layout.preferredWidth: iconSize
                    Layout.preferredHeight: iconSize
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: iconSize
                    implicitHeight: iconSize
                    radius: theme.radiusLarge
                    color: "transparent"
                    clip: true

                    Image {
                        id: dappImg
                        anchors.fill: parent
                        source: dappIconContainer.hasIcon ? dappIconContainer.iconSrc : ""
                        fillMode: Image.PreserveAspectFit
                        mipmap: true
                        asynchronous: false
                        smooth: true
                    }
                }

                ColumnLayout {
                    id: headerTextCol
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: modal.provider ? modal.provider.dappName : "Connect dApp"
                        color: theme.textPrimary
                        font.family: theme.fontFamily
                        font.pixelSize: theme.panelTitleText
                        font.weight: Font.Bold
                    }

                    Text {
                        text: "wants to connect to your Wallez account"
                        color: theme.textSecondary
                        font.family: theme.fontFamily
                        font.pixelSize: theme.secondaryText
                    }
                }
            }

            // Divider Line
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: theme.borderSubtle
            }

            // Permissions Requested List
            ColumnLayout {
                id: permsLayout
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "Requested Permissions"
                    color: theme.textPrimary
                    font.family: theme.fontFamily
                    font.pixelSize: theme.primaryText
                    font.weight: Font.DemiBold
                }

                RowLayout {
                    spacing: 8
                    Text {
                        text: "✓"
                        color: theme.statusSuccess
                        font.bold: true
                        font.pixelSize: theme.secondaryText
                    }
                    Text {
                        text: "View account address and balances"
                        color: theme.textSecondary
                        font.family: theme.fontFamily
                        font.pixelSize: theme.secondaryText
                    }
                }

                RowLayout {
                    spacing: 8
                    visible: modal.provider && modal.provider.requestedGrants && modal.provider.requestedGrants.length > 0
                    Text {
                        text: "✓"
                        color: theme.statusSuccess
                        font.bold: true
                        font.pixelSize: theme.secondaryText
                    }
                    Text {
                        text: "Request identity proof & scoped nullifiers"
                        color: theme.textSecondary
                        font.family: theme.fontFamily
                        font.pixelSize: theme.secondaryText
                    }
                }
            }

            // Error / Status Banner (shown when Wallez is locked or uninitialized)
            Rectangle {
                Layout.fillWidth: true
                visible: modal.provider && modal.provider.lastError && modal.provider.lastError.length > 0
                implicitHeight: errorText.implicitHeight + 16
                radius: theme.radiusButton
                color: Qt.rgba(0.94, 0.27, 0.27, 0.12)
                border.color: theme.statusError
                border.width: 1

                Text {
                    id: errorText
                    anchors.fill: parent
                    anchors.margins: 8
                    text: modal.provider ? modal.provider.lastError : ""
                    color: theme.statusError
                    font.family: theme.fontFamily
                    font.pixelSize: theme.secondaryText
                    wrapMode: Text.WordWrap
                }
            }

            // Divider Line before Footer
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: theme.borderSubtle
            }

            // Action Buttons (Flat style)
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Cancel Button (Flat Secondary Charcoal with outline)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 36
                    radius: theme.radiusButton
                    color: cancelMouse.pressed ? theme.btnSecondaryPressed : (cancelMouse.containsMouse ? theme.btnSecondaryHoverTop : theme.btnSecondaryTop)
                    border.color: theme.btnSecondaryBorderSides
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: theme.textPrimary
                        font.family: theme.fontFamily
                        font.pixelSize: theme.primaryText
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: modal.close()
                    }
                }

                // Connect Button (Flat Primary Blue, borderless)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 36
                    radius: theme.radiusButton
                    color: connectMouse.pressed ? theme.btnPrimaryPressed : (connectMouse.containsMouse ? theme.btnPrimaryHoverTop : theme.btnPrimaryTop)

                    Text {
                        anchors.centerIn: parent
                        text: modal.provider && modal.provider.isConnecting ? "Connecting..." : "Connect Wallet"
                        color: theme.textPrimary
                        font.family: theme.fontFamily
                        font.pixelSize: theme.primaryText
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: connectMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modal.provider) {
                                modal.provider.connect(function (res) {
                                    if (res && res.ok) {
                                        modal.close();
                                    }
                                });
                            }
                        }
                    }
                }
            }
        }
    }
}
