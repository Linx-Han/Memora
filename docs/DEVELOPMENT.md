# 开发

使用 macOS 14+、Swift 6 工具链。项目无远程 Swift 包依赖；ExifTool 随源码提供，通过系统 `/usr/bin/perl` 运行。

```sh
swift run Memora
swift test
```

需要应用包时手动执行：

```sh
./Scripts/build-app.sh
```

输出为 `dist/Memora.app`，采用本地 ad-hoc 签名，没有 Developer ID 签名或公证。运行和测试不会自动打包。

## 代码结构

| 文件 | 职责 |
| --- | --- |
| `MemoraApp.swift` / `ContentView.swift` | 应用入口、命令与工作台 |
| `Library.swift` / `EditDraft.swift` | 图片选择、编辑状态、持久草稿与导出 |
| `Metadata.swift` / `MetadataDate.swift` | ExifTool 读写、时间格式、文件属性 |
| `TagCatalog.swift` | 可写标签目录与常用字段 |
| `LocationPicker.swift` | Apple 地图搜索、选点、地址转换 |
| `PreviewLoader.swift` / `MemoryEdgeRenderer.swift` | 后台缩略图解码、缓存与光晕渲染 |
| `MemoryPreview.swift` / `Appearance.swift` | 预览生命周期、材质与交互 |
| `Localization.swift` | 语言选择与翻译 |

以上文件均位于 `Sources/Memora`。测试位于 `Tests/MemoraTests`，使用临时生成的图片，不依赖私人照片。

## 数据与保存

- 草稿按图片完整路径存入 `~/Library/Application Support/Memora/EditDrafts.json`；移动或重命名原图不会自动迁移草稿。
- 导出复制原图到临时文件，再由 ExifTool 写入修改。不重编码、不回读比较、不重建 XMP。进程或文件操作失败时显示错误并清理临时文件。
- 预览缩略图和光晕不进入导出流程。已有回归测试覆盖 JPEG、PNG、TIFF；其他格式的读写能力取决于 ExifTool 和 ImageIO。
- GPS 移除针对标准坐标标签，不清除描述文字中的地址。文件时间按本机时区解释。
- 保留既有 `local.metaimage.editor` bundle identifier，以延续已安装应用的偏好设置。

## 资源维护

- Logo：`Sources/Memora/Resources/AppIcon.png`。
- 翻译：`Sources/Memora/Resources/Localization.json`；未知高级标签回退到标准标签名。
- 标签目录：运行 `python3 Scripts/build-tag-catalog.py` 从内置 ExifTool 重新生成。
- Swift 格式：`xcrun swift-format format --in-place --recursive Sources/Memora Tests/MemoraTests Package.swift`。

光晕目前使用 Core Image Kernel Language，构建会产生已弃用 API 警告；保留该实现以维持当前效果，后续可迁移到 Metal。
