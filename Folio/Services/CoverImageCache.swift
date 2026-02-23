import SwiftUI

/// Disk-backed image cache for book covers.
/// Stores downloaded covers locally to avoid re-fetching on every render.
actor CoverImageCache {
    static let shared = CoverImageCache()

    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private var memoryCache: [String: Image] = [:]

    private init() {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = caches.appendingPathComponent("BookCovers", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func image(for urlString: String) async -> Image? {
        // 1. Memory cache
        if let cached = memoryCache[urlString] {
            return cached
        }

        let fileURL = cacheDirectory.appendingPathComponent(cacheKey(for: urlString))

        // 2. Disk cache
        if fileManager.fileExists(atPath: fileURL.path()),
           let uiImage = UIImage(contentsOfFile: fileURL.path()) {
            let img = Image(uiImage: uiImage)
            memoryCache[urlString] = img
            return img
        }

        // 3. Network fetch
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  200..<300 ~= httpResponse.statusCode,
                  let uiImage = UIImage(data: data) else {
                return nil
            }

            // Write to disk
            try? data.write(to: fileURL)

            let img = Image(uiImage: uiImage)
            memoryCache[urlString] = img
            return img
        } catch {
            return nil
        }
    }

    private func cacheKey(for urlString: String) -> String {
        // Simple hash-based filename
        let hash = urlString.utf8.reduce(0) { ($0 &<< 5) &- $0 &+ UInt($1) }
        return "\(hash).jpg"
    }
}
