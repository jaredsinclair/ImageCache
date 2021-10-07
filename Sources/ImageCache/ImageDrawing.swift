//
//  ImageDrawing.swift
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

/// Utility for drawing an image according to a specified format.
///
/// - Note: This is public since it may be useful outside this file.
public enum /*scope*/ ImageDrawing {

    // MARK: Common

    /// Draws `image` using the specified format.
    ///
    /// - returns: Returns the formatted image.
    public static func draw(_ image: ImageCache.Image, format: ImageCache.Format) -> ImageCache.Image {
        switch format {
        case .original:
            return image
        case .decompressed:
            return decompress(image)
        case let .scaled(size, mode, bleed, opaque, cornerRadius, border, contentScale):
            return draw(image, at: size, using: mode, bleed: bleed, opaque: opaque, cornerRadius: cornerRadius, border: border, contentScale: contentScale)
        case let .round(size, border, contentScale):
            return draw(image, clippedByOvalOfSize: size, border: border, contentScale: contentScale)
        case .custom(_, let block):
            return block(image)
        }
    }

    // MARK: macOS

    #if os(OSX)
    static func decompress(_ image: Image) -> Image {
        // Not yet implemented.
        return image
    }

    private static func draw(_ image: Image, at targetSize: CGSize, using mode: ImageCache.Format.ContentMode, opaque: Bool, cornerRadius: CGFloat, border: ImageBorder?, contentScale: CGFloat) -> Image {
        // Not yet implemented.
        return image
    }

    private static func draw(_ image: Image, clippedByOvalOfSize targetSize: CGSize, border: ImageCache.Format.Border?, contentScale: CGFloat) -> Image {
        // Not yet implemented.
        return image
    }
    #endif

    // MARK: iOS

    #if os(iOS)
    static func decompress(_ image: Image) -> Image {
        UIGraphicsBeginImageContext(CGSize(width: 1, height: 1)) // Size doesn't matter.
        defer { UIGraphicsEndImageContext() }
        image.draw(at: CGPoint.zero)
        return image
    }

    private static func draw(_ image: Image, at targetSize: CGSize, using mode: ImageCache.Format.ContentMode, bleed: CGFloat, opaque: Bool, cornerRadius: CGFloat, border: ImageCache.Format.Border?, contentScale: CGFloat) -> Image {
        guard !image.size.equalTo(.zero) else { return image }
        guard !targetSize.equalTo(.zero) else { return image }
        switch mode {
        case .scaleAspectFill, .scaleAspectFit:
            var scaledSize: CGSize
            if mode == .scaleAspectFit {
                scaledSize = image.sizeThatFits(targetSize)
            } else {
                scaledSize = image.sizeThatFills(targetSize)
            }
            if bleed != 0 {
                scaledSize.width += bleed * 2
                scaledSize.height += bleed * 2
            }
            let x = (targetSize.width - scaledSize.width) / 2.0
            let y = (targetSize.height - scaledSize.height) / 2.0
            let drawingRect = CGRect(x: x, y: y, width: scaledSize.width, height: scaledSize.height)
            UIGraphicsBeginImageContextWithOptions(targetSize, opaque, contentScale)
            defer { UIGraphicsEndImageContext() }
            if cornerRadius > 0 || border != nil {
                let clipRect = CGRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height)
                let bezPath = UIBezierPath(roundedRect: clipRect, cornerRadius: cornerRadius)
                bezPath.addClip()
                image.draw(in: drawingRect)
                border?.draw(around: bezPath)
            } else {
                image.draw(in: drawingRect)
            }
            return UIGraphicsGetImageFromCurrentImageContext() ?? image
        }
    }

    private static func draw(_ image: Image, clippedByOvalOfSize targetSize: CGSize, border: ImageCache.Format.Border?, contentScale: CGFloat) -> Image {
        guard !image.size.equalTo(.zero) else { return image }
        guard !targetSize.equalTo(.zero) else { return image }
        let scaledSize = image.sizeThatFills(targetSize)
        let x = (targetSize.width - scaledSize.width) / 2.0
        let y = (targetSize.height - scaledSize.height) / 2.0
        let drawingRect = CGRect(x: x, y: y, width: scaledSize.width, height: scaledSize.height)
        let clipRect = CGRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height)
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 0)
        defer { UIGraphicsEndImageContext() }
        let bezPath = UIBezierPath(ovalIn: clipRect)
        bezPath.addClip()
        image.draw(in: drawingRect)
        border?.draw(around: bezPath)
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
    #endif

}
