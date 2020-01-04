//
//  Format.swift
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

import Etcetera

extension ImageCache {

    /// Describes the format options to be used when processing a source image.
    public enum Format {

        // MARK: Typealiases

        /// Use `0` to default to the system-determined default.
        public typealias ContentScale = CGFloat

        // MARK: Formats

        /// Do not modify the source image in any way.
        case original

        /// Scale the source image, with a variety of options.
        ///
        /// - parameter size: The desired output size, in points.
        ///
        /// - parameter mode: The manner in which the image will be scaled
        /// relative to the desired output size.
        ///
        /// - parameter bleed: The number of points, relative to `size`, that
        /// the image should be scaled beyond the desired output size.
        /// Generally, you should provide a value of `0` since this isn't a
        /// commonly-used feature. However, you might want to use a value larger
        /// than `0` if the source image has known artifacts (like, say, a one-
        /// pixel border around some podcast artwork) which can be corrected by
        /// drawing the image slightly larger than the output size, thus
        /// cropping the border from the result.
        ///
        /// - parameter opaque: If `false`, opacity in the source image will be
        /// preserved. If `true`, any opacity in the source image will be
        /// blended into the default (black) bitmap content.
        ///
        /// - parameter cornerRadius: If this value is greater than `0`, the
        /// image will be drawn with the corners rounded by an equivalent number
        /// of points (relative to `size`). A value of `0` or less will disable
        /// this feature.
        ///
        /// - parameter border: If non-nil, the resulting image will include the
        /// requested border drawn around the perimeter of the image.
        ///
        /// - parameter contentScale: The number of pixels per point, which is
        /// used to reckon the output image size relative to the requested
        /// `size`. Pass `0` to use the native defaults for the current device.
        case scaled(size: CGSize, mode: ContentMode, bleed: CGFloat, opaque: Bool, cornerRadius: CGFloat, border: Border?, contentScale: ContentScale)

        /// Scale the source image and crop it to an elliptical shape. The
        /// resulting image will have transparent contents in the corners.
        ///
        /// - parameter size: The desired output size, in points.
        ///
        /// - parameter border: If non-nil, the resulting image will include the
        /// requested border drawn around the perimeter of the image.
        ///
        /// - parameter contentScale: The number of pixels per point, which is
        /// used to reckon the output image size relative to the requested
        /// `size`. Pass `0` to use the native defaults for the current device.
        case round(size: CGSize, border: Border?, contentScale: ContentScale)

        /// Draw the source image using a developer-supplied formatting block.
        ///
        /// - parameter editKey: A key uniquely identifying the formatting
        /// strategy used by `block`. This key is **not** specific to any
        /// particular image, but is instead common to all images drawn with
        /// this format. ImageCache will combine the edit key with other unique
        /// parameters when caching an image drawn with a custom format.
        ///
        /// - parameter block: A developer-supplied formatting block which
        /// accepts the unmodified source image as input and returns a formatted
        /// image. The developer does not need to cache the returned image.
        /// ImageCache will cache the result in the same manner as images drawn
        /// using the other formats.
        case custom(editKey: String, block: (ImageCache.Image) -> ImageCache.Image)

    }

}

//------------------------------------------------------------------------------
// MARK: - ContentMode
//------------------------------------------------------------------------------

extension ImageCache.Format {

    /// Platform-agnostic analogue to UIView.ContentMode
    public enum ContentMode {

        /// Contents scaled to fill with fixed aspect ratio. Some portion of
        /// the content may be clipped.
        case scaleAspectFill

        /// Contents scaled to fit with fixed aspect ratio. The remainder of
        /// the resulting image area will be either transparent or black,
        /// depending upon the requested `opaque` value.
        case scaleAspectFit
    }

}

//------------------------------------------------------------------------------
// MARK: - Border
//------------------------------------------------------------------------------

extension ImageCache.Format {

    /// Border styles you can use when drawing a scaled or round image format.
    public enum Border: Hashable {

        case hairline(ImageCache.Color)

        public func hash(into hasher: inout Hasher) {
            switch self {
            case .hairline(let color):
                hasher.combine(".hairline")
                hasher.combine(color)
            }
        }

        public static func == (lhs: Border, rhs: Border) -> Bool {
            switch (lhs, rhs) {
            case let (.hairline(left), .hairline(right)): return left == right
            }
        }

        #if os(iOS)
        func draw(around path: UIBezierPath) {
            guard let context = UIGraphicsGetCurrentContext() else { return }
            switch self {
            case .hairline(let color):
                context.setStrokeColor(color.cgColor)
                let perceivedWidth: CGFloat = 1.0 // In the units of the context!
                let actualWidth = perceivedWidth * 2.0 // Half'll be cropped
                context.setLineWidth(actualWidth) // it's centered
                context.addPath(path.cgPath)
                context.strokePath()
            }
        }
        #endif

    }

}

//------------------------------------------------------------------------------
// MARK: - Image Rendering Convenience
//------------------------------------------------------------------------------

extension ImageCache.Format {

    func image(from result: DownloadResult) -> Image? {
        switch result {
        case .fresh(let url):
            guard let image = Image.fromFile(at: url) else { return nil }
            return ImageDrawing.draw(image, format: self)
        case .previous(let image):
            return ImageDrawing.draw(image, format: self)
        }
    }

}

//------------------------------------------------------------------------------
// MARK: - Equatable
//------------------------------------------------------------------------------

extension ImageCache.Format: Equatable {

    public static func == (lhs: ImageCache.Format, rhs: ImageCache.Format) -> Bool {
        switch (lhs, rhs) {
        case (.original, .original):
            return true
        case let (.scaled(ls, lm, lbl, lo, lc, lb, lcs), .scaled(rs, rm, rbl, ro, rc, rb, rcs)):
            return ls == rs && lm == rm && lbl == rbl && lo == ro && lc == rc && lb == rb && lcs == rcs
        case let (.round(ls, lb, lc), .round(rs, rb, rc)):
            return ls == rs && lb == rb && lc == rc
        case let (.custom(left, _), .custom(right, _)):
            return left == right
        default:
            return false
        }
    }

}

//------------------------------------------------------------------------------
// MARK: - Hashable
//------------------------------------------------------------------------------

extension ImageCache.Format: Hashable {

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .original:
            hasher.combine(".original")
        case let .scaled(size, mode, bleed, opaque, cornerRadius, border, contentScale):
            hasher.combine(".scaled")
            hasher.combine(size.width)
            hasher.combine(size.height)
            hasher.combine(mode)
            hasher.combine(bleed)
            hasher.combine(opaque)
            hasher.combine(cornerRadius)
            hasher.combine(border)
            hasher.combine(contentScale)
        case let .round(size, border, contentScale):
            hasher.combine(".round")
            hasher.combine(size.width)
            hasher.combine(size.height)
            hasher.combine(border)
            hasher.combine(contentScale)
        case .custom(let key, _):
            hasher.combine(".original")
            hasher.combine(key)
        }
    }

}
