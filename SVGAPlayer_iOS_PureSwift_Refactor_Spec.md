# SVGAPlayer-iOS 纯 Swift 重构执行说明

> 目标读者：接手代码重构的 AI 编程工具 / iOS 工程师  
> 目标项目：基于 `svga/SVGAPlayer-iOS` 的能力，重构为纯 Swift、iOS 13+、CocoaPods 分发的 SVGA 播放器。  
> 重要约束：底层实现尽量全部使用 Swift，不再依赖 Objective-C 版 SVGAPlayer、pbobjc、GPBProtocolBuffers、SSZipArchive Objective-C 封装或原项目 Objective-C 源码。

---

## 1. 背景与参考结论

原始仓库：

- `svga/SVGAPlayer-iOS`
- GitHub: https://github.com/svga/SVGAPlayer-iOS
- 该仓库已归档，作者说明不会继续维护，也不会继续回复 issue。
- 原始实现主要是 Objective-C，核心模块包括：`SVGAParser`、`SVGAVideoEntity`、`SVGAPlayer`、`SVGAContentLayer`、`SVGABitmapLayer`、`SVGAVectorLayer`、`SVGAAudioLayer`、`pbobjc` 等。
- README 中说明该库使用 CoreAnimation 原生渲染 SVGA 动画。

社区参考：

- `Rogue24/SVGAPlayer_Optimized`
- GitHub: https://github.com/Rogue24/SVGAPlayer_Optimized
- 该项目主要优化点是：加载防重、API 简化、播放状态封装、可定制 downloader / loader / cache key、播放区间控制等。
- 但该项目仍依赖其 fork 的 `SVGAPlayer`，且包含 Objective-C 与 Swift 混合实现。
- 其 SPM 分支说明最低支持 iOS 15.5+，不满足本项目的 iOS 13+ 要求。

因此，本项目不能直接照搬 Rogue24 的依赖结构；只能参考其设计思想，例如：

- 加载防重
- 简化 API
- 播放状态机
- 自定义远程下载器
- 自定义资源加载器
- 自定义缓存 key
- 停止场景控制
- 播放区间控制
- 避免外部直接设置底层 videoItem

---

## 2. 最终目标

实现一个新的 Swift 库，暂定名：`SwiftSVGAPlayer`。

目标能力：

1. 纯 Swift 实现 SVGA 解析、模型、缓存、渲染、播放控制。
2. 最低支持 iOS 13.0。
3. 优先支持 CocoaPods 分发。
4. 不依赖原 Objective-C SVGAPlayer 源码。
5. 不依赖 pbobjc / GPBProtocolBuffers Objective-C runtime。
6. 不要求首版支持 SPM，但目录结构不要阻碍后续增加 SPM。
7. 对业务调用方提供现代 Swift API。
8. 尽量兼容原 `.svga` 文件格式，包括 zip / protobuf / image / sprite / frame / transform / matte / dynamic image / dynamic text / audio 等能力。
9. 保留 CoreAnimation 渲染路线，不要首版切换到 Metal。
10. 提供 Demo、单元测试、基础性能测试和迁移文档。

---

## 3. 强制技术约束

### 3.1 平台

```ruby
s.ios.deployment_target = '13.0'
```

### 3.2 语言

```ruby
s.swift_version = '5.0'
```

可使用 Swift 5.x 能力，但必须确认 iOS 13 可用。

### 3.3 禁止事项

重构后的主库代码中禁止出现：

- `.m`
- `.mm`
- `.h`
- Objective-C category
- `@objc` 暴露给 Objective-C 的兼容层，除非是必要的 UIKit runtime 场景
- `SVGAPlayer.h/m`
- `SVGAParser.h/m`
- `SVGAVideoEntity.h/m`
- `Svga.pbobjc.h/m`
- `GPBProtocolBuffers`
- `SSZipArchive` 的 Objective-C 封装
- 原 SVGAPlayer Objective-C 源码直接拷贝

允许：

- 使用 Swift 调用系统框架：UIKit、QuartzCore、CoreGraphics、Foundation、AVFoundation、ImageIO、Compression。
- 使用 Swift 第三方库，但必须满足 iOS 13+。
- 使用 SwiftProtobuf，前提是通过 `.proto` 重新生成 Swift 类型，而不是使用 pbobjc。
- 使用 Swift ZIP 库，例如 ZIPFoundation，前提是版本支持 iOS 13。

### 3.4 分发

首版必须提供 CocoaPods podspec。

示例：

```ruby
Pod::Spec.new do |s|
  s.name             = 'SwiftSVGAPlayer'
  s.version          = '0.1.0'
  s.summary          = 'A pure Swift SVGA animation player for iOS 13+'
  s.homepage         = 'https://github.com/<owner>/SwiftSVGAPlayer'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { '<owner>' => '<email>' }
  s.source           = { :git => 'https://github.com/<owner>/SwiftSVGAPlayer.git', :tag => s.version.to_s }
  s.ios.deployment_target = '13.0'
  s.swift_version    = '5.0'
  s.source_files     = 'Sources/SwiftSVGAPlayer/**/*.swift'
  s.resource_bundles = {
    'SwiftSVGAPlayer' => ['Sources/SwiftSVGAPlayer/PrivacyInfo.xcprivacy']
  }
  s.frameworks       = 'UIKit', 'QuartzCore', 'CoreGraphics', 'Foundation', 'AVFoundation', 'ImageIO', 'Compression'
  s.dependency 'SwiftProtobuf'
  # 如使用 ZIPFoundation，则添加：
  # s.dependency 'ZIPFoundation'
end
```

---

## 4. 推荐目录结构

```text
SwiftSVGAPlayer/
├── SwiftSVGAPlayer.podspec
├── README.md
├── LICENSE
├── CHANGELOG.md
├── Sources/
│   └── SwiftSVGAPlayer/
│       ├── Public/
│       │   ├── SwiftSVGAPlayerView.swift
│       │   ├── SVGASource.swift
│       │   ├── SVGALoopMode.swift
│       │   ├── SVGAPlaybackState.swift
│       │   ├── SVGAStopScene.swift
│       │   └── SVGADynamicItem.swift
│       ├── Parser/
│       │   ├── SVGAParser.swift
│       │   ├── SVGADecoder.swift
│       │   ├── SVGABinaryDecoder.swift
│       │   ├── SVGAJSONDecoder.swift
│       │   ├── SVGAArchiveReader.swift
│       │   └── SVGAResourceLoader.swift
│       ├── Protobuf/
│       │   ├── Svga.pb.swift
│       │   └── README.md
│       ├── Model/
│       │   ├── SVGAVideo.swift
│       │   ├── SVGASprite.swift
│       │   ├── SVGAFrame.swift
│       │   ├── SVGALayout.swift
│       │   ├── SVGATransform.swift
│       │   ├── SVGAShape.swift
│       │   ├── SVGAAudio.swift
│       │   └── SVGAImageResource.swift
│       ├── Render/
│       │   ├── SVGARenderLayer.swift
│       │   ├── SVGASpriteLayer.swift
│       │   ├── SVGABitmapLayer.swift
│       │   ├── SVGAVectorLayer.swift
│       │   ├── SVGAMatteLayer.swift
│       │   ├── SVGADynamicRenderer.swift
│       │   └── SVGALayerPool.swift
│       ├── Playback/
│       │   ├── SVGAPlaybackController.swift
│       │   ├── SVGADisplayLinkDriver.swift
│       │   ├── SVGATimeline.swift
│       │   └── SVGAFrameRange.swift
│       ├── Cache/
│       │   ├── SVGACache.swift
│       │   ├── SVGAMemoryCache.swift
│       │   ├── SVGADiskCache.swift
│       │   └── SVGACacheKeyGenerator.swift
│       ├── Network/
│       │   ├── SVGADownloader.swift
│       │   └── URLSessionSVGADownloader.swift
│       ├── Audio/
│       │   ├── SVGAAudioController.swift
│       │   └── SVGAAudioPlayer.swift
│       ├── Utils/
│       │   ├── SVGAError.swift
│       │   ├── SVGALogger.swift
│       │   ├── Data+Inflate.swift
│       │   ├── UIImage+Decode.swift
│       │   └── DispatchQueue+SVGA.swift
│       └── PrivacyInfo.xcprivacy
├── Example/
│   └── SwiftSVGAPlayerExample/
└── Tests/
    └── SwiftSVGAPlayerTests/
```

---

## 5. Public API 设计

### 5.1 基础使用

目标调用方式：

```swift
let player = SwiftSVGAPlayerView()
view.addSubview(player)

try await player.load(.url(url))
player.play(loop: .count(1))
```

一行播放：

```swift
player.play(.url(url), loop: .forever)
```

本地资源：

```swift
try await player.load(.named("gift", bundle: .main))
player.play()
```

Data：

```swift
try await player.load(.data(data, cacheKey: "gift_001"))
player.play(loop: .count(3))
```

### 5.2 Source

```swift
public enum SVGASource: Equatable {
    case url(URL)
    case fileURL(URL)
    case data(Data, cacheKey: String?)
    case named(String, bundle: Bundle = .main)
}
```

如 `Data` 无法直接实现 `Equatable`，可去掉 `Equatable`，或只对 cacheKey / URL 做内部标识。

### 5.3 播放循环

```swift
public enum SVGALoopMode: Equatable {
    case once
    case count(Int)
    case forever
}
```

### 5.4 播放状态

```swift
public enum SVGAPlaybackState: Equatable {
    case idle
    case loading
    case ready
    case playing
    case paused
    case stopped
    case completed
    case failed(SVGAError)
}
```

如果 `SVGAError` 不适合 `Equatable`，状态可以去掉 `Equatable`。

### 5.5 停止场景

参考 Rogue24 的停止场景思想，但用 Swift API 表达：

```swift
public enum SVGAStopScene: Equatable {
    case clearLayers
    case stepToLeading
    case stepToTrailing
    case keepCurrentFrame
}
```

### 5.6 PlayerView

```swift
public final class SwiftSVGAPlayerView: UIView {
    public var contentMode: UIView.ContentMode
    public var isMuted: Bool
    public var isReversed: Bool
    public var isDebugLogEnabled: Bool
    public var clearsAfterStop: Bool

    public private(set) var state: SVGAPlaybackState
    public private(set) var currentFrame: Int
    public private(set) var totalFrames: Int
    public private(set) var progress: Double

    public var onStateChange: ((SVGAPlaybackState) -> Void)?
    public var onFrameChange: ((_ frame: Int, _ progress: Double) -> Void)?
    public var onCompletion: (() -> Void)?
    public var onError: ((SVGAError) -> Void)?

    public func load(_ source: SVGASource) async throws
    public func play()
    public func play(loop: SVGALoopMode)
    public func play(_ source: SVGASource, loop: SVGALoopMode)
    public func play(range: Range<Int>, loop: SVGALoopMode)
    public func pause()
    public func resume()
    public func stop(then scene: SVGAStopScene)
    public func seek(toFrame frame: Int)
    public func seek(progress: Double)
    public func clear()

    public func setImage(_ image: UIImage?, forKey key: String)
    public func setImageURL(_ url: URL?, forKey key: String)
    public func setText(_ text: NSAttributedString?, forKey key: String)
    public func setHidden(_ hidden: Bool, forKey key: String)
    public func setDrawing(_ drawing: SVGADrawingBlock?, forKey key: String)
}
```

### 5.7 Dynamic drawing

```swift
public typealias SVGADrawingBlock = (_ context: CGContext, _ frame: CGRect, _ frameIndex: Int) -> Void
```

---

## 6. 模块职责

### 6.1 Parser

`SVGAParser` 只负责将 `SVGASource` 解析为 `SVGAVideo`。

```swift
public protocol SVGAParsing {
    func parse(_ source: SVGASource) async throws -> SVGAVideo
}
```

职责：

1. 判断 source 类型。
2. 下载远程 `.svga` 文件。
3. 读取本地 `.svga` 文件。
4. 解压 zip 格式。
5. 解析 `movie.binary`。
6. 兼容旧格式 `movie.spec` JSON。
7. 解析图片资源。
8. 解析音频资源。
9. 生成 Swift 模型。
10. 缓存解析结果。

Parser 不应该：

- 持有 UIView。
- 直接操作 CALayer。
- 直接控制播放。
- 把网络、缓存、解压逻辑写死在一个大类中。

### 6.2 Protobuf

必须使用 SwiftProtobuf 或自研轻量 Protobuf 解析。

优先方案：

1. 从原 SVGA `.proto` 文件生成 `Svga.pb.swift`。
2. 使用 SwiftProtobuf 解码 `movie.binary`。
3. 将 Protobuf 类型转换为内部 Swift value model。

禁止使用：

- `Svga.pbobjc.h`
- `Svga.pbobjc.m`
- `GPBMessage`
- `GPBProtocolBuffers`

### 6.3 Archive / Zip

`.svga` 本质上通常是压缩包，包含：

```text
movie.binary
movie.spec
images...
audios...
```

首选方案：

- 使用 `ZIPFoundation`，前提是 iOS 13+ 可用。

备选方案：

- 使用 Foundation / Compression 自行处理常见 zip entry。

封装协议：

```swift
protocol SVGAArchiveReading {
    func readEntries(from data: Data) throws -> [String: Data]
}
```

不要把具体 ZIP 库泄漏到 public API。

### 6.4 Model

内部模型必须是 Swift 原生类型。

```swift
public struct SVGAVideo {
    public let size: CGSize
    public let fps: Int
    public let frames: Int
    public let sprites: [SVGASprite]
    public let images: [String: SVGAImageResource]
    public let audios: [SVGAAudio]
}
```

```swift
public struct SVGASprite {
    public let imageKey: String?
    public let matteKey: String?
    public let frames: [SVGAFrame]
    public let shapes: [SVGAShape]
}
```

```swift
public struct SVGAFrame {
    public let alpha: CGFloat
    public let layout: SVGALayout
    public let transform: CGAffineTransform
    public let clipPath: CGPath?
    public let shapes: [SVGAShape]
}
```

### 6.5 Render

渲染继续使用 CoreAnimation。

核心类：

```swift
final class SVGARenderLayer: CALayer {
    func configure(video: SVGAVideo)
    func step(to frame: Int, dynamicItems: SVGADynamicItems)
    func clear()
}
```

职责：

1. 根据 `SVGAVideo` 构建 sprite layer。
2. 逐帧应用 frame 数据。
3. 更新 bitmap layer。
4. 更新 vector layer。
5. 更新 matte / mask。
6. 应用动态图片、动态文字、隐藏、绘制。
7. 做 layer 复用，避免重复构建。

性能要求：

- 同一个 video 重复播放时，不应该重复构建全部 layer。
- seek / pause / resume 不应该触发重新解析。
- 动态替换图片不应该触发重新解析。
- 停止后是否清理 layer 由 `SVGAStopScene` 控制。

### 6.6 Playback

播放控制必须从 View 中拆出。

```swift
final class SVGAPlaybackController {
    var state: SVGAPlaybackState { get }
    var currentFrame: Int { get }
    var range: Range<Int> { get set }
    var loopMode: SVGALoopMode { get set }
    var isReversed: Bool { get set }

    func play()
    func pause()
    func resume()
    func stop()
    func seek(toFrame frame: Int)
}
```

`CADisplayLink` 封装：

```swift
final class SVGADisplayLinkDriver {
    func start(fps: Int, tick: @escaping () -> Void)
    func stop()
    func pause()
    func resume()
}
```

iOS 13 下不能依赖过新的 API。

### 6.7 Network

远程加载必须可替换。

```swift
public protocol SVGADownloading {
    func download(from url: URL) async throws -> Data
}
```

默认实现：

```swift
public final class URLSessionSVGADownloader: SVGADownloading {
    public func download(from url: URL) async throws -> Data
}
```

iOS 13 支持 async/await 的运行时部署需要注意兼容；如项目最低编译工具链允许，可以使用 Swift concurrency back deployment。若目标环境不稳定，则提供 completion 版本作为内部兼容层。

### 6.8 Cache

缓存拆成三层：

1. 原始 data 缓存。
2. 解压 entry 缓存，可选。
3. 解析后的 `SVGAVideo` 内存缓存。

协议：

```swift
public protocol SVGACacheKeyGenerating {
    func cacheKey(for source: SVGASource) -> String?
}

public protocol SVGAVideoCaching {
    func video(forKey key: String) -> SVGAVideo?
    func store(_ video: SVGAVideo, forKey key: String)
    func removeVideo(forKey key: String)
    func removeAllVideos()
}
```

默认行为：

- URL 使用 absoluteString 生成 hash。
- Data 必须显式传入 cacheKey，否则不缓存解析结果。
- named/fileURL 使用路径生成 key。

### 6.9 Audio

音频功能首版可以降低优先级，但不要破坏模型设计。

目标：

- 能解析 audio resource。
- 能根据播放状态同步开始、暂停、停止。
- 支持 muted。
- 支持 seek 到帧时同步音频位置。

可使用 AVFoundation。

---

## 7. 兼容功能清单

首版必须支持：

- 加载 bundle `.svga`
- 加载 fileURL `.svga`
- 加载 remote URL `.svga`
- 加载 Data `.svga`
- Protobuf `movie.binary`
- JSON `movie.spec`，如实现成本过高可列为 beta，但需保留接口位置
- bitmap sprite
- basic transform
- alpha
- layout frame
- loop once / count / forever
- play / pause / resume / stop
- seek frame
- seek progress
- clear layers
- dynamic image
- dynamic text
- hide element
- playback range
- loading de-duplication
- memory cache
- disk data cache

第二阶段支持：

- vector shape 完整能力
- matte layer
- dynamic matte bitmap
- audio frame sync
- reverse playback
- drawing block
- layer pool 深度优化
- SwiftUI wrapper
- SPM

---

## 8. 加载防重设计

参考 Rogue24 思路，但用 Swift 原生实现。

需求：

同一个 player 在加载 source A 的过程中，如果再次请求 source B：

- A 的结果不得覆盖 B。
- 以最新请求为准。
- 老请求完成后应被忽略或取消。

同一个 source 被多个 player 同时请求：

- 可以共享下载任务。
- 可以共享解析任务。
- 不应重复下载。

建议：

```swift
actor SVGALoadCoordinator {
    private var tasks: [String: Task<SVGAVideo, Error>] = [:]

    func load(key: String, operation: @escaping () async throws -> SVGAVideo) async throws -> SVGAVideo
}
```

如必须兼容不使用 actor 的实现，可用 serial queue + dictionary。

---

## 9. 错误类型

```swift
public enum SVGAError: Error, Equatable, CustomStringConvertible {
    case invalidSource
    case fileNotFound
    case downloadFailed(String)
    case invalidData
    case unzipFailed(String)
    case missingMovieFile
    case protobufDecodeFailed(String)
    case jsonDecodeFailed(String)
    case imageDecodeFailed(String)
    case unsupportedFeature(String)
    case cancelled
    case internalError(String)
}
```

所有 public async API 必须 throw `SVGAError` 或可被转换为 `SVGAError`。

---

## 10. CocoaPods 要求

必须保证：

```bash
pod lib lint SwiftSVGAPlayer.podspec --allow-warnings
```

可以通过。

Example Podfile：

```ruby
platform :ios, '13.0'

use_frameworks!

target 'SwiftSVGAPlayerExample' do
  pod 'SwiftSVGAPlayer', :path => '../'
end
```

---

## 11. Demo 要求

Example App 至少包含：

1. 本地 bundle 播放。
2. URL 播放。
3. Data 播放。
4. 循环播放。
5. 播放区间。
6. pause / resume / stop。
7. seek slider。
8. dynamic image。
9. dynamic text。
10. hide element。
11. clear layer / keep current frame / step to leading / step to trailing。
12. debug log 开关。
13. 内存缓存开关。
14. loading de-duplication 示例。

---

## 12. 测试要求

### 12.1 单元测试

至少覆盖：

- `SVGASource` cache key。
- URL source 加载。
- fileURL source 加载。
- named source 加载。
- Data source 加载。
- zip entries 读取。
- `movie.binary` 解码。
- protobuf model 映射。
- image decode。
- playback range 合法性。
- loop count 计算。
- stop scene 行为。
- seek frame 边界。
- loading de-duplication。
- memory cache 命中。
- parser cancel 后不回写旧结果。

### 12.2 快照或视觉验证

如果可行，增加固定 SVGA 文件的帧渲染快照测试：

- frame 0
- middle frame
- last frame

允许先输出 `UIImage` 进行人工比对。

### 12.3 性能测试

至少记录：

- 首次 parse 耗时。
- 缓存命中 parse 耗时。
- layer 构建耗时。
- 播放时主线程平均 frame cost。
- 内存峰值。

---

## 13. 分阶段执行计划

### Phase 0：仓库初始化

交付：

- 新建 SwiftSVGAPlayer 仓库结构。
- 添加 podspec。
- 添加 Example。
- 添加基础 CI，至少跑 `xcodebuild test` 和 `pod lib lint`。
- 添加 README 初稿。

验收：

- 空库可以被 Pod 引入。
- Example 可以启动。

### Phase 1：纯 Swift 模型与 source/cache/downloader

交付：

- `SVGASource`
- `SVGAError`
- `SVGACacheKeyGenerator`
- `SVGADownloader`
- `URLSessionSVGADownloader`
- `SVGAMemoryCache`
- `SVGADiskCache`

验收：

- URL / Data / fileURL / named 能读到 Data。
- cache key 单测通过。
- 不引入任何 Objective-C 文件。

### Phase 2：Archive 与 Protobuf 解析

交付：

- Swift archive reader。
- SwiftProtobuf 集成。
- `Svga.pb.swift`。
- `SVGABinaryDecoder`。
- Protobuf 类型映射到 Swift model。

验收：

- 可以解析至少 3 个真实 `.svga` 文件。
- 可以拿到 size / fps / frames / sprites / images。
- 无 pbobjc / GPB 依赖。

### Phase 3：基础渲染

交付：

- `SVGARenderLayer`
- `SVGASpriteLayer`
- `SVGABitmapLayer`
- bitmap sprite 渲染。
- alpha / transform / layout。

验收：

- 本地 SVGA 可显示第一帧。
- 可 step 到指定帧。
- 简单动画肉眼播放正常。

### Phase 4：播放控制

交付：

- `SVGAPlaybackController`
- `SVGADisplayLinkDriver`
- `SwiftSVGAPlayerView`
- play / pause / resume / stop / seek / loop / range。

验收：

- Example 可完整播放。
- range 播放正确。
- loop count 正确。
- stop scene 正确。

### Phase 5：动态内容

交付：

- dynamic image。
- dynamic URL image。
- dynamic text。
- hide element。
- drawing block，若首版时间不够可延后。

验收：

- 可替换 SVGA 中指定 key 的头像/昵称。
- 替换不触发重新解析。

### Phase 6：高级兼容

交付：

- vector shape。
- matte layer。
- dynamic matte bitmap。
- audio。
- reverse playback。

验收：

- 使用原 SVGAPlayer 官方示例资源对比主要效果。
- 若有不兼容项，在 README 中列明。

### Phase 7：发布准备

交付：

- README 完整使用说明。
- Migration Guide。
- API 文档。
- CHANGELOG。
- LICENSE。
- pod lib lint 通过。
- tag `0.1.0`。

---

## 14. 给代码 AI 的执行提示词

可以将下面这段直接交给代码 AI：

```text
你是资深 iOS SDK 工程师。请根据本仓库中的《SVGAPlayer-iOS 纯 Swift 重构执行说明》实现一个新的 SwiftSVGAPlayer 库。

硬性要求：
1. 纯 Swift 实现，最低支持 iOS 13.0。
2. 以 CocoaPods 作为首要分发方式。
3. 不得复用原 svga/SVGAPlayer-iOS 的 Objective-C 源码。
4. 不得使用 pbobjc、GPBProtocolBuffers、SSZipArchive Objective-C 封装。
5. 可使用 SwiftProtobuf 重新生成 Swift protobuf 模型。
6. 可使用支持 iOS 13 的 Swift ZIP 库，或自行实现 zip entry 读取。
7. 先实现 MVP：加载本地/URL/Data svga、解析 movie.binary、显示 bitmap 动画、播放/暂停/停止/seek/loop/range、dynamic image/text、基础缓存、loading 去重。
8. 每个阶段必须补充单元测试和 Example 页面。
9. 若遇到 SVGA 格式兼容问题，不要跳过；请在 TODO_COMPATIBILITY.md 中记录具体文件、缺失字段、预期行为和当前行为。
10. 提交代码时保持模块边界清晰：Parser 不渲染，Render 不下载，Playback 不解析。

请从 Phase 0 开始逐步实现，每完成一个 Phase 输出变更摘要、测试结果和下一步计划。
```

---

## 15. 验收标准

最终 `0.1.0` 至少满足：

- [ ] `pod install` 成功。
- [ ] Example App 能运行在 iOS 13 模拟器。
- [ ] 项目源码无 `.m` / `.mm` / `.h`。
- [ ] 主库无 Objective-C SVGAPlayer 依赖。
- [ ] 主库无 pbobjc / GPBProtocolBuffers 依赖。
- [ ] 可播放本地 `.svga`。
- [ ] 可播放远程 `.svga`。
- [ ] 可播放 Data `.svga`。
- [ ] 支持 play / pause / resume / stop。
- [ ] 支持 seek frame / progress。
- [ ] 支持 loop once / count / forever。
- [ ] 支持 playback range。
- [ ] 支持 dynamic image。
- [ ] 支持 dynamic text。
- [ ] 支持 hide element。
- [ ] 支持 loading de-duplication。
- [ ] 支持 memory cache。
- [ ] README 写明已支持和暂不支持能力。
- [ ] podspec lint 通过。

---

## 16. 重要实现建议

1. 不要第一步就追求 100% 兼容所有 SVGA 特性。先把 parser + bitmap playback 跑通。
2. 不要把 `UIView` 写成巨型类。播放器状态必须拆出去。
3. 不要让 parser 持有 view 或 layer。
4. 不要让 render 触发网络下载。
5. 不要让 dynamic image/text 触发重新 parse。
6. 不要照搬 Rogue24 的继承/兼容旧 API 思路。本项目目标是新 Swift API，而不是兼容 Objective-C API。
7. 不要使用原项目的 `videoItem` 命名作为 public API；可以内部有 `SVGAVideo`。
8. 对调用方隐藏 protobuf、zip、cache 细节。
9. 所有耗时任务离开主线程。
10. 所有 UI / CALayer 更新回到主线程。
11. 对 iOS 13 做真机或模拟器验证，不要只在新系统验证。

---

## 17. 迁移对照

旧用法：

```objc
SVGAParser *parser = [[SVGAParser alloc] init];
SVGAPlayer *player = [[SVGAPlayer alloc] initWithFrame:frame];
[parser parseWithURL:url completionBlock:^(SVGAVideoEntity *videoItem) {
    player.videoItem = videoItem;
    [player startAnimation];
} failureBlock:nil];
```

新用法：

```swift
let player = SwiftSVGAPlayerView(frame: frame)
view.addSubview(player)

try await player.load(.url(url))
player.play(loop: .once)
```

旧动态图片：

```objc
[player setImage:image forKey:@"avatar"];
```

新动态图片：

```swift
player.setImage(image, forKey: "avatar")
```

旧停止：

```objc
[player stopAnimation];
```

新停止：

```swift
player.stop(then: .keepCurrentFrame)
```

---

## 18. 风险点

### 18.1 Protobuf 兼容

风险：不同 SVGA 文件可能来自不同导出工具版本。  
处理：保留官方样例 + 业务真实样例作为测试集；字段缺失要有默认值。

### 18.2 Zip 兼容

风险：部分 `.svga` 文件 zip entry 命名或压缩方式不同。  
处理：ArchiveReader 要输出 entries 列表，方便 debug。

### 18.3 Vector shape

风险：CAShapeLayer 路径和 AE 导出效果不完全一致。  
处理：首版优先 bitmap sprite，vector shape 第二阶段补齐。

### 18.4 Matte

风险：mask 层级和动态 mask bitmap 容易出兼容问题。  
处理：单独建立 matte 测试样例。

### 18.5 音频同步

风险：AVAudioPlayer 与 frame seek 同步复杂。  
处理：首版允许默认关闭音频，第二阶段完善。

### 18.6 Swift concurrency 与 iOS 13

风险：async/await 在 iOS 13 依赖 back deployment，部分老项目工具链可能有问题。  
处理：public API 可以提供 async 版本，同时内部保留 completion 版本或兼容封装。

---

## 19. 首版 MVP 范围建议

首版不要贪大。建议 `0.1.0` 定义为：

必须有：

- CocoaPods 集成。
- iOS 13+。
- 纯 Swift。
- 加载本地/远程/Data。
- 解 zip。
- 解析 `movie.binary`。
- bitmap sprite 播放。
- play/pause/resume/stop/seek/loop/range。
- dynamic image/text/hide。
- loading de-dup。
- memory cache。
- Example。

可以暂缓：

- 完整 vector shape。
- 完整 matte。
- audio 同步。
- SwiftUI。
- SPM。
- 完整 public Objective-C 兼容。

---

## 20. 最终产物

完成后仓库应包含：

```text
SwiftSVGAPlayer.podspec
Sources/SwiftSVGAPlayer/**/*.swift
Example/
Tests/
README.md
CHANGELOG.md
MigrationGuide.md
TODO_COMPATIBILITY.md
LICENSE
```

并能通过：

```bash
pod install
pod lib lint SwiftSVGAPlayer.podspec --allow-warnings
xcodebuild test
```

