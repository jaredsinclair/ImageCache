//
//  DeferredValue.swift
//  ImageCache
//
//  Created by Jared Sinclair on 1/3/20.
//  Copyright © 2020 Nice Boy LLC. All rights reserved.
//

import Etcetera

final class DeferredValue<T>: Sendable {

    var value: T? {
        get { _value.current }
        set { _value.current = newValue }
    }

    private let _value = Protected<T?>(nil)

}
