## WallezKit (`@evice/wallez-kit`)

> **The standard Wallet Connector & Provider for Basecamp dApps.**  

## Features
- **Official Drop-in UI**: Production-ready `<ConnectButton />` and `<ConnectModal />` components out of the box.
- **Real-Time Reactive State**: Instant, automatic bindings for `isConnected`, `activeAddress`, `voterCommitment`, and `balance`.
- **Built-in ZK Identity Accountability**: Support for the [Evice Identity Stack](https://github.com/evice-labs/e-identity-stack) (deterministic scoped nullifiers & BIP-340 Schnorr signatures).

## Quick Start for dApp Developers

### 1. Import the Module
Add the `WallezKit` module import to your dApp's QML files:
```qml
import QtQuick
import QtQuick.Layouts
import WallezKit 1.0
```

### 2. Mount the `Provider`
Instantiate the `Provider` at the root of your application to establish a unified state context:
```qml
Item {
    id: appRoot

    Provider {
        id: wallet
        dappName: "My Evice dApp"
        requestedGrants: ["IdentityRead", "IdentityPropose"]
        onConnected: (account) => console.log("Connected account:", account.canonical_address)
    }

    ConnectModal {
        id: connectModal
        provider: wallet
    }
}
```

### 3. Place the `ConnectButton` in Your Navbar
Drop the interactive connection button anywhere in your header or navigation bar:
```qml
RowLayout {
    // Brand title / dApp Logo
    Text { 
        text: "My dApp" 
        font.bold: true
    }

    Item { Layout.fillWidth: true }

    // Official Drop-in Wallez Connect Button
    ConnectButton {
        provider: wallet
        connectModal: connectModal
    }
}
```

## API Reference

### `Provider`

#### Properties
| Property | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `dappName` | `string` | `"Evice dApp"` | The public name of your application shown in permission prompts. |
| `requestedGrants` | `var` | `["IdentityRead", "IdentityPropose"]` | Array of requested permission grants from the Evice Identity Stack. |
| `isConnected` | `bool` | `false` | Read-only reactive flag indicating if an active session is established. |
| `isConnecting` | `bool` | `false` | Read-only flag set to `true` while handshake or grant requests are pending. |
| `sessionId` | `string` | `""` | The unique session identifier assigned by Wallez Core. |
| `activeAccount` | `var` | `null` | The active account object containing `account_id`, `canonical_address`, `balance`, etc. |
| `activeAddress` | `string` | `""` | The canonical address of the currently selected account (`Public/...` or `Private/...`). |
| `voterCommitment` | `string` | `""` | 32-byte hex public ZK Master Commitment for privacy-preserving citizen verification. |
| `accounts` | `var` | `[]` | Array of all accounts accessible to this dApp session. |
| `statusMessage` | `string` | `"Disconnected"` | Real-time human-readable status description. |
| `lastError` | `string` | `""` | Descriptive error message from the most recent failed operation. |

#### Methods
| Method | Parameters | Return / Callback | Description |
| :--- | :--- | :--- | :--- |
| `connect(callback)` | `callback: function(res)` | `{ ok: bool, session_id: string }` | Initiates the dApp connection handshake, requests accounts, and acquires configured identity grants. |
| `disconnect(callback)` | `callback: function(res)` | `{ ok: bool }` | Terminates and revokes the active session, resetting local reactive state. |
| `deriveNullifier(scopeId, callback)` | `scopeId: string, callback: function(res)` | `{ ok: bool, nullifier: string }` | Computes a deterministic, unlinkable scoped nullifier for a specific domain (e.g. proposal ID). |
| `signAttestation(scopeId, payload, callback)` | `scopeId: string, payload: any, callback: function(res)` | `{ ok: bool, signature: string }` | Produces a 64-byte BIP-340 Schnorr signature using the scoped citizen credential. |
| `proposeContractCall(programId, payerId, mentions, calldataHex, description, callback)` | `programId, payerId, mentions, calldataHex, description, callback` | `{ ok: bool, request_id: string }` | Proposes a smart contract call to the LEZ Sequencer, triggering Wallez's interactive `ApprovalModal`. |
| `proposeTransfer(toAddressOrName, amountUnits, callback)` | `toAddressOrName, amountUnits, callback` | `{ ok: bool, request_id: string }` | Proposes a native token transfer, triggering Wallez's interactive `ApprovalModal`. |

### `ConnectButton`

#### Properties
| Property | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `provider` | `Provider` | *(Required)* | Reference to the `Provider` instance to bind to. |
| `connectModal` | `ConnectModal` | `null` | Optional reference to a `ConnectModal` to display when clicked in a disconnected state. |
| `autoPromptModal` | `bool` | `true` | If `true`, clicking the button when disconnected opens the `connectModal`. If `false`, directly calls `provider.connect()`. |

### `ConnectModal`

#### Properties & Methods
| Member | Type | Description |
| :--- | :--- | :--- |
| `provider` | `Provider` | *(Required)* Reference to the `Provider` instance. |
| `open()` | `function()` | Opens and displays the modal dialog with an animated fade-in backdrop. |
| `close()` | `function()` | Closes and hides the modal dialog. |

## Security Model & Best Practices

- **Zero-Trust Private Key Isolation**: DApps never have access to private keys or master seed mnemonics. All signing operations occur inside the isolated `e_wallet_core` process.
- **Scoped Identity Nullifiers**: When participating in decentralized governance or voting, each proposal uses a unique `scopeId` (`dao.governance.lez/proposal/<id>`). This guarantees unlinkability across different proposals while preventing double-voting (*Sybil resistance*).
- **Interactive Mutational Approvals**: Read operations and deterministic nullifier derivation are handled seamlessly through granted session permissions, while financial transfers and on-chain contract executions always trigger Wallez's explicit `ApprovalModal` dialog.

## License
MIT OR Apache-2.0. Copyright (c) 2026 Evice Labs.
