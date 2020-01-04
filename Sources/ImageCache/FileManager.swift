//
//  FileManager.swift
//  ImageCache
//
//  Created by Jared Sinclair on 1/3/20.
//  Copyright © 2020 Nice Boy LLC. All rights reserved.
//

import Foundation

extension FileManager {

    func image(fromFileAt url: URL) -> Image? {
        if let data = try? Data(contentsOf: url) {
            return Image(data: data)
        } else {
            return nil
        }
    }

    func save(_ image: Image, to url: URL) {
        #if os(iOS)
            guard let data = image.pngData() else { return }
        #elseif os(OSX)
            guard let data = image.tiffRepresentation else { return }
        #endif
        do {
            if fileExists(at: url) {
                try removeItem(at: url)
            }
            try data.write(to: url, options: .atomic)
        } catch {}
    }

}
