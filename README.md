# SwiftSVGAPlayer

[![Platform](https://img.shields.io/badge/platform-iOS%2013%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.0+-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![SPM](https://img.shields.io/badge/SPM-supported-brightgreen.svg)](Package.swift)
[![CocoaPods](https://img.shields.io/badge/CocoaPods-supported-brightgreen.svg)](ZWB_SwiftSVGAPlayer.podspec)

**中文 | [English](README_EN.md)**

**SwiftSVGAPlayer** 是一个以 Swift 实现核心解析与渲染的 SVGA 动画播放器，支持 iOS 13+，提供现代 Swift API、SwiftUI 支持和动态 GIF/WebP 替换能力。

---

## 特性

### Swift 核心实现
- 核心 SVGA 解析、播放与渲染代码使用 Swift 实现
- 无 pbobjc / GPBProtocolBuffers
- 无 SSZipArchive
- 自研轻量 Protobuf 解析器（支持 SVGA 2.x）
- 自研 ZIP 解析器（Store + Deflate，系统 Compression 框架）
- 支持 zlib 直接压缩格式（`78 9C` 头）和 ZIP 包格式（`PK` 头）

### 完整功能
- ✅ 加载 bundle / fileURL / remote URL / Data
- ✅ Protobuf `movie.binary` 解析
- ✅ JSON `movie.spec` 解析（含 shapes / clipPath）
- ✅ Bitmap sprite 渲染（CoreAnimation）
- ✅ Vector shape 渲染（完整 SVG path：M/L/H/V/C/S/Q/T/A/Z，含椭圆弧；支持 SVGA 2.x 官方 shape 字段、RGBA 样式、圆角矩形）
- ✅ Matte layer（遮罩，matteKey 对应 sprite 作为 CALayer mask）
- ✅ Alpha / transform / layout / clipPath
- ✅ 兼容旧版 SVGAPlayer bitmap `nx/ny` 定位修正，减少带 transform 素材的起始位置偏移和首帧补间
- ✅ Loop once / count / forever
- ✅ Play / pause / resume / stop / seek
- ✅ Reverse playback（反向播放）
- ✅ Playback range（播放区间）
- ✅ Dynamic image / imageURL / text / hidden / drawing block
- ✅ Infinite scrolling marquee text（把任意命名槽位替换成无缝滚动文本，支持方向 / 阿语 RTL / 间距 / 速度 / 字体 / 颜色，自研无三方依赖）
- ✅ Dynamic GIF / animated WebP URL replacement（基于 Kingfisher + KingfisherWebP，SDWebImage 运行时兜底）
- ✅ Loading de-duplication（actor-based 加载防重）
- ✅ Memory cache（NSCache）
- ✅ Disk data cache
- ✅ Audio 基础播放 + 帧同步（AVFoundation）
- ✅ SwiftUI wrapper（`SVGAPlayerView`）
- ✅ CocoaPods 分发
- ✅ SPM 分发

---

## 安装

### Swift Package Manager

在 `Package.swift` 中添加：

```swift
dependencies: [
    .package(url: "https://github.com/muskspace0806-prog/ZWB_SwiftSVGAPlayer.git", from: "1.0.15")
]
```

或在 Xcode 中：File → Add Package Dependencies → 输入仓库地址。

### CocoaPods

```ruby
pod 'ZWB_SwiftSVGAPlayer', '~> 1.0.15'
```

---

## 快速开始

### UIKit

```swift
import UIKit

let player = SwiftSVGAPlayerView()
player.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
view.addSubview(player)

// 加载并播放
Task {
    try await player.load(.url(URL(string: "https://example.com/gift.svga")!))
    player.play(loop: .forever)
}
```

### SwiftUI

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        SVGAPlayerView(source: .url(url), loop: .forever)
            .frame(width: 300, height: 300)
    }
}
```

带配置的 SwiftUI 用法：

```swift
SVGAPlayerView(source: .named("gift"), loop: .count(3))
    .svgaReversed(false)
    .svgaMuted(false)
    .svgaContentMode(.scaleAspectFit)
    .svgaDisplayLinkRunLoopMode(.common)
    .onSVGAComplete { print("播放完成") }
    .onSVGAError { error in print("错误: \(error)") }
    .frame(width: 300, height: 300)
```

---

## API 文档

### SVGASource — 资源来源

```swift
// 远程 URL
player.play(.url(URL(string: "https://example.com/gift.svga")!), loop: .forever)

// 本地文件
player.play(.fileURL(fileURL), loop: .once)

// Bundle 资源（自动搜索子目录）
player.play(.named("gift"), loop: .count(3))

// 原始 Data
player.play(.data(data, cacheKey: "gift_v2"), loop: .forever)
```

### SVGALoopMode — 循环模式

```swift
.once          // 播放一次
.count(3)      // 播放 3 次
.forever       // 无限循环
```

### SVGAPlaybackState — 播放状态

```swift
.idle / .loading / .ready / .playing / .paused / .stopped / .completed / .failed(error)
```

### SVGAStopScene — 停止场景

```swift
player.stop(then: .clearLayers)       // 清空图层（默认）
player.stop(then: .stepToLeading)     // 跳到第一帧
player.stop(then: .stepToTrailing)    // 跳到最后一帧
player.stop(then: .keepCurrentFrame)  // 保持当前帧
```

### 播放控制

```swift
player.play()
player.play(loop: .count(3))
player.play(range: 10..<30, loop: .forever)   // 区间播放
player.pause()
player.resume()
player.stop(then: .keepCurrentFrame)
player.seek(toFrame: 15)
player.seek(progress: 0.5)                    // 0.0 ~ 1.0
player.isReversed = true                      // 反向播放
player.clear()
```

### 生命周期、转场、RunLoop mode 与可见区域渲染

`SwiftSVGAPlayerView` 会在离开 `window` 时自动暂停播放，并在重新挂载到 `window` 后恢复需要继续播放的动画。
这可以避免页面 push/pop、cell 离屏或控制器返回后，离屏 SVGA 仍然通过 `CADisplayLink` 持续刷新。

从 `1.0.11` 开始，播放器使用默认 RunLoop mode 驱动帧刷新，滚动、手势追踪和导航转场阶段不会继续抢占主线程刷新大量 SVGA。
从 `1.0.12` 开始，可以按业务场景配置 `displayLinkRunLoopMode`。默认仍为 `.default`，列表 cell 等大量播放器场景无需修改；全屏礼物、直播返币等强展示动画如果需要在公屏列表拖动期间继续播放，可在播放前设置为 `.common`。

```swift
// 默认值，滚动和手势追踪期间不继续抢占主线程
player.displayLinkRunLoopMode = .default

// 全屏礼物、直播返币等强展示场景，允许滚动期间持续播放
player.displayLinkRunLoopMode = .common
```

如果播放器被隐藏、透明、未挂载到 `window`，或被父视图裁剪在可见区域外，也会跳过当前帧的图层渲染与音频帧更新。

从 `1.0.13` 开始，如果业务层已经托管可见范围（例如跑马灯父容器按低频定时器统一判断哪些复制视图需要播放），可以开启 `usesExternalVisibilityControl`，跳过播放器内部每帧层级裁剪判断，减少大量 SVGA 同时位移时的主线程开销。

```swift
// 仅在外部已经负责可见性裁剪时开启
player.usesExternalVisibilityControl = true
```

`play(_:)` 的异步加载任务也会在新的加载、`stop()`、`clear()` 或视图释放时取消，避免旧任务完成后回写到已经离开的播放器。`1.0.13` 额外公开 `cancelLoading()`，方便 cell 复用、跑马灯离开可见区等场景只取消加载任务并保留当前已加载内容。

```swift
// 推荐在 cell 复用或页面明确结束播放时主动清理
player.stop()
player.clear()

// 只想取消当前异步加载，不清空已渲染内容时使用
player.cancelLoading()
```

### 动态内容

```swift
// 替换图片
player.setImage(UIImage(named: "avatar"), forKey: "avatar")

// 远程图片（异步加载）
player.setImageURL(URL(string: "https://..."), forKey: "avatar")

// 远程头像：等比填充并按 SVGA 图层短边自动裁剪为圆形（1.0.6）
player.setImageURL(
    URL(string: "https://..."),
    forKey: "avatar",
    options: .circle()
)

// 动态图片可先于 play 设置；1.0.8 起加载 SVGA 时会保留已设置的动态内容
player.setImageURL(URL(string: "https://..."), forKey: "avatar", options: .circle())
player.play(.named("gift"), loop: .forever)

// 动态 GIF / WebP 替换：外部传字符串，内部下载并判断是否为动图（1.0.14）
player.setAnimatedImageURL("https://example.com/avatar.webp", forKey: "avatar")

// 动态头像：与静态图片一致支持圆形裁剪；播放完成、stop 或 clear 时会自动销毁动图覆盖层
player.setAnimatedImageURL(
    "https://example.com/avatar.gif",
    forKey: "avatar",
    options: .circle(contentMode: .aspectFill)
)

// 自定义动态图片渲染：contentMode / 固定圆角 / 裁剪
let imageOptions = SVGADynamicImageOptions(
    contentMode: .aspectFill,
    cornerRadius: .fixed(24),
    clipsToBounds: true
)
player.setImage(UIImage(named: "avatar"), forKey: "avatar", options: imageOptions)

// 富文本
let attr = NSAttributedString(string: "Hello", attributes: [.foregroundColor: UIColor.red])
player.setText(attr, forKey: "nickname")

// 隐藏元素
player.setHidden(true, forKey: "background")

// 自定义绘制
player.setDrawing({ context, rect, frameIndex in
    context.setFillColor(UIColor.red.cgColor)
    context.fill(rect)
}, forKey: "custom")
```

### 跑马灯（无限滚动文本，1.0.15）

把一个命名槽位（例如设计稿里叫 `id` 的那个 63×21 占位图）替换成无缝循环的滚动文本。完全自研实现，不引入 `MarqueeLabel` 等三方滚动文本库。

**槽位规则**：位置与尺寸仍然由 SVGA 素材中该 key 的槽位决定，**是个固定窗口** —— 文本超出部分被裁剪，不会被缩放。所以滚动文案尽量放在足够宽的槽位里。

**单位规则**：`font` / `gap` / `speed` / `insets` 默认按**屏幕 pt** 写，缩放换算由播放器内部处理，不需要自己算画布比例。

```swift
// 1. 基础用法：把 key 为 "id" 的槽位换成滚动文本
var config = SVGAScrollTextConfig()
config.font      = .systemFont(ofSize: 20, weight: .semibold)  // 屏幕上就是 20pt
config.textColor = .white
config.gap       = 20      // 前后两段文本的间距（pt）
config.speed     = 50      // 每秒滚动 50pt
config.direction = .rightToLeft

player.setScrollingText("恭喜 阿卜杜拉 获得守护徽章", forKey: "id", config: config)

// 2. 方向与阿语 RTL 翻转
config.direction = .leftToRight   // 从左到右
config.isRTLLayout = true         // 阿语：翻转滚动方向，并让文本按 RTL 排版

// 3. 不滚动，只显示一段静态文本（超出槽位部分裁剪）
config.isScrolling = false
config.alignment = .center        // 不滚动时的对齐方式，nil 表示按方向自动决定

// 4. 富文本：同一段文案里混排多种字体 / 字号 / 颜色
let attr = NSMutableAttributedString(string: "恭喜 ", attributes: [
    .font: UIFont.systemFont(ofSize: 20)
])
attr.append(NSAttributedString(string: "阿卜杜拉", attributes: [
    .font: UIFont.systemFont(ofSize: 20, weight: .bold),
    .foregroundColor: UIColor.systemYellow
]))
player.setScrollingAttributedText(attr, forKey: "id", config: config)
// 属性串里没设的字体 / 颜色会自动回落到 config，不会变成 CATextLayer 默认的 Helvetica 36

// 5. 手动指定槽位矩形（不传则自动从 SVGA 布局推算）
player.setScrollingText("...", forKey: "id", config: config,
                        canvasRect: CGRect(x: 87, y: 207, width: 126, height: 41))

// 6. 先设置、后播放：资源未加载完时会记住请求，加载完成后自动生效
player.setScrollingText("...", forKey: "id", config: config)   // 返回 false 表示暂未匹配到布局
player.play(.named("gift"), loop: .forever)

// 7. 移除，还原槽位原始元素
player.removeScrollingText(forKey: "id")
player.removeAllScrollingText()

// 8. 查询槽位在画布坐标系中的矩形
if let rect = player.canvasRect(forKey: "id") { print(rect) }
```

`SVGAScrollTextConfig` 全部可配置项：

| 属性 | 默认值 | 说明 |
|------|--------|------|
| `unit` | `.point` | 长度类参数单位。`.point` 屏幕 pt；`.canvas` 画布单位（需与设计稿 1:1 对应时用） |
| `isScrolling` | `true` | 是否滚动。`false` 时只显示一段静态文本 |
| `direction` | `.rightToLeft` | 滚动方向，另有 `.leftToRight` |
| `isRTLLayout` | `false` | 阿语等 RTL：翻转滚动方向并按从右到左排版 |
| `gap` | `32` | 相邻两段文本之间的间距 |
| `speed` | `60` | 滚动速度（单位 / 秒），必须大于 0 |
| `font` | `.systemFont(ofSize: 24, weight: .semibold)` | 字号，仅 `String` 接口生效 |
| `textColor` | `.white` | 文字颜色，仅 `String` 接口生效 |
| `insets` | `.zero` | 在槽位矩形内再收缩一圈可用区域 |
| `alignment` | `nil` | 不滚动时的对齐方式，`nil` 表示按方向自动决定 |
| `hidesPlaceholder` | `true` | 是否隐藏槽位原本的占位图，避免与跑马灯叠在一起 |

> **单位提示**：`unit` 默认 `.point`，这是相对早期画布单位写法的行为变更。如果已有代码按画布单位调过 `font` / `gap` / `speed`，请显式设置 `config.unit = .canvas`。
>
> **性能提示**：滚动时不会重启动画；尺寸变化动画过程中只在缩放累计变化超过 5% 时才重建文本，避免每帧重新测量文本导致滚动相位被重置（看起来像卡住不动）。`.scaleToFill` 下横纵缩放比不同会拉伸文字，跑马灯建议用 `.scaleAspectFit` / `.scaleAspectFill`。

### 回调

```swift
player.onStateChange = { state in print("State: \(state)") }
player.onFrameChange = { frame, progress in print("Frame: \(frame)") }
player.onCompletion  = { print("完成") }
player.onError       = { error in print("错误: \(error)") }
```

### 缓存管理

```swift
// 清除内存缓存
SVGAMemoryCache.shared.removeAllVideos()

// 清除磁盘缓存
SVGADiskCache.shared.removeAll()
```

### 预热 / 预解析（1.0.3）

在列表数据加载完成后提前异步解析 SVGA，解析结果写入内存与磁盘缓存。
之后 cell 上调用 `play(_:)` 会直接命中内存缓存，避免滚动时同步解码导致的掉帧。

```swift
// 数据回来后预热（自动并发，默认并发数 3）
Task {
    await SVGAPreloader.preload(urlStrings: models.map { $0.svgaUrl })
}

// 也可直接传 URL 或 SVGASource
await SVGAPreloader.preload(urls: urls, maxConcurrent: 4)
await SVGAPreloader.preload([.url(url1), .named("gift")])
```

> 说明：预热复用全局解析器，已缓存的资源会直接跳过；同一资源并发请求会自动去重。

### 缓存配置（1.0.3）

内存缓存默认按「内存成本（字节）」淘汰，而非按个数。
默认上限为物理内存的 1/8（封顶 256MB），收到系统内存警告时自动清空。
列表中 SVGA 数量较多时，无需担心「个数超过阈值」导致反复重解码。

```swift
// 自定义内存成本上限（字节）。例如限制为 128MB
SVGAMemoryCache.shared.costLimit = 128 * 1024 * 1024

// 如需按个数限制可设置 countLimit；0 表示不按个数限制（默认）
SVGAMemoryCache.shared.countLimit = 0
```

### 自定义下载器

```swift
class AuthDownloader: SVGADownloading {
    func download(from url: URL) async throws -> Data {
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }
}

let parser = SVGAParser(downloader: AuthDownloader())
let player = SwiftSVGAPlayerView(parser: parser)
```

---

## 已支持功能

| 功能 | 状态 |
|------|------|
| 加载 bundle / fileURL / URL / Data | ✅ |
| Protobuf movie.binary | ✅ |
| JSON movie.spec（含 shapes） | ✅ |
| Bitmap sprite 渲染 | ✅ |
| Vector shape（完整 SVG path） | ✅ |
| Matte layer（遮罩） | ✅ |
| Alpha / transform / layout | ✅ |
| Loop once / count / forever | ✅ |
| Play / pause / resume / stop | ✅ |
| Seek frame / progress | ✅ |
| Reverse playback | ✅ |
| Playback range | ✅ |
| Dynamic image / text / hidden | ✅ |
| Dynamic drawing block | ✅ |
| Scrolling marquee text（跑马灯，自研无三方依赖） | ✅ |
| Loading de-duplication | ✅ |
| Memory cache | ✅ |
| Disk data cache | ✅ |
| Memory cost-based eviction | ✅ |
| Preload / 预热 | ✅ |
| Audio 帧同步 | ✅ |
| SwiftUI wrapper | ✅ |
| CocoaPods | ✅ |
| SPM | ✅ |

---

## 迁移指南

### 从 SVGAPlayer-iOS（Objective-C）迁移

**旧代码：**

```objc
SVGAParser *parser = [[SVGAParser alloc] init];
SVGAPlayer *player = [[SVGAPlayer alloc] initWithFrame:frame];
[parser parseWithURL:url completionBlock:^(SVGAVideoEntity *videoItem) {
    player.videoItem = videoItem;
    [player startAnimation];
} failureBlock:nil];
```

**新代码：**

```swift
let player = SwiftSVGAPlayerView(frame: frame)
view.addSubview(player)
Task {
    try await player.load(.url(url))
    player.play(loop: .once)
}
```

| 旧 API | 新 API |
|--------|--------|
| `player.loops = 0` | `player.play(loop: .forever)` |
| `player.loops = 1` | `player.play(loop: .once)` |
| `[player startAnimation]` | `player.play()` |
| `[player pauseAnimation]` | `player.pause()` |
| `[player stopAnimation]` | `player.stop(then: .clearLayers)` |
| `[player setImage:img forKey:@"k"]` | `player.setImage(img, forKey: "k")` |
| `[player stepToFrame:10 andPlay:NO]` | `player.seek(toFrame: 10)` |

完整迁移说明见 [MigrationGuide.md](MigrationGuide.md)

---

## 要求

- iOS 13.0+
- Swift 5.0+
- Xcode 13.0+

## 许可证

MIT License. 详见 [LICENSE](LICENSE)
