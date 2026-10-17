import XCTest

@testable import Memora

final class DraftTests: XCTestCase {
  @MainActor func testSavedEditsRestoreWithoutExporting() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let source = try TestFixtures.image(.jpeg, ext: "JPG", folder: folder)
    let sourceData = try Data(contentsOf: source)
    let store = DraftStore(url: folder.appendingPathComponent("drafts.json"))
    let library = Library(drafts: store)
    func loaded(_ model: Library) async throws {
      for _ in 0..<200 {
        if !model.busy { return }
        try await Task.sleep(nanoseconds: 10_000_000)
      }
      XCTFail("Image did not load")
    }
    library.select(source)
    try await loaded(library)
    library.editValue("XMP-dc:Title", "记忆草稿")
    library.exportName = "custom-name"
    library.removeGPS = true
    library.saveDraft()
    XCTAssertFalse(library.dirty)
    XCTAssertEqual(try Data(contentsOf: source), sourceData)
    XCTAssertFalse(
      FileManager.default.fileExists(atPath: folder.appendingPathComponent("custom-name.JPG").path))
    let reopened = Library(drafts: store)
    reopened.select(source)
    try await loaded(reopened)
    XCTAssertEqual(reopened.values["XMP-dc:Title"], "记忆草稿")
    XCTAssertNotEqual(reopened.original["XMP-dc:Title"], "记忆草稿")
    XCTAssertEqual(reopened.exportName, "custom-name")
    XCTAssertTrue(reopened.removeGPS)
    XCTAssertFalse(reopened.dirty)
    XCTAssertTrue(reopened.hasEdits)
    reopened.reset()
    XCTAssertFalse(reopened.hasEdits)
    XCTAssertTrue(reopened.dirty)
    reopened.editValue("XMP-dc:Title", "下一次修改")
    XCTAssertTrue(reopened.dirty)
    XCTAssertNil(try store.load(for: folder.appendingPathComponent("other.JPG")))
  }
}
