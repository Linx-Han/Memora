import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
  case chinese = "zh-Hans"
  case japanese = "ja"
  case korean = "ko"
  case english = "en"
  var id: String { rawValue }
  var title: String {
    switch self {
    case .chinese: "中文"
    case .japanese: "日本語"
    case .korean: "한국어"
    case .english: "English"
    }
  }
  static var current: AppLanguage {
    AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "zh-Hans")
      ?? .chinese
  }
}

enum Translation {
  static let catalog: [String: [String: String]] = {
    guard let url = Bundle.module.url(forResource: "Localization", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let result = try? JSONDecoder().decode([String: [String: String]].self, from: data)
    else { return [:] }
    return result
  }()
  static func text(_ key: String, language: AppLanguage) -> String {
    if language == .chinese { return key }
    if let result = catalog[key]?[language.rawValue] { return result }
    for prefix in ["保存失败：", "已保存："] where key.hasPrefix(prefix) {
      let remaining = String(key.dropFirst(prefix.count))
      if prefix == "已保存：", remaining.hasSuffix(" · 保留原画质") {
        return (catalog[prefix]?[language.rawValue] ?? prefix)
          + remaining.dropLast(" · 保留原画质".count)
          + (catalog[" · 保留原画质"]?[language.rawValue] ?? "")
      }
      return (catalog[prefix]?[language.rawValue] ?? prefix) + text(remaining, language: language)
    }
    if key.hasPrefix("例如 ") {
      let prefix = language == .english ? "e.g. " : language == .japanese ? "例：" : "예: "
      return prefix + key.dropFirst(3)
    }
    return key
  }
}
func L(_ key: String) -> String { Translation.text(key, language: .current) }

struct LanguageSelector: View {
  @AppStorage("appLanguage") private var language = AppLanguage.chinese.rawValue
  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: "globe").foregroundStyle(Appearance.muted).padding(.horizontal, 8)
      ForEach(AppLanguage.allCases) { option in
        Button {
          language = option.rawValue
        } label: {
          Text(verbatim: option.title).font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(
              language == option.rawValue ? Appearance.surface : .clear,
              in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(QuietButtonStyle())
          .accessibilityAddTraits(language == option.rawValue ? .isSelected : [])
      }
    }.padding(4).modifier(SoftSurface(radius: 12, translucent: true))
  }
}
