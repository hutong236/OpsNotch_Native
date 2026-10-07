import XCTest
@testable import OpsNotchCore

final class ShelfUnknownFieldCompatibilityTests: XCTestCase {
    private let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private let payload = #"{"null":null,"yes":true,"no":false,"zero":0,"one":1,"large":9007199254740993,"minimum":-9223372036854775808,"maximum":18446744073709551615,"fraction":-12.125,"exponent":1.25e3,"nested":["future",null,true,{"value":9007199254740993}]}"#

    func testEveryObjectRoundTripsFlatUnknownFieldsAndExactNumbers() throws {
        let original = fixture()
        let store = try JSONDecoder().decode(ShelfStore.self, from: original)
        let encoded = try JSONEncoder().encode(store)
        try assertAllMetadata(encoded)
        let object = try jsonObject(encoded)
        XCTAssertEqual(Set(object.keys), Set(["version", "items", "settings", "future"]))
        let future = try XCTUnwrap(object["future"] as? [String: Any])
        XCTAssertTrue(future["null"] is NSNull)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("unknownFields"))
        XCTAssertEqual(try JSONDecoder().decode(ShelfStore.self, from: encoded), store)
    }

    func testServiceReadDoesNotWriteAndSaveAndMutationPreserveMetadata() throws {
        try withService(fixture()) { service in
            let before = try Data(contentsOf: service.storeURL)
            var store = try service.load()
            XCTAssertEqual(try Data(contentsOf: service.storeURL), before)
            store.settings.language = .enUS
            _ = try service.save(store)
            _ = try service.edit(id: firstID, title: "Edited")
            let disk = try Data(contentsOf: service.storeURL)
            try assertAllMetadata(disk)
            let reloaded = try service.load()
            XCTAssertEqual(reloaded.items[0].title, "Edited")
            XCTAssertEqual(reloaded.settings.language, .enUS)
        }
    }

    func testClearedKnownOptionalsAndDeletedItemsDoNotReturn() throws {
        try withService(fixture(items: [item(firstID), item(secondID)])) { service in
            var store = try service.load()
            store.settings.hotkey = nil
            store.settings.finderRevealHotkey = nil
            store.items.reverse()
            store.items[1].storageMode = nil
            store.items[1].actionKind = nil
            store.items[1].fileExtension = nil
            store.items[1].sourceAppName = nil
            _ = try service.save(store)
            _ = try service.remove(ids: [secondID])
            let disk = try Data(contentsOf: service.storeURL)
            let object = try jsonObject(disk)
            let settings = try XCTUnwrap(object["settings"] as? [String: Any])
            XCTAssertNil(settings["hotkey"])
            XCTAssertNil(settings["finder_reveal_hotkey"])
            let items = try XCTUnwrap(object["items"] as? [[String: Any]])
            XCTAssertEqual(items.count, 1)
            for key in ["storage_mode", "action_kind", "extension", "source_app_name"] {
                XCTAssertNil(items[0][key], key)
            }
            let probe = try JSONDecoder().decode(StoreProbe.self, from: disk)
            XCTAssertEqual(probe.items.map(\.id), [firstID])
            try assertPayload(probe.items[0].future)
            try assertPayload(probe.future)
            try assertPayload(probe.settings.future)
        }
    }

    func testLegacyArrayMigrationRetainsUnknownItemFieldsAndIDs() throws {
        let data = Data("[\(item(firstID, kind: "ip")),\(item(secondID, kind: "command"))]".utf8)
        try withService(data) { service in
            let store = try service.load()
            XCTAssertEqual(store.version, ShelfStore.currentVersion)
            XCTAssertEqual(store.items.map(\.id), [firstID, secondID])
            XCTAssertEqual(store.items.map(\.kind), [.text, .text])
            let object = try jsonObject(Data(contentsOf: service.storeURL))
            let items = try XCTUnwrap(object["items"] as? [[String: Any]])
            XCTAssertEqual(items.count, 2)
            for value in items { XCTAssertNotNil(value["future"]) }
        }
    }

    func testVersionMigrationAndTTLDropOnlyExpiredMetadata() throws {
        let expired = item(secondID, pinned: false, timestamp: 1)
        try withService(fixture(items: [item(firstID), expired], version: 5, ttl: 1)) { service in
            let store = try service.load()
            XCTAssertEqual(store.items.map(\.id), [firstID])
            XCTAssertEqual(store.settings.displayTarget, .all)
            let disk = try Data(contentsOf: service.storeURL)
            try assertAllMetadata(disk)
            XCTAssertEqual(try JSONDecoder().decode(StoreProbe.self, from: disk).items.count, 1)
        }
    }

    func testEvictionDoesNotRestoreRemovedMetadata() throws {
        let items = (1...501).map { index in
            item(UUID(uuidString: String(format: "00000000-0000-0000-0000-%012X", index))!, pinned: false, timestamp: UInt64(index))
        }
        try withService(fixture(items: items)) { service in
            // Save enforces the cap; load keeps TTL disabled for this fixture.
            _ = try service.save(service.load())
            let disk = try Data(contentsOf: service.storeURL)
            let probe = try JSONDecoder().decode(StoreProbe.self, from: disk)
            XCTAssertEqual(probe.items.count, ShelfStoreService.maxItems)
            XCTAssertFalse(probe.items.contains { $0.id == firstID })
            XCTAssertEqual(probe.items.first?.id, secondID)
            try assertPayload(try XCTUnwrap(probe.items.first).future)
            try assertPayload(probe.future)
        }
    }

    func testQuickPathTruncationAndWorkingSetNormalizationKeepSurvivorMetadata() throws {
        let paths = (1...11).map { index in
            #"{"id":"00000000-0000-0000-0000-\#(String(format: "%012X", index))","label":"Folder","path":"~","future":\#(payload)}"#
        }.joined(separator: ",")
        let ids = [firstID, firstID, secondID].map { "\"\($0.uuidString)\"" }.joined(separator: ",")
        try withService(fixture(paths: paths, workingSet: ids)) { service in
            _ = try service.save(service.load())
            let store = try service.load()
            XCTAssertEqual(store.settings.finderQuickPaths.count, 9)
            XCTAssertEqual(store.settings.workingSetItemIDs, [firstID])
            let probe = try JSONDecoder().decode(StoreProbe.self, from: Data(contentsOf: service.storeURL))
            XCTAssertEqual(probe.settings.finder_quick_paths.count, 9)
            for path in probe.settings.finder_quick_paths { try assertPayload(path.future) }
        }
    }

    func testUnsupportedUnknownNumberFailsWithoutReplacingOriginalData() throws {
        // Valid JSON, but beyond Decimal's representable exponent range.
        // Exercise nested failures as well as the root so fallback decoding cannot hide loss.
        let objects = [
            #"{"future":1e200}"#,
            #"{"settings":{"future":1e200}}"#,
            #"{"items":[{"future":1e200}]}"#,
            #"{"settings":{"hotkey":{"keyCode":40,"carbonModifiers":256,"future":1e200}}}"#,
            #"{"settings":{"finder_reveal_hotkey":{"keyCode":40,"carbonModifiers":256,"future":1e200}}}"#,
            #"{"settings":{"finder_quick_paths":[{"future":1e200}]}}"#,
            #"[{"kind":"command","future":1e200}]"#
        ]
        for json in objects {
            let original = Data(json.utf8)
            try withService(original) { service in
                XCTAssertThrowsError(try service.load(), json)
                XCTAssertEqual(try Data(contentsOf: service.storeURL), original)
                XCTAssertThrowsError(try service.addText("Must not overwrite"), json)
                XCTAssertEqual(try Data(contentsOf: service.storeURL), original)
            }
        }
    }

    private func item(_ id: UUID, kind: String = "text", pinned: Bool = true, timestamp: UInt64 = 100) -> String {
        #"{"id":"\#(id.uuidString)","kind":"\#(kind)","title":"Original","content":"legacy content","pinned":\#(pinned),"created_at":\#(timestamp),"updated_at":\#(timestamp),"storage_mode":"reference","action_kind":"open_path","extension":"txt","source_app_name":"Example","future":\#(payload)}"#
    }

    private func fixture(items: [String]? = nil, version: Int = ShelfStore.currentVersion, ttl: Int = 0, paths: String? = nil, workingSet: String = "") -> Data {
        let path = paths ?? #"{"id":"\#(firstID.uuidString)","label":"Folder","path":"~","use_count":18446744073709551615,"future":\#(payload)}"#
        let shortcut = #"{"keyCode":40,"carbonModifiers":256,"future":\#(payload)}"#
        return Data(#"{"version":\#(version),"future":\#(payload),"items":[\#((items ?? [item(firstID)]).joined(separator: ","))],"settings":{"temp_ttl_hours":\#(ttl),"display_target":"mouse","hotkey":\#(shortcut),"finder_reveal_hotkey":\#(shortcut),"finder_quick_paths":[\#(path)],"working_set_item_ids":[\#(workingSet)],"future":\#(payload)}}"#.utf8)
    }

    private func withService(_ data: Data, body: (ShelfStoreService) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let service = ShelfStoreService(rootURL: root)
        try data.write(to: service.storeURL)
        try body(service)
    }

    private func jsonObject(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func assertAllMetadata(_ data: Data) throws {
        let probe = try JSONDecoder().decode(StoreProbe.self, from: data)
        try assertPayload(probe.future)
        try assertPayload(probe.settings.future)
        for item in probe.items { try assertPayload(item.future) }
        for path in probe.settings.finder_quick_paths { try assertPayload(path.future) }
        try assertPayload(try XCTUnwrap(probe.settings.hotkey).future)
        try assertPayload(try XCTUnwrap(probe.settings.finder_reveal_hotkey).future)
    }

    private func assertPayload(_ actual: Payload) throws {
        XCTAssertEqual(actual, try JSONDecoder().decode(Payload.self, from: Data(payload.utf8)))
        XCTAssertEqual(actual.large, 9_007_199_254_740_993)
        XCTAssertEqual(actual.minimum, Int64.min)
        XCTAssertEqual(actual.maximum, UInt64.max)
        XCTAssertTrue(actual.yes)
        XCTAssertFalse(actual.no)
    }

    // Independent typed probes avoid floating-point/NSNumber conversion in numeric assertions.
    private struct Payload: Decodable, Equatable {
        let null: String?
        let yes: Bool
        let no: Bool
        let zero: Int64
        let one: Int64
        let large: Int64
        let minimum: Int64
        let maximum: UInt64
        let fraction: Decimal
        let exponent: Decimal
        let nested: [Atom]
        enum Atom: Decodable, Equatable {
            case null, bool(Bool), string(String), object([String: Int64])
            init(from decoder: Decoder) throws {
                let value = try decoder.singleValueContainer()
                if value.decodeNil() { self = .null }
                else if let bool = try? value.decode(Bool.self) { self = .bool(bool) }
                else if let string = try? value.decode(String.self) { self = .string(string) }
                else { self = .object(try value.decode([String: Int64].self)) }
            }
        }
    }
    private struct MetadataProbe: Decodable { let future: Payload }
    private struct ItemProbe: Decodable { let id: UUID; let future: Payload }
    private struct SettingsProbe: Decodable {
        let future: Payload
        let finder_quick_paths: [MetadataProbe]
        let hotkey: MetadataProbe?
        let finder_reveal_hotkey: MetadataProbe?
    }
    private struct StoreProbe: Decodable {
        let future: Payload
        let items: [ItemProbe]
        let settings: SettingsProbe
    }
}
