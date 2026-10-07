#if os(macOS)
import XCTest
@testable import OpsNotchApp

@MainActor
final class SettingsInformationArchitectureTests: XCTestCase {
    func testSettingsSidebarOrderIsStable() {
        XCTAssertEqual(
            OpsSettingsSection.allCases,
            [.general, .shelf, .clipboard, .finder, .workspace, .inputMethod, .shortcuts, .advanced]
        )
    }

    func testEverySettingsSectionHasLocalizedLabelsAndUniqueIcons() {
        let sections = OpsSettingsSection.allCases
        XCTAssertEqual(Set(sections.map(\.symbolName)).count, sections.count)

        for section in sections {
            let zh = L10n.text(section.localizationKey, .zhCN)
            let en = L10n.text(section.localizationKey, .enUS)
            XCTAssertNotEqual(zh, section.localizationKey)
            XCTAssertNotEqual(en, section.localizationKey)
            XCTAssertFalse(zh.isEmpty)
            XCTAssertFalse(en.isEmpty)
        }
    }
}
#endif
