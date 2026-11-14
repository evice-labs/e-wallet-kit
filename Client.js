.pragma library

/**
 * JSON Parser with multi-pass unwrapping for IPC payloads.
 */
function parseJson(raw) {
    var parsed = raw;
    for (var i = 0; i < 4 && typeof parsed === "string"; i++) {
        var trimmed = parsed.trim();
        if ((trimmed.startsWith("{") && trimmed.endsWith("}")) ||
            (trimmed.startsWith("[") && trimmed.endsWith("]")) ||
            (trimmed.startsWith("\"") && trimmed.endsWith("\""))) {
            try {
                parsed = JSON.parse(trimmed);
            } catch (e) {
                break;
            }
        } else {
            break;
        }
    }
    if (typeof parsed !== "object" || parsed === null) {
        return { ok: true, value: parsed };
    }
    return parsed;
}

/**
 * Convert string or object to 0x-prefixed hex string.
 */
function toHex(input) {
    var str = typeof input === "string" ? input : JSON.stringify(input);
    var hex = "0x";
    for (var i = 0; i < str.length; i++) {
        var code = str.charCodeAt(i).toString(16);
        if (code.length === 1) code = "0" + code;
        hex += code;
    }
    return hex;
}

/**
 * Format address / account ID with ellipsis.
 * e.g. "Public/Dski76bxctBduZw6ZQhRJd52dZ6UFW7a7fWqc8hFYsEk" -> "Public/Dski...sEk"
 */
function truncateAddress(addr, leadLen, tailLen) {
    if (!addr || typeof addr !== "string") return "";
    var lead = leadLen || 12;
    var tail = tailLen || 4;
    if (addr.length <= lead + tail) return addr;
    return addr.substring(0, lead) + "..." + addr.substring(addr.length - tail);
}

/**
 * Format LEZ native unit balance with thousands separators.
 */
function formatBalance(balanceUnits) {
    if (balanceUnits === undefined || balanceUnits === null) return "0.00";
    var num = Number(balanceUnits);
    if (isNaN(num)) return String(balanceUnits);
    return (num / 100.0).toLocaleString(undefined, {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2
    });
}

