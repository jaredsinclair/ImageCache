//
//  FileNameHashes.swift
//  ImageCache
//
//  Created by Jared Sinclair on 11/10/24.
//

import Foundation
import Etcetera
import CryptoKit

public enum FileNameHashes {

    /// Your app can provide something stronger than the default implementation
    /// (a string representation of a SHA1 hash) if so desired.
    public static func registerFileNameHasher(block: @escaping (URL) -> String) {
        _uniqueFilenameFromUrl.access {
            $0 = block
        }
    }

    static func uniqueFilename(from url: URL) -> String {
        _uniqueFilenameFromUrl.current(url)
    }

    private static let _uniqueFilenameFromUrl: Protected<(URL) -> String> = Protected(Insecure.SHA1.filename(for:))

}
