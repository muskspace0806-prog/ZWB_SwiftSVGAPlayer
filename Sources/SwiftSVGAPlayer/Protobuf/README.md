# Protobuf

本目录包含 SVGA Protobuf 解析实现。

## 实现方式

本库使用**自研轻量 Protobuf 解析器**（`ZWB_Svga.pb.swift`），不依赖 SwiftProtobuf 或 pbobjc。

### 设计原则

- 纯 Swift 实现，零外部依赖
- 支持 SVGA 2.x proto 格式
- 支持 varint / length-delimited / fixed32 wire types
- 字段缺失时使用默认值，保证向后兼容

### 对应 Proto 定义

```protobuf
// SVGA 2.x proto（简化版）
message MovieEntity {
    string version = 1;
    MovieParams params = 2;
    map<string, bytes> images = 3;
    repeated SpriteEntity sprites = 4;
    repeated AudioEntity audios = 5;
}

message MovieParams {
    float viewBoxWidth = 1;
    float viewBoxHeight = 2;
    int32 fps = 3;
    int32 frames = 4;
}

message SpriteEntity {
    string imageKey = 1;
    repeated FrameEntity frames = 2;
    string matteKey = 3;
}

message FrameEntity {
    float alpha = 1;
    Layout layout = 2;
    Transform transform = 3;
    string clipPath = 4;
    repeated ShapeEntity shapes = 5;
}
```

### 如需使用 SwiftProtobuf

如果项目已集成 SwiftProtobuf，可以：
1. 从官方 SVGA proto 文件生成 `Svga.pb.swift`
2. 替换 `ZWB_SVGABinaryDecoder.swift` 中的解码调用

官方 proto 文件：https://github.com/svga/SVGAPlayer-iOS/blob/master/Source/proto/svga.proto
