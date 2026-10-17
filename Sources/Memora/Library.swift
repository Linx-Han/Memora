import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor final class Library: ObservableObject {
  @Published var files: [URL] = []
  @Published var selected: URL?
  @Published var rows: [MetadataRow] = []
  @Published var values: [String: String] = [:]
  @Published var original: [String: String] = [:]
  @Published var removeGPS = false
  @Published var exportName = ""
  @Published var initialExportName = ""
  @Published var busy = false
  @Published var message: String?
  @Published var status = ""
  @Published var image: NSImage?
  let engine = MetadataEngine()
  let previews = PreviewLoader()
  let drafts: DraftStore
  private var savedValues: [String: String] = [:]
  private var savedRemoveGPS = false
  private var savedExportName = ""
  init(drafts: DraftStore = .standard) { self.drafts = drafts }
  var metadataChanges: [String: String] { values.filter { $0.value != (original[$0.key] ?? "") } }
  var hasEdits: Bool { !metadataChanges.isEmpty || removeGPS || exportName != initialExportName }
  var dirty: Bool {
    values != savedValues || removeGPS != savedRemoveGPS || exportName != savedExportName
  }
  private func markDraftSaved() {
    savedValues = values
    savedRemoveGPS = removeGPS
    savedExportName = exportName
  }
  func saveDraft() {
    guard let selected, !busy else { return }
    do {
      let draft = EditDraft(changes: metadataChanges, removeGPS: removeGPS, exportName: exportName)
      try drafts.save(draft, for: selected)
      markDraftSaved()
      status = "已保存：编辑草稿，下次打开此图片会恢复"
    } catch { status = "保存失败：\(error.localizedDescription)" }
  }
  func editValue(_ key: String, _ value: String) {
    values[key] = value
    if key == "ExifIFD:DateTimeOriginal" {
      values["XMP-xmp:CreateDate"] = value
    }
  }
  func reset() {
    values = original
    removeGPS = false
    exportName = initialExportName
  }
  var allRows: [MetadataRow] {
    let known = Set(rows.map(\.key))
    return
      (rows
      + values.keys.filter { !known.contains($0) }.map {
        MetadataRow(key: $0, value: values[$0] ?? "")
      }).sorted { $0.key < $1.key }
  }
  func open() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.image]
    panel.allowsMultipleSelection = true
    if panel.runModal() == .OK { add(panel.urls) }
  }
  func add(_ urls: [URL]) {
    guard !busy else { return }
    for url in urls where !files.contains(url) { files.append(url) }
    if let first = urls.first { select(first) }
  }
  func select(_ url: URL) {
    guard !busy, url != selected else { return }
    if dirty {
      let alert = NSAlert()
      alert.messageText = L("放弃尚未保存的修改？")
      alert.informativeText = L("切换图片将清除当前编辑。")
      alert.addButton(withTitle: L("继续编辑"))
      alert.addButton(withTitle: L("放弃修改"))
      guard alert.runModal() == .alertSecondButtonReturn else { return }
    }
    selected = url
    busy = true
    rows = []
    values = [:]
    original = [:]
    removeGPS = false
    image = nil
    exportName = url.deletingPathExtension().lastPathComponent + "-edited"
    initialExportName = exportName
    Task {
      do {
        async let metadata = engine.read(url)
        image = await previews.load(url)
        rows = try await metadata
        values = Dictionary(
          uniqueKeysWithValues: rows.filter { TagCatalog.editable($0.key) }.map {
            ($0.key, $0.value)
          })
        for field in EditField.common where values[field.id] == nil { values[field.id] = "" }
        original = values
        if let draft = try drafts.load(for: url) {
          values.merge(draft.changes) { _, edited in edited }
          removeGPS = draft.removeGPS
          exportName = draft.exportName
        }
        markDraftSaved()
        status = "已读取 \(rows.count) 项元数据"
      } catch { message = error.localizedDescription }
      busy = false
    }
  }
  func exportImage() {
    guard let source = selected, !busy else { return }
    guard !exportName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !exportName.contains("/"), !exportName.contains(":"), !exportName.contains("\0"),
      ![".", ".."].contains(exportName)
    else {
      status = "保存失败：文件名不能为空，也不能包含 /、: 或空字符。"
      return
    }
    let folder = source.deletingLastPathComponent()
    let requested = folder.appendingPathComponent(exportName).appendingPathExtension(
      source.pathExtension)
    var target = SaveFilename.destination(requested, source: source)
    var suffix = 2
    while FileManager.default.fileExists(atPath: target.path) {
      target = folder.appendingPathComponent("\(exportName)-\(suffix)").appendingPathExtension(
        source.pathExtension)
      suffix += 1
    }
    let changes = metadataChanges
    busy = true
    Task {
      do {
        try await engine.save(
          source: source, destination: target, changes: changes, removeGPS: removeGPS)
        status = "已保存：\(target.lastPathComponent) · 保留原画质"
      } catch { status = "保存失败：\(error.localizedDescription)" }
      busy = false
    }
  }
}
