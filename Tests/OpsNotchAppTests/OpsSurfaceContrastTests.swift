#if os(macOS)
import XCTest
@testable import OpsNotchApp

final class OpsSurfaceContrastTests: XCTestCase {
    func testIncreasedContrastStrengthensStructuralSurfaceMetrics() {
        XCTAssertGreaterThan(
            OpsSurface.panelStrokeOpacity(increasedContrast: true),
            OpsSurface.panelStrokeOpacity(increasedContrast: false)
        )
        XCTAssertGreaterThan(
            OpsSurface.focusStrokeOpacity(increasedContrast: true),
            OpsSurface.focusStrokeOpacity(increasedContrast: false)
        )
        XCTAssertGreaterThan(
            OpsSurface.selectedOpacity(increasedContrast: true),
            OpsSurface.selectedOpacity(increasedContrast: false)
        )
        XCTAssertGreaterThan(
            OpsSurface.dropTargetStrokeOpacity(increasedContrast: true),
            OpsSurface.dropTargetStrokeOpacity(increasedContrast: false)
        )
        XCTAssertGreaterThan(
            OpsSurface.settingsCardOpacity(increasedContrast: true),
            OpsSurface.settingsCardOpacity(increasedContrast: false)
        )
    }
}
#endif
