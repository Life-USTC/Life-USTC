//
//  UUIDExtension.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/2.
//

import CommonCrypto
import Foundation

extension UUID {
    enum UUIDv5NameSpace: String {
        case dns = "6ba7b810-9dad-11d1-80b4-00c04fd430c8"
        case url = "6ba7b811-9dad-11d1-80b4-00c04fd430c8"
        case oid = "6ba7b812-9dad-11d1-80b4-00c04fd430c8"
        case x500 = "6ba7b814-9dad-11d1-80b4-00c04fd430c8"
    }

    /// UUIDv5 implementation
    ///
    /// See https://stackoverflow.com/a/48076401, thx
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
