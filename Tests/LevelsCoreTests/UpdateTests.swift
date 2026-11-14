import CryptoKit
import XCTest
@testable import LevelsCore

final class UpdateTests: XCTestCase {
    func testVersionsCompareNumberByNumber() throws {
        let v = { (s: String) in try XCTUnwrap(AppVersion(s)) }
        XCTAssertLessThan(try v("1.4"), try v("1.4.1"))
        XCTAssertLessThan(try v("1.9"), try v("1.10"))
        XCTAssertLessThan(try v("1.4.1"), try v("2"))
        XCTAssertEqual(try v("1.4"), try v("1.4.0"))
        XCTAssertFalse(try v("1.4") < v("1.4.0"))
        XCTAssertEqual(try v("1.04").description, "1.4")
    }

    func testMalformedVersionsAreRejected() {
        XCTAssertNil(AppVersion(""))
        XCTAssertNil(AppVersion("1.x"))
        XCTAssertNil(AppVersion("1..2"))
        XCTAssertNil(AppVersion("v1.4"))
    }

    func testManifestDecodes() throws {
        let json = """
        {"version": "1.4.1", "url": "https://github.com/rafaelisdev/levels/releases/download/v1.4.1/Levels.zip",
         "signature": "c2ln", "minimumSystemVersion": "11.0"}
        """
        let manifest = try JSONDecoder().decode(UpdateManifest.self, from: Data(json.utf8))
        XCTAssertEqual(manifest.version, "1.4.1")
        XCTAssertEqual(manifest.url.lastPathComponent, "Levels.zip")
        XCTAssertEqual(manifest.minimumSystemVersion, "11.0")
    }

    func testSignatureAcceptsOnlyTheSignedBytesAndKey() throws {
        let key = Curve25519.Signing.PrivateKey()
        let publicKey = key.publicKey.rawRepresentation.base64EncodedString()
        let zip = Data((0..<4096).map { UInt8($0 % 251) })
        let signature = try key.signature(for: zip).base64EncodedString()

        XCTAssertTrue(UpdateSignature.isValid(zip, signature: signature, publicKey: publicKey))

        var tampered = zip
        tampered[2000] ^= 1
        XCTAssertFalse(UpdateSignature.isValid(tampered, signature: signature, publicKey: publicKey))

        let otherKey = Curve25519.Signing.PrivateKey().publicKey.rawRepresentation.base64EncodedString()
        XCTAssertFalse(UpdateSignature.isValid(zip, signature: signature, publicKey: otherKey))
        XCTAssertFalse(UpdateSignature.isValid(zip, signature: "not base64!", publicKey: publicKey))
        XCTAssertFalse(UpdateSignature.isValid(zip, signature: signature, publicKey: "c2hvcnQ="))
    }
}
