import Foundation

/// 3.9: the world map's memory — where you've been, the expansion milestones it shows on its timeline, and when you
/// last looked (pins newer than that get a "New" tag). Everything else on the map is read live from the game.
/// Older saves record their existing footprint silently at their first month end (`WorldMap.monthly`).
struct WorldMapState: Codable, Hashable, DefaultValue {
    static var defaultValue: WorldMapState { WorldMapState() }

    /// The footprint has been recorded once (so an old save's existing sites don't all announce themselves).
    @D var seeded: Bool = false
    /// Continents with one of your open datacenters, and with one of your offices.
    @D var siteContinents: Set<String> = []
    @D var officeContinents: Set<String> = []
    /// Datacenter locations (LocationCatalog IDs) and office cities you've opened in.
    @D var places: Set<String> = []
    /// Your expansion, newest first (capped at 60).
    @D var log: [MapMilestone] = []
    /// When you last left the map screen.
    @D var lastLook: Date? = nil
}

/// One step of your expansion, with where it happened so the map can fly to it.
struct MapMilestone: Codable, Hashable, Identifiable {
    var date: Date
    var text: String
    var lon: Double
    var lat: Double
    /// "site", "office", "continent", "fab" or "alien".
    var kind: String

    /// Not stored: milestones draw no IDs, so recording them can't shift anything else's.
    var id: String { "\(kind)|\(text)|\(Int(date.timeIntervalSince1970))" }
}
