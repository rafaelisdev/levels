// Signs release zips so Levels can verify an update before installing it.
//
//   swift scripts/sign_update.swift generate <key file>
//       New Ed25519 key pair: writes the private key (base64, mode 600), prints the
//       public key to put into Sources/Levels/Updater.swift.
//   swift scripts/sign_update.swift sign <key file> <file> <expected public key>
//       Prints the base64 signature of <file>. Refuses a key whose public half isn't
//       the one built into the app, so no release can ship that the app would reject.
//
// The private key never goes into the repo. Lose it and existing installs can no
// longer update themselves (they would need one manual install of a build with a new key).
import CryptoKit
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func readKey(_ path: String) -> Curve25519.Signing.PrivateKey {
    guard let text = try? String(contentsOfFile: path, encoding: .utf8),
          let raw = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)),
          let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: raw) else {
        fail("can't read a signing key from \(path)")
    }
    return key
}

let args = Array(CommandLine.arguments.dropFirst())
switch args.first {
case "generate" where args.count == 2:
    let path = args[1]
    guard !FileManager.default.fileExists(atPath: path) else { fail("\(path) already exists; not replacing a signing key") }
    let key = Curve25519.Signing.PrivateKey()
    guard FileManager.default.createFile(atPath: path, contents: Data(key.rawRepresentation.base64EncodedString().utf8),
                                         attributes: [.posixPermissions: 0o600]) else { fail("can't write \(path)") }
    print(key.publicKey.rawRepresentation.base64EncodedString())

case "sign" where args.count == 4:
    let key = readKey(args[1])
    guard key.publicKey.rawRepresentation.base64EncodedString() == args[3] else {
        fail("this key doesn't match the public key in the app; the app would reject the update")
    }
    guard let data = FileManager.default.contents(atPath: args[2]) else { fail("can't read \(args[2])") }
    guard let signature = try? key.signature(for: data) else { fail("signing failed") }
    print(signature.base64EncodedString())

default:
    fail("usage: sign_update.swift generate <key file> | sign <key file> <file> <expected public key>")
}
