import Foundation

/// Requires stable, exclusive Space ownership and valid display placement.
/// A transient dual-Space membership must never authorize a follow operation.
public struct WindowMoveConfirmation {
    public let targetSpaceID: UInt64
    private var stableSamples = 0

    public init(targetSpaceID: UInt64) { self.targetSpaceID = targetSpaceID }

    public mutating func observe(spaceIDs: Set<UInt64>, isOnTargetDisplay: Bool) -> Bool {
        stableSamples = spaceIDs == [targetSpaceID] && isOnTargetDisplay ? stableSamples + 1 : 0
        return stableSamples >= 3
    }
}
