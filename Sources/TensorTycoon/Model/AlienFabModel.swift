import Foundation

/// 3.5: your alien fab line. One line makes every alien chip you own the rights to: your own orders queue on it,
/// and whatever it has left over goes to merchant customers. You expand it with money; world supply rules for
/// merchant GPUs never apply to it.
struct AlienFabState: Codable, Hashable, DefaultValue {
    static var defaultValue: AlienFabState { AlienFabState() }

    /// Chips a month the line makes (0 until your first alien chip tapes out).
    @D var capacityMonth: Double = 0
    /// An expansion ramping up, and when it comes online.
    @D var pendingCapacity: Double = 0
    @D var pendingReady: Date? = nil
    /// When the line finishes everything you've ordered for yourself so far.
    @D var busyUntil: Date? = nil
    /// Chips the line has made, lifetime (your orders and merchant sales).
    @D var produced: Double = 0
    /// Volume milestones reached (each one is a yield discovery that cuts production cost).
    @D var yieldLevel: Int = 0
    @D var milestones: Set<String> = []
    /// When the pilot line opened.
    @D var opened: Date? = nil
    /// Older saves: merchant capacity reserved per alien chip has been folded into the line.
    @D var migrated: Bool = false

    var exists: Bool { capacityMonth > 0 || opened != nil }
}
