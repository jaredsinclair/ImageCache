//
//  CallbackMode.swift
//  ImageCache
//
//  Created by Jared Sinclair on 1/3/20.
//  Copyright © 2020 Nice Boy LLC. All rights reserved.
//

extension ImageCache {

    /// The manner in which a completion handler is (or will be) executed.
    ///
    /// Indicates whether a completion handler was executed synchronously before
    /// the return, or will be executed asynchronously at some point in the
    /// future. When asynchronous, the cancellation block associated value of
    /// the `.async` mode can be used to cancel the pending request.
    public enum CallbackMode {

        /// The completion handler was performed synchronously, before the
        /// method returned.
        case sync

        /// The completion handler will be performed asynchronously, sometime
        /// after the method returned.
        ///
        /// - parameter cancellation: A block which the caller can use to cancel
        /// the in-flight request.
        case async(cancellation: () -> Void)
    }

}
