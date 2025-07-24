¬# CraftingReality - 连续语音控制集成 (双窗口架构)

## 概述

基于 swift-scribe 的架构，我们为 CraftingReality 实现了**双窗口语音控制功能**：
- **主窗口**：显示语音控制界面和状态指示器
- **Immersive Space**：纯粹的 3D 内容展示

用户可以通过自然语音指令实时创建和操控 3D 对象，同时在主窗口中获得清晰的视觉反馈。

## ✨ 主要功能

### 🎤 连续语音识别
- **自动启动**: 点击 "Got It!" 按钮后自动进入 immersive 模式并开始语音识别
- **实时转录**: 基于 Apple 的 SpeechAnalyzer 和 SpeechTranscriber 实现
- **智能指令检测**: 自动识别完整指令并执行，无需手动触发

### 🎯 智能指令处理
- **自动分类**: 支持创建、移动、缩放、修改、系统等多种指令类型
- **即时执行**: 检测到完整指令后自动执行，或等待 2 秒超时自动执行
- **上下文理解**: 支持 "make it bigger"、"move left" 等自然语言指令

### 🌟 直观用户界面
- **主窗口界面**: 实时显示语音识别状态（监听/处理/空闲）
- **命令预览**: 显示当前累积的语音指令
- **3D 环境**: 纯粹的 3D 内容，无界面干扰

## 🚀 使用流程

### 1. 启动语音控制
```
InstructionView (说明页面)
    ↓ 点击 "Got It! Start Voice Control"
主窗口切换为语音控制界面 + Immersive Space 开启
    ↓ 自动启动 (1秒延迟)
连续语音识别开始
```

### 2. 双窗口体验
```
主窗口                        Immersive Space
┌─────────────────────┐      ┌─────────────────────┐
│ Voice-Controlled    │      │                     │
│ 3D Playground       │      │     🔴  🔵  🟢      │
│                     │      │                     │
│ 🎤 Listening        │      │    📦              │
│ "Create red cube"   │      │         📦         │
│                     │      │              📦    │
│ [Current Command]   │      │                     │
│ create red cube     │      │    3D Objects       │
│                     │      │    Floating Here    │
│ [Start/Stop Voice]  │      │                     │
└─────────────────────┘      └─────────────────────┘
```

### 3. 语音指令示例

#### 创建对象
- "Create a red cube"
- "Make a blue sphere"
- "Add more boxes"

#### 操控对象 (在 Immersive Space 中点击选择对象)
- "Move it left"
- "Make it bigger"
- "Change color to green"
- "Scale down"

#### 系统控制
- "Start physics"
- "Stop physics"
- "Enable gravity"

### 4. 即时执行关键词
说出以下关键词可立即执行当前指令：
- "execute", "done", "go", "now"
- "do it", "make it", "yes", "ok"

## 🏗 技术架构

### 核心组件

#### 1. 双窗口架构
```swift
// 主窗口 - 语音控制界面
WindowGroup(id: appModel.windowID) {
    ContentView() // 包含 VoiceStatusIndicator
}

// Immersive Space - 纯3D内容
ImmersiveSpace(id: appModel.immersiveSpaceID) {
    ImmersiveView() // 只有 ObjectPlaygroundView
}
```

#### 2. ContinuousVoiceController
```swift
@Observable
@MainActor
final class ContinuousVoiceController {
    // 基于 swift-scribe 的连续语音识别
    // 智能指令检测和自动执行
    // 与 EntityMaker 无缝集成
}
```

#### 3. 状态管理
```swift
// AppModel 中的状态
var showVoiceControl = false  // 控制主窗口显示内容
var immersiveSpaceState = ImmersiveSpaceState.closed
```

### 智能指令检测

系统使用正则表达式模式匹配来识别完整指令：

```swift
let commandPatterns = [
    // 创建指令
    "^(create|make|add|build)\\s+.*",
    "^.*\\s+(cube|sphere|box|ball).*$",
    
    // 移动指令
    "^(move|slide)\\s+.*(left|right|up|down).*",
    
    // 缩放指令
    "^(make|scale)\\s+.*(bigger|smaller).*",
    
    // 修改指令
    "^(change|turn)\\s+.*(color|red|blue|green).*"
]
```

## 🎛 控制选项

### 主窗口控制
- **语音状态指示器**: 显示当前监听/处理状态
- **指令预览**: 实时显示累积的语音指令
- **开始/停止按钮**: 手动控制语音识别

### Immersive Space 交互
- **点击物体**: 选择当前活动对象（用于后续操作）
- **3D 环境**: 查看创建的对象和物理交互

### 语音控制
- **"Start Voice Control"**: 开始语音识别
- **"Stop Listening"**: 停止语音识别
- **即时执行关键词**: 立即处理当前指令

## 🔧 配置选项

### 语音识别配置
```swift
static let locale = Locale(components: .init(
    languageCode: .english, 
    script: nil, 
    languageRegion: .unitedStates
))

private let commandTimeoutInterval: TimeInterval = 2.0 // 2秒超时
```

### 用户体验配置
- **自动启动**: 主窗口显示语音界面后 1 秒自动开始语音识别
- **智能超时**: 检测到静音 2 秒后自动执行累积指令
- **实时反馈**: 持续显示转录文本和系统状态

## 🎨 视觉设计

### 主窗口界面
- **标题**: "Voice-Controlled 3D Playground"
- **说明文字**: "Look around you to see the 3D playground..."
- **语音状态指示器**: 实时状态和命令预览

### 状态指示器设计
- **监听状态**: 绿色渐变圆圈，脉冲动画
- **处理状态**: 橙色渐变圆圈，弹跳动画
- **空闲状态**: 灰色渐变圆圈，静态显示

### Immersive Space
- **纯3D环境**: 无UI干扰的沉浸式体验
- **物体交互**: 点击选择，物理效果
- **空间边界**: 3x3x2米的约束盒

## 🔄 架构优势

### 与单窗口方案的对比

#### 优势 ✅
- **清晰的视觉反馈**: 主窗口中的语音界面清晰可见
- **沉浸式3D体验**: Immersive Space 中无UI干扰
- **灵活的交互**: 可以同时查看两个窗口
- **稳定的界面**: SwiftUI 在普通窗口中更稳定

#### 使用体验
- **主窗口**: 查看语音指令状态和反馈
- **Immersive Space**: 专注于3D对象创建和交互
- **无缝切换**: 语音指令直接影响3D环境

## 🎯 最佳实践

### 语音指令建议
1. **明确具体**: "Create a red cube" 比 "Make something" 更好
2. **自然语言**: 支持 "make it bigger" 这样的自然表达
3. **分步执行**: 复杂操作分解为简单指令
4. **及时确认**: 可以说 "execute" 立即执行指令

### 系统使用建议
1. **窗口布局**: 将主窗口放在容易看到的位置
2. **环境要求**: 相对安静的环境以获得最佳识别效果
3. **对象选择**: 在 Immersive Space 中点击对象来选择
4. **设备要求**: iOS 26+ 或 macOS 26+ Beta

## 🐛 故障排除

### 常见问题
1. **语音识别不工作**: 检查麦克风权限
2. **指令不执行**: 尝试说 "execute" 强制执行
3. **看不到语音界面**: 确保主窗口可见
4. **3D对象不出现**: 查看 Immersive Space 窗口

### 调试信息
系统会在控制台输出详细的调试信息：
```
[ContentView] Auto-started voice control
[ContinuousVoice] Processing command: 'create red cube'
[ContinuousVoice] Command processed successfully!
```

---

🎉 **双窗口架构完成！** 现在你可以享受清晰的语音反馈和沉浸式的3D创作体验了！ 