//
//  File.swift
//  
//
//  Created by Jared Sinclair on 8/3/20.
//

import Foundation

public extension ImageCache {

    /// ImageCache supports multiple ways of obtaining original images:
    ///
    /// - from an HTTP/FILE URL
    /// - by manually seeding the original image before requesters ask for it
    /// - by providing a custom source
    ///
    /// Of these only the first two will have their original (canonical) images
    /// written to ImageCache's disk cache. If you use `.custom` it's your
    /// responsiblity to maintain a cache of the original value as needed.
    enum OriginalImageSource: Hashable {

        /// The HTTP/FILE URL to the file.
        case url(URL)

        /// The image will be manually seeded into the cache.
        case manuallySeeded(imageIdentifier: ImageIdentifier)

        /// A custom means of obtaining a source image.
        case custom(imageIdentifier: ImageIdentifier, namespace: Namespace, loader: Loader)

        public typealias ImageIdentifier = String
        public typealias Namespace = String
        public typealias Loader = (@escaping LoaderCompletion) -> Void
        public typealias LoaderCompletion = (Image?) -> Void

        public static func ==(lhs: OriginalImageSource, rhs: OriginalImageSource) -> Bool {
            switch (lhs, rhs) {
            case (.url(let left), .url(let right)):
                return left == right
            case (.manuallySeeded(let left), .manuallySeeded(let right)):
                return left == right
            case (.custom(let l1, let l2, _), .custom(let r1, let r2, _)):
                return l1 == r1 && l2 == r2
            case (.url, _), (.manuallySeeded, _), (.custom, _):
                return false
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case .url(let url):
                hasher.combine(url)
            case .manuallySeeded(let imageIdentifier):
                hasher.combine(imageIdentifier)
            case .custom(let identifier, let namespace, _):
                hasher.combine(identifier)
                hasher.combine(namespace)
            }
        }
    }

}
