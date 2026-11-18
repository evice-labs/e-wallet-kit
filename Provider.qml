import QtQuick
import "Client.js" as Client

Item {
    id: provider

    // DApp Configuration
    property string dappName: "Logos dApp"
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
    property string selectedAccountId: ""
    property string voterCommitment: ""
    property var accounts: []
    property var availableAccounts: []
    property string statusMessage: "Disconnected"
    property string lastError: ""

    property var _pendingConnectCallback: null
    property int _connectRetryCount: 0
    property var _approvalEnvelopes: ({})

    // Events & Signals
    signal connected(var account)
    signal disconnected
    signal accountChanged(var account)
    signal commitmentLoaded(string commitment)
    signal errorOccurred(string method, string message)

    Component.onCompleted: {
        warmup();
    }

    Component.onDestruction: {
        if (provider.isConnected && provider.sessionId) {
            provider.disconnect();
        }
    }

    Timer {
        id: retryConnectTimer
        interval: 300
        repeat: false
        onTriggered: {
            provider._attemptConnect(provider._pendingConnectCallback);
        }
    }

    // Pre-warm QRemoteObjectReplica transport connection to e_wallet_core on startup
    function warmup() {
        if (!provider.isHostAvailable) {
            return;
        }
        try {
            logos.callModule("e_wallet_core", "isInitialized", []);
        } catch (e)
        // Ignore warm-up errors while replica initializes
        {}
    }

    function formatErrorMessage(rawErr) {
        var msg = String(rawErr || "");
        if (msg.indexOf("Wallet is locked") !== -1 || msg.indexOf("WalletLocked") !== -1 || msg.indexOf("WALLET_LOCKED") !== -1) {
            return "Wallez is locked. Please unlock your wallet in the Wallez app first.";
        }
        if (msg.indexOf("not initialized") !== -1 || msg.indexOf("Null engine") !== -1) {
            return "Wallez is not initialized yet. Please open and unlock the Wallez app first.";
        }
        return msg || "Failed to establish Wallez session.";
    }

    // Core IPC Invoker
    function invoke(method, args, callback) {
        if (!provider.isHostAvailable) {
            var fallbackErr = {
                ok: false,
                error: "Host module 'e_wallet_core' is not available. Please launch within Basecamp."
            };
            provider.lastError = fallbackErr.error;
            provider.errorOccurred(method, fallbackErr.error);
            if (callback)
                callback(fallbackErr);
            return fallbackErr;
        }

        try {
            var rawResult = logos.callModule("e_wallet_core", method, args || []);
            var parsed = Client.parseJson(rawResult);
            if (parsed && parsed.ok === false && provider.isConnected && method !== "connectDApp" && method !== "revokeSession") {
                var errStr = String(parsed.error || "");
                if (errStr.indexOf("SessionNotFound") !== -1 || errStr.indexOf("Session not found") !== -1 || errStr.indexOf("WalletLocked") !== -1 || errStr.indexOf("Wallet is locked") !== -1) {
                    resetSessionState();
                }
            }
            if (callback)
                callback(parsed);
            return parsed;
        } catch (err) {
            var caughtErr = {
                ok: false,
                error: err.toString()
            };
            provider.lastError = caughtErr.error;
            provider.errorOccurred(method, caughtErr.error);
            if (callback)
                callback(caughtErr);
            return caughtErr;
        }
    }

    // Connect Handshake
    function connect(selectedIdOrCallback, maybeCallback) {
        var cb = (typeof selectedIdOrCallback === "function") ? selectedIdOrCallback : maybeCallback;
        if (typeof selectedIdOrCallback === "string" && selectedIdOrCallback.length > 0) {
            provider.selectedAccountId = selectedIdOrCallback;
        }
        if (provider.isConnected && provider.sessionId) {
            if (cb)
                cb({
                    ok: true,
                    session_id: provider.sessionId
                });
            return;
        }

        provider.lastError = "";
        provider.isConnecting = true;
        provider.statusMessage = "Connecting to Wallez Core...";
        provider._connectRetryCount = 0;
        provider._pendingConnectCallback = cb || null;

        _attemptConnect(cb);
    }

    function _attemptConnect(callback) {
        invoke("connectDApp", [provider.dappName, provider.apiVersion], function (res) {
            if (res && res.ok && res.session_id) {
                provider._pendingConnectCallback = null;
                provider.sessionId = res.session_id;
                provider.statusMessage = "Session established: " + provider.sessionId.substring(0, 16) + "...";

                // Step 1: Load and grant permitted accounts
                loadAccounts(function () {
                    // Step 2: Acquire Identity Grants if requested
                    acquireGrants(function () {
                        provider.isConnecting = false;
                        provider.isConnected = true;
                        provider.lastError = "";
                        provider.statusMessage = "Connected";
                        console.log("[WallezKit] Connected session:", provider.sessionId, "account:", provider.activeAddress);
                        provider.connected(provider.activeAccount);
                        if (callback)
                            callback({
                                ok: true,
                                session_id: provider.sessionId
                            });
                    });
                });
            } else {
                var rawErr = (res && res.error) ? String(res.error) : "";
                var isTransientReplicaError = (!res || rawErr.length === 0 || rawErr.indexOf("replica") !== -1 || rawErr.indexOf("RemoteObject") !== -1);
                if (isTransientReplicaError && provider._connectRetryCount < 2) {
                    provider._connectRetryCount += 1;
                    retryConnectTimer.restart();
                    return;
                }

                provider._pendingConnectCallback = null;
                provider.isConnecting = false;
                provider.isConnected = false;
                var friendlyErr = formatErrorMessage(rawErr);
                provider.statusMessage = friendlyErr;
                provider.lastError = friendlyErr;
                console.warn("[WallezKit] connectDApp failed:", friendlyErr, "(raw:", rawErr + ")");
                provider.errorOccurred("connectDApp", friendlyErr);
                if (callback)
                    callback({
                        ok: false,
                        error: friendlyErr
                    });
            }
        });
    }

    // Disconnect / Revoke Session
    function disconnect(callback) {
        _cleanupAllApprovalEnvelopes();
        if (!provider.sessionId) {
            resetSessionState();
            if (callback)
                callback({
                    ok: true
                });
            return;
        }

        var sid = provider.sessionId;
        invoke("revokeSession", [sid], function (res) {
            resetSessionState();
            if (callback)
                callback(res || {
                    ok: true
                });
        });
    }

    function _registerApprovalEnvelope(reqId, promptMeta) {
        if (!reqId || !provider.isHostAvailable)
            return;
        var envelopeStr = "internal_approval:" + JSON.stringify(promptMeta);
        invoke("connectDApp", [envelopeStr, 1], function (envRes) {
            if (envRes && envRes.ok && envRes.session_id) {
                var updated = Object.assign({}, provider._approvalEnvelopes);
                updated[reqId] = envRes.session_id;
                provider._approvalEnvelopes = updated;
            }
        });
    }

    function cleanupApprovalEnvelope(reqId) {
        if (!reqId || !provider._approvalEnvelopes || !provider._approvalEnvelopes[reqId])
            return;
        var envSid = provider._approvalEnvelopes[reqId];
        var updated = Object.assign({}, provider._approvalEnvelopes);
        delete updated[reqId];
        provider._approvalEnvelopes = updated;
        invoke("revokeSession", [envSid]);
    }

    function _cleanupAllApprovalEnvelopes() {
        var envs = provider._approvalEnvelopes || {};
        for (var reqId in envs) {
            if (envs.hasOwnProperty(reqId) && envs[reqId]) {
                invoke("revokeSession", [envs[reqId]]);
            }
        }
        provider._approvalEnvelopes = ({});
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

    function loadAvailableAccounts(callback) {
        if (!provider.isHostAvailable) {
            provider.availableAccounts = [];
            if (callback)
                callback({
                    ok: false,
                    accounts: []
                });
            return;
        }
        invoke("isInitialized", [], function (initRes) {
            var isInit = !!(initRes && (initRes.initialized === true || initRes.value === true || (initRes.ok === true && initRes.locked !== true && initRes.initialized !== false)));
            invoke("listAllAccounts", [], function (allRes) {
                if (allRes && allRes.ok && Array.isArray(allRes.accounts) && allRes.accounts.length > 0) {
                    provider.availableAccounts = allRes.accounts;
                    var hasCurrent = false;
                    for (var i = 0; i < allRes.accounts.length; i++) {
                        if (allRes.accounts[i].account_id === provider.selectedAccountId) {
                            hasCurrent = true;
                            break;
                        }
                    }
                    if (!hasCurrent) {
                        provider.selectedAccountId = allRes.accounts[0].account_id || "";
                    }
                } else {
                    provider.availableAccounts = [];
                    if (allRes && allRes.error) {
                        provider.lastError = formatErrorMessage(allRes.error);
                    }
                }
                if (callback)
                    callback(allRes || {
                        ok: false,
                        accounts: []
                    });
            });
        });
    }

    function selectAccount(accountId) {
        if (!accountId)
            return;
        provider.selectedAccountId = accountId;
        var list = (provider.accounts && provider.accounts.length > 0) ? provider.accounts : provider.availableAccounts;
        for (var i = 0; i < list.length; i++) {
            if (list[i].account_id === accountId) {
                provider.activeAccount = list[i];
                provider.activeAddress = list[i].canonical_address || list[i].account_id;
                provider.accountChanged(provider.activeAccount);
                break;
            }
        }
    }

    // Accounts Loader
    function loadAccounts(callback) {
        if (!provider.sessionId) {
            if (callback)
                callback();
            return;
        }

        invoke("listSessionAccounts", [provider.sessionId], function (res) {
            if (res && res.ok && res.accounts && res.accounts.length > 0) {
                provider.accounts = res.accounts;
                var chosen = res.accounts[0];
                if (provider.selectedAccountId) {
                    for (var i = 0; i < res.accounts.length; i++) {
                        if (res.accounts[i].account_id === provider.selectedAccountId) {
                            chosen = res.accounts[i];
                            break;
                        }
                    }
                }
                provider.activeAccount = chosen;
                provider.activeAddress = chosen.canonical_address || chosen.account_id;
                provider.selectedAccountId = chosen.account_id || "";
                provider.accountChanged(provider.activeAccount);
                if (callback)
                    callback();
            } else {
                // Query all accounts and bind read + propose permissions to the selected account (or all if unspecified)
                invoke("listAllAccounts", [], function (allRes) {
                    if (allRes && allRes.ok && allRes.accounts && allRes.accounts.length > 0) {
                        var accList = allRes.accounts;
                        var chosen = accList[0];
                        if (provider.selectedAccountId) {
                            for (var k = 0; k < accList.length; k++) {
                                if (accList[k].account_id === provider.selectedAccountId) {
                                    chosen = accList[k];
                                    break;
                                }
                            }
                        }
                        var targetAccId = chosen.account_id;
                        if (provider.selectedAccountId && targetAccId) {
                            invoke("grantAccountAccess", [provider.sessionId, targetAccId, "read"]);
                            invoke("grantAccountAccess", [provider.sessionId, targetAccId, "propose"]);
                            provider.accounts = [chosen];
                        } else {
                            for (var j = 0; j < accList.length; j++) {
                                var accId = accList[j].account_id;
                                if (accId) {
                                    invoke("grantAccountAccess", [provider.sessionId, accId, "read"]);
                                    invoke("grantAccountAccess", [provider.sessionId, accId, "propose"]);
                                }
                            }
                            provider.accounts = accList;
                        }
                        provider.activeAccount = chosen;
                        provider.activeAddress = chosen.canonical_address || chosen.account_id;
                        provider.selectedAccountId = chosen.account_id || "";
                        provider.accountChanged(provider.activeAccount);
                    }
                    if (callback)
                        callback();
                });
            }
        });
    }

    // Identity Grants & ZK Citizency
    function acquireGrants(callback) {
        if (!provider.sessionId || !provider.requestedGrants || provider.requestedGrants.length === 0) {
            if (callback)
                callback();
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
            invoke("requestIdentityAccess", [provider.sessionId, g], function () {
                processNextGrant();
            });
        }
        processNextGrant();
    }

    function loadIdentityCommitment(callback) {
        if (!provider.sessionId) {
            if (callback)
                callback();
            return;
        }

        invoke("getIdentityCommitment", [provider.sessionId], function (res) {
            if (res && res.ok && res.commitment) {
                provider.voterCommitment = res.commitment;
                provider.commitmentLoaded(res.commitment);
            }
            if (callback)
                callback();
        });
    }

    // High-Level DApp Operations

    // Derive a deterministic, unlinkable scoped nullifier for a specific domain/proposal.
    function deriveNullifier(scopeId, callback) {
        if (!provider.sessionId) {
            if (callback)
                callback({
                    ok: false,
                    error: "No active Wallez session"
                });
            return;
        }
        invoke("deriveScopedNullifier", [provider.sessionId, scopeId], function (res) {
            if (callback)
                callback(res);
        });
    }

    // Sign a structured ballot or attestation using BIP-340 Schnorr and scoped credential.
    function signAttestation(scopeId, payload, callback) {
        if (!provider.sessionId) {
            if (callback)
                callback({
                    ok: false,
                    error: "No active Wallez session"
                });
            return;
        }
        var messageHex = Client.toHex(payload);
        invoke("signIdentityAttestation", [provider.sessionId, scopeId, messageHex], function (res) {
            if (callback)
                callback(res);
        });
    }

    // Propose an explicit smart contract call (triggers Wallez ApprovalModal).
    function proposeContractCall(programId, payerId, mentions, calldataHex, description, callback) {
        if (!provider.sessionId) {
            if (callback)
                callback({
                    ok: false,
                    error: "No active Wallez session"
                });
            return;
        }
        var cleanProgram = String(programId || "").replace(/^Public\//, "").replace(/^Private\//, "");
        var rawPayer = payerId || (provider.activeAccount ? provider.activeAccount.account_id : "");
        var cleanPayer = String(rawPayer || "").replace(/^Public\//, "").replace(/^Private\//, "");
        var cleanCalldata = String(calldataHex || "").replace(/^0[xX]/, "");
        var mentionsArr = Array.isArray(mentions) ? mentions.map(function (m) {
            return String(m || "").replace(/^Public\//, "").replace(/^Private\//, "");
        }) : [];
        var mentionsJson = typeof mentions === "string" ? mentions : JSON.stringify(mentionsArr);
        var descText = description || ("Smart contract call proposed by " + provider.dappName);
        invoke("proposeContractCall", [provider.sessionId, cleanProgram, cleanPayer, mentionsJson, cleanCalldata, descText], function (res) {
            if (res && res.ok && res.status === "pending_approval" && res.request_id) {
                _registerApprovalEnvelope(res.request_id, {
                    request_id: res.request_id,
                    session_id: provider.sessionId,
                    dapp_name: provider.dappName,
                    dapp_identity: provider.dappName,
                    request_kind: "contract_call",
                    program_id: cleanProgram,
                    payer_id: cleanPayer,
                    summary: descText,
                    effects: "Invoke Program " + cleanProgram.substring(0, 12) + "... (" + Math.floor(cleanCalldata.length / 2) + " bytes)"
                });
            }
            if (callback)
                callback(res);
        });
    }

    // Propose a native token transfer (triggers Wallez ApprovalModal).
    function proposeTransfer(toAddressOrName, amountUnits, callback) {
        if (!provider.sessionId) {
            if (callback)
                callback({
                    ok: false,
                    error: "No active Wallez session"
                });
            return;
        }
        var fromAcc = provider.activeAccount ? provider.activeAccount.account_id : "";
        invoke("proposeNativeTransfer", [provider.sessionId, fromAcc, toAddressOrName, String(amountUnits)], function (res) {
            if (res && res.ok && res.status === "pending_approval" && res.request_id) {
                _registerApprovalEnvelope(res.request_id, {
                    request_id: res.request_id,
                    session_id: provider.sessionId,
                    dapp_name: provider.dappName,
                    dapp_identity: provider.dappName,
                    request_kind: "native_transfer",
                    payer_id: fromAcc,
                    to: toAddressOrName,
                    amount: String(amountUnits),
                    summary: "Transfer " + String(amountUnits) + " units to " + toAddressOrName,
                    effects: "Debit " + String(amountUnits) + " units from " + fromAcc.substring(0, 12) + "..."
                });
            }
            if (callback)
                callback(res);
        });
    }

    // Cancel a pending transaction approval request
    function cancelRequest(requestId, callback) {
        if (!requestId) {
            if (callback)
                callback({
                    ok: false,
                    error: "Missing request ID"
                });
            return;
        }
        cleanupApprovalEnvelope(requestId);
        invoke("cancelRequest", [requestId], function (res) {
            if (callback)
                callback(res);
        });
    }
}
