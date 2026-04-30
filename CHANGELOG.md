# Changelog

## [0.1.0] - 2026-04-30

### Added
- 纯 Swift 实现，iOS 13+，无 Objective-C 依赖
- 自研轻量 Protobuf 解析器（无需 SwiftProtobuf / pbobjc）
- 纯 Swift ZIP 解析器（无需 SSZipArchive / ZIPFoundation）
- `SVGASource`：支持 url / fileURL / data / named
- `SVGALoopMode`：once / count / forever
- `SVGAPlaybackState`：完整状态机
- `SVGAStopScene`：clearLayers / stepToLeading / stepToTrailing / keepCurrentFrame
- `SwiftSVGAPlayerView`：完整 Public API
- `SVGAParser`：异步解析，支持 movie.binary（Protobuf）和 movie.spec（JSON）
- `SVGAMemoryCache`：基于 NSCache 的内存缓存
- `SVGADiskCache`：原始 Data 磁盘缓存
- `SVGACacheKeyGenerator`：MD5 缓存 key 生成
- `URLSessionSVGADownloader`：可替换的远程下载器
- `SVGALoadCoordinator`：actor-based 加载防重
- `SVGARenderLayer`：CoreAnimation 渲染
- `SVGAPlaybackController`：播放控制（帧推进、loop、range、seek）
- `SVGADisplayLinkDriver`：CADisplayLink 封装
- `SVGAAudioController`：基础音频同步（AVFoundation）
- Dynamic image / text / hidden 支持
- CocoaPods podspec

### Known Limitations (Phase 2+)
- Vector shape 完整渲染（Phase 6）
- Matte layer（Phase 6）
- Audio 完整同步（Phase 6）
- Reverse playback（Phase 6）
- Drawing block（Phase 5）
- SwiftUI wrapper（Phase 7）
- SPM 支持（Phase 7）
