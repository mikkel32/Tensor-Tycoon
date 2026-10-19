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
    }

    /// Same-subject photos for each topic. Every key must be a file in Resources/Images
    /// (Scripts/check_images.sh checks this).
    static let pools: [Topic: [String]] = [
        .campus: ["hyperscale_campus", "dc_ashburn", "dc_construction", "dc_cooling_tower"],
        .hall: ["dc_hall", "dc_rows", "dc_corridor", "server_room", "dc_cern", "dc_servers"],
        .construction: ["dc_construction", "dc_build_interior", "dc_foulum"],
        .cooling: ["chiller", "dc_cooling_tower", "immersion"],
        .grid: ["substation", "power_lines", "power_substation_night"],
        .solar: ["solar_farm"],
        .wind: ["hq_dk_wind", "power_wind", "power_offshore"],
        .nuclear: ["nuclear", "power_nuclear2"],
        .battery: ["power_battery"],
        .hydro: ["power_hydro"],
        .geothermal: ["power_geothermal"],
        .fusion: ["power_fusion"],
        .gas: ["power_gas", "generator"],
        .fab: ["wafer", "wafer_closeup", "fab_cleanroom", "fab_steppers", "fab_wetbench", "fab_euv"],
        .government: ["gov_capitol", "gov_reichstag"],
        .nationalLab: ["natlab_ornl", "natlab_bnl", "fr_esrf"],
        .science: ["lab_materials", "lab_biology", "lab_automation", "lab_chemistry", "lab_physics", "lab_electronics", "lab_tem", "lab_spectro"],
        .finance: ["stock_exchange", "fin_cbot"],
        .compute: ["supercomputer", "gpu_cluster", "hpc_summit", "hpc_frontier", "dc_liquid"],
        .network: ["network", "fiber", "dc_servers"],
        .events: ["event_hall", "event_auditorium"],
        .hackathon: ["event_hackathon", "event_hackathon2"],
        .robotics: ["lab_robotics", "robot_factory", "robot_humanoid"],
        .city: ["sf_skyline", "city_tokyo", "city_nyc", "city_singapore", "city_seoul", "city_london"],
        // Second wave
        .aerospace: ["space_cleanroom", "space_mirror", "space_chamber", "space_antenna"],
        .missionControl: ["space_mission_control", "space_apollo_control"],
        .quantum: ["quantum_ibm", "quantum_fridge", "quantum_cryostat"],
        .cryogenics: ["cryo_lab", "quantum_fridge"],
        .instruments: ["lab_tem", "lab_spectro", "lab_materials"],
        .packaging: ["chip_chiplets", "chip_hbm", "chip_dieshot"],
        .chipTest: ["chip_test", "lab_electronics"],
        .controlRoom: ["hpc_control", "grid_control", "space_mission_control"],
        .liquidCooling: ["dc_liquid", "immersion"],
        .industrialCooling: ["industrial_cooling", "dc_cooling_tower", "chiller"],
        .university: ["dk_sdu_odense", "dk_aarhus_uni", "dk_dtu", "ro_univ_bucharest", "ro_ubb_cluj", "fr_minatec", "it_robot_lab"],
        .boardroom: ["biz_boardroom"],
        .exhibition: ["biz_expo", "event_hall"],
    ]

    /// Extra photos of each HQ city (keyed by `HQCity.id`), so a city screen or a local story can
    /// show its research site or business district, not only the skyline. The skyline photo the
    /// catalog names stays first.
    static let cityGallery: [String: [String]] = [
        "paris": ["hq_paris", "city_la_defense"],
        "grenoble": ["hq_grenoble", "fr_grenoble_science", "fr_minatec", "fr_esrf"],
        "odense": ["hq_odense", "dk_sdu_odense", "dk_odense_robotics"],
        "aarhus": ["hq_aarhus", "dk_aarhus_uni"],
        "copenhagen": ["hq_copenhagen", "dk_dtu"],
        "bucharest": ["hq_bucharest", "ro_univ_bucharest"],
        "cluj": ["hq_cluj", "ro_ubb_cluj"],
        "turin": ["hq_turin", "it_turin_lingotto"],
        "milan": ["hq_milan"],
        "rome": ["hq_rome"],
        "lyon": ["hq_lyon"],
        "aalborg": ["hq_aalborg"],
    ]

    /// A university or public research photo for each country (keyed by `Country.id`).
    static let universityByCountry: [String: [String]] = [
        "dk": ["dk_sdu_odense", "dk_aarhus_uni", "dk_dtu"],
        "ro": ["ro_univ_bucharest", "ro_ubb_cluj"],
        "it": ["it_robot_lab"],
        "fr": ["fr_grenoble_science", "fr_minatec", "fr_esrf"],
    ]

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
        (.robotics, ["robot", "robots", "robotic", "robotics", "robotaxi", "humanoid", "humanoids", "embodied"]),
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
        (.fab, ["fab", "fabs", "foundry", "foundries", "wafer", "wafers", "lithography", "euv", "tsmc"]),
        (.nationalLab, ["national lab", "national laboratory", "doe", "genesis mission"]),
        (.government, ["senate", "congress", "parliament", "regulation", "regulators", "regulator", "lawmakers", "law", "bill",
                       "act", "executive order", "white house", "ministry", "minister", "government", "ban", "bans", "export controls",
                       "sanctions", "treaty", "hearing", "commission"]),
        (.finance, ["ipo", "shares", "stock", "stocks", "valuation", "investors", "earnings", "market cap", "bond", "bonds",
                    "crash", "rally", "funding round", "acquires", "acquisition", "merger", "nasdaq", "dividend"]),
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
        return set
    }()

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
