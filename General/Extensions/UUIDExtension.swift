//
//  UUIDExtension.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/2.
//

import CommonCrypto
import Foundation

extension UUID {
    /// Standard UUIDv5 namespace identifiers defined in RFC 4122
    enum UUIDv5NameSpace: String {
        /// DNS namespace for domain names
        case dns = "6ba7b810-9dad-11d1-80b4-00c04fd430c8"
        /// URL namespace for URLs
        case url = "6ba7b811-9dad-11d1-80b4-00c04fd430c8"
        /// ISO OID namespace
        case oid = "6ba7b812-9dad-11d1-80b4-00c04fd430c8"
        /// X.500 DN namespace
        case x500 = "6ba7b814-9dad-11d1-80b4-00c04fd430c8"
    }

    /// Creates a UUIDv5 (name-based UUID using SHA-1)
    ///
    /// UUIDv5 generates deterministic UUIDs from a namespace and name.
    /// Same name in same namespace always produces the same UUID.
    ///
    /// - Parameters:
    ///   - name: The name string to hash
    ///   - nameSpace: The UUID namespace to use (dns, url, oid, or x500)
    /// - Note: Implementation based on https://stackoverflow.com/a/48076401
    init(name: String, nameSpace: UUIDv5NameSpace) {
        // Get UUID bytes from name space:
        var spaceUID = UUID(uuidString: nameSpace.rawValue)!.uuid
        var data = withUnsafePointer(to: &spaceUID) {
            [count = MemoryLayout.size(ofValue: spaceUID)] in
            Data(bytes: $0, count: count)
        }

        // Append name string in UTF-8 encoding:
        data.append(contentsOf: name.utf8)

        // Compute digest (MD5 or SHA1, depending on the version):
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            _ = CC_SHA1(ptr.baseAddress, CC_LONG(data.count), &digest)
        }

        // Set version bits:
        digest[6] &= 0x0F
        digest[6] |= 3 << 4
        // Set variant bits:
        digest[8] &= 0x3F
        digest[8] |= 0x80

        // Create UUID from digest:
        self = NSUUID(uuidBytes: digest) as UUID
    }
}
