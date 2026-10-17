import AppKit
import XCTest

@testable import Memora

final class XMPRegressionTests: XCTestCase {
  func testDirectSaveUsesEditedAuthorsAndDates() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let source = try TestFixtures.image(.jpeg, ext: "JPG", folder: folder)
    let first = (1...10).map { "<rdf:li>作者\($0)</rdf:li>" }.joined()
    let second = (11...20).map { "<rdf:li>作者\($0)</rdf:li>" }.joined()
    let packet = """
      <x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"><rdf:Description rdf:about="" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:xmp="http://ns.adobe.com/xap/1.0/" xmlns:mem="https://example.com/memory/">
      <dc:creator><rdf:Seq>\(first)</rdf:Seq></dc:creator>
      <dc:creator><rdf:Seq>\(second)</rdf:Seq></dc:creator>
      <xmp:CreateDate>2000-01-01T00:00:00Z</xmp:CreateDate>
      <mem:Note>preserve-unrelated-custom-property</mem:Note>
      </rdf:Description></rdf:RDF></x:xmpmeta>
      """
    let xml = folder.appendingPathComponent("duplicate.xmp")
    try Data(packet.utf8).write(to: xml)
    let engine = MetadataEngine()
    _ = try await engine.run(["-overwrite_original", "-XMP<=\(xml.path)", source.path])
    let original = try Data(contentsOf: source)
    let target = folder.appendingPathComponent("saved.JPG")
    let date = "2026:08:21 01:42:19"
    try await engine.save(
      source: source, destination: target,
      changes: [
        "XMP-dc:Creator": (1...20).map { "作者\($0)" }.joined(separator: "\n"),
        "ExifIFD:DateTimeOriginal": date, "ExifIFD:OffsetTimeOriginal": "+10:00",
        "XMP-xmp:CreateDate": date, "XMP-xmp:ModifyDate": date, "System:FileCreateDate": date,
        "System:FileModifyDate": date,
      ], removeGPS: false)
    let rows = try await engine.read(target)
    XCTAssertEqual(
      rows.first { $0.key == "XMP-dc:Creator" }?.value,
      (1...20).map { "作者\($0)" }.joined(separator: "\n"))
    XCTAssertEqual(rows.first { $0.key == "XMP-xmp:CreateDate" }?.value, date)
    XCTAssertEqual(rows.first { $0.key == "System:FileCreateDate" }?.value, date)
    let savedPacket = try await engine.run(["-b", "-XMP", target.path])
    XCTAssertTrue(
      String(data: savedPacket, encoding: .utf8)!.contains("preserve-unrelated-custom-property"))
    XCTAssertEqual(original, try Data(contentsOf: source))
    let before = try await engine.digest(source)
    let after = try await engine.digest(target)
    XCTAssertEqual(before, after)
  }

}
