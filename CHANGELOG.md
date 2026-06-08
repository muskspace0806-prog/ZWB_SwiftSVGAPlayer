# Changelog

## [1.0.4] - 2026-06-08

### 修复
- 兼容旧版 SVGAPlayer 的 bitmap `nx/ny` 定位修正：播放带 transform 的 SVGA 素材时，减少首帧从右上角等偏移位置闪入的问题

### 发布
- CocoaPods 版本升级到 `1.0.4`
- README 同步更新 CocoaPods 与 SPM 集成示例

## [1.0.3] - 2026-06-05

### 性能优化
- 内存缓存淘汰维度由「个数」改为「内存成本（字节）」：基于 `NSCache.totalCostLimit`，按解码位图字节数计 cost，避免列表中 SVGA 数量略超阈值时反复重解码或内存暴涨
- 默认内存上限自适应：物理内存的 1/8，封顶 256MB，兜底 32MB
- 收到系统内存警告时自动清空内存缓存，降低被系统终止的风险

### 新增
- `SVGAPreloader` 公开预热 API：支持在列表数据加载完成时提前异步解析 SVGA，展示时直接命中内存缓存秒开
  - `SVGAPreloader.preload(_:maxConcurrent:)`
  - `SVGAPreloader.preload(urls:maxConcurrent:)`
  - `SVGAPreloader.preload(urlStrings:maxConcurrent:)`
  - 内置并发上限控制（默认 3），复用解析防重与多级缓存
- `SVGAMemoryCache` 公开缓存配置：`costLimit`（成本上限，字节）、`countLimit`（个数上限，0 表示不限）
- `SVGAVideo.estimatedMemoryCost`：估算单个动画的位图内存占用

### 修复
- 统一 SPM 与 CocoaPods 源码：`Package.swift` 改为指向 `Sources/SwiftSVGAPlayer`，与 Pod 共用同一份权威源码，修复此前 SPM 分发缺失 Public 类型的问题


## [1.0.2] - 2026-05-12

- 新增默认有效播放帧数计算，自动排除尾部连续空帧/哨兵帧
- 修复部分 SVGA 素材声明帧数、图片数量、sprite 帧数组不一致时循环闪屏的问题
- 修复 `play(range:)` 自定义播放区间会被播放控制器重置的问题
- `seek(toFrame:)` 自动限制到默认有效播放范围内，避免手动 seek 到尾部空帧

## [1.0.1] - 2026-05-12

- 修复 CocoaPods 集成后无法访问 `SwiftSVGAPlayerView` 的问题
- 恢复 UIKit 和 SwiftUI 播放器入口的公开 API

## [1.0.0] - 2026-05-11

- CocoaPods pod 名称调整为 `ZWB_SwiftSVGAPlayer`
- 版本同步到 `1.0.0`

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
