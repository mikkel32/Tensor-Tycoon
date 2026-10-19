import Foundation

/// 3.4: photo honesty check.
///
///   TensorTycoon --photo-check
///
/// Checks that the bundled photos tell the truth about what they show: every photo the catalogues and topic pools
/// name has a credit; no accelerator is shown with a generic stock photo or someone else's photo without a label;
/// headline topics pick the right pool; and in a played game every hardware story whose photo stands in for the
/// chip is marked illustrative in the news feed. (Scripts/check_images.sh checks the files themselves.) Exits 1 on
/// any failure.
enum PhotoHarness {
    static func main() -> Int32 {
        var failures: [String] = []
        func check(_ ok: Bool, _ what: @autoclosure () -> String) { if !ok { failures.append(what()) } }
        let credited = Set(ImageCredits.all.map(\.id))

        // 1. Everything the game can show is credited.
        for a in HardwareCatalog.all { check(credited.contains(a.image), "\(a.id): photo \(a.image) has no credit") }
        for l in LocationCatalog.all { check(credited.contains(l.image), "location \(l.id): photo \(l.image) has no credit") }
        for (topic, pool) in ImagePicker.pools.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            check(!pool.isEmpty, "topic \(topic.rawValue) has no photos")
            for k in pool { check(credited.contains(k), "topic \(topic.rawValue): \(k) has no credit") }
        }
        for k in ImagePicker.facilityPhotos.sorted() { check(credited.contains(k), "facility photo \(k) has no credit") }
        for c in ImageCredits.all {
            check(c.license == "Public domain" || c.licenseURL != nil, "\(c.id): no licence deed for \(c.license)")
        }

        // 2. Accelerator labels. A stock photo (a wafer, a hall) is always "Illustrative"; a photo shared by several
        //    chips is shown unlabelled for at most the one chip it depicts.
        var stockChips = 0
        for a in HardwareCatalog.all where ImagePicker.isIllustrative(a.image) {
            stockChips += 1
            check(a.representativeImage, "\(a.id) shows the stock photo \(a.image) as if it were the chip")
            check(a.photoLabel?.text == "Illustrative", "\(a.id) shows the stock photo \(a.image) labelled \(a.photoLabel?.text ?? "nothing")")
        }
        for (photo, chips) in Dictionary(grouping: HardwareCatalog.all, by: \.image).sorted(by: { $0.key < $1.key }) {
            let unlabelled = chips.filter { $0.photoLabel == nil }.map(\.id)
            check(unlabelled.count <= 1, "photo \(photo) is presented as the real thing for \(unlabelled.joined(separator: ", "))")
        }

        // 3. Headline topics.
        let topics: [(String, ImagePicker.Topic)] = [
            ("Waymo expands its robotaxi service", .robotaxi), ("EU AI Act obligations take effect", .europe),
            ("Chinese lab ships an open model", .chinaTech), ("TSMC breaks ground in Arizona", .fabConstruction),
            ("Grid operator opens a new control room", .controlRoom), ("Humanoid robots enter the factory", .robotics),
        ]
        for (headline, want) in topics {
            let got = ImagePicker.topic(for: headline)
            check(got == want, "\"\(headline)\" picks \(got?.rawValue ?? "no topic"), expected \(want.rawValue)")
        }

        // 4. A played game: hardware stories about chips shown with stand-in photos are marked illustrative.
        _ = PTPlay.play(era: "2022", seed: 1, years: 3, mode: "quiet", flags: [])
        var stories = 0, standIns = 0
        if let s = PTPlay.lastState {
            for n in s.news where n.image != nil {
                guard let a = HardwareCatalog.all.first(where: { n.title.hasSuffix("announces \($0.name)") || n.title == "\($0.name) is now available"
                    || n.title.hasSuffix("× \($0.name)") }) else { continue }
                stories += 1
                if a.photoIsStandIn { standIns += 1 }
                let shown = n.illustrative || ImagePicker.isIllustrative(n.image)
                check(shown == a.photoIsStandIn || (shown && ImagePicker.isIllustrative(n.image)),
                      "news \"\(n.title)\": photo \(n.image ?? "") marked \(shown ? "illustrative" : "real") but the chip's photo is \(a.photoIsStandIn ? "a stand-in" : "real")")
                check(n.image.map { credited.contains($0) } ?? true, "news \"\(n.title)\": photo \(n.image ?? "") has no credit")
            }
        } else {
            failures.append("the 2022 playtest produced no game")
        }
        check(stories > 0 && standIns > 0, "the playtest produced no hardware stories to check (\(stories), \(standIns) stand-ins)")

        print("== Photo check ==")
        print("  \(ImageCredits.all.count) credited photos · \(HardwareCatalog.all.count) accelerators (\(stockChips) on stock photos) · "
              + "\(LocationCatalog.all.count) locations (\(LocationCatalog.all.filter(\.photoShowsPlace).count) show the place) · "
              + "\(stories) hardware stories (\(standIns) with stand-in photos)")
        for f in failures.prefix(40) { print("  FAIL: \(f)") }
        print(failures.isEmpty ? "  OK: photos are credited and labelled honestly" : "  FAILED: \(failures.count) problem(s)")
        return failures.isEmpty ? 0 : 1
    }
}
