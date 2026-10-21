# 「听阅」— iOS 自签听书 App 设计文档

> 一款无需上架 App Store、通过个人 Apple ID 免费自签的 iOS 阅读 + 听书应用。
> 支持导入 Word / PPT / TXT / PDF / Markdown / EPUB，用豆包风格音色朗读，可调语速、切换音色。

---

## 1. 总体方案

| 项目 | 方案 |
|---|---|
| 目标平台 | iOS 15+（iPhone 为主） |
| 开发框架 | SwiftUI + AVFoundation |
| 开发工具 | Xcode（Mac 上运行，Windows 用户可用云 Mac 如 MacStadium / 巨量云码） |
| 分发方式 | 个人开发者账号（免费 Apple ID）自签，7 天有效；或付费开发者账号（¥688/年）自签 1 年 |
| 签名工具 | Xcode 直签 / AltStore / Sideloadly / 全能签 等 |
| TTS 引擎 | 火山引擎 豆包语音合成 API（在线，最接近豆包音色）+ AVSpeechSynthesizer（离线兜底） |
| 数据存储 | 本地文件 + UserDefaults / SwiftData（阅读进度、书架） |

### 1.1 自签说明（重要）

- **免费 Apple ID**：Xcode 里登录个人 Apple ID，Bundle ID 改成唯一值（如 `com.anyun.tingyue`），直接 Run 到真机即可安装，**每 7 天需重签一次**（重新连 Mac 点 Run，或用 AltStore 自动续签）。
- **付费开发者账号**：签名有效期 1 年，体验最好。
- **无需上架**：个人证书签名的 App 只能在自己设备上运行，正好符合你的需求。
- 注意：设备需在「设置 → 通用 → VPN与设备管理」中信任开发者证书。

---

## 2. 功能模块设计

### 2.1 功能架构图

```
听阅 App
├── 书架模块
│   ├── 文档导入（文件App / AirDrop / Wi-Fi传输）
│   ├── 格式解析（txt/pdf/docx/pptx/md/epub）
│   ├── 书籍管理（封面、进度、删除、分组）
│
├── 阅读模块
│   ├── 分页/滚动阅读器
│   ├── 字体、字号、行距、主题（日间/夜间/护眼）
│   ├── 阅读进度记忆、书签、目录跳转
│   ├── 划词朗读 / 从任意段落开始朗读
│
├── 听书模块（TTS）
│   ├── 豆包音色（火山引擎 API 在线合成）
│   ├── 音色切换（阳光男声/温柔女声/甜美女声/少年音…）
│   ├── 语速调节（0.5x ~ 2.0x）
│   ├── 后台播放 + 锁屏控制（MPRemoteCommandCenter）
│   ├── 定时关闭（15/30/60分钟/读完结尾）
│   ├── 逐句高亮跟随（朗读到哪一句亮哪句）
│
└── 设置模块
    ├── TTS 引擎切换（豆包在线 / 系统离线）
    ├── API Key 配置
    ├── 缓存清理
```

### 2.2 文档导入与解析

| 格式 | 解析方案 | 说明 |
|---|---|---|
| TXT | 原生 String | 自动识别 GBK/UTF-8 编码 |
| PDF | PDFKit（系统自带） | 提取文本层；扫描版 PDF 提示无文字层 |
| Word (.docx) | 苆果原生不行 → 用 `SwiftDocX` 或解压 XML 提取 `word/document.xml` 文本 | 免费方案够用 |
| PPT (.pptx) | 解压 XML 提取每页 `p:t` 文本 | 按幻灯片分页朗读 |
| Markdown | 原生正则去语法标记 | |
| EPUB | SwiftZipper 解压 + HTML 解析 | 可选二期 |

导入渠道：
1. 系统文件 App「用听阅打开」（注册 `CFBundleDocumentTypes` / `LSSupportsOpeningDocumentsInPlace`）
2. App 内「+」按钮 → `UIDocumentPickerViewController` 从文件 App / iCloud 选取
3. 局域网 Wi-Fi 传输（App 内起小型 HTTP Server，电脑浏览器拖文件进来，可选二做）

### 2.3 TTS 听书核心（豆包音色）

**方案 A（推荐）：火山引擎豆包语音 API**
- 火山引擎控制台开通「语音技术 → 语音合成大模型」，使用豆包同源的音色（如 `zh_female_...` 系列豆包音色）
- App 内通过 `URLSession` 调用，返回 MP3 音频流播放
- 需要用户自己注册火山引擎账号，把 Access Token 填进 App 设置页
- 优点：音色与豆包高度一致，自然度极高；缺点：需联网、按量计费（个人使用每月免费额度通常够用）

**方案 B（兜底）：AVSpeechSynthesizer（系统离线 TTS）**
- iOS 系统自带，完全离线免费，支持中文多音色（设置 → 辅助功能 → 语音内容 可下载「婷婷」「云希」等增强音色）
- 语速 `rate` 0.1~1.0 可调
- 用于无网环境或未配置 API Key 时

**App 内策略**：默认豆包在线，网络失败/无 Key 自动降级到系统 TTS，并在界面提示。

**音色列表设计**（对齐豆包）：
| 音色名 | 火山 voice_type | 特点 |
|---|---|---|
| 阳光青年 | BV001_streaming | 豆包默认男声，清朗 |
| 温柔淑女 | BV700_streaming | 豆包女声，温柔 |
| 甜美元声 | BV705_streaming | 少女音 |
| 磁性大叔 | BV002_streaming | 低沉稳重 |
| 活泼少年 | BV701_streaming | 少年音 |
| （离线）系统音色 | AVSpeechSynthesisVoice | 兜底 |

**朗读控制**：
- 语速滑杆 0.5x–2.0x，步进 0.1
- 播放/暂停/上一句/下一句/快进15s
- 定时关闭、读完结尾自动停
- 逐句高亮：TTS 按句子分段请求，配合 `AVAudioPlayer` 播放的同时高亮当前句
- 后台播放：`AVAudioSession` 设为 `.playback`，接入 `MPRemoteCommandCenter`，锁屏/控制中心可控制

---

## 3. 界面设计

### 3.1 页面结构（TabView 三个页签）

```
┌─────────────────────────────────────┐
│  听阅                        ⚙️ 设置 │
│ ┌─────────┐ ┌─────────┐ ┌─────────┐ │
│ │ 📕 封面  │ │ 📘 封面  │ │ 📙 封面  │ │  ← 书架（网格）
│ │ 三体 68% │ │ 报告 12% │ │ 笔记    │ │
│ └─────────┘ └─────────┘ └─────────┘ │
│        [ + 导入文档 ]                 │
├─────────────────────────────────────┤
│  📚 书架    ▶ 正在听    ⚙️ 设置       │
└─────────────────────────────────────┘
```

**关键页面：**
1. **书架页**：网格/列表展示，显示书名、封面（文档首页缩略图）、阅读进度；右上角导入；长按删除/重命名。
2. **正在听页**：当前书目大卡片 + 歌词式逐句滚动文本 + 底部播放器（音色按钮、语速滑杆、定时器）。
3. **阅读页**：全屏阅读，点屏幕中间呼出菜单（顶部返回/目录/书签，底部朗读按钮、字体/主题设置）；朗读时句子高亮 + 自动滚动。
4. **设置页**：TTS 引擎选择、火山引擎 Token 填写、音色试听、默认语速、外观主题。

### 3.2 视觉风格
- 主色：暖橙 #FF7A2F（听书氛围感），夜间模式深灰 #1C1C1E
- 字体：系统 SF / 苹方，阅读页可切「宋体模式」
- 圆角卡片 + 大按钮，单手可达（播放控制集中在屏幕下半部）

---

## 4. 技术实现要点

### 4.1 工程结构

```
TingYue/
├── TingYueApp.swift          // 入口
├── Models/
│   ├── Book.swift            // 书籍模型（SwiftData）
│   ├── ReadingProgress.swift
├── Services/
│   ├── ImportService.swift   // 文档导入 & 格式识别
│   ├── ParserService.swift   // txt/pdf/docx/pptx 解析为纯文本+分句
│   ├── TTSManager.swift      // 火山引擎 API + AVSpeechSynthesizer 统一封装
│   ├── PlayerManager.swift   // 播放队列、后台、锁屏控制、定时
│   └── WiFiTransfer.swift    // (二期) 局域网传书
├── Views/
│   ├── BookShelfView.swift
│   ├── NowPlayingView.swift
│   ├── ReaderView.swift
│   └── SettingsView.swift
└── Resources/
    └── Info.plist            // 注册文档类型、后台音频 UIBackgroundModes: audio
```

### 4.2 关键代码骨架

**分句（朗读与高亮的基本单位）：**
```swift
func splitSentences(_ text: String) -> [String] {
    // 按 。！？；\n 切分，保留标点
}
```

**火山引擎豆包 TTS 调用（核心）：**
```swift
func synthesize(_ text: String, voice: String, speed: Double,
                completion: @escaping (URL?) -> Void) {
    var req = URLRequest(url: URL(string: "https://openspeech.bytedance.com/api/v1/tts")!)
    req.httpMethod = "POST"
    req.setValue("Bearer;\(accessToken)", forHTTPHeaderField: "Authorization")
    // body: {app:{appid,token,cluster:volcano_tts},
    //        audio:{voice_type, encoding:"mp3", speed_ratio},
    //        request:{text, operation:"query", reqid: UUID}}
    // 返回 JSON 里 data 为 base64 MP3 → 存临时文件 → AVAudioPlayer 播放
}
```

**后台播放 + 锁屏控制：**
```swift
try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
try? AVAudioSession.sharedInstance().setActive(true)
MPRemoteCommandCenter.shared().playCommand.addTarget { _ in PlayerManager.shared.play(); return .success }
// pauseCommand / nextTrackCommand(下一句) / skipForwardCommand(快进15s)
```

### 4.3 Info.plist 关键配置
- `UIBackgroundModes: [audio]` —— 听书后台不断
- `CFBundleDocumentTypes` + `UTImportedTypeDeclarations` —— 支持「文件App → 用听阅打开」txt/pdf/docx/pptx
- `UISupportsDocumentBrowser = YES`

### 4.4 成本与额度说明
- 火山引擎语音合成：个人实名后有免费额度（新用户通常赠送几十万字符/数月），超出约 ¥xx/万字符，个人听书一个月几本书基本在几块钱以内；也可完全用系统离线 TTS，零成本。

---

## 5. 开发路线图

| 阶段 | 内容 | 工作量预估 |
|---|---|---|
| P0 MVP | TXT/PDF 导入 + 系统TTS朗读 + 语速/音色切换 + 书架 + 阅读页 | 1~2 周（业余时间） |
| P1 | 火山引擎豆包音色接入 + 逐句高亮 + 后台/锁屏播放 + 定时关闭 | 1 周 |
| P2 | Word/PPT 解析、Wi-Fi 传书、EPUB、书签、主题商店式皮肤 | 2 周+ |

## 6. 风险与注意事项
1. **自签 7 天过期**：免费证书每周要重签（AltStore 可自动），建议直接买 ¥688/年 个人开发者账号。
2. **docx/pptx 解析**：无官方 API，用社区库或自解 XML，复杂排版文档只取正文文本（听书场景足够）。
3. **扫描版 PDF** 无文字层，需 OCR（可用系统 Vision 框架 `VNRecognizeTextRequest`，中文识别免费离线）——列为 P2。
4. **API Key 安全**：自用 App 直接填在设置页存 Keychain 即可，无上架合规问题。
5. **版权提示**：仅自用导入自己的文档，不涉及分发，无风险。
