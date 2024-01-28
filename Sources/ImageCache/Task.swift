//
//  Task.swift
//  ImageCache
//
//  Created by Jared Sinclair on 1/3/20.
//  Copyright © 2020 Nice Boy LLC. All rights reserved.
//

import Foundation

struct Task<TaskID: Hashable, Result> {

    typealias Cancellation = @Sendable () -> Void
    typealias Completion = @Sendable @MainActor (Result) -> Void

    var requests = [UUID: Request<Result>]()
    let id: TaskID
    let cancellation: Cancellation
    let completion: Completion

    init(id: TaskID, cancellation: @escaping Cancellation, completion: @escaping Completion) {
        self.id = id
        self.cancellation = cancellation
        self.completion = completion
    }

}
