import XCTest

@testable import Memora

final class LocalizationTests: XCTestCase {
  func testDimensionsAlwaysHaveSeparator() {
    XCTAssertEqual(
      PhotoDimensions.text(rows: [.init(key: "Composite:ImageSize", value: "4032 3024")]),
      "4032 × 3024")
    XCTAssertEqual(
      PhotoDimensions.text(rows: [.init(key: "Composite:ImageSize", value: "4032x3024")]),
      "4032 × 3024")
    XCTAssertEqual(
      PhotoDimensions.text(rows: [
        .init(key: "File:ImageWidth", value: "800"), .init(key: "File:ImageHeight", value: "600"),
      ]), "800 × 600")
    XCTAssertEqual(PhotoDimensions.text(rows: []), "—")
  }
  func testAllLanguagesHaveTranslationsAndPreserveUnknownValues() {
    XCTAssertGreaterThan(Translation.catalog.count, 100)
    for (key, translations) in Translation.catalog {
      for language in [AppLanguage.english, .japanese, .korean] {
        XCTAssertFalse((translations[language.rawValue] ?? "").isEmpty, key)
        XCTAssertFalse(Translation.text(key, language: language).isEmpty)
      }
    }
    XCTAssertEqual(Translation.text("画廊", language: .english), "Gallery")
    XCTAssertEqual(Translation.text("画廊", language: .japanese), "ギャラリー")
    XCTAssertEqual(Translation.text("画廊", language: .korean), "갤러리")
    XCTAssertEqual(Translation.text("画廊", language: .chinese), "画廊")
    XCTAssertEqual(
      Translation.text("2026:10:16 12:00:00", language: .english), "2026:10:16 12:00:00")
    XCTAssertEqual(
      Translation.text("已保存：照片.JPG · 保留原画质", language: .english),
      "Saved: 照片.JPG · Original quality preserved")
  }
}
