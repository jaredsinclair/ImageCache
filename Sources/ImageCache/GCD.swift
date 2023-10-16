//
//  GCD.swift
//  ImageCache
//
//  Created by Jared Sinclair on 1/3/20.
//  Copyright © 2020 Nice Boy LLC. All rights reserved.
//

import Foundation

func onMain(_ block: @escaping @Sendable @MainActor () -> Void) {
    DispatchQueue.main.async { block() }
}

func deferred(on queue: OperationQueue, block: @escaping @Sendable () -> Void) {
    onMain { queue.addOperation(block) }
}
