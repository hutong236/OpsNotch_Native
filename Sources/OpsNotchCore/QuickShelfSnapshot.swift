import Foundation

/// Stores one derived value per caller-managed revision. The caller decides which
/// state mutations invalidate the snapshot, so repeated UI reads stay O(1).
public final class QuickShelfSnapshotCache<Value> {
    private var cachedRevision: UInt64?
    private var cachedValue: Value?

    public init() {}

    public func value(for revision: UInt64, build: () -> Value) -> Value {
        if cachedRevision == revision, let cachedValue {
            return cachedValue
        }

        let value = build()
        cachedRevision = revision
        cachedValue = value
        return value
    }

    public func removeAll() {
        cachedRevision = nil
        cachedValue = nil
    }
}

/// Ranked ShelfItem partitions shared by Quick Shelf rendering, keyboard navigation,
/// selection and highlighted-item lookup.
public struct QuickShelfItemSnapshot: Equatable, Sendable {
    public let working: [ShelfItem]
    public let pinned: [ShelfItem]
    public let recent: [ShelfItem]
    public let visibleItems: [ShelfItem]

    public init(working: [ShelfItem], pinned: [ShelfItem], recent: [ShelfItem]) {
        self.working = working
        self.pinned = pinned
        self.recent = recent
        self.visibleItems = working + pinned + recent
    }
}

public enum QuickShelfItemSnapshotBuilder {
    public static func build(
        items: [ShelfItem],
        workingSetItemIDs: [UUID],
        query: String,
        kindFilter: ShelfKindFilter,
        appContext: AppContextKind,
        now: UInt64 = ShelfClock.now(),
        searchScope: CommandSearchScope? = nil
    ) -> QuickShelfItemSnapshot {
        let scope = searchScope ?? CommandSearchScope(query: query, kindFilter: kindFilter)
        let items = items.filter { scope.includes($0) }
        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let orderedByWorkingSet = workingSetItemIDs.compactMap { byID[$0] }
        let workingIDs = Set(workingSetItemIDs)
        let remaining = items.filter { !workingIDs.contains($0.id) }

        let working = SmartShelfRanking.ordered(
            orderedByWorkingSet,
            query: scope.query,
            kindFilter: scope.kindFilter,
            appContext: appContext,
            now: now
        )
        let pinned = SmartShelfRanking.ordered(
            remaining.filter(\.pinned),
            query: scope.query,
            kindFilter: scope.kindFilter,
            appContext: appContext,
            now: now
        )
        let recent = SmartShelfRanking.ordered(
            remaining.filter { !$0.pinned },
            query: scope.query,
            kindFilter: scope.kindFilter,
            appContext: appContext,
            now: now
        )

        return QuickShelfItemSnapshot(
            working: working,
            pinned: pinned,
            recent: recent
        )
    }
}
