//
//  Typealiases.swift
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

//------------------------------------------------------------------------------
// MARK: - Typealiases
//------------------------------------------------------------------------------

extension ImageCache {

    // MARK: Typealiases (All)

    public typealias Bytes = UInt

    // MARK: Typealiases (iOS)

    #if os(iOS)
    public typealias Image = UIImage
    public typealias Color = UIColor
    #endif

    // MARK: Typealiases (macOS)

    #if os(OSX)
    public typealias Image = NSImage
    public typealias Color = NSColor
    #endif

}

extension ImageCache.Bytes {

    public static func fromMegabytes(_ number: UInt) -> UInt {
        return number * 1_000_000
    }

}
