import AppKit
import ImageIO
import SwiftUI

/// Loads the bundled Wikimedia Commons photos (see ImageCredits) from the app bundle,
/// falling back to the source tree when running from `swift run` / Xcode.
/// Thumbnails are decoded once at a small size, which keeps photo-heavy screens fast.
@MainActor
enum ImageLibrary {
    private static var full: [String: NSImage] = [:]
    private static var thumbs: [String: NSImage] = [:]

    private static let directories: [URL] = {
        var dirs: [URL] = []
        if let res = Bundle.main.resourceURL {
            dirs.append(res.appendingPathComponent("Images", isDirectory: true))
        }
        // Source tree: <root>/Sources/TensorTycoon/Util/Images.swift -> <root>/Resources/Images
        let src = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Images", isDirectory: true)
        dirs.append(src)
        return dirs
    }()

    private static func url(_ key: String) -> URL? {
        for dir in directories {
            for ext in ["jpg", "png"] {
                let u = dir.appendingPathComponent("\(key).\(ext)")
                if FileManager.default.fileExists(atPath: u.path) { return u }
            }
        }
        return nil
    }

    static func image(_ key: String) -> NSImage? {
        if let img = full[key] { return img }
        guard let u = url(key), let img = NSImage(contentsOf: u) else { return nil }
        full[key] = img
        return img
    }

    /// A downsampled copy (longest side ≈ 560 px) for cards and lists.
    static func thumbnail(_ key: String) -> NSImage? {
        if let img = thumbs[key] { return img }
        guard let u = url(key), let src = CGImageSourceCreateWithURL(u as CFURL, nil) else { return image(key) }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 560,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return image(key) }
        let img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        thumbs[key] = img
        return img
    }

    static func credit(_ key: String) -> ImageCredit? { ImageCredits.all.first { $0.id == key } }
}

/// A bundled photo that fills its frame, with a tasteful placeholder if missing.
struct Photo: View {
    let key: String
    var contentMode: ContentMode = .fill
    var thumb = true

    var body: some View {
        if let img = thumb ? ImageLibrary.thumbnail(key) : ImageLibrary.image(key) {
            Image(nsImage: img)
                .resizable()
                .interpolation(.medium)
                .aspectRatio(contentMode: contentMode)
        } else {
            LinearGradient(colors: [.indigo.opacity(0.6), .cyan.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay(Image(systemName: "photo").font(.largeTitle).foregroundStyle(.white.opacity(0.6)))
        }
    }
}
