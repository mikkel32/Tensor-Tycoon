import Foundation

extension GameState {
    /// 3.8: free chips for a job that needs `needing`, recalling leased-out chips of the same type when idle ones
    /// aren't enough (leases used to block work with nothing saying why). Returns the free count afterwards.
    @discardableResult
    mutating func recallLeased(_ accelID: String, needing: Int) -> Int {
        let free = Economy.freeChips(self, accelID)
        let leased = leases[accelID] ?? 0
        guard needing > free, leased > 0, free + leased >= needing else { return free }
        let back = needing - free
        leases[accelID] = leased - back > 0 ? leased - back : nil
        let name = HardwareCatalog.get(accelID)?.name ?? "chips"
        Sim.news(&self, "Recalled \(Fmt.int(back))× \(name) from lease", "Your next job needed them, so they came off the rental market and are yours again.", .company)
        return Economy.freeChips(self, accelID)
    }

    /// " N are leased out." when recalling would help, for "only X free" errors.
    func leasedNote(_ accelID: String) -> String {
        let n = leases[accelID] ?? 0
        return n > 0 ? " \(Fmt.int(n)) are leased out (Chip Sales > Leasing)." : ""
    }
}
