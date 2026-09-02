import Foundation

/// Finder 快捷路径的展示排序。
/// 数字绑定仍由原数组位置决定；这里只返回推荐的视觉顺序。
public enum FinderQuickPathRanking {
    public struct Ranked: Equatable, Sendable {
        /// 固定数字槽位：数组第 0 项永远绑定数字 1，以此类推。
        public let slot: Int
        public let item: FinderQuickPath

        public init(slot: Int, item: FinderQuickPath) {
            self.slot = slot
            self.item = item
        }
    }

    /// 最近使用优先；最近时间相同再按累计使用次数；都相同则保持固定数字槽位顺序。
    /// 这样排序结果可预测，同时能让经常使用的目录自然靠前。
    public static func ranked(_ items: [FinderQuickPath]) -> [Ranked] {
        items.prefix(9).enumerated().map { Ranked(slot: $0.offset + 1, item: $0.element) }
            .sorted { lhs, rhs in
                if lhs.item.lastUsedAt != rhs.item.lastUsedAt {
                    return lhs.item.lastUsedAt > rhs.item.lastUsedAt
                }
                if lhs.item.useCount != rhs.item.useCount {
                    return lhs.item.useCount > rhs.item.useCount
                }
                return lhs.slot < rhs.slot
            }
    }
}
