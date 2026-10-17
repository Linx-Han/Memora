import Foundation

struct MetadataRow: Identifiable {
  var id: String { key }
  let key: String
  let value: String
  var group: String { String(key.split(separator: ":").first ?? "Other") }
  var name: String { String(key.split(separator: ":").last ?? "") }
}

enum SaveFilename {
  static func destination(_ requested: URL, source: URL) -> URL {
    let stem = requested.pathExtension.isEmpty ? requested : requested.deletingPathExtension()
    return source.pathExtension.isEmpty ? stem : stem.appendingPathExtension(source.pathExtension)
  }
}

struct MetadataError: LocalizedError {
  let message: String
  var errorDescription: String? { message }
}

actor MetadataEngine {
  func run(_ arguments: [String]) throws -> Data {
    let script = Bundle.module.url(forResource: "ExifTool", withExtension: nil)!
      .appendingPathComponent("exiftool")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
    process.arguments = [script.path, "-config", ""] + arguments
    // File-backed output avoids pipe-buffer deadlocks on large metadata payloads.
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let out = folder.appendingPathComponent("out")
    let err = folder.appendingPathComponent("err")
    FileManager.default.createFile(atPath: out.path, contents: nil)
    FileManager.default.createFile(atPath: err.path, contents: nil)
    let stdout = try FileHandle(forWritingTo: out)
    let stderr = try FileHandle(forWritingTo: err)
    defer {
      try? stdout.close()
      try? stderr.close()
    }
    process.standardOutput = stdout
    process.standardError = stderr
    try process.run()
    process.waitUntilExit()
    let errors = String(data: try Data(contentsOf: err), encoding: .utf8) ?? ""
    guard process.terminationStatus == 0 else {
      throw MetadataError(message: errors.isEmpty ? "元数据处理失败。" : errors)
    }
    return try Data(contentsOf: out)
  }

  func read(_ url: URL) throws -> [MetadataRow] {
    let data = try run(["-j", "-n", "-G1", "-s", "-a", url.path])
    guard let objects = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
      let object = objects.first
    else { throw MetadataError(message: "无法读取元数据。") }
    var result = object.filter { $0.key != "SourceFile" }.map { key, value in
      MetadataRow(
        key: key,
        value: (value as? String) ?? (value as? [Any])?.map { String(describing: $0) }.joined(
          separator: "\n") ?? String(describing: value))
    }.sorted { $0.key < $1.key }
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    for (key, attribute) in [
      ("System:FileCreateDate", FileAttributeKey.creationDate),
      ("System:FileModifyDate", .modificationDate),
    ] {
      result.removeAll { $0.key == key }
      if let date = attributes[attribute] as? Date {
        result.append(MetadataRow(key: key, value: TagCatalog.dateFormatter().string(from: date)))
      }
    }
    return result.sorted { $0.key < $1.key }
  }

  func save(source: URL, destination requested: URL, changes: [String: String], removeGPS: Bool)
    throws
  {
    let destination = SaveFilename.destination(requested, source: source)
    guard
      source.standardizedFileURL.resolvingSymlinksInPath()
        != destination.standardizedFileURL.resolvingSymlinksInPath()
    else { throw MetadataError(message: "请选择新的文件名，保留原始图片。") }
    for (tag, value) in changes {
      guard TagCatalog.editable(tag) else { throw MetadataError(message: "不支持的编辑字段。") }
      if tag == "XMP-xmp:Rating", !value.isEmpty,
        !(Int(value).map { (0...5).contains($0) } ?? false)
      {
        throw MetadataError(message: "评分应为 0 至 5 的整数。")
      }
      if ["ExifIFD:DateTimeOriginal", "ExifIFD:CreateDate", "IFD0:ModifyDate"].contains(tag),
        !value.isEmpty
      {
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_US_POSIX")
        format.dateFormat = "yyyy:MM:dd HH:mm:ss"
        format.isLenient = false
        guard let date = format.date(from: value), format.string(from: date) == value else {
          throw MetadataError(message: "拍摄时间格式应为 yyyy:MM:dd HH:mm:ss。")
        }
      }
    }
    for (key, value) in changes {
      if TagCatalog.fileDates.contains(key) { _ = try TagCatalog.fileDate(value) }
      if ["GPS:GPSLatitude", "GPS:GPSLongitude", "GPS:GPSAltitude"].contains(key), !value.isEmpty {
        let maximum =
          key.hasSuffix("Latitude")
          ? 90.0 : key.hasSuffix("Longitude") ? 180.0 : Double.greatestFiniteMagnitude
        guard let number = Double(value), number.isFinite, number >= 0, number <= maximum else {
          throw MetadataError(message: "\(key) 必须是有效范围内的非负数；方向请使用半球或海拔基准字段。")
        }
      }
    }
    if removeGPS
      && changes.keys.contains(where: { $0.contains("GPS") && !(changes[$0]?.isEmpty ?? true) })
    {
      throw MetadataError(message: "不能同时修改 GPS 坐标并移除 GPS，请选择其中一种操作。")
    }
    var effective = changes
    for (key, value) in changes where MetadataDate.isXMPDate(key) && !value.isEmpty {
      if let canonical = MetadataDate.canonical(value) { effective[key] = canonical }
    }
    let needsGPSContext = changes.keys.contains { $0.hasPrefix("GPS:") }
    let existing = needsGPSContext ? try read(source) : []
    for (coordinate, reference, allowed) in [
      ("GPS:GPSLatitude", "GPS:GPSLatitudeRef", ["N", "S"]),
      ("GPS:GPSLongitude", "GPS:GPSLongitudeRef", ["E", "W"]),
    ] {
      let value = changes[coordinate] ?? existing.first { $0.key == coordinate }?.value ?? ""
      let ref = changes[reference] ?? existing.first { $0.key == reference }?.value ?? ""
      if changes[coordinate] != nil || changes[reference] != nil {
        if value.isEmpty {
          effective[coordinate] = ""
          effective[reference] = ""
        } else if !allowed.contains(ref) {
          throw MetadataError(message: "坐标需要填写对应半球：纬度 N/S，经度 E/W。")
        }
      }
    }
    let staging = destination.deletingLastPathComponent().appendingPathComponent(
      ".memora-\(UUID().uuidString).\(source.pathExtension)")
    defer { try? FileManager.default.removeItem(at: staging) }
    try FileManager.default.copyItem(at: source, to: staging)
    // Direct metadata writing: no XML reconstruction, digest, or read-back
    // comparison. -m lets ExifTool handle recoverable minor metadata defects.
    var args = ["-overwrite_original", "-P", "-m", "-n", "-charset", "IPTC=UTF8", "-sep", "\n"]
    let metadataChanges = effective.filter { !TagCatalog.fileDates.contains($0.key) }
    args += metadataChanges.sorted { $0.key < $1.key }.map { "-\($0.key)=\($0.value)" }
    if removeGPS {
      args += [
        "-GPS:all=", "-XMP-exif:GPS*=", "-XMP:Geotag=", "-XMP-iptcExt:LocationCreatedGPS*=",
        "-XMP-iptcExt:LocationShownGPS*=",
      ]
    }
    if !metadataChanges.isEmpty || removeGPS { _ = try run(args + [staging.path]) }
    var attributes: [FileAttributeKey: Any] = [:]
    for (key, attribute) in [
      ("System:FileCreateDate", FileAttributeKey.creationDate),
      ("System:FileModifyDate", .modificationDate),
    ] {
      if let value = effective[key] { attributes[attribute] = try TagCatalog.fileDate(value) }
    }
    if !attributes.isEmpty {
      try FileManager.default.setAttributes(attributes, ofItemAtPath: staging.path)
    }
    if FileManager.default.fileExists(atPath: destination.path) {
      _ = try FileManager.default.replaceItemAt(
        destination, withItemAt: staging, options: .usingNewMetadataOnly)
    } else {
      try FileManager.default.moveItem(at: staging, to: destination)
    }
  }
}

enum PhotoDimensions {
  static func text(rows: [MetadataRow]) -> String {
    let width = rows.first { $0.name == "ImageWidth" }?.value
    let height = rows.first { $0.name == "ImageHeight" }?.value
    if let width, let height { return "\(width) × \(height)" }
    let parts = (rows.first { $0.name == "ImageSize" }?.value ?? "").split { !$0.isNumber }
    guard parts.count == 2 else { return "—" }
    return "\(parts[0]) × \(parts[1])"
  }
}
