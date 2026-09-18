public enum QuickShelfHorizontalDirection: Sendable {
    case left
    case right
}

public enum QuickShelfKeyboardNavigation {
    /// 返回目标功能区的首个可见条目。功能区不可见或为空时返回 nil，
    /// 由调用方保持当前高亮，不跨区猜测其他候选。
    public static func destinationID(
        for direction: QuickShelfHorizontalDirection,
        finderEntryIDs: [String],
        recentEntryIDs: [String]
    ) -> String? {
        switch direction {
        case .left:
            return recentEntryIDs.first
        case .right:
            return finderEntryIDs.first
        }
    }
}
