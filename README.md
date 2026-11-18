## WallezKit (`@evice/wallez-kit`)

> **The standard Wallet Connector & Provider for Basecamp dApps.**  

## Features
- **Official Drop-in UI**: Production-ready `<ConnectButton />` and `<ConnectModal />` components out of the box, with inline error feedback when the host wallet is locked or uninitialized.
- **Real-Time Reactive State & Lifecycle Management**: Instant bindings for `isConnected`, `activeAddress`, `voterCommitment`, and `accounts`, with automatic IPC replica warm-up on mount, automatic session revocation on component destruction, and reactive session invalidation detection when the wallet locks or revokes access.
- **Built-in ZK Identity Accountability**: Support for the [Evice Identity Stack](https://github.com/evice-labs/e-identity-stack) (deterministic scoped nullifiers & raw hex-encoded BIP-340 Schnorr signatures).
- **Interactive Approval Synchronization**: Automatic cross-module approval envelope registration and cleanup (`proposeContractCall`, `proposeTransfer`, `cancelRequest`) for seamless `ApprovalModal` handshakes in Wallez.

## Installation

Add WallezKit as a Git submodule inside your Basecamp dApp's `qml/` directory:

```bash
cd my-basecamp-dapp
git submodule add https://github.com/evice-labs/wallez-kit.git qml/WallezKit
```

> **Cloning an existing dApp?** Clone with submodules so WallezKit is initialized automatically:
> ```bash
> git clone --recursive <dapp-repo-url>
> # or if already cloned:
> git submodule update --init --recursive
> ```

## Quick Start for dApp Developers

### 1. Import the Module
Add the `WallezKit` module import to your dApp's QML files:
```qml
import QtQuick
import QtQuick.Layouts
import "WallezKit"
```

### 2. Mount the `Provider`
Instantiate the `Provider` at the root of your application to establish a unified state context:
```qml
Item {
    id: appRoot

    Provider {
        id: wallet
        dappName: "My dApp"
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
| `dappName` | `string` | `"Logos dApp"` | The public name of your application shown in permission prompts and Wallez Activity Feed. |
| `dappIcon` | `string` | `""` | Optional icon URL/path displayed in `ConnectModal` when valid. |
| `apiVersion` | `int` | `1` | Capability negotiation protocol version passed to `connectDApp`. |
| `requestedGrants` | `var` | `["IdentityRead", "IdentityPropose"]` | Array of requested permission grants from the Evice Identity Stack. |
| `isConnected` | `bool` | `false` | Read-only reactive flag indicating if an active session is established. |
| `isConnecting` | `bool` | `false` | Read-only flag set to `true` while handshake or grant requests are pending. |
| `sessionId` | `string` | `""` | The unique session identifier assigned by Wallez Core. |
| `activeAccount` | `var` | `null` | The active account object containing `account_id`, `canonical_address`, `balance`, etc. |
| `activeAddress` | `string` | `""` | The canonical address of the currently selected account (`Public/...` or `Private/...`). |
| `selectedAccountId` | `string` | `""` | Account ID selected by the user in `ConnectModal` (or via `selectAccount()`) for scoped session grants. |
| `voterCommitment` | `string` | `""` | 32-byte hex public ZK Master Commitment for privacy-preserving citizen verification. |
| `accounts` | `var` | `[]` | Array of accounts granted to this dApp session. |
| `availableAccounts` | `var` | `[]` | Array of wallet accounts fetched via `loadAvailableAccounts()` for selection in `ConnectModal`. |
| `statusMessage` | `string` | `"Disconnected"` | Real-time human-readable status description. |
| `lastError` | `string` | `""` | Descriptive error message from the most recent failed operation (e.g. when Wallez is locked or not initialized). |

#### Methods
| Method | Parameters | Return / Callback | Description |
| :--- | :--- | :--- | :--- |
| `warmup` | *(none)* | `void` | Pre-warms the `QRemoteObjectReplica` IPC connection to `e_wallet_core`. Called automatically on `Component.onCompleted` and `ConnectModal.open()`. |
| `loadAvailableAccounts` | `callback` | `{ ok, accounts }` | Fetches available wallet accounts before handshake so the user can choose which account to connect in `ConnectModal`. |
| `selectAccount` | `accountId` | `void` | Switches the active account for the current dApp session and emits `accountChanged`. |
| `connect` | `selectedIdOrCallback, callback` | `{ ok, session_id, error? }` | Initiates the dApp connection handshake (with automatic cold-start replica retry), grants `read`/`propose` access to the selected account, and acquires configured identity grants. |
| `disconnect` | `callback` | `{ ok }` | Cleans up pending approval envelopes, revokes the active session on `e_wallet_core`, and resets local reactive state. Called automatically on `Component.onDestruction`. |
| `deriveNullifier` | `scopeId, callback` | `{ ok, nullifier }` | Computes a deterministic, unlinkable scoped nullifier for a specific domain (e.g. proposal ID). |
| `signAttestation` | `scopeId, payload, callback` | `{ ok, signature }` | Encodes `payload` as raw lowercase hex (`Client.toHex`) and produces a 64-byte BIP-340 Schnorr signature using the scoped citizen credential. |
| `proposeContractCall` | `programId, payerId, mentions, calldataHex, description, callback` | `{ ok, request_id, status }` | Normalizes account prefixes (`Public/` / `Private/`) and calldata hex, proposes a smart contract call, and registers a cross-module approval envelope for Wallez's `ApprovalModal`. |
| `proposeTransfer` | `toAddressOrName, amountUnits, callback` | `{ ok, request_id, status }` | Proposes a native token transfer and registers an approval envelope with transfer metadata (`amount`, `payer_id`, `to`) for Wallez's `ApprovalModal`. |
| `cancelRequest` | `requestId, callback` | `{ ok }` | Cleans up the approval envelope and cancels a `pending_approval` request in Wallez Core. |
| `cleanupApprovalEnvelope` | `requestId` | `void` | Removes the temporary approval notification envelope once a request has been resolved. |

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

Dual-licensed under either:
- **Apache License, Version 2.0** ([LICENSE-APACHE](LICENSE-APACHE))
- **MIT License** ([LICENSE-MIT](LICENSE-MIT))

at your option.
