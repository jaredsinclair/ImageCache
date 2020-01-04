//
//  URL.swift
//  ImageCache
//
//  Created by Jared Sinclair on 1/3/20.
//  Copyright © 2020 Nice Boy LLC. All rights reserved.
//

import Foundation

extension URL {

    func subdirectory(named name: String) -> URL {
        return appendingPathComponent(name, isDirectory: true)
    }

}
