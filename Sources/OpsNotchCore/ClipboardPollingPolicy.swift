public enum ClipboardPollingPolicy {
    public struct Schedule: Equatable, Sendable {
        public let intervalMilliseconds: Int
        public let toleranceMilliseconds: Int

        public init(intervalMilliseconds: Int, toleranceMilliseconds: Int) {
            self.intervalMilliseconds = intervalMilliseconds
            self.toleranceMilliseconds = toleranceMilliseconds
        }
    }

    /// Keep the existing capture cadence so rapid consecutive copies are not made easier
    /// to miss, while giving the system explicit timer tolerance to coalesce wakeups.
    public static func schedule(panelVisible: Bool) -> Schedule {
        if panelVisible {
            return Schedule(intervalMilliseconds: 100, toleranceMilliseconds: 20)
        }
        return Schedule(intervalMilliseconds: 400, toleranceMilliseconds: 100)
    }
}
