import Crypto
import Foundation

/// The App Store `appAccountToken` for a Tokeny account.
///
/// UUID version 5 (RFC 4122) of the canonical lowercase Tokeny user id, under
/// ``namespace``. The same account always produces the same token, on every device.
/// The server recomputes it and rejects a transaction whose token is not the caller's
/// (`server/lib/apple-entitlement.ts`, `docs/apple-iap.md`). Do not change the namespace:
/// existing App Store transactions are bound to it.
public enum AppAccountToken {
    public static let namespace = "b7e1c4a2-5d38-4f0e-9c61-2a8e6f0d4b93"

    /// Nil when `userId` is not a UUID. Surrounding whitespace is ignored; hex digits are lowercased.
    public static func string(forUserId userId: String) -> String? {
        let name = userId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isCanonicalUUID(name) else { return nil }
        return uuidV5(namespace: namespace, name: name)
    }

    public static func uuid(forUserId userId: String) -> UUID? {
        guard let string = string(forUserId: userId) else { return nil }
        return UUID(uuidString: string)
    }

    /// Exposed for the RFC 4122 test vector. Production tokens go through ``string(forUserId:)``.
    static func uuidV5(namespace: String, name: String) -> String? {
        guard let ns = hexUUIDBytes(namespace) else { return nil }
        var data = Data(ns)
        data.append(contentsOf: name.utf8)
        let digest = Array(Insecure.SHA1.hash(data: data))
        var bytes = Array(digest.prefix(16))
        guard bytes.count == 16 else { return nil }
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return formatUUID(bytes)
    }
}

/// StoreKit may start a purchase only when this returns a token.
/// Nil for signed-out and for the on-device Apple identity (that id is not a Tokeny user id).
public enum ProPurchaseGate {
    public static func token(serverUserID: String?) -> UUID? {
        guard let serverUserID else { return nil }
        return AppAccountToken.uuid(forUserId: serverUserID)
    }
}

private func isCanonicalUUID(_ value: String) -> Bool {
    value.range(
        of: #"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"#,
        options: .regularExpression
    ) != nil
}

private func hexUUIDBytes(_ uuid: String) -> [UInt8]? {
    let hex = uuid.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: "-", with: "")
    guard hex.count == 32 else { return nil }
    var bytes: [UInt8] = []
    var index = hex.startIndex
    while index < hex.endIndex {
        let next = hex.index(index, offsetBy: 2)
        guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
        bytes.append(byte)
        index = next
    }
    return bytes
}

private func formatUUID(_ bytes: [UInt8]) -> String {
    let hex = bytes.map { String(format: "%02x", $0) }.joined()
    func slice(_ start: Int, _ end: Int) -> String {
        let s = hex.index(hex.startIndex, offsetBy: start)
        let e = hex.index(hex.startIndex, offsetBy: end)
        return String(hex[s..<e])
    }
    return "\(slice(0, 8))-\(slice(8, 12))-\(slice(12, 16))-\(slice(16, 20))-\(slice(20, 32))"
}
