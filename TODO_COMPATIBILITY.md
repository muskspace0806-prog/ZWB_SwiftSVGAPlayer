# TODO_COMPATIBILITY.md
# SVGA 格式兼容性问题记录

## 格式说明

每条记录格式：
- **文件**：测试文件名
- **问题**：具体缺失字段或行为差异
- **预期行为**：原 SVGAPlayer-iOS 的表现
- **当前行为**：本库当前表现
- **优先级**：P0（阻塞）/ P1（重要）/ P2（次要）
- **状态**：TODO / IN_PROGRESS / DONE

---

## 已知兼容性问题

### 1. Vector Shape 路径渲染
- **问题**：SVG path `d` 字符串中的 `A`（arc）命令暂未实现
- **预期行为**：正确渲染圆弧路径
- **当前行为**：arc 命令被跳过，路径不完整
- **优先级**：P1
- **状态**：TODO（Phase 6）

### 2. Matte Layer（遮罩）
- **问题**：`matteKey` 字段已解析但渲染层未应用 mask
- **预期行为**：使用 matteKey 对应的 sprite 作为 mask layer
- **当前行为**：matteKey 被忽略，无遮罩效果
- **优先级**：P1
- **状态**：TODO（Phase 6）

### 3. Audio 帧同步精度
- **问题**：音频 seek 精度依赖 AVAudioPlayer.currentTime，可能有毫秒级误差
- **预期行为**：音频与动画帧精确同步
- **当前行为**：基本同步，但快速 seek 时可能有轻微偏差
- **优先级**：P2
- **状态**：TODO（Phase 6）

### 4. ZIP64 格式
- **问题**：自研 ZIP 解析器暂不支持 ZIP64 扩展字段
- **预期行为**：支持超过 4GB 的 SVGA 文件（实际不太可能）
- **当前行为**：ZIP64 文件解析失败
- **优先级**：P2
- **状态**：TODO

### 5. movie.spec JSON 格式完整性
- **问题**：旧版 JSON 格式中的 shapes / clipPath 字段暂未完整解析
- **预期行为**：完整解析所有 JSON 字段
- **当前行为**：基础 layout / transform / alpha 正常，shapes 为空
- **优先级**：P2
- **状态**：TODO（Phase 6）

### 6. Drawing Block
- **问题**：`SVGADynamicItem.drawing` 已定义但渲染层未实现自定义绘制
- **预期行为**：在指定 key 的 layer 上执行自定义 CGContext 绘制
- **当前行为**：drawing block 被忽略
- **优先级**：P1
- **状态**：TODO（Phase 5）

---

## 测试文件清单

待补充真实 .svga 测试文件后填写。
