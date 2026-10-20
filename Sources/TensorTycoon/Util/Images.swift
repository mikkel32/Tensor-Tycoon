import AppKit
import ImageIO
import SwiftUI

/// Loads the bundled Wikimedia Commons photos (see ImageCredits) from the app bundle,
/// falling back to the source tree when running from `swift run` / Xcode.
///
/// Memory: every photo is decoded through ImageIO at the size it is shown at (`Photo` measures its
/// frame), never larger than 2400 px. Large decodes (heroes, banners) live in an `NSCache` with a byte
/// budget, so the cache evicts instead of growing with every screen visited. Small thumbnails (lists,
/// cards, credits) are cheap and kept in their own, larger-count cache.
@MainActor
enum ImageLibrary {
    /// Decode sizes (longest side, in pixels). A request is rounded up to the next bucket so a
    /// screen with many slightly different frame sizes still shares one decode per photo.
    enum Size: Int, CaseIterable, Sendable {
        /// Credits rows, tiny list icons.
        case icon = 192
        /// Cards and list rows (what `Photo` starts with before it has been laid out).
        case card = 560
        /// Wide banners, sheets and full-width cards.
        case banner = 1200
        /// Full-width heroes and the main-menu background. Bundled photos are at most 2400 px wide, and
        /// photos used as heroes at least 1800 px (Scripts/check_images.sh checks both).
        case full = 2400
    }

    /// Byte budget for the banner/full-size cache (decoded RGBA). About 11 hero-sized (2400 × 1350) photos.
    static let largeCacheBytes = 144 * 1024 * 1024
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

    /// A large copy for heroes (≤ 2400 px), held in the evicting cache.
    static func image(_ key: String) -> NSImage? { image(key, size: .full) }

    /// A downsampled copy (longest side ≈ 560 px) for cards and lists.
    static func thumbnail(_ key: String) -> NSImage? { image(key, size: .card) }

    /// The smallest bucket that still looks sharp when the photo's longest laid-out side is `points` long on a
    /// Retina screen. `Photo` calls this with its measured size.
    static func size(forPoints points: CGFloat) -> Size {
        let px = Int((points * 2).rounded(.up))
        return Size.allCases.first { $0.rawValue >= px } ?? .full
    }

    static func credit(_ key: String) -> ImageCredit? { ImageCredits.byID[key] }

    /// The tooltip for a photo: what it really shows, who took it and the licence. `illustrative` says it stands in
    /// for something else; `prefix` is put in front (e.g. why an accelerator's photo is a stand-in). Built here, not in
    /// view expressions, so SwiftUI's `.help` overloads stay cheap to type-check.
    static func tooltip(_ key: String?, illustrative: Bool = false, prefix: String = "") -> String {
        var t = prefix
        guard let key, let c = credit(key) else {
            if illustrative && t.isEmpty { t = "Illustrative photo" }
            return t
        }
        if !t.isEmpty { t += " " }
        t += illustrative ? "Illustrative photo — actually shows: " : "Photo: "
        t += c.subject
        t += " · " + c.author + " · " + c.license + " · Wikimedia Commons"
        return t
    }

    /// The full attribution for a credit line's tooltip, with how the bundled copy was edited.
    static func attributionTooltip(_ c: ImageCredit) -> String {
        var t = c.subject + ". " + c.attribution
        if c.modified != "none" { t += " · " + c.modified.capitalizedFirst }
        return t
    }

    /// Drops every decoded photo (e.g. on a memory warning or after leaving a photo-heavy screen).
    static func purge() {
        large.removeAllObjects()
        small.removeAllObjects()
    }
}

/// A bundled photo that fills its frame, with a tasteful placeholder if missing.
///
/// The photo measures the size it is laid out at and decodes the smallest bucket that is sharp there
/// (`ImageLibrary.size(forPoints:)`): a list thumbnail gets an icon-sized copy, a full-width banner a 1200
/// or 2400 px one. Before its first layout pass it starts from a ≈560 px card thumbnail, or from a full-size
/// copy with `thumb: false` (heroes), so a hero is decoded once at the right size. `size` fixes the bucket
/// instead (e.g. `.icon` for credits rows). `illustrative: true` adds the standard "Illustrative photo" pill,
/// for real photos standing in for speculative, roadmap, custom or alien hardware and for the player's
/// fictional facilities (see `ImagePicker.isIllustrative` and `Accelerator.photoIsIllustrative`).
struct Photo: View {
    let key: String
    var contentMode: ContentMode = .fill
    var thumb = true
    var size: ImageLibrary.Size? = nil
    var illustrative = false
    /// The longest side the picture was last laid out at, in points (0 before the first layout pass).
    @State private var laidOut: CGFloat = 0

    private var bucket: ImageLibrary.Size {
        if let size { return size }
        if laidOut > 0 { return ImageLibrary.size(forPoints: laidOut) }
        return thumb ? .card : .full
    }

    var body: some View {
        if illustrative || contentMode == .fill {
            // Fill the frame the caller gives and clip to it. On its own a `.fill` photo reports the
            // size of the scaled image, so a wide one (the San Francisco skyline) widened the card or
            // sheet around it past its column; this also keeps the pill inside the visible area.
            Color.clear
                .overlay { picture }
                .clipped()
                .illustrativePhoto(illustrative, key: key)
        } else {
            picture
        }
    }

    /// The decoded photo, reporting the size it is laid out at (a `.fill` photo's overflowing size, which is what
    /// its pixels are stretched over) so the next render can pick the right bucket. The measure only grows, so a
    /// photo sitting exactly on a bucket boundary can't flip between two decodes.
    private var picture: some View {
        decoded
            .background {
                GeometryReader { geo in
                    Color.clear
                        .onAppear { measured(geo.size) }
                        .onChange(of: geo.size) { _, size in measured(size) }
                }
            }
    }

    /// What VoiceOver reads for the photo: its credited subject, and whether it only stands in for the real thing.
    private var accessibilityText: String {
        let subject = ImageCredits.byID[key]?.subject ?? "Photo"
        return illustrative ? "Illustrative photo: \(subject)" : subject
    }

    private func measured(_ size: CGSize) {
        let longest = max(size.width, size.height).rounded(.up)
        if longest > laidOut { laidOut = longest }
    }

    @ViewBuilder private var decoded: some View {
        if let img = ImageLibrary.image(key, size: bucket) {
            Image(nsImage: img)
                .resizable()
                .interpolation(.medium)
                .aspectRatio(contentMode: contentMode)
                .accessibilityLabel(accessibilityText)
        } else {
            LinearGradient(colors: [.indigo.opacity(0.6), .cyan.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay(Image(systemName: "photo").font(.largeTitle).foregroundStyle(.white.opacity(0.6)))
        }
    }
}

/// A caption pinned to a corner of a photo (bottom-leading unless the photo already has text there) that adapts
/// to the photo's width: the full text on banners and cards, the short text on small cards, and a bare badge on
/// list thumbnails (the photo's tooltip still explains it). Overlay it on the photo so it is proposed the photo's frame.
struct PhotoCaptionBadge: View {
    let text: String
    let short: String
    var symbol = "photo"
    var accessibility: String
    var alignment: Alignment = .bottomLeading

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            Group {
                if w < 96 {
                    Image(systemName: symbol)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(.black.opacity(0.62), in: .circle)
                        .padding(3)
                } else {
                    PhotoPill(text: w < 200 ? short : text, symbol: symbol).padding(6)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        }
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel(accessibility)
    }
}

/// The "Illustrative photo" pill used wherever a real photo stands in for something that isn't
/// what the photo shows. Kept here so every screen labels such photos the same way.
struct IllustrativePill: View {
    var alignment: Alignment = .bottomLeading

    var body: some View {
        PhotoCaptionBadge(text: "Illustrative photo", short: "Illustrative", accessibility: "Illustrative photo, not the actual item",
                          alignment: alignment)
    }
}

extension View {
    /// Overlays the "Illustrative photo" pill (bottom-leading, or `alignment` when the photo carries its own caption
    /// there) and a tooltip naming the photo's real subject and credit when `on` is true; does nothing otherwise.
    @MainActor @ViewBuilder
    func illustrativePhoto(_ on: Bool, key: String? = nil, alignment: Alignment = .bottomLeading) -> some View {
        if on {
            self
                .overlay { IllustrativePill(alignment: alignment) }
                .help(ImageLibrary.tooltip(key, illustrative: true))
        } else {
            self
        }
    }

    /// Overlays an accelerator photo's caption ("Similar hardware" or "Illustrative", sized to the photo like
    /// `PhotoCaptionBadge`) and a tooltip saying why and what the photo really shows. Does nothing when the
    /// photo is of the chip itself. Apply it after the photo's frame and clip.
    @MainActor @ViewBuilder
    func acceleratorPhotoLabel(_ accel: Accelerator?, alignment: Alignment = .bottomLeading) -> some View {
        if let accel, let l = accel.photoLabel {
            self
                .overlay {
                    PhotoCaptionBadge(text: l.text, short: l.short, symbol: l.symbol, accessibility: "\(l.text) photo", alignment: alignment)
                }
                .help(ImageLibrary.tooltip(accel.image, illustrative: true, prefix: l.help))
        } else {
            self
        }
    }
}
