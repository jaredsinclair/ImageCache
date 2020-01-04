//
//  ImageKey.swift
//  ImageCache
//
//  Created by Jared Sinclair on 1/3/20.
//  Copyright © 2020 Nice Boy LLC. All rights reserved.
//

import Foundation
import CoreGraphics

/// Uniquely identifies a particular format of an image from a particular URL.
final class ImageKey: Hashable {

    /// The HTTP URL to the original image from which the cached image was derived.
    let url: URL

    /// The format used when processing the cached image.
    let format: ImageCache.Format

    init(url: URL, format: ImageCache.Format) {
        self.url = url
        self.format = format
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(format)
    }

    var filenameSuffix: String {
        switch format {
        case .original:
            return "_original"
        case let .scaled(size, mode, bleed, opaque, radius, border, contentScale):
            let base = "_scaled_\(Int(size.width))_\(Int(size.height))_\(mode)_\(Int(bleed))_\(opaque)_\(Int(radius))_\(Int(contentScale))"
            if let border = border, case .hairline(let color) = border {
                return base + "_hairline(\(color.fileNameExpression))"
            } else {
                return base + "_nil"
            }
        case let .round(size, border, contentScale):
            let base = "_round_\(Int(size.width))_\(Int(size.height))"
            if let border = border, case .hairline(let color) = border {
                return base + "_hairline(\(color.fileNameExpression))" + "_\(Int(contentScale))"
            } else {
                return base + "_nil"
            }
        case let .custom(key, _):
            return "_custom_\(key)"
        }
    }

    static func == (lhs: ImageKey, rhs: ImageKey) -> Bool {
        return lhs.url == rhs.url && lhs.format == rhs.format
    }

}

extension Color {

    var fileNameExpression: String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        func describe(_ color: CGFloat) -> String {
            let multiplied = color * 1_000_000
            let rounded = Int(multiplied) / 1000
            return "\(rounded)"
        }
        return "\(describe(r))-\(describe(g))-\(describe(b))-\(describe(a))"
    }

}
