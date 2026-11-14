import QtQuick
import "Client.js" as Client

Item {
    id: provider

    // DApp Configuration
    property string dappName: "Evice dApp"
    property string dappIcon: ""
    property int apiVersion: 1
    property var requestedGrants: ["IdentityRead", "IdentityPropose"]

    // Reactive Session State
    readonly property bool isHostAvailable: typeof logos !== "undefined" && typeof logos.callModule === "function"
    property bool isConnected: false
    property bool isConnecting: false
    property string sessionId: ""
    property var activeAccount: null
    property string activeAddress: ""
    property string voterCommitment: ""
    property var accounts: []
    property string statusMessage: "Disconnected"
    property string lastError: ""

    // Events & Signals
    signal connected(var account)
    signal disconnected
    signal accountChanged(var account)
    signal commitmentLoaded(string commitment)
    signal errorOccurred(string method, string message)

    // Core IPC Invoker
    function invoke(method, args, callback) {
        provider.lastError = "";
        if (!provider.isHostAvailable) {
            var fallbackErr = {
                ok: false,
                error: "Host module 'e_wallet_core' is not available. Please launch within Basecamp."
            };
            provider.lastError = fallbackErr.error;
            provider.errorOccurred(method, fallbackErr.error);
            if (callback) callback(fallbackErr);
            return fallbackErr;
        }

        try {
            var rawResult = logos.callModule("e_wallet_core", method, args || []);
            var parsed = Client.parseJson(rawResult);
            if (callback) callback(parsed);
            return parsed;
        } catch (err) {
            var caughtErr = {
                ok: false,
                error: err.toString()
            };
            provider.lastError = caughtErr.error;
            provider.errorOccurred(method, caughtErr.error);
            if (callback) callback(caughtErr);
            return caughtErr;
        }
    }

    // Connect Handshake
    function connect(callback) {
        if (provider.isConnected && provider.sessionId) {
            if (callback) callback({ ok: true, session_id: provider.sessionId });
            return;
        }

        provider.isConnecting = true;
        provider.statusMessage = "Connecting to Wallez Core...";

        invoke("connectDApp", [provider.dappName, provider.apiVersion], function(res) {
            if (res && res.ok && res.session_id) {
                provider.sessionId = res.session_id;
                provider.statusMessage = "Session established: " + provider.sessionId.substring(0, 16) + "...";

                // Step 1: Load permitted accounts
                loadAccounts(function() {
                    // Step 2: Acquire Identity Grants if requested
                    acquireGrants(function() {
                        provider.isConnecting = false;
                        provider.isConnected = true;
                        provider.statusMessage = "Connected";
                        provider.connected(provider.activeAccount);
                        if (callback) callback({ ok: true, session_id: provider.sessionId });
                    });
                });
            } else {
                provider.isConnecting = false;
                provider.isConnected = false;
                var errStr = res && res.error ? String(res.error) : "Failed to establish Wallez session";
                provider.statusMessage = "Connection failed: " + errStr;
                provider.lastError = errStr;
                provider.errorOccurred("connectDApp", errStr);
                if (callback) callback(res || { ok: false, error: errStr });
            }
        });
    }

    // Disconnect / Revoke Session
    function disconnect(callback) {
        if (!provider.sessionId) {
            resetSessionState();
            if (callback) callback({ ok: true });
            return;
        }

        var sid = provider.sessionId;
        invoke("revokeSession", [sid], function(res) {
            resetSessionState();
            if (callback) callback(res || { ok: true });
        });
    }

    function resetSessionState() {
        provider.sessionId = "";
        provider.isConnected = false;
        provider.isConnecting = false;
        provider.activeAccount = null;
        provider.activeAddress = "";
        provider.voterCommitment = "";
        provider.accounts = [];
        provider.statusMessage = "Disconnected";
        provider.disconnected();
    }

    // Accounts Loader
    function loadAccounts(callback) {
        if (!provider.sessionId) {
            if (callback) callback();
            return;
        }

        invoke("listSessionAccounts", [provider.sessionId], function(res) {
            if (res && res.ok && res.accounts && res.accounts.length > 0) {
                provider.accounts = res.accounts;
                provider.activeAccount = res.accounts[0];
                provider.activeAddress = res.accounts[0].canonical_address || res.accounts[0].account_id;
                provider.accountChanged(provider.activeAccount);
                if (callback) callback();
            } else {
                // Fallback: Query all accounts if session accounts list is empty
                invoke("listAllAccounts", [], function(allRes) {
                    if (allRes && allRes.ok && allRes.accounts && allRes.accounts.length > 0) {
                        provider.accounts = allRes.accounts;
                        provider.activeAccount = allRes.accounts[0];
                        provider.activeAddress = allRes.accounts[0].canonical_address || allRes.accounts[0].account_id;
                        provider.accountChanged(provider.activeAccount);
                    }
                    if (callback) callback();
                });
            }
        });
    }

    // Identity Grants & ZK Citizency
    function acquireGrants(callback) {
        if (!provider.sessionId || !provider.requestedGrants || provider.requestedGrants.length === 0) {
            if (callback) callback();
            return;
        }

        var grants = provider.requestedGrants.slice();
        function processNextGrant() {
            if (grants.length === 0) {
                // All grants processed, load citizen master commitment
                loadIdentityCommitment(callback);
                return;
            }
            var g = grants.shift();
            invoke("requestIdentityAccess", [provider.sessionId, g], function() {
                processNextGrant();
            });
        }
        processNextGrant();
    }

    function loadIdentityCommitment(callback) {
        if (!provider.sessionId) {
            if (callback) callback();
            return;
        }

        invoke("getIdentityCommitment", [provider.sessionId], function(res) {
            if (res && res.ok && res.commitment) {
                provider.voterCommitment = res.commitment;
                provider.commitmentLoaded(res.commitment);
            }
            if (callback) callback();
        });
    }

    // High-Level DApp Operations

    /**
     * Derive a deterministic, unlinkable scoped nullifier for a specific domain/proposal.
     */
    function deriveNullifier(scopeId, callback) {
        if (!provider.sessionId) {
            if (callback) callback({ ok: false, error: "No active Wallez session" });
            return;
        }
        invoke("deriveScopedNullifier", [provider.sessionId, scopeId], function(res) {
            if (callback) callback(res);
        });
    }

    /**
     * Sign a structured ballot or attestation using BIP-340 Schnorr and scoped credential.
     */
    function signAttestation(scopeId, payload, callback) {
        if (!provider.sessionId) {
            if (callback) callback({ ok: false, error: "No active Wallez session" });
            return;
        }
        var messageHex = Client.toHex(payload);
        invoke("signIdentityAttestation", [provider.sessionId, scopeId, messageHex], function(res) {
            if (callback) callback(res);
        });
    }

    /**
     * Propose an explicit smart contract call (triggers Wallez ApprovalModal).
     */
    function proposeContractCall(programId, payerId, mentions, calldataHex, description, callback) {
        if (!provider.sessionId) {
            if (callback) callback({ ok: false, error: "No active Wallez session" });
            return;
        }
        var mentionsJson = typeof mentions === "string" ? mentions : JSON.stringify(mentions || []);
        invoke("proposeContractCall", [
            provider.sessionId,
            programId,
            payerId || (provider.activeAccount ? provider.activeAccount.account_id : ""),
            mentionsJson,
            calldataHex,
            description || "Smart contract call proposed by " + provider.dappName
        ], function(res) {
            if (callback) callback(res);
        });
    }

    /**
     * Propose a native token transfer (triggers Wallez ApprovalModal).
     */
    function proposeTransfer(toAddressOrName, amountUnits, callback) {
        if (!provider.sessionId) {
            if (callback) callback({ ok: false, error: "No active Wallez session" });
            return;
        }
        var fromAcc = provider.activeAccount ? provider.activeAccount.account_id : "";
        invoke("proposeNativeTransfer", [
            provider.sessionId,
            fromAcc,
            toAddressOrName,
            String(amountUnits)
        ], function(res) {
            if (callback) callback(res);
        });
    }
}

