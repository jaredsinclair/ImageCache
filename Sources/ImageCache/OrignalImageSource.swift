//
//  File.swift
//  
//
//  Created by Jared Sinclair on 8/3/20.
//

import Foundation

public extension ImageCache {

    /// @JARED
    enum OriginalImageSource: Hashable {

        /// @JARED
        case url(URL)

        /// @JARED
        case custom(ImageIdentifier, Namespace, Loader)

        public typealias ImageIdentifier = String
        public typealias Namespace = String
        public typealias Loader = (LoaderCompletion) -> Void
        public typealias LoaderCompletion = (Image?) -> Void

        public static func ==(lhs: OriginalImageSource, rhs: OriginalImageSource) -> Bool {
            switch (lhs, rhs) {
            case (.url(let left), .url(let right)):
                return left == right
            case (.custom(let l1, let l2, _), .custom(let r1, let r2, _)):
                return l1 == r1 && l2 == r2
            case (.url, _), (.custom, _):
                return false
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case .url(let url):
                hasher.combine(url)
            case .custom(let identifier, let namespace, _):
                hasher.combine(identifier)
                hasher.combine(namespace)
            }
        }
    }

}
