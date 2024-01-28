import Foundation

extension ImageCache {

    /// Equivalent to `image(from:format:completion:)` but as `async`.
    public func image(
        from url: URL,
        format: Format = .original
    ) async -> Image? {
        await image(from: .url(url), format: format)
    }

    /// Equivalent to `image(from:format:completion:)` but as `async`.
    public func image(
        from source: OriginalImageSource,
        format: Format = .original
    ) async -> Image? {
        if let cached = memoryCachedImage(from: source, format: format) {
            return cached
        }
        return await withCheckedContinuation { (continuation: CheckedContinuation<Image?, Never>) in
            self.image(from: source, format: format, completion: { image in
                continuation.resume(returning: image)
            })
        }
    }

}
