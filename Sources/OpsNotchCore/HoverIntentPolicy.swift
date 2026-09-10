public struct HoverIntentPoint: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct HoverIntentPolicy: Equatable, Sendable {
    public let entryEdgeTolerance: Double
    public let sideEntryExclusion: Double
    public let maxTravel: Double

    public init(
        entryEdgeTolerance: Double = 4,
        sideEntryExclusion: Double = 8,
        maxTravel: Double = 6
    ) {
        self.entryEdgeTolerance = entryEdgeTolerance
        self.sideEntryExclusion = sideEntryExclusion
        self.maxTravel = maxTravel
    }

    /// Hover intent must enter through the lower edge of the activation strip.
    /// Entering from either side is treated as ordinary menu-bar traversal and rejected.
    public func acceptsEntry(
        _ point: HoverIntentPoint,
        activationWidth: Double,
        activationHeight: Double
    ) -> Bool {
        guard activationWidth > 0, activationHeight > 0 else { return false }
        guard point.x >= 0, point.x <= activationWidth,
              point.y >= 0, point.y <= activationHeight else { return false }

        let bottomEdgeLimit = min(max(0, entryEdgeTolerance), activationHeight)
        let horizontalInset = min(max(0, sideEntryExclusion), activationWidth / 2)
        return point.y <= bottomEdgeLimit
            && point.x > horizontalInset
            && point.x < activationWidth - horizontalInset
    }

    /// Once a valid entry is recognized, meaningful pointer movement cancels the dwell.
    public func remainsStable(from start: HoverIntentPoint, to current: HoverIntentPoint) -> Bool {
        let dx = current.x - start.x
        let dy = current.y - start.y
        return (dx * dx + dy * dy) <= maxTravel * maxTravel
    }
}
