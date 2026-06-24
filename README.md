# ExternalDock ⚡

**一个 macOS 原生应用，在外接屏上显示一个自定义的 Dock 栏。**

还在因为拓展屏没有 Dock 而烦恼吗？ExternalDock 帮你把常用应用图标放到外接屏上，点击即可启动，已运行的应用还会显示小黑点指示。

<p align="center">
  <img src="Resources/ExternalDock.icns" width="128" height="128" alt="ExternalDock icon">
</p>

---

## ✨ 功能

| 功能 | 说明 |
|------|------|
| 🖥️ **外接屏检测** | 自动识别外接屏，无外接屏时回退到主屏 |
| 📐 **四边缘停靠** | 底部 / 顶部 / 左侧 / 右侧，沿边缘居中显示 |
| 🚀 **点击启动应用** | 点击图标快速启动应用，不抢焦点 |
| 🔵 **运行状态指示** | 正在运行的应用图标旁显示小黑点 |
| 🖱️ **悬停放大动画** | 鼠标悬停时图标向远离屏幕边缘方向放大 |
| 🔄 **屏幕热插拔** | 拔掉外接屏自动隐藏，插回自动恢复 |
| 📌 **菜单栏控制** | ⚡ 菜单栏图标，随时切换边缘、打开设置 |
| ⚙️ **自定义应用列表** | 添加/删除任意 .app，拖拽排序 |
| 🚫 **无 Dock 图标** | 只显示菜单栏图标，不占用系统 Dock 空间 |
| 🌫️ **毛玻璃效果** | 原生 NSVisualEffectView 背景 |
| 🪟 **自动移窗** | 点击已在主屏运行的应用，自动把窗口移到外接屏（需辅助功能授权） |

---

## 📸 截图

```
                   ┌────────── 顶部 ──────────┐
                   │  🎬  💻  📁  📝  🎵  ⚙️  │
                   │  (横排居中)              │
                   └──────────────────────────┘
  ┌── 左侧 ──┐                        ┌── 右侧 ──┐
  │    🎬     │                        │    🎬     │
  │    💻     │                        │    💻     │
  │    📁     │      外接屏            │    📁     │
  │  (竖排)  │                        │  (竖排)  │
  └──────────┘                        └──────────┘
                   ┌────────── 底部 ──────────┐
                   │  🎬  💻  📁  📝  🎵  ⚙️  │
                   │  (默认位置)              │
                   └──────────────────────────┘
```

---

## 🚀 快速开始

### 系统要求

- macOS 13.0+ (Ventura 及以上)
- Apple Silicon (ARM64) 或 Intel Mac

### 下载

在 [Releases](https://github.com/fairzy/external_dock/releases) 下载最新版 `ExternalDock.app.zip`，解压后放入 `/Applications`。

### 自行编译

```bash
git clone https://github.com/fairzy/external_dock.git
cd external_dock
chmod +x build.sh
./build.sh
cp -R build/ExternalDock.app /Applications/
```

编译产物：`build/ExternalDock.app` (Release 优化，~220KB)

### 使用

1. 启动 `/Applications/ExternalDock.app`
2. 菜单栏出现 ⚡ 图标
3. 外接屏上自动显示 Dock 栏
4. 点击 ⚡ → 「切换边缘」选择位置
5. 点击 ⚡ → 「设置 External Dock...」添加/删除应用

> **提示**：可以添加到登录项开机自启：
> 系统设置 → 通用 → 登录项 → 添加 ExternalDock

---

## ⚙️ 设置

- **添加应用**：设置中点击「➕ 添加应用」，选择 `/Applications` 中的任意 .app
- **删除应用**：在 Dock 上右键点击图标 → 「移除此应用」
- **切换边缘**：菜单栏 ⚡ → 「切换边缘」→ 底部/顶部/左侧/右侧
- **访达定位**：右键图标 → 「在访达中显示」

---

## 🔐 辅助功能授权（可选）

点击已在主屏运行的应用时，自动将其窗口移到外接屏，需要辅助功能授权。

> ⚠️ 每次重新编译后，授权会失效，需要重新勾选

**设置方法：**
1. 打开 **系统设置 → 隐私与安全性 → 辅助功能**
2. 点 `+` 添加 `/Applications/ExternalDock.app`
3. 勾选 ExternalDock
4. 完全退出并重新启动 App

**验证授权：**
```bash
osascript -e 'tell application "System Events" to get name of every window of every process'
```
如果返回窗口列表，说明授权生效。

---

## 🏗️ 项目结构

```
ExternalDock/
├── App/
│   ├── main.swift                 # 入口
│   ├── ExternalDockApp.swift      # AppDelegate + 菜单栏
│   ├── DockWindowManager.swift    # 屏幕检测 + 窗口定位
│   ├── DockViewController.swift   # Dock 内容视图 + 图标动画
│   ├── AppIconManager.swift       # 图标加载 + 应用启动 + 移窗
│   └── SettingsWindowController.swift  # 偏好设置窗口
├── Resources/
│   ├── Info.plist                 # App 配置
│   └── ExternalDock.icns          # 应用图标
├── build.sh                       # 一键编译
└── README.md
```

### 技术栈

- **语言**: Swift 6.3
- **框架**: AppKit (纯代码，无 Storyboard)
- **窗口**: NSPanel (浮动面板，不抢焦点)
- **架构**: ~600 行，零第三方依赖

---

## 🤝 贡献

Issues 和 Pull Requests 欢迎提交！

---

## 📄 协议

MIT License

Copyright © 2026

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

---

*Made with ❤️ for the multi-monitor macOS community*