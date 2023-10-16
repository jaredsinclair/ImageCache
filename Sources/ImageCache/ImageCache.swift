//
//  ImageCache.swift
//  ImageCache
//
//  Created by Jared Sinclair on 8/15/15.
//  Copyright © 2020 Nice Boy LLC. All rights reserved.
//
// swiftlint:disable identifier_name - Clarity!
// swiftlint:disable line_length - I dislike multi-line function signatures.
// swiftlint:disable nesting - Seriously, why do we even Swift then.
// swiftlint:disable function_parameter_count - Some problems are hard.

import CryptoKit
import Etcetera
import Combine

#if os(iOS)
import UIKit
#elseif os(OSX)
import AppKit
#endif

/// An image cache that balances high-performance features with straightforward
/// usage and sensible defaults.
///
/// - Warning: This class currently only supports iOS and tvOS. I have vague plans
/// to have it support macOS and watchOS, too, but that's a way's off.
@MainActor public final class ImageCache {

    // MARK: Shared Instance

    /// The shared instance. You're not obligated to use this.
    public static let shared = ImageCache()

    // MARK: Public Properties

    /// The default directory where ImageCache stores files on disk.
    public nonisolated static var defaultDirectory: URL {
        return FileManager.default.cachesDirectory().subdirectory(named: "Images")
    }

    /// Disk storage will be automatically trimmed to this byte limit (by 
    /// trimming the least-recently accessed items first). Trimming will occur
    /// whenever the app enters the background, or when this value is changed.
    ///
    /// Provide a `nil` value to allow for unbounded disk usage. YOLO.
    public var byteLimitForFileStorage: Bytes? {
        didSet { trimStaleFiles() }
    }

    /// Your app can provide something stronger than the default implementation
    /// (a string representation of a SHA1 hash) if so desired.
    public nonisolated var uniqueFilenameFromUrl: (URL) -> String {
        get { _uniqueFilenameFromUrl.current }
        set { _uniqueFilenameFromUrl.current = newValue }
    }

    /// When `true` this will empty the in-memory cache when the app enters the
    /// background. This can help reduce the likelihood that your app will be
    /// terminated in order to reclaim memory for foregrounded applications.
    /// Defaults to `false`.
    public var shouldRemoveAllImagesFromMemoryWhenAppEntersBackground: Bool {
        get { return memoryCache.shouldRemoveAllObjectsWhenAppEntersBackground }
        set { memoryCache.shouldRemoveAllObjectsWhenAppEntersBackground = newValue }
    }

    // MARK: Private Properties

    private let directory: URL
    private let urlSession: URLSession
    private let formattingTaskRegistry = TaskRegistry<ImageKey, Image?>()
    private let downloadTaskRegistry = TaskRegistry<ImageKey, DownloadResult?>()
    private let userImageDiskTaskRegistry = TaskRegistry<ImageKey, URL>()
    private let memoryCache = MemoryCache<ImageKey, Image>()
    private let formattingQueue: OperationQueue
    private let diskWritingQueue: OperationQueue
    private let workQueue: OperationQueue
    private nonisolated let _uniqueFilenameFromUrl: Protected<(URL) -> String>
    private var cancellables = Set<AnyCancellable>()

    // MARK: Init / Deinit

    /// Designated initializer.
    ///
    /// - parameter directory: The desired directory. This must not be a system-
    /// managed directory (like /Caches), but it can be a subdirectory thereof.
    ///
    /// - parameter byteLimitForFileStorage: Disk storage will be automatically
    /// trimmed to this byte limit (by trimming the least-recently accessed
    /// items first). Trimming will occur whenever the app enters the
    /// background, or when this value is changed. Provide a `nil` value to
    /// allow for unbounded disk usage. YOLO.
    public init(
        directory: URL = ImageCache.defaultDirectory,
        byteLimitForFileStorage: Bytes? = .fromMegabytes(500)
    ) {
        self._uniqueFilenameFromUrl = Protected(Insecure.SHA1.filename(for:))
        self.directory = directory
        self.byteLimitForFileStorage = byteLimitForFileStorage
        self.urlSession = {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 15
            config.timeoutIntervalForResource = 90
            return URLSession(configuration: config)
        }()
        self.formattingQueue = {
            let q = OperationQueue()
            q.qualityOfService = .userInitiated
            return q
        }()
        self.workQueue = {
            let q = OperationQueue()
            q.qualityOfService = .userInitiated
            return q
        }()
        self.diskWritingQueue = {
            let q = OperationQueue()
            q.qualityOfService = .background
            return q
        }()
        _ = FileManager.default.createDirectory(at: directory)
        observeNotifications()
    }

    // MARK: Public Methods

    /// Retrieves an image from the specified URL, formatted to the requested
    /// format.
    ///
    /// If the formatted image already exists in memory, it will be returned
    /// synchronously. If not, ImageCache will look for the cached formatted
    /// image on disk. If that is not found, ImageCache will look for the cached
    /// original image on disk, format it, save the formatted image to disk, and
    /// return the formatted image. If all of the above turn up empty, the
    /// original file will be downloaded from the url and saved to disk, then
    /// the formatted image will be generated and saved to disk, then the
    /// formatted image will be cached in memory, and then finally the formatted
    /// image will be returned to the caller via the completion handler. If any
    /// of the above steps fail, the completion block will be called with `nil`.
    ///
    /// Concurrent requests for the same resource are combined into the smallest
    /// possible number of active tasks. Requests for different image formats
    /// based on the same original image will lead to a single download task for
    /// the original file. Requests for the same image format will lead to a
    /// single image formatting task. The same result is distributed to all
    /// requests in the order in which they were requested.
    ///
    /// - parameter url: The HTTP URL at which the original image is found.
    ///
    /// - parameter format: The desired image format for the completion result.
    ///
    /// - parameter completion: A completion handler called when the image is
    /// available in the desired format, or if the request failed. The
    /// completion handler will always be performed on the main queue.
    ///
    /// - returns: A callback mode indicating whether the completion handler was
    /// executed synchronously before the return, or will be executed
    /// asynchronously at some point in the future. When asynchronous, the
    /// cancellation block associated value of the `.async` mode can be used to
    /// cancel the request for this image. Cancelling a request will not cancel
    /// any other in-flight requests. If the cancelled request was the only
    /// remaining request awaiting the result of a downloading or formatting
    /// task, then the unneeded task will be cancelled and any in-progress work
    /// will be abandoned.
    @discardableResult
    public func image(
        from url: URL,
        format: Format = .original,
        completion: @escaping @Sendable @MainActor (Image?) -> Void
    ) -> CallbackMode {
        image(from: .url(url), format: format, completion: completion)
    }

    /// Retrieves an image from the specified source, formatted to the requested
    /// format.
    ///
    /// If the formatted image already exists in memory, it will be returned
    /// synchronously. If not, ImageCache will look for the cached formatted
    /// image on disk. If that is not found, ImageCache will look for the cached
    /// original image on disk, format it, save the formatted image to disk, and
    /// return the formatted image. If all of the above turn up empty, the
    /// original file will be obtained from the source and saved to disk, then
    /// the formatted image will be generated and saved to disk, then the
    /// formatted image will be cached in memory, and then finally the formatted
    /// image will be returned to the caller via the completion handler. If any
    /// of the above steps fail, the completion block will be called with `nil`.
    ///
    /// Concurrent requests for the same resource are combined into the smallest
    /// possible number of active tasks. Requests for different image formats
    /// based on the same original image will lead to a single obtain task for
    /// the original file. Requests for the same image format will lead to a
    /// single image formatting task. The same result is distributed to all
    /// requests in the order in which they were requested.
    ///
    /// - parameter source: The source where the original image is found.
    ///
    /// - parameter format: The desired image format for the completion result.
    ///
    /// - parameter completion: A completion handler called when the image is
    /// available in the desired format, or if the request failed. The
    /// completion handler will always be performed on the main queue.
    ///
    /// - returns: A callback mode indicating whether the completion handler was
    /// executed synchronously before the return, or will be executed
    /// asynchronously at some point in the future. When asynchronous, the
    /// cancellation block associated value of the `.async` mode can be used to
    /// cancel the request for this image. Cancelling a request will not cancel
    /// any other in-flight requests. If the cancelled request was the only
    /// remaining request awaiting the result of a downloading or formatting
    /// task, then the unneeded task will be cancelled and any in-progress work
    /// will be abandoned.
    @discardableResult
    public func image(
        from source: OriginalImageSource,
        format: Format = .original,
        completion: @escaping @Sendable @MainActor (Image?) -> Void
    ) -> CallbackMode {
        let key = ImageKey(source: source, format: format)
        return image(for: key, completion: completion)
    }

    /// Removes all the cached images from the in-memory cache only. Files on
    /// disk will not be removed.
    public func removeAllImagesFromMemory() {
        memoryCache.removeAll()
    }

    /// Removes and recreates the directory containing all cached image files.
    /// Images cached in-memory will not be removed.
    public func removeAllFilesFromDisk() {
        _ = try? FileManager.default.removeItem(at: directory)
        _ = FileManager.default.createDirectory(at: directory)
    }

    /// Convenience function for storing user-provided images in memory.
    ///
    /// - parameter image: The image to be added. ImageCache will not apply any
    /// formatting to this image, instead treating it as a source image.
    ///
    /// - parameter destinations: Where the image should be saved.
    ///
    /// - parameter key: A developer-provided key uniquely identifying this
    /// image. This key should be as unique as a URL to a remote image might be.
    ///
    /// - parameter completion: Performed when the image has been added to all
    /// the requested destinations. May or may not be called synchronously.
    public func add(
        userProvidedImage image: Image,
        to destinations: [UserProvidedImageDestination] = UserProvidedImageDestination.allCases,
        key: String,
        completion: @escaping @Sendable @MainActor (_ fileUrl: URL?) -> Void
    ) {
        let key = ImageKey(source: .manuallySeeded(imageIdentifier: key), format: .original)
        onMain {
            if destinations.contains(.memory) {
                self.memoryCache[key] = image
            }
            guard destinations.contains(.disk) else {
                completion(nil)
                return
            }
            let saveOperation = DeferredValue<Operation>()
            _ = self.userImageDiskTaskRegistry.addRequest(
                taskId: key,
                workQueue: self.workQueue,
                taskExecution: { finish in
                    let blockOperation = BlockOperation {
                        let fileUrl = self.fileUrl(forOriginalImageWithKey: key)
                        FileManager.default.save(image, to: fileUrl)
                        onMain { finish(fileUrl) }
                    }
                    saveOperation.value = blockOperation
                    self.diskWritingQueue.addOperation(blockOperation)
                }, taskCancellation: {
                    saveOperation.value?.cancel()
                }, taskCompletion: { _ in
                    // no-op
                }, requestCompletion: { url in
                    completion(url)
                }
            )
        }
    }

    /// An alternative to `image(from:format:completion:)` that sources from an
    /// existing user-provided source image.
    ///
    /// This method will resolve to a `nil` image if the image has not already
    /// been added via `add(userProvidedImage:to:key:)`
    @discardableResult
    public func userProvidedImage(
        key: String,
        format: Format = .original,
        completion: @escaping @Sendable @MainActor (Image?) -> Void
    ) -> CallbackMode {
        let key = ImageKey(source: .manuallySeeded(imageIdentifier: key), format: format)
        return image(for: key, completion: completion)
    }

    // MARK: Private Methods

    /// Fetches an image using all the heuristics described above.
    private func image(
        for key: ImageKey,
        completion: @escaping @Sendable @MainActor (Image?) -> Void
    ) -> CallbackMode {

        let task = BackgroundTask.start()
        let completion: @Sendable @MainActor (Image?) -> Void = {
            completion($0)
            task?.end()
        }

        if let image = memoryCache[key] {
            completion(image)
            return .sync
        }

        // Use a deferred value for `formattingRequestId` so that we can capture
        // a future reference to the formatting request ID. This will allow us
        // to cancel the request whether it's in the downloading or formatting
        // step at the time the user executes the cancellation block. The same
        // approach applies to the download request.

        let formattingRequestId = DeferredValue<UUID>()
        let downloadRequestId = DeferredValue<UUID>()

        checkForFormattedImage(key: key) { [weak self] cachedImage in
            guard let this = self else { completion(nil); return }
            if let image = cachedImage {
                this.memoryCache[key] = image
                completion(image)
            } else {
                downloadRequestId.value = this.obtainOriginalFile(for: key) { [weak this] downloadResult in
                    guard let this = this else { completion(nil); return }
                    guard let downloadResult = downloadResult else { completion(nil); return }
                    // `this.formatImage` is asynchronous, but returns a request ID
                    // synchronously which can be used to cancel the formatting request.
                    formattingRequestId.value = this.formatImage(
                        key: key,
                        result: downloadResult,
                        completion: completion
                    )
                }
            }
        }

        return .async(cancellation: { [weak self] in
            defer { task?.end() }
            guard let this = self else { return }
            if let id = formattingRequestId.value {
                this.formattingTaskRegistry.cancelRequest(withId: id)
            }
            if let id = downloadRequestId.value {
                this.downloadTaskRegistry.cancelRequest(withId: id)
            }
        })
    }

    /// Adds a request for formatting a downloaded image. If this request is the
    /// first for this format, it will create a task for that format. Otherwise
    /// it will be appended to the existing task. Upon completion of the task,
    /// the formatted image will be inserted into the in-memory cache.
    ///
    /// If an image in the requested format already exists on disk, then the
    /// the request(s) will be fulfilled with that existing image.
    ///
    /// - parameter key: The key to use when caching the image.
    ///
    /// - parameter result: The result of a previous download phase. Contains
    /// either a previously-downloaded image, a local URL to a freshly-
    /// downloaded image file.
    ///
    /// - parameter completion: A block performed on the main queue when the
    /// requested is fulfilled, or when the underlying task fails for one reason
    /// or another.
    ///
    /// - returns: Returns an ID for the request. This ID can be used to later
    /// cancel the request if needed.
    private func formatImage(
        key: ImageKey,
        result: DownloadResult,
        completion: @escaping @Sendable @MainActor (Image?) -> Void
    ) -> UUID {
        let operation = DeferredValue<Operation>()
        return formattingTaskRegistry.addRequest(
            taskId: key,
            workQueue: workQueue,
            taskExecution: { [weak self] finish in
                guard let this = self else {
                    onMain { finish(nil) }
                    return
                }
                let destination = this.fileUrl(forFormattedImageWithKey: key)
                if let image = FileManager.default.image(fromFileAt: destination) {
                    onMain { finish(image) }
                } else {
                    let blockOperation = BlockOperation {
                        let image = key.format.image(from: result)
                        if let image = image {
                            this.diskWritingQueue.addOperation {
                                FileManager.default.save(image, to: destination)
                            }
                        }
                        onMain { finish(image) }
                    }
                    operation.value = blockOperation
                    this.formattingQueue.addOperation(blockOperation)
                }
            },
            taskCancellation: {
                operation.value?.cancel()
            },
            taskCompletion: { [weak self] result in
                result.map { self?.memoryCache[key] = $0 }
            },
            requestCompletion: completion
        )
    }

    /// Adds a request for obtaining the canonical version of an image.
    ///
    /// If the original image is found already on disk, then the image will be
    /// instantiated from the data on disk. Otherwise, the image will be
    /// downloaded and moved to the expected location on disk, and the resulting
    /// file URL will be returned to the caller via the completion block.
    ///
    /// - parameter url: The HTTP URL at which the original image is found.
    ///
    /// - parameter completion: A block performed on the main queue when the
    /// image file is found, or if the request fails.
    ///
    /// - returns: Returns an ID for the request. This ID can be used to later
    /// cancel the request if needed.
    private func obtainOriginalFile(
        for key: ImageKey,
        completion: @escaping @Sendable @MainActor (DownloadResult?) -> Void
    ) -> UUID {
        enum TaskValue {
            case url(URLSessionDownloadTask)
            case manuallySeeded
            case custom(OriginalImageSource.Loader)

            func cancel() {
                switch self {
                case .url(let task):
                    task.cancel()
                case .manuallySeeded:
                    break // not cancellable
                case .custom:
                    break // not supported, yet.
                }
            }
        }

        let destination = fileUrl(forOriginalImageWithKey: key)
        let taskValue = DeferredValue<TaskValue>()
        return downloadTaskRegistry.addRequest(
            taskId: key,
            workQueue: workQueue,
            taskExecution: { finish in
                if FileManager.default.fileExists(at: destination), let image = Image.fromFile(at: destination) {
                    onMain { finish(.previous(image)) }
                } else {
                    switch key.source {
                    case .url(let url):
                        let urlTask = self.urlSession.downloadTask(with: url) { (temp, _, _) in
                            if let temp = temp, let _ = try? FileManager.default.moveFile(from: temp, to: destination) {
                                onMain { finish(.fresh(destination)) }
                            } else {
                                onMain { finish(nil) }
                            }
                        }
                        taskValue.value = .url(urlTask)
                        urlTask.resume()
                    case .manuallySeeded:
                        onMain { finish(nil) }
                    case .custom(_, _, let loader):
                        taskValue.value = .custom(loader)
                        loader { image in
                            if let image = image {
                                onMain { finish(.previous(image)) }
                            } else {
                                onMain { finish(nil) }
                            }
                        }
                    }
                }
        },
            taskCancellation: { taskValue.value?.cancel() },
            taskCompletion: { _ in },
            requestCompletion: completion
        )
    }

    /// Checks if an existing image of a given format already exists on disk.
    ///
    /// - parameter key: The key used when caching the formatted image.
    ///
    /// - parameter completion: A block performed with the result, called upon
    /// the main queue. If found, the image is decompressed on a background
    /// queue to avoid doing so on the main queue.
    private func checkForFormattedImage(
        key: ImageKey,
        completion: @escaping @Sendable @MainActor (Image?) -> Void
    ) {
        deferred(on: workQueue) {
            let image: Image? = {
                let destination = self.fileUrl(forFormattedImageWithKey: key)
                guard let data = try? Data(contentsOf: destination) else { return nil }
                guard let image = Image(data: data) else { return nil }
                return ImageDrawing.decompress(image)
            }()
            onMain {
                completion(image)
            }
        }
    }

    /// Returns the absolute file URL for the original image included in `key`,
    /// regardless of the `format` used in `key`.
    private nonisolated func fileUrl(forOriginalImageWithKey key: ImageKey) -> URL {
        let filename: String
        switch key.source {
        case .url(let url):
            let originalKey = ImageKey(source: .url(url), format: .original)
            filename = uniqueFilenameFromUrl(url) + originalKey.filenameSuffix
        case .manuallySeeded(let id):
            filename = "\(id).MANUALLY_SEEDED_ORIGINAL"
        case .custom(let id, let namespace, _):
            filename = "\(namespace).\(id).CUSTOM_ORIGINAL"
        }
        return directory.appendingPathComponent(filename, isDirectory: false)
    }

    /// Returns the absolute file URL for an image with `key`, taking into
    /// account the format specified by that key (we save formatted images, too).
    private nonisolated func fileUrl(forFormattedImageWithKey key: ImageKey) -> URL {
        let filename: String
        switch key.source {
        case .url(let url):
            filename = uniqueFilenameFromUrl(url) + key.filenameSuffix
        case .manuallySeeded(let id):
            filename = "\(id).\(key.filenameSuffix)"
        case .custom(let identifier, let namespace, _):
            filename = "\(namespace).\(identifier).\(key.filenameSuffix)"
        }
        return directory.appendingPathComponent(filename, isDirectory: false)
    }

    private func observeNotifications() {
        #if os(iOS)
        NotificationCenter.default
            .publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.trimStaleFiles()
                }
            }
            .store(in: &cancellables)
        #endif
    }

    private func trimStaleFiles() {
        guard let byteLimit = byteLimitForFileStorage else { return }
        let task = BackgroundTask.start()
        DispatchQueue.global().async {
            FileManager.default.removeFilesByDate(
                inDirectory: self.directory,
                untilWithinByteLimit: byteLimit
            )
            task?.end()
        }
    }

}

private func didntThrow(_ block: () throws -> Void) -> Bool {
    do { try block(); return true } catch { return false }
}
