import SwiftUI

struct AddTagSheet: View {
  var onSelect: (String) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var query = ""
  var matches: [TagDefinition] {
    Array(
      TagCatalog.all.filter {
        query.isEmpty || $0.id.localizedCaseInsensitiveContains(query)
          || $0.title.localizedCaseInsensitiveContains(query)
          || TagCatalog.displayTitle($0.id).localizedCaseInsensitiveContains(query)
      }.prefix(120))
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text(L("添加元数据字段")).font(.headline)
        Spacer()
        Button(L("完成")) { dismiss() }.buttonStyle(SoftActionButtonStyle())
      }
      TextField(L("搜索名称，例如 GPS、City、Date、作者"), text: $query).modifier(SoftField())
      Text(String(format: L("可搜索 %d 个标准可写标签；可写范围取决于图片格式。最多显示 120 项。"), TagCatalog.all.count)).font(
        .caption
      ).foregroundStyle(Appearance.muted)
      List(matches) { tag in
        Button {
          onSelect(tag.id)
          dismiss()
        } label: {
          VStack(alignment: .leading, spacing: 4) {
            Text(TagCatalog.displayTitle(tag.id))
            Text("\(tag.id) · \(tag.type)\(tag.isList ? L(" · 每行一项") : "")").font(.caption)
              .foregroundStyle(Appearance.muted)
          }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 5)
        }.buttonStyle(QuietButtonStyle())
      }
    }.padding(24).frame(width: 570, height: 540).preferredColorScheme(.light)
  }
}
