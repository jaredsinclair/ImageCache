//
//  MemoryCache.swift
//  ImageCache
//
//  Created by Jared Sinclair on 1/3/20.
//  Copyright © 2020 Nice Boy LLC. All rights reserved.
//

import Foundation
import Etcetera

#if os(iOS)
import UIKit
#elseif os(OSX)
import AppKit
#endif

final class MemoryCache<Key: Hashable, Value> {

    var shouldRemoveAllObjectsWhenAppEntersBackground = false

    private var items = ProtectedDictionary<Key, Value>()
    private var observers = [NSObjectProtocol]()

    subscript(key: Key) -> Value? {
        get { return items[key] }
        set { items[key] = newValue }
    }

    subscript(filter: (Key) -> Bool) -> [Key: Value] {
        return items.access {
            $0.filter { filter($0.key) }
        }
    }

    init() {
        #if os(iOS)
            observers.append(NotificationCenter.default.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    self?.removeAll()
            }))
            observers.append(NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    guard let this = self else { return }
                    if this.shouldRemoveAllObjectsWhenAppEntersBackground {
                        this.removeAll()
                    }
            }))
        #endif
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func removeAll() {
        items.access { $0.removeAll() }
    }

}
