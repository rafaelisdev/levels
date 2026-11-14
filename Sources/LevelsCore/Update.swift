import CryptoKit
import Foundation

/// A dotted version ("1.4", "1.4.1") compared number by number, so 1.10 > 1.9 and
/// 1.4 == 1.4.0.
public struct AppVersion: Comparable, CustomStringConvertible {
    public let parts: [Int]

    public init(_ parts: [Int]) {
        self.parts = parts
    }

    public init?(_ string: String) {
        let parts = string.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !parts.isEmpty, !parts.contains(nil) else { return nil }
        self.parts = parts.compactMap { $0 }
    }

    /// The macOS version this process runs on.
    public static var system: AppVersion {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return AppVersion([v.majorVersion, v.minorVersion, v.patchVersion])
    }

    public var description: String { parts.map(String.init).joined(separator: ".") }

    public static func < (a: AppVersion, b: AppVersion) -> Bool { compare(a, b) < 0 }
    public static func == (a: AppVersion, b: AppVersion) -> Bool { compare(a, b) == 0 }

    private static func compare(_ a: AppVersion, _ b: AppVersion) -> Int {
        for i in 0..<max(a.parts.count, b.parts.count) {
            let x = i < a.parts.count ? a.parts[i] : 0
            let y = i < b.parts.count ? b.parts[i] : 0
            if x != y { return x < y ? -1 : 1 }
        }
        return 0
    }
}

/// What every release publishes next to Levels.zip, as `update.json`.
public struct UpdateManifest: Codable, Equatable {
    public var version: String
    public var url: URL
    /// Ed25519 signature of the zip, base64 (scripts/sign_update.swift).
    public var signature: String
    public var minimumSystemVersion: String

    public init(version: String, url: URL, signature: String, minimumSystemVersion: String) {
        self.version = version
        self.url = url
        self.signature = signature
        self.minimumSystemVersion = minimumSystemVersion
    }
}

/// Checks that a download was signed with the release key. The signature covers the
/// whole zip, so a changed byte anywhere (or a different file) fails.
public enum UpdateSignature {
    public static func isValid(_ data: Data, signature: String, publicKey: String) -> Bool {
        guard let signature = Data(base64Encoded: signature),
              let keyData = Data(base64Encoded: publicKey),
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData) else { return false }
        return key.isValidSignature(signature, for: data)
    }
}
