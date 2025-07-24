# CraftingReality Mobile Demo

这是CraftingReality项目的手机端适配版本。该版本保留了语音控制功能，但移除了RealityView，改为在屏幕上显示解析后的语音命令结果。

## 主要特性

### 🎤 语音控制
- **连续语音识别**: 实时识别语音命令
- **智能命令解析**: 自动分类命令类型（创建、移动、缩放、修改、系统）
- **实时反馈**: 显示语音转录和命令处理状态

### 📱 手机端适配
- **移除RealityView**: 不再依赖visionOS特有的3D显示
- **命令显示界面**: 在屏幕上显示解析后的命令信息
- **单窗口界面**: 适合手机端的简洁布局

## 架构变化

### Mobile组件
- **MobileEntityMaker**: 保留命令解析逻辑，但不创建实际3D对象
- **MobileContinuousVoiceController**: 适配手机端的语音控制器
- **CommandDisplayView**: 显示命令历史和解析结果
- **MobileContentView**: 手机端主界面

### 支持的语音命令

#### 创建命令
- "Create a red cube" → 显示：1x red box - Size: 0.12, Metallic: false, Roughness: 0.8
- "Make a blue sphere" → 显示：1x blue sphere - Size: 0.11, Metallic: false, Roughness: 0.6
- "Add more boxes" → 显示：3x gray box - Size: 0.13, Metallic: false, Roughness: 0.7

#### 修改命令（需要先创建对象）
- "Make it red" → 显示：red color, roughness: 0.5, metallic: false
- "Change color to green" → 显示：green color, roughness: 0.6, metallic: false

#### 缩放命令（需要先创建对象）
- "Make it bigger" → 显示：Scale factor: 2.0
- "Scale down" → 显示：Scale factor: 0.5

#### 移动命令（需要先创建对象）
- "Move it left" → 显示：negative 0.5m on x-axis
- "Move it up" → 显示：positive 0.5m on y-axis

#### 系统命令
- "Start physics" → 显示：System enabled
- "Stop physics" → 显示：System disabled

## 使用方法

1. **启动应用**: 应用会自动初始化AI系统
2. **开始语音控制**: AI系统准备好后会自动开始监听
3. **说出命令**: 使用上述支持的语音命令
4. **查看结果**: 命令解析结果会显示在下方的命令历史中

## 界面说明

### 语音控制区域（顶部）
- **状态指示器**: 显示当前语音识别状态
- **实时转录**: 显示正在识别的语音内容
- **开始/停止按钮**: 手动控制语音识别

### 命令显示区域（底部）
- **当前活动对象**: 显示当前选中的虚拟对象信息
- **系统状态**: 显示物理系统是否启用
- **命令历史**: 显示所有已处理的命令及其结果

## 技术实现

### 命令解析流程
1. **语音识别**: 使用Apple的SpeechTranscriber进行实时语音转文字
2. **命令分类**: 使用AI模型判断命令类型
3. **参数提取**: 根据命令类型提取相关参数
4. **结果显示**: 在界面上显示解析结果

### 与原版本的区别
- ❌ 移除RealityKit依赖
- ❌ 移除ImmersiveSpace
- ❌ 移除3D对象创建
- ✅ 保留语音识别和命令解析
- ✅ 添加命令结果显示界面
- ✅ 适配单窗口布局

## 开发说明

### 项目结构
```
CraftingReality/
├── EntityMaker/
│   ├── EntityMaker.swift          # 原版本（visionOS）
│   └── MobileEntityMaker.swift    # 手机版本
├── Speech/
│   ├── ContinuousVoiceController.swift       # 原版本
│   └── MobileContinuousVoiceController.swift # 手机版本
├── Views/
│   ├── ContentView.swift          # 原版本（visionOS）
│   ├── MobileContentView.swift    # 手机版本
│   ├── CommandDisplayView.swift   # 命令显示界面
│   └── MobileVoiceStatusIndicator.swift # 手机版本语音指示器
├── CraftingRealityApp.swift       # 原版本App入口（已禁用）
└── CraftingRealityMobileApp.swift # 手机版本App入口
```

### 切换版本
- **使用手机版本**: 当前配置，使用`CraftingRealityMobileApp`作为入口点
- **切换回visionOS版本**: 在`CraftingRealityApp.swift`中恢复`@main`标记，在`CraftingRealityMobileApp.swift`中注释掉`@main`标记

## 系统要求
- **iOS 26+** - Foundation Models和Apple Intelligence支持
- 支持Apple Intelligence的设备（iPhone 15 Pro/Pro Max或更新设备）
- 麦克风权限
- Apple Intelligence必须启用

---

**注意**: 这是一个演示版本，主要用于展示语音命令解析功能在手机端的实现。如需完整的3D交互体验，请使用原版本的visionOS应用。

**重要**: 此应用需要iOS 26+系统和支持Apple Intelligence的设备。Foundation Models功能只在iOS 26+中可用。
