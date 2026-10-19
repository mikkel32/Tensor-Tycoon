import Foundation

/// Chooses a bundled photo (see ImageCredits) for a topic.
///
/// Choices are a pure function of a seed string (a news title, a listing name, a catalog id), hashed
/// with FNV-1a: the same item always shows the same photo, across runs and machines. It never touches
/// the game's random stream, so picking photos cannot change how a game plays out.
enum ImagePicker {
    enum Topic: String, CaseIterable, Sendable {
        case campus, hall, construction, cooling
        case grid, solar, wind, nuclear, battery, hydro, geothermal, fusion, gas
        case fab, government, nationalLab, science, finance, compute, network, events, hackathon, robotics, city
        // Second wave
        case aerospace, missionControl, quantum, cryogenics, instruments, packaging, chipTest, controlRoom
        case liquidCooling, industrialCooling, university, boardroom, exhibition
        // 3.4
        case robotaxi, fabConstruction, europe, chinaTech
    }

    /// Same-subject photos for each topic. Every key must be a file in Resources/Images
    /// (Scripts/check_images.sh checks this).
    static let pools: [Topic: [String]] = [
        .campus: ["hyperscale_campus", "dc_ashburn", "dc_construction", "dc_cooling_tower", "loc_the_dalles"],
        .hall: ["dc_hall", "dc_rows", "dc_corridor", "server_room", "dc_cern", "dc_servers"],
        .construction: ["dc_construction", "dc_build_interior", "dc_foulum"],
        .cooling: ["chiller", "dc_cooling_tower", "immersion"],
        // grid_control is the outside of a grid control centre (a substation hall), so it illustrates the grid, not a control room.
        .grid: ["substation", "power_lines", "power_substation_night", "grid_control"],
        .solar: ["solar_farm"],
        .wind: ["hq_dk_wind", "power_wind", "power_offshore"],
        .nuclear: ["nuclear", "power_nuclear2", "power_nuclear_build", "uae_barakah"],
        .battery: ["power_battery"],
        .hydro: ["power_hydro"],
        .geothermal: ["power_geothermal"],
        .fusion: ["power_fusion"],
        .gas: ["power_gas", "generator"],
        .fab: ["wafer", "wafer_closeup", "fab_cleanroom", "fab_steppers", "fab_wetbench", "fab_euv", "fab_tsmc18"],
        .government: ["gov_capitol", "gov_reichstag", "gov_folketinget", "gov_assemblee", "gov_montecitorio"],
        .nationalLab: ["natlab_ornl", "natlab_bnl", "fr_esrf"],
        .science: ["lab_materials", "lab_biology", "lab_automation", "lab_chemistry", "lab_physics", "lab_electronics", "lab_tem", "lab_spectro"],
        .finance: ["stock_exchange", "fin_cbot"],
        .compute: ["supercomputer", "gpu_cluster", "hpc_summit", "hpc_frontier", "dc_liquid", "hpc_marenostrum5"],
        .network: ["network", "fiber", "dc_servers"],
        .events: ["event_hall", "event_auditorium"],
        .hackathon: ["event_hackathon", "event_hackathon2"],
        .robotics: ["lab_robotics", "robot_factory", "robot_humanoid", "robot_quadruped"],
        // city_seoul was dropped: Commons flags it for South Korea's lack of freedom of panorama.
        .city: ["sf_skyline", "city_tokyo", "city_nyc", "city_singapore", "city_london", "city_shenzhen"],
        // Second wave
        .aerospace: ["space_cleanroom", "space_mirror", "space_chamber", "space_antenna"],
        .missionControl: ["space_mission_control", "space_apollo_control"],
        .quantum: ["quantum_ibm", "quantum_fridge", "quantum_cryostat"],
        .cryogenics: ["cryo_lab", "quantum_fridge"],
        .instruments: ["lab_tem", "lab_spectro", "lab_materials"],
        .packaging: ["chip_chiplets", "chip_hbm", "chip_dieshot"],
        .chipTest: ["chip_test", "lab_electronics"],
        .controlRoom: ["hpc_control", "space_mission_control", "grid_control_room", "power_nuclear_control"],
        .liquidCooling: ["dc_liquid", "immersion", "gpu_blade_liquid"],
        .industrialCooling: ["industrial_cooling", "dc_cooling_tower", "chiller"],
        .university: ["dk_sdu_odense", "dk_aarhus_uni", "dk_dtu", "ro_univ_bucharest", "ro_ubb_cluj", "fr_minatec", "it_robot_lab", "it_sapienza"],
        .boardroom: ["biz_boardroom"],
        .exhibition: ["biz_expo", "event_hall"],
        // 3.4
        .robotaxi: ["robot_robotaxi"],
        .fabConstruction: ["fab_arizona_build"],
        .europe: ["gov_eu_commission"],
        .chinaTech: ["city_beijing", "city_shenzhen"],
    ]

    /// Extra photos of each HQ city (keyed by `HQCity.id`), so a city screen or a local story can
    /// show its research site or business district, not only the skyline. The skyline photo the
    /// catalog names stays first.
    static let cityGallery: [String: [String]] = [
        "paris": ["hq_paris", "city_la_defense", "gov_assemblee"],
        "grenoble": ["hq_grenoble", "fr_grenoble_science", "fr_minatec", "fr_esrf"],
        "odense": ["hq_odense", "dk_sdu_odense", "dk_odense_robotics"],
        "aarhus": ["hq_aarhus", "dk_aarhus_uni"],
        "copenhagen": ["hq_copenhagen", "dk_dtu", "gov_folketinget"],
        "bucharest": ["hq_bucharest", "ro_univ_bucharest"],
        "cluj": ["hq_cluj", "ro_ubb_cluj"],
        "turin": ["hq_turin", "it_turin_lingotto"],
        "milan": ["hq_milan"],
        "rome": ["hq_rome", "it_sapienza", "gov_montecitorio"],
        "lyon": ["hq_lyon"],
        "aalborg": ["hq_aalborg"],
    ]

    /// A university or public research photo for each country (keyed by `Country.id`).
    static let universityByCountry: [String: [String]] = [
        "dk": ["dk_sdu_odense", "dk_aarhus_uni", "dk_dtu"],
        "ro": ["ro_univ_bucharest", "ro_ubb_cluj"],
        "it": ["it_robot_lab", "it_sapienza"],
        "fr": ["fr_grenoble_science", "fr_minatec", "fr_esrf"],
    ]

    /// The seat of each country's parliament (keyed by `Country.id`), which writes the rules a lab there lives under.
    /// Real photos of the named buildings. Romania has none: its Palace of the Parliament is a recent building in a
    /// country without commercial freedom of panorama.
    static let nationalByCountry: [String: [String]] = [
        "dk": ["gov_folketinget"],
        "fr": ["gov_assemblee"],
        "it": ["gov_montecitorio"],
        "us": ["gov_capitol"],
    ]

    /// Photos for a country card beyond the HQ city's skyline: the city's other sites, then the country's
    /// parliament and universities, without repeats, at most `limit`. Each is a real photo of what its credit
    /// names, so the card captions it with that subject rather than calling it illustrative.
    static func countryPhotos(country: String, city: String, skyline: String, limit: Int = 4) -> [String] {
        var out: [String] = []
        let candidates = (cityGallery[city] ?? []) + (nationalByCountry[country] ?? []) + (universityByCountry[country] ?? [])
        for k in candidates where k != skyline && !out.contains(k) && out.count < limit { out.append(k) }
        return out
    }

    /// Generic photos that many call sites share. An item carrying one of these is shown a
    /// same-subject alternative from its pool instead, so the feed doesn't repeat one picture.
    /// Photos of specific things (a chip, a city, a lab) are never swapped.
    static let variants: [String: Topic] = [
        "wafer": .fab,
        "wafer_closeup": .fab,
        "stock_exchange": .finance,
        "supercomputer": .compute,
        "gpu_cluster": .compute,
        "network": .network,
        "hyperscale_campus": .campus,
        "dc_construction": .construction,
        "dc_hall": .hall,
        "dc_rows": .hall,
        "server_room": .hall,
        "substation": .grid,
        "nuclear": .nuclear,
        "solar_farm": .solar,
        "immersion": .liquidCooling,
    ]

    /// Words in a headline that name a topic, checked in order (the first match wins).
    /// Short keywords match whole words only, so "fab" doesn't match "fabulous" and "ban" doesn't match "bank".
    static let keywords: [(Topic, [String])] = [
        (.missionControl, ["mission control", "launch window", "spacecraft operations"]),
        (.aerospace, ["satellite", "satellites", "spacecraft", "orbit", "orbital", "space telescope", "aerospace", "launch vehicle", "nasa", "esa"]),
        (.quantum, ["quantum", "qubit", "qubits"]),
        (.cryogenics, ["cryogenic", "cryogenics", "superconducting", "superconductor", "millikelvin"]),
        (.packaging, ["packaging", "cowos", "hbm", "chiplet", "chiplets", "interposer", "advanced packaging", "3d stacking"]),
        (.chipTest, ["tape-out", "tapeout", "first silicon", "bring-up", "test chips", "probe station"]),
        (.liquidCooling, ["liquid cooling", "liquid-cooled", "direct-to-chip", "immersion"]),
        (.controlRoom, ["control room", "operations centre", "operations center", "noc", "grid operator"]),
        (.instruments, ["microscope", "microscopy", "spectroscopy", "spectrometer", "crystallography", "synchrotron"]),
        (.robotaxi, ["robotaxi", "robotaxis", "self-driving", "driverless", "autonomous vehicle", "autonomous vehicles", "autonomous driving"]),
        (.robotics, ["robot", "robots", "robotic", "robotics", "humanoid", "humanoids", "embodied", "quadruped"]),
        (.hackathon, ["hackathon", "hackathons", "game jam"]),
        (.events, ["conference", "keynote", "summit", "expo", "neurips", "icml", "iclr", "showcase", "demo day"]),
        (.fusion, ["fusion"]),
        (.nuclear, ["nuclear", "reactor", "reactors", "smr", "smrs"]),
        (.solar, ["solar"]),
        (.wind, ["wind farm", "wind power", "offshore wind", "turbines"]),
        (.battery, ["battery", "batteries", "storage farm"]),
        (.hydro, ["hydro", "hydropower", "dam"]),
        (.geothermal, ["geothermal"]),
        (.gas, ["gas turbines", "gas plant", "natural gas"]),
        (.cooling, ["cooling", "chiller", "chillers", "heatwave", "cooling towers"]),
        (.grid, ["grid", "transmission", "substation", "blackout", "power shortage", "utility", "utilities", "electricity"]),
        (.fabConstruction, ["fab construction", "new fab", "fab under construction", "breaks ground"]),
        (.fab, ["fab", "fabs", "foundry", "foundries", "wafer", "wafers", "lithography", "euv", "tsmc"]),
        (.nationalLab, ["national lab", "national laboratory", "doe", "genesis mission"]),
        (.europe, ["eu", "eu ai act", "european commission", "european union", "brussels", "eurohpc"]),
        (.government, ["senate", "congress", "parliament", "regulation", "regulators", "regulator", "lawmakers", "law", "bill",
                       "act", "executive order", "white house", "ministry", "minister", "government", "ban", "bans", "export controls",
                       "sanctions", "treaty", "hearing", "commission"]),
        (.finance, ["ipo", "shares", "stock", "stocks", "valuation", "investors", "earnings", "market cap", "bond", "bonds",
                    "crash", "rally", "funding round", "acquires", "acquisition", "merger", "nasdaq", "dividend"]),
        (.chinaTech, ["beijing", "shenzhen", "hangzhou", "zhongguancun", "chinese"]),
        (.university, ["university", "universities", "campus partnership", "phd", "professor", "professors", "academic", "academia"]),
        (.boardroom, ["board", "boardroom", "board meeting", "ceo", "shareholders", "chairman", "chairwoman", "directors"]),
        (.exhibition, ["trade show", "trade fair", "exhibition", "ces", "computex"]),
        (.campus, ["datacenter", "datacenters", "datacentre", "data center", "data centers", "campus", "gigawatt", "stargate"]),
        (.compute, ["supercomputer", "cluster", "exaflop", "exascale", "training run", "gpus"]),
        (.science, ["nobel", "protein", "biology", "drug", "drugs", "physics", "materials", "chemistry", "discovery", "scientific", "lab result"]),
    ]

    // MARK: - Picking

    /// A photo for `topic`, the same one every time for the same `seed`.
    static func pick(_ topic: Topic, seed: String) -> String {
        let pool = pools[topic] ?? ["supercomputer"]
        return pool[Int(stableHash(seed) % UInt64(pool.count))]
    }

    /// An illustrative photo for one datacenter: its region's photo or another campus or hall,
    /// so a player with five sites in one region doesn't see the same picture five times.
    static func sitePhoto(location: String, seed: String) -> String {
        var pool = [location]
        for k in (pools[.campus] ?? []) + (pools[.hall] ?? []) where !pool.contains(k) { pool.append(k) }
        // The region's own photo comes up about a third of the time.
        let h = stableHash(seed)
        return h % 3 == 0 ? location : pool[1 + Int((h / 3) % UInt64(pool.count - 1))]
    }

    /// One of a city's photos (see `cityGallery`), the same one every time for the same `seed`.
    /// Falls back to `fallback` (normally the catalog's skyline key) for cities without a gallery.
    static func cityPhoto(_ cityID: String, fallback: String, seed: String) -> String {
        guard let pool = cityGallery[cityID], !pool.isEmpty else { return fallback }
        return pool[Int(stableHash(cityID + "|" + seed) % UInt64(pool.count))]
    }

    /// A university or research-campus photo for a country, falling back to the generic university pool.
    static func universityPhoto(country: String, seed: String) -> String {
        let pool = universityByCountry[country] ?? pools[.university] ?? ["dk_dtu"]
        return pool[Int(stableHash(country + "|" + seed) % UInt64(pool.count))]
    }

    // MARK: - Honest labels

    /// Photos of a general subject: everything in a topic pool, the generic variants, and the non-skyline
    /// city and university photos. When one of these is shown for a specific story, facility or product
    /// (a news item, the player's own lab, a fictional site), it illustrates rather than depicts, and the
    /// view should mark it "Illustrative" (`Photo(key:, illustrative: true)`). Photos of one specific real
    /// thing (a chip, a named building shown as itself) are not in this set.
    static let stockPhotos: Set<String> = {
        var set = Set(pools.values.joined())
        set.formUnion(variants.keys)
        set.formUnion(cityGallery.values.joined().filter { !$0.hasPrefix("hq_") })
        set.formUnion(universityByCountry.values.joined())
        set.formUnion(facilityPhotos)
        return set
    }()

    /// Photos that only ever stand for the player's own facilities and so aren't in a topic pool: the garage
    /// and start-up office, the liquid-cooling retrofit, lab kinds and Advanced Projects facilities. News and
    /// decisions about those facilities reuse them, and they always illustrate.
    static let facilityPhotos: Set<String> = ["garage", "rack_rear", "lab_energy", "lab_anechoic"]

    /// True when `key` is a stock photo (see `stockPhotos`) and so should carry the "Illustrative" pill
    /// wherever it stands in for something specific, such as a news story or a decision.
    static func isIllustrative(_ key: String?) -> Bool {
        guard let key else { return false }
        return stockPhotos.contains(key)
    }

    /// The topic a headline is about, if it names one.
    static func topic(for text: String) -> Topic? {
        let cleaned = String(text.lowercased().map { $0.isLetter || $0.isNumber || $0 == "-" ? $0 : " " })
        let haystack = " " + cleaned.split(separator: " ").joined(separator: " ") + " "
        for (topic, list) in keywords {
            // Whole words; keywords of six letters or more also match as word starts ("datacenter" → "datacenters").
            for k in list where haystack.contains(" \(k) ") || (k.count >= 6 && haystack.contains(" \(k)")) {
                return topic
            }
        }
        return nil
    }

    /// The photo to show for a news item or decision.
    /// - A specific photo (a chip, a city, a lab) is kept as it is.
    /// - A generic photo is swapped for a same-subject photo chosen by the title;
    ///   the catch-all San Francisco skyline follows the headline's topic when it names one.
    /// - With no photo, a headline that names a topic gets one when `fill` is set, and finance and
    ///   policy stories get a trading floor or a parliament.
    static func illustrate(_ image: String?, title: String, category: NewsCategory? = nil, fill: Bool = true) -> String? {
        if let image {
            if image == "sf_skyline" { return pick(topic(for: title) ?? .city, seed: title) }
            if let t = variants[image] { return pick(t, seed: title) }
            return image
        }
        guard fill else { return nil }
        if let t = topic(for: title) { return pick(t, seed: title) }
        switch category {
        case .finance: return pick(.finance, seed: title)
        case .policy: return pick(.government, seed: title)
        default: return nil
        }
    }

    /// FNV-1a, 64-bit. Swift's own `Hasher` is randomly seeded per process, so it can't be used here.
    static func stableHash(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for b in s.utf8 {
            h ^= UInt64(b)
            h = h &* 0x0000_0100_0000_01b3
        }
        return h
    }
}

// MARK: - Accelerator photos

/// The caption an accelerator's photo carries when it isn't a photo of that exact chip.
struct PhotoLabel: Sendable, Equatable {
    let text: String
    /// The shorter caption small cards use (see `PhotoCaptionBadge`).
    let short: String
    let symbol: String
    let help: String
}

extension Accelerator {
    /// The chip doesn't ship as real hardware (a roadmap projection, a fictional part, your own or alien silicon), so
    /// its photo is an illustration, never a picture of the thing itself.
    var photoIsUnreleased: Bool {
        if vendor == .custom { return true }
        guard representativeImage else { return false }
        return name.localizedCaseInsensitiveContains("roadmap") || fact.localizedCaseInsensitiveContains("roadmap")
            || fact.localizedCaseInsensitiveContains("fictional")
    }

    /// The photo is an illustration rather than a picture of related hardware: the chip is unreleased or your own, or
    /// no free photo of anything like it exists and a generic stock photo (a wafer, a supercomputer hall) stands in.
    var photoIsIllustrative: Bool {
        photoIsUnreleased || (representativeImage && ImagePicker.isIllustrative(image))
    }

    /// True when the photo isn't of this exact chip: a related chip (`representativeImage`) or an illustration.
    /// News about the chip marks such a photo "Illustrative".
    var photoIsStandIn: Bool { representativeImage || photoIsIllustrative }

    /// The photo's caption: "Illustrative" for chips that don't exist yet, are your own design or are shown with a
    /// generic photo, "Similar hardware" for real chips shown with a photo of a close relative, nothing for a photo of
    /// the chip itself.
    var photoLabel: PhotoLabel? {
        if photoIsUnreleased {
            return PhotoLabel(text: "Illustrative", short: "Illustrative", symbol: "paintbrush.pointed.fill",
                              help: "Not a photo of this chip: it's a roadmap projection or your own design, so the picture is a stand-in.")
        }
        if photoIsIllustrative {
            return PhotoLabel(text: "Illustrative", short: "Illustrative", symbol: "photo",
                              help: "Not a photo of this chip: no freely licensed photo of it or a close relative was available, so a generic photo stands in.")
        }
        if representativeImage {
            return PhotoLabel(text: "Similar hardware", short: "Similar", symbol: "photo",
                              help: "A photo of closely related hardware; no freely licensed photo of this exact chip was available.")
        }
        return nil
    }
}
