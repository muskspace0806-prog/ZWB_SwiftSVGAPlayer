# Migration Guide

## 从 SVGAPlayer-iOS (Objective-C) 迁移到 SwiftSVGAPlayer

### 概述

SwiftSVGAPlayer 提供了与原 SVGAPlayer-iOS 功能对等的纯 Swift API，但 API 设计有所不同，更符合现代 Swift 惯例。

---

## 基础播放

### 旧版

```objc
SVGAParser *parser = [[SVGAParser alloc] init];
SVGAPlayer *player = [[SVGAPlayer alloc] initWithFrame:self.view.bounds];
player.loops = 0; // 0 = 无限循环
[self.view addSubview:player];

[parser parseWithURL:[NSURL URLWithString:@"https://example.com/test.svga"]
     completionBlock:^(SVGAVideoEntity *videoItem) {
    player.videoItem = videoItem;
    [player startAnimation];
} failureBlock:^(NSError *error) {
    NSLog(@"Error: %@", error);
}];
```

### 新版

```swift
let player = SwiftSVGAPlayerView(frame: view.bounds)
view.addSubview(player)

player.onError = { error in print("Error: \(error)") }

Task {
    try await player.load(.url(URL(string: "https://example.com/test.svga")!))
    player.play(loop: .forever)
}
```

---

## 本地资源

### 旧版

```objc
[parser parseWithNamed:@"test" inBundle:nil completionBlock:^(SVGAVideoEntity *videoItem) {
    player.videoItem = videoItem;
    [player startAnimation];
} failureBlock:nil];
```

### 新版

```swift
try await player.load(.named("test"))
player.play()
```

---

## 循环控制

| 旧版 | 新版 |
|------|------|
| `player.loops = 0` | `player.play(loop: .forever)` |
| `player.loops = 1` | `player.play(loop: .once)` |
| `player.loops = 3` | `player.play(loop: .count(3))` |

---

## 播放控制

| 旧版 | 新版 |
|------|------|
| `[player startAnimation]` | `player.play()` |
| `[player pauseAnimation]` | `player.pause()` |
| `[player stopAnimation]` | `player.stop(then: .clearLayers)` |
| `[player stepToFrame:10 andPlay:NO]` | `player.seek(toFrame: 10)` |
| `[player stepToPercentage:0.5 andPlay:NO]` | `player.seek(progress: 0.5)` |

---

## 动态内容

### 动态图片

```objc
// 旧版
[player setImage:[UIImage imageNamed:@"avatar"] forKey:@"avatar"];
```

```swift
// 新版
player.setImage(UIImage(named: "avatar"), forKey: "avatar")
```

### 动态文字

```objc
// 旧版
[player setAttributedText:attrText forKey:@"nickname"];
```

```swift
// 新版
player.setText(attrText, forKey: "nickname")
```

### 隐藏元素

```objc
// 旧版
[player setHidden:YES forKey:@"background"];
```

```swift
// 新版
player.setHidden(true, forKey: "background")
```

---

## 停止场景

旧版 `stopAnimation` 默认清空画面。新版提供更细粒度控制：

```swift
player.stop(then: .clearLayers)       // 等同旧版默认行为
player.stop(then: .keepCurrentFrame)  // 停止但保留最后一帧
player.stop(then: .stepToLeading)     // 停止并跳到第一帧
player.stop(then: .stepToTrailing)    // 停止并跳到最后一帧
```

---

## 状态监听

### 旧版（delegate）

```objc
player.delegate = self;

- (void)svgaPlayerDidFinishedAnimation:(SVGAPlayer *)player {
    NSLog(@"Finished");
}
```

### 新版（closure）

```swift
player.onCompletion = {
    print("Finished")
}

player.onStateChange = { state in
    switch state {
    case .playing:  print("Playing")
    case .paused:   print("Paused")
    case .completed: print("Completed")
    default: break
    }
}
```

---

## 缓存控制

### 旧版

```objc
// 清除缓存（无标准 API）
```

### 新版

```swift
// 清除内存缓存
SVGAMemoryCache.shared.removeAllVideos()

// 清除磁盘缓存
SVGADiskCache.shared.removeAll()

// 清除指定 key
let key = SVGACacheKeyGenerator.shared.cacheKey(for: .url(url))!
SVGAMemoryCache.shared.removeVideo(forKey: key)
```

---

## 自定义下载器

### 旧版

```objc
// 不支持自定义下载器
```

### 新版

```swift
class AuthenticatedDownloader: SVGADownloading {
    func download(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }
}

let parser = SVGAParser(downloader: AuthenticatedDownloader())
let player = SwiftSVGAPlayerView(parser: parser)
```

---

## 注意事项

1. **async/await**：新版 `load()` 是 async 方法，需要在 `Task` 或 `async` 上下文中调用。
2. **线程安全**：所有 UI 操作（play/pause/stop/seek）必须在主线程调用。
3. **内存管理**：`SwiftSVGAPlayerView` 持有 parser 引用，注意循环引用。
4. **iOS 13 兼容**：async/await 在 iOS 13 通过 Swift concurrency back deployment 支持，需要 Xcode 13.2+。
