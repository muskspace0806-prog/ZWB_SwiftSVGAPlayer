# SwiftSVGAPlayer

[![Platform](https://img.shields.io/badge/platform-iOS%2013%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.0+-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![SPM](https://img.shields.io/badge/SPM-supported-brightgreen.svg)](Package.swift)
[![CocoaPods](https://img.shields.io/badge/CocoaPods-supported-brightgreen.svg)](ZWB_SwiftSVGAPlayer.podspec)

**[中文](README.md) | English**

**SwiftSVGAPlayer** is an SVGA animation player with Swift-based core parsing and rendering for iOS 13+. It provides a modern Swift API, UIKit playback, SwiftUI integration, dynamic content replacement, animated GIF/WebP replacement, caching, and CocoaPods / Swift Package Manager distribution.

---

## Features

### Swift Core

- Swift implementation for core SVGA parsing, playback, and rendering
- No pbobjc / GPBProtocolBuffers
- No SSZipArchive
- Lightweight built-in Protobuf decoder for SVGA 2.x
- Lightweight built-in ZIP reader for Store and Deflate entries
- Supports zlib-compressed protobuf files and ZIP-based SVGA packages

### Playback And Rendering

- Load from bundle, file URL, remote URL, or raw Data
- Protobuf `movie.binary` parsing
- JSON `movie.spec` parsing with shapes and clip paths
- Bitmap sprite rendering with CoreAnimation
- Vector shape rendering with SVG path support, SVGA 2.x official shape fields, RGBA styles, and rounded rectangles
- Matte layer support
- Alpha, transform, layout, and clip path support
- Loop once, count, or forever
- Play, pause, resume, stop, and seek
- Reverse playback and playback ranges
- Dynamic image, image URL, text, hidden state, and drawing block
- Infinite scrolling marquee text that replaces any named SVGA slot, with direction, RTL flip, gap, speed, font, and color control (first-party, no third-party scrolling-text dependency)
- Dynamic GIF and animated WebP URL replacement, powered by Kingfisher + KingfisherWebP with SDWebImage runtime fallback
- Loading de-duplication with actor-based coordination
- Memory cache and disk data cache
- Basic audio playback with frame synchronization
- SwiftUI wrapper

---

## Installation

### Swift Package Manager

Add the package in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/muskspace0806-prog/ZWB_SwiftSVGAPlayer.git", from: "1.0.15")
]
```

Or add the repository URL in Xcode with File -> Add Package Dependencies.

### CocoaPods

```ruby
pod 'ZWB_SwiftSVGAPlayer', '~> 1.0.15'
```

---

## Quick Start

### UIKit

```swift
import UIKit
import SwiftSVGAPlayer

let player = SwiftSVGAPlayerView()
player.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
view.addSubview(player)

player.play(.named("gift"), loop: .forever)
```

### SwiftUI

```swift
import SwiftUI
import SwiftSVGAPlayer

struct ContentView: View {
    let url: URL

    var body: some View {
        SVGAPlayerView(source: .url(url), loop: .forever)
            .frame(width: 300, height: 300)
    }
}
```

---

## Dynamic Content

Replace an image:

```swift
player.setImage(UIImage(named: "avatar"), forKey: "avatar")
```

Load and replace a remote image:

```swift
player.setImageURL(URL(string: "https://example.com/avatar.jpg"), forKey: "avatar")
```

Render a remote avatar as a circle:

```swift
player.setImageURL(
    URL(string: "https://example.com/avatar.jpg"),
    forKey: "avatar",
    options: .circle()
)
```

Customize dynamic image rendering:

```swift
let options = SVGADynamicImageOptions(
    contentMode: .aspectFill,
    cornerRadius: .fixed(24),
    clipsToBounds: true
)
player.setImage(UIImage(named: "avatar"), forKey: "avatar", options: options)
```

Dynamic images can be configured before playback starts. Since `1.0.8`, the player keeps existing dynamic content while configuring the SVGA render layers:

```swift
player.setImageURL(URL(string: "https://example.com/a.jpg"), forKey: "avatar", options: .circle())
player.play(.named("gift"), loop: .forever)
```

Replace a dynamic image with an animated GIF or WebP URL. The public API accepts a string URL and the player decides whether the downloaded data is animated:

```swift
player.setAnimatedImageURL("https://example.com/avatar.webp", forKey: "avatar")

player.setAnimatedImageURL(
    "https://example.com/avatar.gif",
    forKey: "avatar",
    options: .circle(contentMode: .aspectFill)
)
```

Animated overlays follow the matched SVGA key frame, support the same circle/fixed-corner options as static dynamic images, and are removed automatically when playback completes, stops, clears, or the player is released.

Replace text:

```swift
let text = NSAttributedString(
    string: "Hello",
    attributes: [.foregroundColor: UIColor.red]
)
player.setText(text, forKey: "nickname")
```

Hide a sprite:

```swift
player.setHidden(true, forKey: "background")
```

---

## Scrolling Marquee Text (1.0.15)

Replace any named SVGA slot (for example a 63x21 placeholder sprite whose key is `id`) with seamlessly looping scrolling text. Implemented first-party; it does not pull in `MarqueeLabel` or any other third-party scrolling-text library.

**Slot rules**: position and size still come from the SVGA asset's slot for that key. The slot is a **fixed window** — overflowing text is clipped, not scaled. Use a slot that is wide enough for the text you plan to show.

**Unit rules**: `font` / `gap` / `speed` / `insets` are written in **screen points by default**; the player handles scale conversion internally, so you never have to compute the canvas ratio yourself.

```swift
// 1. Basic usage: replace the slot keyed "id" with scrolling text
var config = SVGAScrollTextConfig()
config.font      = .systemFont(ofSize: 20, weight: .semibold)  // 20pt on screen
config.textColor = .white
config.gap       = 20      // spacing between consecutive text copies (pt)
config.speed     = 50      // scroll 50pt per second
config.direction = .rightToLeft

player.setScrollingText("Congratulations Abdullah", forKey: "id", config: config)

// 2. Direction and Arabic RTL flip
config.direction = .leftToRight   // left to right
config.isRTLLayout = true         // Arabic: flip scroll direction and lay out right-to-left

// 3. Static (non-scrolling) text, clipped to the slot
config.isScrolling = false
config.alignment = .center        // nil means derive from direction

// 4. Rich text: mix multiple fonts / sizes / colors in one string
let attr = NSMutableAttributedString(string: "Congratulations ", attributes: [
    .font: UIFont.systemFont(ofSize: 20)
])
attr.append(NSAttributedString(string: "Abdullah", attributes: [
    .font: UIFont.systemFont(ofSize: 20, weight: .bold),
    .foregroundColor: UIColor.systemYellow
]))
player.setScrollingAttributedText(attr, forKey: "id", config: config)
// Attributes you did not set fall back to `config` instead of CATextLayer's default Helvetica 36

// 5. Override the slot rect manually (omit to derive it from the SVGA layout)
player.setScrollingText("...", forKey: "id", config: config,
                        canvasRect: CGRect(x: 87, y: 207, width: 126, height: 41))

// 6. Configure before loading: the request is remembered and applied once the asset loads
player.setScrollingText("...", forKey: "id", config: config)   // false = layout not matched yet
player.play(.named("gift"), loop: .forever)

// 7. Remove and restore the original slot content
player.removeScrollingText(forKey: "id")
player.removeAllScrollingText()

// 8. Query the slot rect in canvas coordinates
if let rect = player.canvasRect(forKey: "id") { print(rect) }
```

`SVGAScrollTextConfig` options:

| Property | Default | Description |
|----------|---------|-------------|
| `unit` | `.point` | Unit for length values. `.point` = screen points; `.canvas` = canvas units, for 1:1 design-canvas mapping |
| `isScrolling` | `true` | Set `false` to render a single static line |
| `direction` | `.rightToLeft` | Scroll direction; also `.leftToRight` |
| `isRTLLayout` | `false` | RTL languages: flips scroll direction and lays text out right-to-left |
| `gap` | `32` | Spacing between consecutive text copies |
| `speed` | `60` | Scroll speed (units per second), must be greater than 0 |
| `font` | `.systemFont(ofSize: 24, weight: .semibold)` | Font, `String` API only |
| `textColor` | `.white` | Text color, `String` API only |
| `insets` | `.zero` | Shrinks the usable area inside the slot rect |
| `alignment` | `nil` | Alignment when not scrolling; `nil` derives it from direction |
| `hidesPlaceholder` | `true` | Hides the slot's original placeholder bitmap so it does not overlap the marquee |

> **Unit note**: `unit` defaults to `.point`, which is a behavior change from the earlier canvas-unit approach. If existing code tuned `font` / `gap` / `speed` against canvas units, set `config.unit = .canvas` explicitly.
>
> **Performance note**: scrolling never restarts the animation, and during size animations the text is rebuilt only after the cumulative scale change exceeds 5% — this avoids re-measuring text every frame and resetting the scroll phase (which looks like the marquee is frozen). Under `.scaleToFill` the horizontal and vertical scale factors differ and text will be stretched; prefer `.scaleAspectFit` / `.scaleAspectFill` for marquee slots.

---

## Playback Control

```swift
player.play()
player.play(loop: .count(3))
player.play(range: 10..<30, loop: .forever)
player.pause()
player.resume()
player.stop(then: .keepCurrentFrame)
player.seek(toFrame: 15)
player.seek(progress: 0.5)
player.isReversed = true
player.clear()
```

## Lifecycle, Transitions, RunLoop Mode, And Visible Rendering

Since `1.0.10`, `SwiftSVGAPlayerView` automatically pauses playback when it leaves the `window`, and resumes playback when it is attached again if the animation was playing before.
This prevents off-screen SVGA views from continuing to drive `CADisplayLink` during navigation transitions, reused cells, or controller pop flows.

Since `1.0.11`, the player drives frames in the default RunLoop mode, so heavy SVGA playback does not keep competing with scrolling, gesture tracking, or navigation transitions.
Since `1.0.12`, `displayLinkRunLoopMode` can be configured per player. The default remains `.default`, so list cells and pages with many players keep the previous behavior. For full-screen gifts, live return-coin effects, or other must-keep-playing animations, set it to `.common` before playback to keep rendering while a chat list is being dragged.

```swift
// Default behavior. Scrolling and gesture tracking do not keep driving frames.
player.displayLinkRunLoopMode = .default

// Full-screen gifts or live return-coin effects that must keep playing while scrolling.
player.displayLinkRunLoopMode = .common
```

When the player is hidden, transparent, detached from `window`, or clipped outside an ancestor's visible bounds, the current frame render and audio frame update are skipped.

Since `1.0.13`, callers that already manage visibility externally, such as a marquee container that periodically decides which duplicated views should play, can set `usesExternalVisibilityControl` to skip the player's per-frame hierarchy clipping check and reduce main-thread cost while many SVGA views are moving.

```swift
// Enable only when visibility is already managed by the caller.
player.usesExternalVisibilityControl = true
```

Async loading started by `play(_:)` is also cancelled when a new load starts, when `stop()` / `clear()` is called, or when the view is released. This prevents stale load tasks from writing decoded resources back to a detached player. `1.0.13` also exposes `cancelLoading()` for reused cells or marquee items that leave the visible range, so callers can cancel only the current load task while keeping already loaded content.

```swift
// Recommended when a reused cell or a finished page no longer needs playback.
player.stop()
player.clear()

// Cancel the current async load without clearing already rendered content.
player.cancelLoading()
```

---

## Callbacks

```swift
player.onStateChange = { state in print("State: \(state)") }
player.onFrameChange = { frame, progress in print("Frame: \(frame), \(progress)") }
player.onCompletion = { print("Completed") }
player.onError = { error in print("Error: \(error)") }
```

---

## Requirements

- iOS 13.0+
- Swift 5.0+
- Xcode 13.0+

## License

MIT License. See [LICENSE](LICENSE).
