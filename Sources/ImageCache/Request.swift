//
//  Request.swift
//  ImageCache
//
//  Created by Jared Sinclair on 1/3/20.
//  Copyright © 2020 Nice Boy LLC. All rights reserved.
//

import Foundation

struct Request<Result> {
    typealias Completion = (Result) -> Void

    let id = UUID()
    let completion: Completion
}
