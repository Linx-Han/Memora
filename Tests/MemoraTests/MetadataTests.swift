import AppKit
import XCTest

@testable import Memora

final class MetadataTests: XCTestCase {
  func testLosslessSaveAndGPSRemoval() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let engine = MetadataEngine()
    for (type, ext) in [(NSBitmapImageRep.FileType.jpeg, "jpg"), (.png, "png"), (.tiff, "tiff")] {
      let source = try TestFixtures.image(type, ext: ext, folder: folder)
      _ = try await engine.run([
        "-overwrite_original", "-GPSLatitude=31.2", "-GPSLatitudeRef=S", "-GPSLongitude=115.8",
        "-GPSLongitudeRef=E", source.path,
      ])
      let original = try Data(contentsOf: source)
      let target = folder.appendingPathComponent("编辑.\(ext)")
      let edits = [
        "XMP-dc:Title": "海边日落", "XMP-dc:Creator": "林", "XMP-xmp:Rating": "4",
        "ExifIFD:DateTimeOriginal": "2026:10:15 14:30:00",
      ]
      try await engine.save(source: source, destination: target, changes: edits, removeGPS: true)
      XCTAssertEqual(try Data(contentsOf: source), original)
      let before = try await engine.digest(source)
      let after = try await engine.digest(target)
      XCTAssertEqual(before, after)
      let rows = try await engine.read(target)
      XCTAssertFalse(rows.contains { $0.group == "GPS" })
      XCTAssertEqual(rows.first { $0.key == "XMP-dc:Title" }?.value, "海边日落")
      // Existing destination replacement and clearing a field.
      try await engine.save(
        source: target, destination: folder.appendingPathComponent("clear.\(ext)"),
        changes: ["XMP-dc:Title": ""], removeGPS: false)
      try await engine.save(
        source: source, destination: target, changes: ["XMP-dc:Title": "第二次"], removeGPS: false)
      let replaced = try await engine.read(target)
      XCTAssertEqual(replaced.first { $0.key == "XMP-dc:Title" }?.value, "第二次")
    }
  }
  func testRejectsUnsafeSaveAndInvalidValues() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let source = try TestFixtures.image(.jpeg, ext: "jpg", folder: folder)
    let original = try Data(contentsOf: source)
    let engine = MetadataEngine()
    let target = folder.appendingPathComponent("output.jpg")
    for (destination, changes) in [
      (source, ["XMP-dc:Title": "bad"]), (target, ["XMP-xmp:Rating": "9"]),
      (target, ["ExifIFD:DateTimeOriginal": "2026:02:30 12:00:00"]),
      (target, ["FileName": "bad.jpg"]),
    ] {
      do {
        try await engine.save(
          source: source, destination: destination, changes: changes, removeGPS: false)
        XCTFail("Should reject")
      } catch {}
    }
    XCTAssertEqual(original, try Data(contentsOf: source))
    XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
  }
  func testExpandedMetadataAndFileTimes() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let engine = MetadataEngine()
    for (type, ext) in [(NSBitmapImageRep.FileType.jpeg, "jpg"), (.png, "png"), (.tiff, "tiff")] {
      let source = try TestFixtures.image(type, ext: ext, folder: folder)
      let original = try Data(contentsOf: source)
      let target = folder.appendingPathComponent("自定义名字.\(ext)")
      let edits = [
        "GPS:GPSLatitude": "31.9523", "GPS:GPSLatitudeRef": "S",
        "GPS:GPSLongitude": "115.8613", "GPS:GPSLongitudeRef": "E",
        "GPS:GPSAltitude": "25.5", "GPS:GPSAltitudeRef": "0",
        "XMP-photoshop:City": "珀斯", "XMP-photoshop:Country": "澳大利亚",
        "XMP-iptcCore:Location": "国王公园", "XMP-dc:Subject": "旅行\n城市\n风景",
        "XMP-dc:Creator": "作者甲\n作者乙",
        "ExifIFD:CreateDate": "2025:01:02 03:04:05", "IFD0:ModifyDate": "2025:02:03 04:05:06",
        "XMP-xmp:CreateDate": "2025:01:02 03:04:05+08:00",
        "System:FileCreateDate": "2024:01:02 03:04:05",
        "System:FileModifyDate": "2024:02:03 04:05:06",
        "ExifIFD:ISO": "200", "ExifIFD:ExposureTime": "0.008", "ExifIFD:FNumber": "2.8",
        "ExifIFD:LensModel": "RF 24–70mm", "ExifIFD:UserComment": "中文备注",
        "XMP-photoshop:Headline": "新增的高级标签",
      ]
      try await engine.save(source: source, destination: target, changes: edits, removeGPS: false)
      let rows = try await engine.read(target)
      for key in [
        "XMP-dc:Subject", "XMP-dc:Creator", "XMP-photoshop:City", "System:FileCreateDate",
        "System:FileModifyDate", "ExifIFD:UserComment",
      ] {
        XCTAssertEqual(rows.first { $0.key == key }?.value, edits[key], key)
      }
      XCTAssertEqual(try Data(contentsOf: source), original)
      // Date-only edits and replacing an existing destination must retain requested dates.
      try await engine.save(
        source: source, destination: target,
        changes: [
          "System:FileCreateDate": "2023:01:01 00:00:00",
          "System:FileModifyDate": "2023:02:01 00:00:00",
        ], removeGPS: false)
      let replaced = try await engine.read(target)
      XCTAssertEqual(
        replaced.first { $0.key == "System:FileCreateDate" }?.value, "2023:01:01 00:00:00")
      XCTAssertEqual(
        replaced.first { $0.key == "System:FileModifyDate" }?.value, "2023:02:01 00:00:00")
    }
  }

  func testCatalogAndLocationValidation() async throws {
    for field in EditField.common { XCTAssertTrue(TagCatalog.editable(field.id), field.id) }
    XCTAssertFalse(TagCatalog.editable("IFD0:ImageWidth"))
    XCTAssertFalse(TagCatalog.editable("System:FileName"))
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let source = try TestFixtures.image(.jpeg, ext: "jpg", folder: folder)
    let target = folder.appendingPathComponent("saved.jpg")
    let engine = MetadataEngine()
    let sentinel = Data("existing destination must survive".utf8)
    try sentinel.write(to: target)
    for (changes, remove) in [
      (["GPS:GPSLatitude": "91", "GPS:GPSLatitudeRef": "N"], false),
      (["GPS:GPSLongitude": "-181"], false),
      (["GPS:GPSLatitude": "10"], false),
      (["GPS:GPSLatitude": "10", "GPS:GPSLatitudeRef": "N"], true),
      (["System:FileCreateDate": ""], false),
      (["IFD0:ImageWidth": "20"], false),
      (["ExifIFD:ISO": "not a number"], false),
    ] {
      do {
        try await engine.save(
          source: source, destination: target, changes: changes, removeGPS: remove)
        XCTFail("Should reject \(changes)")
      } catch {}
      XCTAssertEqual(try Data(contentsOf: target), sentinel)
    }
  }

  func testMakerNotesWarningSavePreservesData() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let source = try TestFixtures.image(.jpeg, ext: "JPG", folder: folder)
    let notes = Data("UnknownCameraNotes".utf8) + Data(0..<64)
    let binary = folder.appendingPathComponent("notes.bin")
    try notes.write(to: binary)
    let engine = MetadataEngine()
    _ = try await engine.run([
      "-overwrite_original", "-Make=Unknown", "-MakerNotes<=\(binary.path)", source.path,
    ])
    let original = try Data(contentsOf: source)
    let requested = folder.appendingPathComponent("saved.png")
    // This write produces the exact minor warning reported by the user.
    try await engine.save(
      source: source, destination: requested,
      changes: ["ExifIFD:DateTimeOriginal": "2026:10:15 12:30:00"], removeGPS: false)
    let target = folder.appendingPathComponent("saved.JPG")
    XCTAssertFalse(FileManager.default.fileExists(atPath: requested.path))
    let rows = try await engine.read(target)
    XCTAssertEqual(
      rows.first { $0.key == "ExifIFD:DateTimeOriginal" }?.value, "2026:10:15 12:30:00")
    let savedNotes = try await engine.run(["-b", "-MakerNotes", target.path])
    XCTAssertEqual(savedNotes, notes)
    XCTAssertEqual(try Data(contentsOf: source), original)
    let before = try await engine.digest(source)
    let after = try await engine.digest(target)
    XCTAssertEqual(before, after)
  }

  func testXMPDateEquivalentFormats() {
    XCTAssertTrue(MetadataDate.equivalent("2026:10:15 14:30:00+08:00", "2026-10-15T14:30:00+0800"))
    XCTAssertTrue(MetadataDate.equivalent("2026:10:15 06:30:00Z", "2026-10-15T06:30:00+00:00"))
    XCTAssertTrue(MetadataDate.equivalent("2026:10:15 14:30:00.12", "2026-10-15 14:30:00.1200"))
    XCTAssertFalse(MetadataDate.equivalent("2026:10:15 14:30:00+08:00", "2026:10:15 14:30:00"))
    XCTAssertFalse(
      MetadataDate.equivalent("2026:10:15 14:30:00+08:00", "2026:10:15 14:30:00+09:00"))
    XCTAssertFalse(MetadataDate.equivalent("2026:10:15 14:30:01", "2026:10:15 14:30:00"))
    XCTAssertFalse(MetadataDate.equivalent("2026:10:15 14:30:00.12", "2026:10:15 14:30:00.13"))
    XCTAssertNil(MetadataDate.canonical("2026-02-30T12:00:00Z"))
  }

  func testXMPDateSaveAcceptsISOAndNormalizedInput() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let source = try TestFixtures.image(.jpeg, ext: "jpg", folder: folder)
    let original = try Data(contentsOf: source)
    let engine = MetadataEngine()
    let inputs = [
      "2026-10-15T14:30:00+08:00", "2026-10-15 14:30:00", "2026:10:15 14:30:00",
      "2026-10-15T06:30:00Z", "2026:10:15 14:30:00.1200+0800",
    ]
    for (index, input) in inputs.enumerated() {
      let target = folder.appendingPathComponent("saved-\(index).jpg")
      try await engine.save(
        source: source, destination: target,
        changes: ["XMP-xmp:CreateDate": input, "XMP-xmp:ModifyDate": input], removeGPS: false)
      let rows = try await engine.read(target)
      for key in ["XMP-xmp:CreateDate", "XMP-xmp:ModifyDate"] {
        XCTAssertTrue(
          MetadataDate.equivalent(rows.first { $0.key == key }?.value ?? "", input), input)
      }
    }
    XCTAssertEqual(try Data(contentsOf: source), original)
  }

  @MainActor func testDateEditorSynchronizesCreateDate() {
    let library = Library()
    library.values["XMP-xmp:CreateDate"] = "2000:01:01 00:00:00Z"
    library.editValue("ExifIFD:DateTimeOriginal", "2026:10:15 18:30:00")
    XCTAssertEqual(library.values["XMP-xmp:CreateDate"], "2026:10:15 18:30:00")
    library.editValue("XMP-xmp:CreateDate", "2026-10-16T09:30:00+08:00")
    XCTAssertEqual(library.values["XMP-xmp:CreateDate"], "2026-10-16T09:30:00+08:00")
    XCTAssertEqual(library.values["ExifIFD:DateTimeOriginal"], "2026:10:15 18:30:00")
  }

  func testDateEditorReplacesExistingXMPDate() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let engine = MetadataEngine()
    for (type, ext) in [(NSBitmapImageRep.FileType.jpeg, "jpg"), (.png, "png"), (.tiff, "tiff")] {
      let source = try TestFixtures.image(type, ext: ext, folder: folder)
      _ = try await engine.run([
        "-overwrite_original", "-XMP-xmp:CreateDate=2000:01:01 00:00:00Z", source.path,
      ])
      let original = try Data(contentsOf: source)
      let target = folder.appendingPathComponent("updated.\(ext)")
      let entered = "2026:10:15 18:30:00"
      try await engine.save(
        source: source, destination: target,
        changes: [
          "ExifIFD:DateTimeOriginal": entered, "XMP-xmp:CreateDate": entered,
          "XMP-dc:Title": "修改日期",
        ], removeGPS: false)
      let rows = try await engine.read(target)
      XCTAssertEqual(rows.first { $0.key == "XMP-xmp:CreateDate" }?.value, entered)
      XCTAssertEqual(try Data(contentsOf: source), original)
    }
  }

}
