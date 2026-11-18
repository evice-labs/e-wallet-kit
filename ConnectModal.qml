import QtQuick
import QtQuick.Layouts
import "Client.js" as Client

Item {
    id: modal

    anchors.fill: parent
    visible: opacity > 0
    opacity: 0
    z: 9999

    required property var provider
    property bool isDropdownOpen: false

    Theme {
        id: theme
    }

    readonly property var selectedAccObj: {
        if (!modal.provider || !modal.provider.availableAccounts || modal.provider.availableAccounts.length === 0)
            return null;
        var list = modal.provider.availableAccounts;
        var sid = modal.provider.selectedAccountId || "";
        for (var i = 0; i < list.length; i++) {
            if (list[i].account_id === sid)
                return list[i];
        }
        return list[0];
    }

    readonly property var otherAccounts: {
        if (!modal.provider || !modal.provider.availableAccounts)
            return [];
        var list = modal.provider.availableAccounts;
        var selId = modal.selectedAccObj ? modal.selectedAccObj.account_id : "";
        var out = [];
        for (var i = 0; i < list.length; i++) {
            if (list[i].account_id !== selId)
                out.push(list[i]);
        }
        return out;
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutQuad
        }
    }

    function open() {
        modal.isDropdownOpen = false;
        if (modal.provider) {
            modal.provider.lastError = "";
            if (typeof modal.provider.warmup === "function") {
                modal.provider.warmup();
            }
            if (typeof modal.provider.loadAvailableAccounts === "function") {
                modal.provider.loadAvailableAccounts();
            }
        }
        modal.opacity = 1.0;
    }

    function close() {
        modal.isDropdownOpen = false;
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

            // Divider Line between Permissions and Select Account
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: theme.borderSubtle
                visible: modal.provider && modal.provider.availableAccounts && modal.provider.availableAccounts.length > 0
            }

            // Account Selection Dropdown
            ColumnLayout {
                id: accountSelectorLayout
                Layout.fillWidth: true
                spacing: 8
                visible: modal.provider && modal.provider.availableAccounts && modal.provider.availableAccounts.length > 0

                Text {
                    text: "Select Account"
                    color: theme.textPrimary
                    font.family: theme.fontFamily
                    font.pixelSize: theme.primaryText
                    font.weight: Font.DemiBold
                }

                // First / Active Selected Account Card
                Rectangle {
                    id: selectedAccountCard
                    readonly property bool isPriv: !!(modal.selectedAccObj && modal.selectedAccObj.is_private)
                    Layout.fillWidth: true
                    implicitHeight: 48
                    radius: theme.radiusButton
                    color: (modal.isDropdownOpen || triggerMouse.containsMouse) ? theme.bgSurfaceSubtle : theme.bgSurface
                    border.color: "transparent"
                    border.width: 0

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            RowLayout {
                                spacing: 6
                                Text {
                                    text: (modal.selectedAccObj && modal.selectedAccObj.label) ? modal.selectedAccObj.label : (selectedAccountCard.isPriv ? "Private Account" : "Public Account")
                                    color: theme.textPrimary
                                    font.family: theme.fontFamily
                                    font.pixelSize: theme.secondaryText
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    text: selectedAccountCard.isPriv ? "SHIELDED" : "PUBLIC"
                                    color: selectedAccountCard.isPriv ? theme.statusShielded : theme.btnPrimaryTop
                                    font.family: theme.fontFamily
                                    font.pixelSize: theme.badgeText
                                    font.weight: Font.Bold
                                }
                            }

                            Text {
                                text: modal.selectedAccObj ? Client.truncateAddress(modal.selectedAccObj.canonical_address || modal.selectedAccObj.account_id, 14, 6) : ""
                                color: theme.textMuted
                                font.family: theme.fontMono
                                font.pixelSize: theme.secondaryText
                            }
                        }

                        Text {
                            text: (modal.selectedAccObj && modal.selectedAccObj.formatted_balance ? modal.selectedAccObj.formatted_balance : "0") + " " + (modal.selectedAccObj && modal.selectedAccObj.unit ? modal.selectedAccObj.unit : "LGO")
                            color: theme.textSecondary
                            font.family: theme.fontMono
                            font.pixelSize: theme.secondaryText
                            font.weight: Font.Medium
                        }

                        Text {
                            visible: modal.otherAccounts.length > 0
                            text: modal.isDropdownOpen ? "∧" : "∨"
                            color: theme.textSecondary
                            font.pixelSize: theme.secondaryText
                        }
                    }

                    MouseArea {
                        id: triggerMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: modal.otherAccounts.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (modal.otherAccounts.length > 0) {
                                modal.isDropdownOpen = !modal.isDropdownOpen;
                            }
                        }
                    }
                }

                // Dropdown Options
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: dropdownCol.implicitHeight
                    radius: theme.radiusButton
                    color: theme.bgSurface
                    border.color: "transparent"
                    border.width: 0
                    clip: true
                    visible: modal.isDropdownOpen && modal.otherAccounts.length > 0

                    ColumnLayout {
                        id: dropdownCol
                        anchors.fill: parent
                        spacing: 0

                        Repeater {
                            model: modal.otherAccounts
                            delegate: ColumnLayout {
                                id: otherAccDelegate
                                required property var modelData
                                required property int index
                                readonly property bool isPriv: !!(modelData && modelData.is_private)
                                Layout.fillWidth: true
                                spacing: 0

                                Rectangle {
                                    visible: otherAccDelegate.index > 0
                                    Layout.fillWidth: true
                                    implicitHeight: 1
                                    color: theme.borderSubtle
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 44
                                    radius: 0
                                    border.color: "transparent"
                                    border.width: 0
                                    color: otherAccMouse.containsMouse ? theme.bgSurfaceSubtle : theme.bgSurface

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 10

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            RowLayout {
                                                spacing: 6
                                                Text {
                                                    text: otherAccDelegate.modelData.label ? otherAccDelegate.modelData.label : (otherAccDelegate.isPriv ? "Private Account" : "Public Account")
                                                    color: theme.textPrimary
                                                    font.family: theme.fontFamily
                                                    font.pixelSize: theme.secondaryText
                                                    font.weight: Font.DemiBold
                                                }
                                                Text {
                                                    text: otherAccDelegate.isPriv ? "SHIELDED" : "PUBLIC"
                                                    color: otherAccDelegate.isPriv ? theme.statusShielded : theme.btnPrimaryTop
                                                    font.family: theme.fontFamily
                                                    font.pixelSize: theme.badgeText
                                                    font.weight: Font.Bold
                                                }
                                            }

                                            Text {
                                                text: Client.truncateAddress(otherAccDelegate.modelData.canonical_address || otherAccDelegate.modelData.account_id, 14, 6)
                                                color: theme.textMuted
                                                font.family: theme.fontMono
                                                font.pixelSize: theme.secondaryText
                                            }
                                        }

                                        Text {
                                            text: (otherAccDelegate.modelData.formatted_balance || "0") + " " + (otherAccDelegate.modelData.unit || "LGO")
                                            color: theme.textSecondary
                                            font.family: theme.fontMono
                                            font.pixelSize: theme.secondaryText
                                            font.weight: Font.Medium
                                        }
                                    }

                                    MouseArea {
                                        id: otherAccMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (modal.provider) {
                                                modal.provider.selectedAccountId = otherAccDelegate.modelData.account_id || "";
                                            }
                                            modal.isDropdownOpen = false;
                                        }
                                    }
                                }
                            }
                        }
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

            // Action Buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Cancel Button
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

                // Connect Button
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
                                modal.provider.connect(modal.provider.selectedAccountId, function (res) {
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
