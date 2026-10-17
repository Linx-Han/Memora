<p align="center"><img src="Sources/Memora/Resources/AppIcon.png" width="112" alt="Memora"></p>
<h1 align="center">Memora</h1>
<p align="center">为你的足迹打上标签。</p>

原生 macOS 照片元数据编辑器。调整时间、地点与版权，保留原始画质。

- 编辑 EXIF、XMP、IPTC；通过 Apple 地图选择拍摄位置。
- **保存更改**保留本地草稿；**无损另存为**导出同格式副本，不重新编码图片。
- 支持中文、日本語、한국어和 English。照片在本地处理，地图服务需要联网。

## 使用

macOS 14+，Swift 6 / Xcode 16+。

```sh
swift run Memora
```

拖入图片开始编辑。`⌘S` 保存草稿，`⇧⌘S` 导出；副本保存在原图目录，重名自动编号。

## 设计理念

照片承载的不只是画面，还有时间、地点与故事。Memora 让这些信息成为可以轻松整理的记忆。

浅奶油黄白与磨砂玻璃营造安静的工作空间。开始页像薄纱一样渐显；照片中央清晰稳定，边缘的柔光、色散与四角拉伸让记忆缓缓浮现。所有视觉效果仅用于预览。

[开发说明](docs/DEVELOPMENT.md) · [设计说明](docs/DESIGN.md) · [第三方组件](docs/THIRD_PARTY.md)
