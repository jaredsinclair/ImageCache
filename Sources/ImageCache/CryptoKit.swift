//
//  CryptoKit.swift
//  ImageCache
//
//  Created by Jared Sinclair on 1/3/20.
//  Copyright © 2020 Nice Boy LLC. All rights reserved.
//

import CryptoKit
import Foundation

extension Insecure.SHA1 {

    static func filename(for url: URL) -> String {
        guard let bytes = url.absoluteString.data(using: .utf8) else {
            assertionFailure("Unable to obtain key bytes for \(url)")
            return url.absoluteString
        }
        return Insecure.SHA1.hash(data: bytes).stringRepresentation
    }

}

extension Insecure.SHA1Digest {

    var stringRepresentation: String {
        map { String(format: "%02hhx", $0) }.joined()
    }

}
