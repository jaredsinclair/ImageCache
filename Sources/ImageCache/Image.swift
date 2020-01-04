//
//  Image.swift
//  ImageCache
//
//  Created by Jared Sinclair on 1/3/20.
//  Copyright © 2020 Nice Boy LLC. All rights reserved.
//

#if os(iOS)
import UIKit
#elseif os(OSX)
import AppKit
#endif

typealias Image = ImageCache.Image
typealias Color = ImageCache.Color

extension Image {

    #if os(iOS)
    static func fromFile(at url: URL) -> Image? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return Image(data: data)
    }
    #endif

    func sizeThatFills(_ other: CGSize) -> CGSize {
        guard !size.equalTo(.zero) else { return other }
        let h = size.height
        let w = size.width
        let heightRatio = other.height / h
        let widthRatio = other.width / w
        if heightRatio > widthRatio {
            return CGSize(width: w * heightRatio, height: h * heightRatio)
        } else {
            return CGSize(width: w * widthRatio, height: h * widthRatio)
        }
    }

    func sizeThatFits(_ other: CGSize) -> CGSize {
        guard !size.equalTo(.zero) else { return other }
        let h = size.height
        let w = size.width
        let heightRatio = other.height / h
        let widthRatio = other.width / w
        if heightRatio > widthRatio {
            return CGSize(width: w * widthRatio, height: h * widthRatio)
        } else {
            return CGSize(width: w * heightRatio, height: h * heightRatio)
        }
    }

}
