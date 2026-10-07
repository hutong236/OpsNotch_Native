#if os(macOS)
import AppKit
import Foundation
import SwiftUI

enum OpsMotion {
    enum Token {
        case instant
        case quick
        case standard
        case expressive

        fileprivate var baseDuration: TimeInterval {
            switch self {
            case .instant: return 0.10
            case .quick: return 0.15
            case .standard: return 0.22
            case .expressive: return 0.31
            }
        }
    }

    /// Minimal fades remain available when the system requests reduced motion.
    static func duration(
        for token: Token,
        reduceMotion: Bool = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    ) -> TimeInterval {
        reduceMotion ? 0.01 : token.baseDuration
    }

    /// AppKit callers must skip positional/scale interpolation when this is zero.
    static func spatialDuration(
        for token: Token,
        reduceMotion: Bool = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    ) -> TimeInterval {
        reduceMotion ? 0 : token.baseDuration
    }

    /// Reduce Motion removes the scale transform entirely, retaining only a fade.
    static func transition(
        reduceMotion: Bool = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    ) -> AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98))
    }

    // Compatibility for existing consumers during incremental migration.
    static func duration(_ token: Token) -> TimeInterval {
        duration(for: token)
    }

    static func animation(_ token: Token) -> Animation {
        .easeOut(duration: duration(token))
    }

    static var instant: Animation { animation(.instant) }
    static var quick: Animation { animation(.quick) }
    static var standard: Animation { animation(.standard) }
    static var expressive: Animation { animation(.expressive) }
}
#endif
