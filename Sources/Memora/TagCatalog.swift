import Foundation

struct TagDefinition: Codable, Identifiable {
  struct Option: Codable {
    let value: String
    let label: String
  }
  let id: String
  let title: String
  let type: String
  let isList: Bool
  let options: [Option]
}

enum TagCatalog {
  static let all: [TagDefinition] = {
    guard let url = Bundle.module.url(forResource: "WritableTags", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let tags = try? JSONDecoder().decode([TagDefinition].self, from: data)
    else { return [] }
    return tags
  }()
  static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
  static func displayTitle(_ key: String) -> String {
    guard let title = byID[key]?.title else {
      return key.split(separator: ":").last.map(String.init) ?? key
    }
    let translated = L(title)
    if AppLanguage.current != .chinese && translated == title
      && title.unicodeScalars.contains(where: { (0x4E00...0x9FFF).contains($0.value) })
    {
      return key.split(separator: ":").last.map(String.init) ?? key
    }
    return translated
  }
  static let fileDates = ["System:FileCreateDate", "System:FileModifyDate"]
  static func editable(_ key: String) -> Bool { byID[key] != nil || fileDates.contains(key) }
  static func dateFormatter() -> DateFormatter {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy:MM:dd HH:mm:ss"
    f.isLenient = false
    return f
  }
  static func fileDate(_ value: String) throws -> Date {
    let f = dateFormatter()
    guard let date = f.date(from: value), f.string(from: date) == value else {
      throw MetadataError(message: "日期格式应为 yyyy:MM:dd HH:mm:ss，且必须为有效日期。")
    }
    return date
  }
}

struct EditField: Identifiable {
  let id: String
  let title: String
  let placeholder: String
}

extension EditField {
  static let sections: [(String, [EditField])] = [
    (
      "标题与版权",
      [
        .init(id: "XMP-dc:Title", title: "标题", placeholder: "为照片命名"),
        .init(id: "XMP-dc:Description", title: "描述", placeholder: "记录照片背后的故事"),
        .init(id: "XMP-dc:Creator", title: "作者", placeholder: "摄影师姓名"),
        .init(id: "XMP-dc:Rights", title: "版权", placeholder: "© 2026"),
        .init(id: "XMP-dc:Subject", title: "关键词", placeholder: "每行一个关键词"),
        .init(id: "IFD0:ImageDescription", title: "EXIF 图片描述", placeholder: "图片描述"),
        .init(id: "IFD0:Artist", title: "EXIF 作者", placeholder: "作者"),
        .init(id: "IFD0:Copyright", title: "EXIF 版权", placeholder: "版权声明"),
        .init(id: "XMP-xmp:Rating", title: "评分", placeholder: "0–5"),
      ]
    ),
    (
      "日期与时间",
      [
        .init(id: "ExifIFD:DateTimeOriginal", title: "拍摄时间", placeholder: "yyyy:MM:dd HH:mm:ss"),
        .init(id: "ExifIFD:CreateDate", title: "数字化时间", placeholder: "yyyy:MM:dd HH:mm:ss"),
        .init(id: "IFD0:ModifyDate", title: "EXIF 修改时间", placeholder: "yyyy:MM:dd HH:mm:ss"),
        .init(id: "ExifIFD:OffsetTimeOriginal", title: "拍摄时区", placeholder: "+08:00"),
        .init(
          id: "XMP-xmp:CreateDate", title: "XMP 创建时间", placeholder: "yyyy:MM:dd HH:mm:ss+08:00"),
        .init(
          id: "XMP-xmp:ModifyDate", title: "XMP 修改时间", placeholder: "yyyy:MM:dd HH:mm:ss+08:00"),
        .init(
          id: "System:FileCreateDate", title: "文件创建时间", placeholder: "本地时间 yyyy:MM:dd HH:mm:ss"),
        .init(
          id: "System:FileModifyDate", title: "文件修改时间", placeholder: "本地时间 yyyy:MM:dd HH:mm:ss"),
      ]
    ),
    ("地点与 GPS", []),
    (
      "相机与拍摄参数",
      [
        .init(id: "IFD0:Make", title: "相机品牌", placeholder: "例如 Canon"),
        .init(id: "IFD0:Model", title: "相机型号", placeholder: "例如 EOS R5"),
        .init(id: "ExifIFD:LensModel", title: "镜头型号", placeholder: "例如 RF 24–70mm"),
        .init(id: "ExifIFD:ISO", title: "ISO 感光度", placeholder: "例如 100"),
        .init(id: "ExifIFD:ExposureTime", title: "曝光时间（秒）", placeholder: "例如 0.008（1/125 秒）"),
        .init(id: "ExifIFD:FNumber", title: "光圈", placeholder: "例如 2.8"),
        .init(id: "ExifIFD:FocalLength", title: "焦距（毫米）", placeholder: "例如 50"),
        .init(id: "ExifIFD:ExposureCompensation", title: "曝光补偿（EV）", placeholder: "例如 -0.3"),
        .init(id: "ExifIFD:UserComment", title: "用户备注", placeholder: "备注"),
        .init(id: "IFD0:Software", title: "处理软件", placeholder: "软件名称"),
      ]
    ),
  ]
  static var common: [EditField] { sections.flatMap { $0.1 } }
}
