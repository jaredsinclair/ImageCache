//
//  Request.swift
//  ImageCache
//
//  Created by Jared Sinclair on 1/3/20.
//  Copyright © 2020 Nice Boy LLC. All rights reserved.
//

import Foundation

struct Request<Result>: Sendable {
    typealias Completion = @Sendable @MainActor (Result) -> Void

    let id = UUID()
    let completion: Completion
}
