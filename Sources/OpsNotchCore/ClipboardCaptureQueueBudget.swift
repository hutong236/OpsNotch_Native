/// Backpressure for clipboard snapshots retained in memory while asynchronous
/// normalization and managed-file persistence are pending.
///
/// This is an admission policy, not an item-size limit: one large clipboard
/// value can be accepted when the queue is empty. After that, no additional
/// pasteboard payloads are read until the backlog falls below the budget.
/// NSPasteboard has no event log, so the newest clipboard value will be retried
/// when capacity returns; intermediate changes under overload are not recoverable.
public enum ClipboardCaptureQueueBudget {
    public static let maximumBufferedBytes = 48 * 1024 * 1024
    public static let maximumOutstandingItems = 48

    public static func shouldReadNextChange(
        outstandingItemCount: Int,
        outstandingByteCount: Int
    ) -> Bool {
        // Always admit a single snapshot, including a very large image, when
        // there is no earlier work. Otherwise enforce both budget dimensions.
        guard outstandingItemCount > 0 else { return true }
        return outstandingItemCount < maximumOutstandingItems
            && outstandingByteCount < maximumBufferedBytes
    }
}
