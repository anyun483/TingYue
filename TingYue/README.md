# 听阅 TingYue — iOS 自签听书 App（源码工程）

阅读 + 听书二合一：导入 TXT / PDF / Word / PPT / Markdown，用豆包音色朗读，语速可调、音色可切换、后台锁屏可控制。**无需上架 App Store，个人自签安装。**

## 零、免 Mac 云编译路线（Windows 全程搞定）

仓库里已配好 `project.yml`（XcodeGen 工程定义）和 `.github/workflows/build-ipa.yml`（GitHub Actions 云端 macOS 自动编译）。

**步骤：**
1. 注册 [GitHub](https://github.com)，新建仓库，把本目录（`TingYue/` 和 `.github/`）整体推上去
   - `git init && git add . && git commit -m "feat: TingYue v1.0.0" && git remote add origin <你的仓库地址> && git push -u origin main`
   - 注意：`.github` 必须在仓库根目录（与 `TingYue/` 平级）
2. 推送后自动触发编译（也可在仓库 Actions 页手动 Run workflow）；等约 5~10 分钟
3. Actions 页进入该次运行 → 底部 Artifacts 下载 **TingYue-unsigned.ipa**
4. Windows 装 [Sideloadly](http://sideloadly.io/)：拖入 IPA → 登录你的 Apple ID → iPhone 连数据线 → Start → 手机上信任证书（设置 → 通用 → VPN与设备管理）
5. 完成 ✅ 免费证书 7 天有效，到期重复第 4 步重签即可（30 秒）

> Sideloadly 需要电脑装好 iTunes（Apple Devices 驱动）；手机解锁状态下操作。

## 一、组装工程（有 Mac 的走这条，10 分钟）

本仓库是源码文件，需在 Mac 上组装为 Xcode 工程（Windows 用户可用云 Mac）：

1. Mac 上打开 Xcode → `Create New Project` → iOS **App**
   - Product Name: `TingYue`；Interface: **SwiftUI**；Language: **Swift**
2. 把 `TingYue/` 目录下所有 `.swift` 文件拖入工程（保持 `Models / Services / Views` 分组），删除 Xcode 自动生成的 `ContentView.swift` 和 `TingYueApp.swift`（用本仓库的替换）
3. 添加 ZIP 依赖（解析 Word/PPT 需要）：
   - `File → Add Package Dependencies` → 输入 `https://github.com/weichsel/ZIPFoundation` → Add Library
4. 配置 `Info.plist`（Target → Info 标签）：
   - `UIBackgroundModes` → 添加 `audio`（听书后台不断）
   - `CFBundleDocumentTypes`：添加 5 个文档类型 `txt / pdf / docx / pptx / md`，勾选 "Viewer"，使「文件 App → 用听阅打开」生效
   - `UISupportsDocumentBrowser = YES`
   - `LSSupportsOpeningDocumentsInPlace = NO`
5. `Signing & Capabilities`：
   - Team 选你的个人 Apple ID（没有就点 `Add Account` 登录，免费即可）
   - Bundle Identifier 改唯一：`com.你的名字.tingyue`
   - 勾选 `Automatically manage signing`
6. iPhone 数据线连 Mac → 顶部选真机 → **⌘R Run**
7. 手机上首次打开会提示"不受信任的开发者"：设置 → 通用 → VPN与设备管理 → 信任你的 Apple ID

> 免费证书 **7 天过期**，到期重连 Mac 点一次 Run 即可（或用 AltStore 自动续签）；¥688/年 开发者账号则 1 年。

## 二、豆包音色配置（App 内操作）

1. 注册 [火山引擎](https://www.volcengine.com/) → 实名认证 → 控制台搜索「语音合成大模型」开通
2. 拿到 **App ID** 与 **Access Token**（App Key/Secret 需换取，详见官方文档「获取语音合成访问令牌」）
3. App「设置」页填入 → 点「试听」确认 → 阅读页即可用豆包音色朗读

不配置也能用：自动降级 iPhone 系统离线中文音色（设置 → 辅助功能 → 语音内容 可下载更多音色）。

## 三、功能清单

- [x] 书架：网格展示、进度条、导入/删除
- [x] 导入：App 内文件选择器 + 文件App「用听阅打开」
- [x] 解析：TXT(GBK/UTF-8) / PDF(文字层) / DOCX / PPTX / Markdown
- [x] 阅读：分句排版、点句朗读、高亮跟随、字号/夜间模式
- [x] 听书：豆包 5 音色切换、语速 0.5x–2.0x、上一句/下一句
- [x] 后台播放 + 锁屏/控制中心控制
- [x] 定时关闭（15/30/60 分钟）
- [x] 阅读进度自动记忆

## 四、目录结构

```
TingYue/
├── TingYueApp.swift        入口 + 外部文档打开导入
├── Models/Book.swift       书籍模型（SwiftData）+ 沙盒存储
├── Services/
│   ├── ParserService.swift 格式解析 + 分句
│   ├── ImportService.swift 文件导入
│   ├── TTSManager.swift    火山引擎豆包 TTS（在线）
│   └── PlayerManager.swift 播放队列/后台/锁屏/定时
└── Views/
    ├── MainTabView.swift   三 Tab 入口
    ├── BookShelfView.swift 书架
    ├── ReaderView.swift    阅读页（含设置浮层）
    ├── NowPlayingView.swift 正在听页
    └── SettingsView.swift  设置页
```

## 五、已知边界

- 扫描版 PDF 无文字层，会提示导入失败（OCR 属二期）
- 在线合成每次请求上限 1024 字符，代码已自动按句切分，无感知
- 复杂排版 Word/PPT 只提取正文文本（听书场景足够）
- 代码在 Windows 环境编写，未经 Xcode 编译验证，如遇小编译错误（如 iOS 版本 API 差异）按 Xcode 提示微调即可
