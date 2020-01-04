//
//  DownloadResult.swift
//  ImageCache
//
//  Created by Jared Sinclair on 1/3/20.
//  Copyright © 2020 Nice Boy LLC. All rights reserved.
//

import Foundation

/// Communicates to `ImageCache` whether the result of a download operation was
/// that a new file was freshly downloaded, or whether a previously-downloaded
/// file was able to be used.
enum DownloadResult {

    /// A fresh file was downloaded and is available locally at a file URL.
    case fresh(URL)

    /// A previously-downloaded image was already available on disk.
    case previous(Image)

}
