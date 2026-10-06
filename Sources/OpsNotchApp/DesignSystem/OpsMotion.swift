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

    static func duration(_ token: Token) -> TimeInterval {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.01 : token.baseDuration
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
