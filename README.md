# SwiftSVGAPlayer

[![Platform](https://img.shields.io/badge/platform-iOS%2013%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.0+-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![SPM](https://img.shields.io/badge/SPM-supported-brightgreen.svg)](Package.swift)
[![CocoaPods](https://img.shields.io/badge/CocoaPods-supported-brightgreen.svg)](SwiftSVGAPlayer.podspec)

**SwiftSVGAPlayer** 是一个纯 Swift 实现的 SVGA 动画播放器，支持 iOS 13+，提供现代 Swift API 和 SwiftUI 支持。

---

## 特性

### 纯 Swift，零 OC 依赖
- 无 Objective-C 代码
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
- ✅ Vector shape 渲染（完整 SVG path：M/L/H/V/C/S/Q/T/A/Z，含椭圆弧）
- ✅ Matte layer（遮罩，matteKey 对应 sprite 作为 CALayer mask）
- ✅ Alpha / transform / layout / clipPath
- ✅ Loop once / count / forever
- ✅ Play / pause / resume / stop / seek
- ✅ Reverse playback（反向播放）
- ✅ Playback range（播放区间）
- ✅ Dynamic image / imageURL / text / hidden / drawing block
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
    .package(url: "https://github.com/muskspace0806-prog/ZWB_SwiftSVGAPlayer.git", from: "0.1.0")
]
```

或在 Xcode 中：File → Add Package Dependencies → 输入仓库地址。

### CocoaPods

```ruby
pod 'SwiftSVGAPlayer', '~> 0.1.0'
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

### 动态内容

```swift
// 替换图片
player.setImage(UIImage(named: "avatar"), forKey: "avatar")

// 远程图片（异步加载）
player.setImageURL(URL(string: "https://..."), forKey: "avatar")

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
| Loading de-duplication | ✅ |
| Memory cache | ✅ |
| Disk data cache | ✅ |
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
