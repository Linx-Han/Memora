import Foundation

struct EditDraft: Codable, Equatable {
  var changes: [String: String]
  var removeGPS: Bool
  var exportName: String
}

struct DraftStore {
  let url: URL
  static var standard: DraftStore {
    let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    return DraftStore(url: folder.appendingPathComponent("Memora/EditDrafts.json"))
  }
  private func key(_ source: URL) -> String {
    source.standardizedFileURL.resolvingSymlinksInPath().path
  }
  private func read() throws -> [String: EditDraft] {
    guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
    return try JSONDecoder().decode([String: EditDraft].self, from: Data(contentsOf: url))
  }
  func load(for source: URL) throws -> EditDraft? { try read()[key(source)] }
  func save(_ draft: EditDraft, for source: URL) throws {
    var drafts = try read()
    drafts[key(source)] = draft
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONEncoder().encode(drafts).write(to: url, options: .atomic)
  }
}
