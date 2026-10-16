// Ed25519 signing for in-app updates. The app trusts the public key in Updater.swift (UpdateConfig.publicKeys)
// and only installs a release whose signature matches the manifest below.
//
//   swift Scripts/update_signing.swift keygen                     -> prints PRIVATE=… and PUBLIC=… (base64 raw keys)
//   <private key> | swift Scripts/update_signing.swift public     -> prints the public key
//   <private key> | swift Scripts/update_signing.swift sign <zip> <version>
//   swift Scripts/update_signing.swift verify <zip> <version> <signature> <public key>
//
// The private key is read from stdin so it never appears in the process list.
import CryptoKit
import Foundation

/// Must match UpdateEngine.manifest(version:sha256:size:) in the app.
func manifest(version: String, sha256: String, size: Int64) -> Data {
    Data("TensorTycoon update v1\nversion=\(version)\nsha256=\(sha256)\nsize=\(size)\n".utf8)
}

func digest(of url: URL) throws -> (sha256: String, size: Int64) {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    var hasher = SHA256()
    var size: Int64 = 0
    while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
        hasher.update(data: chunk)
        size += Int64(chunk.count)
    }
    return (hasher.finalize().map { String(format: "%02x", $0) }.joined(), size)
}

func readPrivateKey() throws -> Curve25519.Signing.PrivateKey {
    let input = String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard let raw = Data(base64Encoded: input) else { throw NSError(domain: "update_signing", code: 1, userInfo: [NSLocalizedDescriptionKey: "No base64 private key on stdin"]) }
    return try Curve25519.Signing.PrivateKey(rawRepresentation: raw)
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let args = Array(CommandLine.arguments.dropFirst())
do {
    switch args.first {
    case "keygen":
        let key = Curve25519.Signing.PrivateKey()
        print("PRIVATE=\(key.rawRepresentation.base64EncodedString())")
        print("PUBLIC=\(key.publicKey.rawRepresentation.base64EncodedString())")
    case "public":
        print(try readPrivateKey().publicKey.rawRepresentation.base64EncodedString())
    case "sign":
        guard args.count == 3 else { fail("usage: sign <zip> <version>") }
        let key = try readPrivateKey()
        let (sha, size) = try digest(of: URL(fileURLWithPath: args[1]))
        let signature = try key.signature(for: manifest(version: args[2], sha256: sha, size: size))
        print(signature.base64EncodedString())
    case "verify":
        guard args.count == 5, let sig = Data(base64Encoded: args[3]), let pub = Data(base64Encoded: args[4]) else {
            fail("usage: verify <zip> <version> <signature> <public key>")
        }
        let (sha, size) = try digest(of: URL(fileURLWithPath: args[1]))
        let key = try Curve25519.Signing.PublicKey(rawRepresentation: pub)
        guard key.isValidSignature(sig, for: manifest(version: args[2], sha256: sha, size: size)) else { fail("BAD signature") }
        print("OK \(args[2]) sha256=\(sha) size=\(size)")
    default:
        fail("usage: keygen | public | sign <zip> <version> | verify <zip> <version> <signature> <public key>")
    }
} catch {
    fail("error: \(error.localizedDescription)")
}
