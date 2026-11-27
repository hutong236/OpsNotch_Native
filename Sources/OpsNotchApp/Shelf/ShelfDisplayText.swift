#if os(macOS)
import Foundation

/// Limit summary rendering work independently of the original stored content.
/// Bound Unicode scalars rather than Characters: a single extended grapheme
/// cluster can contain an arbitrarily large number of combining scalars.
enum ShelfDisplayText {
    static func bounded(_ text: String, limit: Int = 512) -> String {
        precondition(limit > 0)
        let scalars = text.unicodeScalars
        guard let end = scalars.index(scalars.startIndex, offsetBy: limit, limitedBy: scalars.endIndex),
              end != scalars.endIndex else { return text }
        return String(scalars[..<end]) + "…"
    }
}
#endif
