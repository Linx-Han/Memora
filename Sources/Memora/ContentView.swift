import SwiftUI

struct ContentView: View {
  @EnvironmentObject var model: Library
  @State private var search = ""
  @State private var category = "全部"
  @State private var tab = "编辑信息"
  @State private var targeted = false
  @State private var showAddTag = false
  @State private var showLocationPicker = false
  @State private var onlyEditable = false
  let accent = Appearance.accent
  var filtered: [MetadataRow] {
    model.allRows.filter { row in
      let groupMatch =
        category == "全部"
        || (category == "EXIF"
          ? ["IFD0", "ExifIFD", "IFD1", "InteropIFD"].contains(row.group)
          : category == "XMP" ? row.group.hasPrefix("XMP") : row.group == category)
      return groupMatch && (!onlyEditable || TagCatalog.editable(row.key))
        && (search.isEmpty || row.key.localizedCaseInsensitiveContains(search)
          || (model.values[row.key] ?? row.value).localizedCaseInsensitiveContains(search)
          || (TagCatalog.byID[row.key]?.title.localizedCaseInsensitiveContains(search) ?? false)
          || TagCatalog.displayTitle(row.key).localizedCaseInsensitiveContains(search))
    }
  }
  var body: some View {
    HStack(spacing: 0) {
      sidebar.frame(width: 226)
      Divider()
      VStack(spacing: 0) {
        if model.selected != nil {
          HStack {
            VStack(alignment: .leading, spacing: 5) {
              Text(model.selected?.lastPathComponent ?? "").font(
                .system(size: 16, weight: .medium)
              ).lineLimit(1)
              Text(L(model.selected == nil ? "让每一张照片的信息井然有序" : "读取、整理与编辑照片元数据")).font(.caption)
                .foregroundStyle(Appearance.muted)
            }
            Spacer()
            if model.busy { ProgressView().controlSize(.small) }
            Button(action: model.exportImage) {
              Label(L("无损另存为"), systemImage: "square.and.arrow.down").font(
                .system(size: 13, weight: .medium)
              ).padding(.horizontal, 16).padding(.vertical, 11)
            }
            .buttonStyle(QuietButtonStyle(prominent: true)).disabled(
              model.selected == nil || model.busy)
          }.padding(24).padding(.top, 28)
        }
        if model.selected == nil {
          emptyState
        } else {
          HStack(spacing: 0) {
            preview.frame(maxWidth: .infinity)
            Divider()
            inspector.frame(width: 390)
          }
        }

      }
    }
    .tint(accent)
    .font(.system(size: 13))
    .foregroundStyle(Appearance.ink)
    .preferredColorScheme(.light)
    .background(GlassBackground().ignoresSafeArea())
    .overlay {
      if targeted {
        RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(
          accent.opacity(0.65), lineWidth: 2
        ).padding(6).allowsHitTesting(false)
      }
    }
    .sheet(isPresented: $showLocationPicker) {
      LocationPicker(initial: model.values) { location in
        for (key, value) in location.metadata { model.editValue(key, value) }
        model.removeGPS = false
        model.status = "位置已更新，保存图片后生效"
      }
    }
    .sheet(isPresented: $showAddTag) {
      AddTagSheet { key in
        if model.values[key] == nil { model.values[key] = "" }
        search = key
        category = "全部"
        tab = "全部元数据"
      }
    }
    .dropDestination(for: URL.self) { urls, _ in
      model.add(urls)
      return true
    } isTargeted: {
      targeted = $0
    }
  }
  var sidebar: some View {
    VStack(alignment: .leading, spacing: 22) {
      HStack(spacing: 10) {
        AppLogo(size: 38)
        VStack(alignment: .leading, spacing: 2) {
          Text("Memora").font(.system(size: 14, weight: .medium))
          Text(L("照片元数据工作室")).font(.caption2).foregroundStyle(Appearance.muted)
        }
      }.padding(.top, 28)
      Button(action: model.open) {
        Label(L("添加图片"), systemImage: "plus").font(.system(size: 13, weight: .medium)).frame(
          maxWidth: .infinity
        ).padding(.vertical, 11)
      }.buttonStyle(QuietButtonStyle()).modifier(SoftSurface(radius: 8, translucent: true))
        .disabled(model.busy)
      HStack {
        Text(L("画廊")).font(.system(size: 11, weight: .medium)).foregroundStyle(Appearance.muted)
        Spacer()
        Text("\(model.files.count)").font(.caption).foregroundStyle(Appearance.muted)
      }
      WarmScrollView {
        LazyVStack(spacing: 6) {
          ForEach(model.files, id: \.self) { url in
            Button {
              model.select(url)
            } label: {
              HStack(spacing: 10) {
                Image(systemName: "photo").font(.title3).foregroundStyle(
                  model.selected == url ? accent : Appearance.muted)
                VStack(alignment: .leading, spacing: 4) {
                  Text(url.lastPathComponent).lineLimit(1).font(.system(size: 12, weight: .medium))
                  Text(url.pathExtension.uppercased()).font(.system(size: 10)).foregroundStyle(
                    Appearance.muted)
                }
                Spacer(minLength: 0)
              }.padding(10).background(
                model.selected == url ? Appearance.surface.opacity(0.65) : .clear,
                in: RoundedRectangle(cornerRadius: 8))
            }.buttonStyle(QuietButtonStyle()).disabled(model.busy)
          }
        }
      }
    }.padding(18).background(GlassBackground(tint: 0.06))
  }

  var emptyState: some View {
    VStack(alignment: .center, spacing: 18) {
      AppLogo(size: 100).modifier(WelcomeEntrance(delay: 0))
      Text(L("为你的足迹打上标签")).multilineTextAlignment(.center).font(.system(size: 21, weight: .medium))
        .modifier(WelcomeEntrance(delay: 0.10))
      Text(L("将图片拖到这里，或从资料库中选择\n调整 EXIF、拍摄参数、位置信息与版权")).multilineTextAlignment(.center)
        .foregroundStyle(Appearance.muted).lineSpacing(7).modifier(WelcomeEntrance(delay: 0.20))
      Button(action: model.open) {
        Text(L("选择图片…")).font(.system(size: 13, weight: .medium)).padding(.horizontal, 24).padding(
          .vertical, 12)
      }.buttonStyle(QuietButtonStyle(prominent: true)).disabled(model.busy).modifier(
        WelcomeEntrance(delay: 0.30))
    }.frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(
        LinearGradient(
          colors: [Appearance.surface.opacity(0.12), Appearance.cream.opacity(0.04)],
          startPoint: .topLeading, endPoint: .bottomTrailing)
      )
      .overlay(alignment: .bottom) { LanguageSelector().padding(.bottom, 28) }
  }
  var preview: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack {
        Label(L("图片预览"), systemImage: "photo").font(.system(size: 11, weight: .medium))
          .foregroundStyle(Appearance.muted)
        Spacer()
        Text(model.selected?.pathExtension.uppercased() ?? "").font(.caption.monospaced()).padding(
          .horizontal, 8
        ).padding(.vertical, 4).background(
          Appearance.surface.opacity(0.25),
          in: RoundedRectangle(cornerRadius: 8, style: .continuous))
      }
      ZStack {
        RoundedRectangle(cornerRadius: 16, style: .continuous).fill(
          LinearGradient(
            colors: [Appearance.surface.opacity(0.28), Appearance.cream.opacity(0.12)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(
            Appearance.line.opacity(0.65)))
        if let image = model.image {
          MemoryPreview(image: image)
        } else if model.busy {
          ProgressView(L("正在读取图片…")).controlSize(.small)
        } else {
          ContentUnavailableView(
            L("无法预览此图片"), systemImage: "photo", description: Text(L("仍可查看已识别的元数据")))
        }
      }.frame(maxHeight: .infinity)
      HStack(spacing: 32) {
        stat("尺寸", value: PhotoDimensions.text(rows: model.rows))
        stat("文件大小", value: fileSizeText)
        stat("元数据", value: String(format: L("%d 项"), model.rows.count))
      }
      Label(L("修改信息，保留原始画质"), systemImage: "checkmark.shield.fill").font(.caption).foregroundStyle(
        accent
      ).padding(12).frame(maxWidth: .infinity, alignment: .leading).modifier(
        SoftSurface(radius: 8, translucent: true))
    }.padding(24).background(Appearance.surface.opacity(0.08))
  }
  var fileSizeText: String {
    guard let raw = model.rows.first(where: { $0.name == "FileSize" })?.value,
      let bytes = Int64(raw)
    else { return "—" }
    return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
  }
  func stat(_ title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(L(title)).font(.caption).foregroundStyle(Appearance.muted)
      Text(value).font(.system(size: 13, weight: .medium))
    }
  }
  var inspector: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 4) {
        ForEach(["编辑信息", "全部元数据"], id: \.self) { item in
          Button {
            tab = item
          } label: {
            Text(L(item)).font(.system(size: 12, weight: .medium))
              .frame(maxWidth: .infinity).padding(.vertical, 8)
              .background(
                tab == item ? Appearance.surface : .clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
              )
              .shadow(color: .black.opacity(tab == item ? 0.035 : 0), radius: 3, y: 1)
          }.buttonStyle(QuietButtonStyle())
            .accessibilityAddTraits(tab == item ? .isSelected : [])
        }
      }.padding(4).background(
        Appearance.surface.opacity(0.25), in: RoundedRectangle(cornerRadius: 12, style: .continuous)
      )
      if tab == "编辑信息" {
        WarmScrollView {
          VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
              Text(L("导出文件名")).font(.system(size: 14, weight: .medium))
              HStack {
                TextField(L("文件名"), text: $model.exportName).modifier(SoftField())
                Text("." + (model.selected?.pathExtension ?? "")).foregroundStyle(Appearance.muted)
              }
              Text(L("另存副本使用此名称，原文件保留。")).font(.caption).foregroundStyle(Appearance.muted)
            }
            ForEach(EditField.sections, id: \.0) { section in
              InspectorSection(title: section.0) {
                VStack(alignment: .leading, spacing: 16) {
                  if section.0 == "地点与 GPS" {
                    Button {
                      showLocationPicker = true
                    } label: {
                      Label(L("在 Apple 地图中选择位置"), systemImage: "map")
                    }.buttonStyle(SoftActionButtonStyle())
                    let location = [
                      "XMP-photoshop:Country", "XMP-photoshop:City", "XMP-iptcCore:Location",
                    ].compactMap { model.values[$0] }.filter { !$0.isEmpty }.joined(
                      separator: " · ")
                    if !location.isEmpty {
                      Text(location).font(.caption).foregroundStyle(Appearance.muted)
                    }
                    Text(L("搜索地点或地图选点；保存更改保留编辑，导出时写入图片。")).font(.caption).foregroundStyle(
                      Appearance.muted)
                  }
                  if section.0 == "日期与时间" {
                    Text(L("修改拍摄时间会同步 XMP 创建时间；也可单独编辑下方 XMP 时间。")).font(.caption).foregroundStyle(
                      Appearance.muted)

                  }
                  ForEach(section.1) { field in
                    VStack(alignment: .leading, spacing: 6) {
                      HStack {
                        Text(L(field.title)).font(.caption.weight(.medium)).foregroundStyle(
                          Appearance.muted)
                        if (model.values[field.id] ?? "") != (model.original[field.id] ?? "") {
                          Circle().fill(.orange).frame(width: 5, height: 5)
                        }
                      }
                      if field.id == "ExifIFD:DateTimeOriginal" {
                        HStack(spacing: 8) {
                          TextField(
                            L(field.placeholder),
                            text: Binding(
                              get: { model.values[field.id] ?? "" },
                              set: { model.editValue(field.id, $0) })
                          )
                          .modifier(SoftField()).frame(maxWidth: .infinity)
                          .accessibilityLabel(L(field.title))
                          Button {
                            let value = model.values[field.id] ?? ""
                            for key in [
                              "ExifIFD:CreateDate", "IFD0:ModifyDate", "XMP-xmp:CreateDate",
                              "XMP-xmp:ModifyDate", "System:FileCreateDate",
                              "System:FileModifyDate",
                            ] { model.editValue(key, value) }
                          } label: {
                            Text(L("全部应用")).font(.system(size: 12, weight: .medium))
                              .padding(.horizontal, 12).padding(.vertical, 8)
                          }
                          .buttonStyle(QuietButtonStyle())
                          .modifier(SoftSurface(radius: 8, translucent: true))
                          .disabled((model.values[field.id] ?? "").isEmpty)
                          .fixedSize()
                          .help(L("将拍摄时间应用到其余常用时间字段"))
                        }
                      } else {
                        metadataInput(field.id, placeholder: field.placeholder)
                      }
                    }
                  }
                }.padding(.vertical, 12)
              }
              Divider()
            }
            Toggle(isOn: $model.removeGPS) {
              Label(L("移除 GPS 定位标签"), systemImage: "location.slash")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Appearance.muted)
            }
            .toggleStyle(.switch).controlSize(.mini)
            .help(L("导出时清除 EXIF / XMP GPS 坐标；描述、地名及厂商私有字段可能仍含位置信息。"))
            Button {
              model.reset()
            } label: {
              Text(L("撤销全部修改")).font(.system(size: 12)).padding(.horizontal, 12).padding(
                .vertical, 8)
            }.buttonStyle(QuietButtonStyle()).modifier(SoftSurface(radius: 8, translucent: true))
              .disabled(!model.hasEdits)
          }.padding(.vertical, 8)
        }.disabled(model.busy)
      } else {
        TextField(L("搜索标签、中文名称或内容"), text: $search).modifier(SoftField())
        HStack {
          Toggle(L("仅可编辑"), isOn: $onlyEditable).toggleStyle(.checkbox)
          Spacer()
          Button {
            showAddTag = true
          } label: {
            Label(L("添加字段"), systemImage: "plus")
          }.buttonStyle(SoftActionButtonStyle()).disabled(model.busy)
        }.font(.caption)
        Text(L("数值使用原始值；列表每行一项。留空删除。只读字段不支持安全无损修改。")).font(.caption).foregroundStyle(
          Appearance.muted)
        Picker(L("分类"), selection: $category) {
          ForEach(["全部", "EXIF", "XMP", "GPS", "IPTC", "File", "System"], id: \.self) {
            Text(L($0))
          }
        }.labelsHidden()
        WarmScrollView {
          LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(filtered) { row in
              VStack(alignment: .leading, spacing: 5) {
                HStack {
                  Text(TagCatalog.displayTitle(row.key)).font(.system(size: 12, weight: .medium))
                  Spacer()
                  if !TagCatalog.editable(row.key) {
                    Label(L("只读"), systemImage: "lock").font(.caption2).foregroundStyle(
                      Appearance.muted)
                  } else if (model.values[row.key] ?? "") != (model.original[row.key] ?? "") {
                    Circle().fill(.orange).frame(width: 5, height: 5)
                  }
                }
                if TagCatalog.editable(row.key) {
                  metadataInput(row.key, placeholder: "留空删除")
                } else {
                  Text(row.value).font(.system(size: 12)).foregroundStyle(Appearance.muted)
                    .textSelection(.enabled)
                }
                Text(row.key).font(.system(size: 9, design: .monospaced)).foregroundStyle(
                  Appearance.muted)
              }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10)
              Divider()
            }
            if filtered.isEmpty {
              Text(L("没有匹配的元数据")).foregroundStyle(Appearance.muted).padding(.vertical, 24)
            }
          }
        }
      }
      if model.status.hasPrefix("已保存：") || model.status.hasPrefix("保存失败：") {
        Text(L(model.status)).font(.caption).foregroundStyle(Appearance.muted)
          .textSelection(.enabled)
      }
      Button(action: model.saveDraft) {
        Label(L("保存更改"), systemImage: "checkmark.seal")
          .font(.system(size: 13, weight: .medium))
          .frame(maxWidth: .infinity).padding(.vertical, 11)
      }
      .buttonStyle(QuietButtonStyle(prominent: true))
      .disabled(model.selected == nil || model.busy)
    }.padding(20).background(GlassBackground(tint: 0.18))
  }
  @ViewBuilder func metadataInput(_ key: String, placeholder: String) -> some View {
    let binding = Binding<String>(
      get: { model.values[key] ?? "" }, set: { model.editValue(key, $0) })
    HStack(alignment: .top, spacing: 5) {
      TextField(L(placeholder), text: binding, axis: .vertical)
        .lineLimit(1...6).modifier(SoftField()).accessibilityLabel(key)
      if let definition = TagCatalog.byID[key], !definition.options.isEmpty {
        Menu {
          Button(L("清空")) { binding.wrappedValue = "" }
          ForEach(definition.options, id: \.value) { option in
            Button("\(option.label)（\(option.value)）") { binding.wrappedValue = option.value }
          }
        } label: {
          Image(systemName: "chevron.down").padding(.vertical, 9)
        }.menuStyle(.borderlessButton).frame(width: 22)
      }
    }.disabled(model.busy || (model.removeGPS && key.contains("GPS")))
  }

}
