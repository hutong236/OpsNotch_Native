import Foundation

// AX uses global points with the origin at the primary display's top left.
// NSScreen uses global points with the origin at its bottom left. Do not apply
// backingScaleFactor: a Retina pixel count is not an AX coordinate.
public enum WindowDisplayGeometry {
    public static func quartzRect(_ appKitRect: CGRect, primaryTop: CGFloat) -> CGRect {
        CGRect(x: appKitRect.minX, y: primaryTop - appKitRect.maxY,
               width: appKitRect.width, height: appKitRect.height)
    }

    public static func isUsable(_ rect: CGRect) -> Bool {
        [rect.origin.x, rect.origin.y, rect.size.width, rect.size.height].allSatisfy { $0.isFinite }
            && rect.size.width > 0 && rect.size.height > 0
    }

    public static func destinationFrame(window: CGRect, source: CGRect, destination: CGRect) -> CGRect? {
        guard isUsable(window), isUsable(source), isUsable(destination) else { return nil }
        let size = CGSize(width: min(window.width, destination.width),
                          height: min(window.height, destination.height))
        func fraction(_ offset: CGFloat, _ room: CGFloat) -> CGFloat {
            room > 0 ? min(1, max(0, offset / room)) : 0.5
        }
        let x = fraction(window.minX - source.minX, source.width - window.width)
        let y = fraction(window.minY - source.minY, source.height - window.height)
        return CGRect(x: destination.minX + x * (destination.width - size.width),
                      y: destination.minY + y * (destination.height - size.height),
                      width: size.width, height: size.height)
    }

    public static func contains(_ window: CGRect, in visibleFrame: CGRect) -> Bool {
        guard isUsable(window), isUsable(visibleFrame) else { return false }
        // Allow rounding by the AX server, but require the whole window to fit.
        return visibleFrame.insetBy(dx: -2, dy: -2).contains(window)
    }
}
