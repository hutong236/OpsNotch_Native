public enum ShelfSectionKind: CaseIterable, Equatable, Hashable, Sendable {
    case context
    case now
    case favorites
    case recent
    case results
}

public enum ShelfSectionModel {
    public static func visibleSections(itemCounts: [ShelfSectionKind: Int]) -> [ShelfSectionKind] {
        ShelfSectionKind.allCases.filter { (itemCounts[$0] ?? 0) > 0 }
    }
}
