import CoreLocation
import XCTest

@testable import Memora

final class LocationTests: XCTestCase {
  func testMapLocationSavedInImage() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let source = try TestFixtures.image(.jpeg, ext: "JPG", folder: folder)
    let target = folder.appendingPathComponent("location.JPG")
    var location = PhotoLocation(
      coordinate: CLLocationCoordinate2D(latitude: -31.9523, longitude: 115.8613))
    location.country = "Australia"
    location.state = "Western Australia"
    location.city = "Perth"
    location.detail = "测试地点"
    let engine = MetadataEngine()
    try await engine.save(
      source: source, destination: target, changes: location.metadata, removeGPS: false)
    let rows = try await engine.read(target)
    let values = Dictionary(uniqueKeysWithValues: rows.map { ($0.key, $0.value) })
    let coordinate = try XCTUnwrap(PhotoLocation.coordinate(from: values))
    XCTAssertEqual(coordinate.latitude, -31.9523, accuracy: 0.000001)
    XCTAssertEqual(coordinate.longitude, 115.8613, accuracy: 0.000001)
    XCTAssertEqual(values["XMP-photoshop:City"], "Perth")
    XCTAssertEqual(values["IPTC:City"], "Perth")
    XCTAssertEqual(values["XMP-iptcCore:Location"], "测试地点")
    XCTAssertEqual(Double(values["XMP-exif:GPSLatitude"] ?? "") ?? 0, -31.9523, accuracy: 0.000001)
    XCTAssertEqual(Double(values["XMP-exif:GPSLongitude"] ?? "") ?? 0, 115.8613, accuracy: 0.000001)
    // A new pin without an address must remove the previous place's details.
    let blank = PhotoLocation(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: -1))
    let second = folder.appendingPathComponent("moved.JPG")
    try await engine.save(
      source: target, destination: second, changes: blank.metadata, removeGPS: false)
    let movedRows = try await engine.read(second)
    let moved = Dictionary(uniqueKeysWithValues: movedRows.map { ($0.key, $0.value) })
    XCTAssertNil(moved["XMP-photoshop:City"])
    XCTAssertNil(moved["IPTC:City"])
    XCTAssertEqual(
      try XCTUnwrap(PhotoLocation.coordinate(from: moved)).longitude, -1, accuracy: 0.000001)
  }
}
