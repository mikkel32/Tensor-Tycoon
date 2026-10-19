import AppKit
import ImageIO
import SwiftUI

/// Loads the bundled Wikimedia Commons photos (see ImageCredits) from the app bundle,
/// falling back to the source tree when running from `swift run` / Xcode.
///
/// Memory: every photo is decoded through ImageIO at the size it is shown at, never larger than
/// 1600 px. Large decodes (heroes, banners) live in an `NSCache` with a byte budget, so the cache
/// evicts instead of growing with every screen visited. Small thumbnails (lists, cards, credits)
/// are cheap and kept in their own, larger-count cache.
@MainActor
enum ImageLibrary {
    /// Decode sizes (longest side, in pixels). A request is rounded up to the next bucket so a
    /// screen with many slightly different frame sizes still shares one decode per photo.
    enum Size: Int, CaseIterable, Sendable {
        /// Credits rows, tiny list icons.
        case icon = 192
        /// Cards and list rows (the default for `Photo`).
        case card = 560
        /// Wide banners and decision sheets.
        case banner = 1200
        /// Full-width heroes. Bundled photos are at most 1600 px wide.
        case full = 1600
    }

    /// Byte budget for the banner/full-size cache (decoded RGBA). About 12 hero-sized photos.
    static let largeCacheBytes = 96 * 1024 * 1024
    /// Byte budget for icon and card thumbnails (~120 card thumbnails or many more icons).
    static let smallCacheBytes = 64 * 1024 * 1024

    private static let large: NSCache<NSString, NSImage> = {
        let c = NSCache<NSString, NSImage>()
        c.totalCostLimit = largeCacheBytes
        c.name = "TensorTycoon.photos.large"
        return c
    }()

    private static let small: NSCache<NSString, NSImage> = {
        let c = NSCache<NSString, NSImage>()
        c.totalCostLimit = smallCacheBytes
        c.name = "TensorTycoon.photos.small"
        return c
    }()

    private static var missing: Set<String> = []

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

    /// The photo decoded with its longest side at most `size` pixels (never upscaled).
    static func image(_ key: String, size: Size) -> NSImage? {
        let cacheKey = "\(key)@\(size.rawValue)" as NSString
        let cache = size.rawValue <= Size.card.rawValue ? small : large
        if let img = cache.object(forKey: cacheKey) { return img }
        if missing.contains(key) { return nil }
        guard let u = url(key), let src = CGImageSourceCreateWithURL(u as CFURL, nil) else {
            missing.insert(key)
            return nil
        }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: size.rawValue,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else {
            missing.insert(key)
            return nil
        }
        let img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        cache.setObject(img, forKey: cacheKey, cost: cg.bytesPerRow * cg.height)
        return img
    }

    /// A large copy for heroes (≤ 1600 px), held in the evicting cache.
    static func image(_ key: String) -> NSImage? { image(key, size: .full) }

    /// A downsampled copy (longest side ≈ 560 px) for cards and lists.
    static func thumbnail(_ key: String) -> NSImage? { image(key, size: .card) }

    /// The smallest bucket that still looks sharp in a frame `points` wide on a Retina screen.
    static func size(forPoints points: CGFloat) -> Size {
        let px = Int((points * 2).rounded(.up))
        return Size.allCases.first { $0.rawValue >= px } ?? .full
    }

    static func credit(_ key: String) -> ImageCredit? { ImageCredits.byID[key] }

    /// Drops every decoded photo (e.g. on a memory warning or after leaving a photo-heavy screen).
    static func purge() {
        large.removeAllObjects()
        small.removeAllObjects()
    }
}

/// A bundled photo that fills its frame, with a tasteful placeholder if missing.
///
/// `thumb: true` (the default) decodes a ≈560 px card thumbnail; `thumb: false` a large copy for
/// heroes. `size` picks a bucket explicitly (e.g. `.icon` for credits rows, `.banner` for strips).
/// `illustrative: true` adds the standard "Illustrative photo" pill, for real photos standing in for
/// speculative, roadmap, custom or alien hardware and for the player's fictional facilities
/// (see `ImagePicker.isIllustrative` and `Accelerator.photoIsIllustrative`).
struct Photo: View {
    let key: String
    var contentMode: ContentMode = .fill
    var thumb = true
    var size: ImageLibrary.Size? = nil
    var illustrative = false

    private var bucket: ImageLibrary.Size { size ?? (thumb ? .card : .full) }

    var body: some View {
        if illustrative {
            // Fill the frame the caller gives and clip to it, so the pill sits inside the visible
            // area even when a `.fill` photo overflows its frame.
            Color.clear
                .overlay { picture }
                .clipped()
                .illustrativePhoto(true, key: key)
        } else {
            picture
        }
    }

    @ViewBuilder private var picture: some View {
        if let img = ImageLibrary.image(key, size: bucket) {
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

/// The "Illustrative photo" pill used wherever a real photo stands in for something that isn't
/// what the photo shows. Kept here so every screen labels such photos the same way.
/// It adapts to the photo's width: the full label on banners and cards, "Illustrative" on small
/// cards, and a bare photo badge on list thumbnails (the tooltip still explains it).
struct IllustrativePill: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            Group {
                if w < 96 {
                    Image(systemName: "photo")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(.black.opacity(0.62), in: .circle)
                        .padding(3)
                } else {
                    PhotoPill(text: w < 200 ? "Illustrative" : "Illustrative photo", symbol: "photo").padding(6)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel("Illustrative photo, not the actual item")
    }
}

extension View {
    /// Overlays the "Illustrative photo" pill (bottom-leading) and a tooltip naming the photo's real
    /// subject and credit when `on` is true; does nothing otherwise.
    @MainActor @ViewBuilder
    func illustrativePhoto(_ on: Bool, key: String? = nil) -> some View {
        if on {
            self
                .overlay { IllustrativePill() }
                .help(key.flatMap { ImageLibrary.credit($0) }.map { "Illustrative photo — actually shows: \($0.subject) · \($0.author) · \($0.license)" }
                      ?? "Illustrative photo")
        } else {
            self
        }
    }
}
