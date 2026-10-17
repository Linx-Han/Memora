import Foundation

/// Normalize date syntax without guessing a timezone or discarding precision.
enum MetadataDate {
  static func canonical(_ value: String) -> String? {
    let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let pattern =
      #"^(\d{4})[-:](\d{1,2})[-:](\d{1,2})(?:[Tt ](\d{1,2}):(\d{2})(?::(\d{2})(?:\.(\d+))?)?(?:\s*([Zz]|[+-]\d{2}:?\d{2}))?)?$"#
    guard let regex = try? NSRegularExpression(pattern: pattern),
      let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
    else { return nil }
    func part(_ index: Int) -> String? {
      guard let range = Range(match.range(at: index), in: text) else { return nil }
      return String(text[range])
    }
    guard let year = Int(part(1) ?? ""), let month = Int(part(2) ?? ""),
      let day = Int(part(3) ?? "")
    else { return nil }
    let hour = Int(part(4) ?? "0") ?? -1
    let minute = Int(part(5) ?? "0") ?? -1
    let second = Int(part(6) ?? "0") ?? -1
    guard (0...23).contains(hour), (0...59).contains(minute), (0...59).contains(second) else {
      return nil
    }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let components = DateComponents(year: year, month: month, day: day)
    guard let date = calendar.date(from: components) else { return nil }
    let checked = calendar.dateComponents([.year, .month, .day], from: date)
    guard checked.year == year, checked.month == month, checked.day == day else { return nil }
    var result = String(format: "%04d:%02d:%02d", year, month, day)
    if part(4) != nil {
      result += String(format: " %02d:%02d", hour, minute)
      if part(6) != nil { result += String(format: ":%02d", second) }
      if var fraction = part(7) {
        while fraction.last == "0" { fraction.removeLast() }
        if !fraction.isEmpty { result += "." + fraction }
      }
    }
    if let zone = part(8) {
      if zone.uppercased() == "Z" {
        result += "Z"
      } else {
        let compact = zone.replacingOccurrences(of: ":", with: "")
        let hours = Int(compact.dropFirst().prefix(2)) ?? 99
        let minutes = Int(compact.suffix(2)) ?? 99
        guard hours <= 23, minutes <= 59 else { return nil }
        if compact == "+0000" {
          result += "Z"
        } else {
          result += String(compact.prefix(1)) + String(format: "%02d:%02d", hours, minutes)
        }
      }
    }
    return result
  }

  static func isXMPDate(_ key: String) -> Bool {
    key.hasPrefix("XMP-") && TagCatalog.byID[key]?.type == "date"
  }
}
