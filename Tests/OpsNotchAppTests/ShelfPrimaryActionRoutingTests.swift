#if os(macOS)
import XCTest
import OpsNotchCore
@testable import OpsNotchApp

final class ShelfPrimaryActionRoutingTests: XCTestCase {
    func testFilePrimaryPreservesFilePayloadRatherThanOpening() async {
        await MainActor.run {
            let file = ShelfItem(kind: .file, title: "Report", content: "/tmp/report.pdf")
            let presentation = ShelfPresentationAdapter.adapt(file, language: .enUS)
            XCTAssertEqual(presentation.primaryAction.intent, .copyShelfItem(file.id))
            XCTAssertEqual(ShelfLogic.copyPayload(items: [file]).filePaths, [file.content])
        }
    }

}
#endif
