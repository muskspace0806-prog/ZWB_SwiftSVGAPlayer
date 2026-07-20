# Changelog

## [1.0.11] - 2026-07-20

### 修复
- 修复 iOS 26 下个人主页勋章跑马灯等大量 SVGA 播放器场景中，页面返回或导航转场后仍可能卡顿的问题
- `CADisplayLink` 改为默认 RunLoop mode 驱动，避免滚动、手势追踪和导航转场阶段继续刷新大量 SVGA
- 播放器被隐藏、透明、未挂载到 `window`，或被父视图裁剪到可见区域外时，跳过当前帧图层渲染与音频帧更新

### 文档
- README / README_EN 同步更新 CocoaPods 与 SPM 集成示例到 `1.0.11`
- README / README_EN 新增转场与可见区域渲染说明

### 发布
- CocoaPods 版本升级到 `1.0.11`
- SPM 通过 Git tag `1.0.11` 分发

## [1.0.10] - 2026-07-20

### 修复
- 修复 iOS 26.5/26.5.2 上页面 push/pop 后，离屏 `SwiftSVGAPlayerView` 仍可能持续驱动 `CADisplayLink`，导致内存持续增长或页面卡顿的问题
- `SwiftSVGAPlayerView` 离开 `window` 时自动暂停播放，重新挂载到 `window` 后按需恢复播放，避免离屏动画继续刷新
- 修复 `play(_:)` 异步加载任务的生命周期管理，避免旧任务完成后回写到已经离开的播放器
- `stop()` / `clear()` 会取消当前加载任务并清理自动恢复播放标记

### 文档
- README / README_EN 同步更新 CocoaPods 与 SPM 集成示例到 `1.0.10`
- README / README_EN 新增生命周期与内存释放说明

### 发布
- CocoaPods 版本升级到 `1.0.10`
- SPM 通过 Git tag `1.0.10` 分发

## [1.0.9] - 2026-06-29

### 修复
- 修复 SVGA 2.x 官方 Protobuf vector shape 字段号兼容问题，支持 `shapeArgs` / `rectArgs` / `ellipseArgs` / `styles` / `transform` 官方字段布局
- 修复纯 `.vector` 素材只显示在左上角或位置异常的问题，矢量路径现在会正确合成 frame transform 与 shape transform
- 修复圆角矩形参数丢失问题，支持 `cornerRadius` 渲染
- 支持官方 `RGBAColor` 样式消息解析，修复 vector shape fill / stroke 样式丢失导致不可见的问题

### 文档
- README / README_EN 同步更新 CocoaPods 与 SPM 集成示例到 `1.0.9`
- 新增 `test05.svga` 纯 vector shape 兼容性验证素材

## [1.0.8] - 2026-06-15

### 修复
- 修复动态图片先于 `play(_:)` 设置时，SVGA 加载完成重建渲染图层会清空 `dynamicItems`，导致远程图片偶发不显示的问题
- `configure(video:)` 重建 sprite layer 时保留已设置的动态内容；用户主动 `clear()` 时仍会清理动态图层状态

### 文档
- README 顶部新增 `中文 | English` 语言切换
- 新增英文 README：`README_EN.md`
- README 同步更新 CocoaPods 与 SPM 集成示例到 `1.0.8`

## [1.0.7] - 2026-06-15

### 修复
- 远程动态图片下载完成后统一回到主线程更新渲染层，避免后台线程改动 `CALayer` 导致动态图片不刷新或不显示
- 远程动态图片设置成功后主动刷新当前帧，确保播放前后异步返回的图片都能立即展示

### 发布
- CocoaPods 版本升级到 `1.0.7`
- README 同步更新 CocoaPods 与 SPM 集成示例

## [1.0.6] - 2026-06-15

### 新增
- 新增 `SVGADynamicImageOptions`，支持动态图片按 `.aspectFit` / `.aspectFill` / `.scaleToFill` 渲染
- 新增动态图片圆角能力：`.fixed(_:)` 固定圆角与 `.circle` 自动圆形裁剪
- `SwiftSVGAPlayerView` 新增 `setImage(_:forKey:options:)` 与 `setImageURL(_:forKey:options:)` 重载，旧 API 保持兼容

### 发布
- CocoaPods 版本升级到 `1.0.6`
- README 同步更新 CocoaPods、SPM 与动态头像圆形裁剪示例

## [1.0.5] - 2026-06-08

### 修复
- Bitmap 渲染改为完全对齐旧版 SVGAPlayer 的中心锚点 `nx/ny` 修正流程，避免带 transform 素材首帧从对角线偏移位置补间到目标点
- 播放启动前立即渲染起始帧，避免首个 display link tick 前从 layer 默认位置闪入
- 关闭核心渲染 layer 的隐式动画 action，避免 cell 刷新或 UIKit 动画事务触发 position/transform 自动补间

### 发布
- CocoaPods 版本升级到 `1.0.5`
- README 同步更新 CocoaPods 与 SPM 集成示例

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
