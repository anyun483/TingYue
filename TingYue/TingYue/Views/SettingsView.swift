import SwiftUI

/// 设置页：豆包在线合成配置 / 音色切换 / 默认语速 / 引擎开关
struct SettingsView: View {
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var tts = TTSManager.shared
    @AppStorage("use_online_tts") private var useOnline = true
    @State private var appID = UserDefaults.standard.string(forKey: "volcano_appid") ?? ""
    @State private var token = UserDefaults.standard.string(forKey: "volcano_token") ?? ""
    @State private var testText = "你好，我是听阅，很高兴为你读书。"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("优先使用豆包在线音色", isOn: $useOnline)
                    if useOnline {
                        TextField("火山引擎 App ID", text: $appID)
                            .autocorrectionDisabled().textInputAutocapitalization(.never)
                        SecureField("Access Token", text: $token)
                            .autocorrectionDisabled().textInputAutocapitalization(.never)
                        HStack {
                            TextField("试听文本", text: $testText)
                            Button("试听") { testVoice() }
                                .buttonStyle(.borderedProminent).disabled(appID.isEmpty || token.isEmpty)
                        }
                        if let err = tts.lastError {
                            Text("上次在线合成失败：\(err)（已自动用系统音色）")
                                .font(.caption).foregroundStyle(.red)
                        }
                    }
                } header: {
                    Text("豆包音色（火山引擎语音合成）")
                } footer: {
                    Text("火山引擎控制台 → 语音技术 → 语音合成大模型，获取 App ID 与 Access Token。个人实名后每月有免费额度；不配置则自动使用 iPhone 系统离语音色。")
                }

                Section("音色") {
                    Picker("在线音色", selection: $player.voice) {
                        ForEach(TTSManager.onlineVoices) { v in
                            Text(v.name).tag(v)
                        }
                    }
                }

                Section {
                    Slider(value: Binding(get: { player.speed },
                                          set: { player.speed = $0 }),
                           in: 0.5...2.0, step: 0.1)
                    Text("默认语速 \(String(format: "%.1f", player.speed))x")
                        .font(.footnote).foregroundStyle(.secondary)
                } header: { Text("语速") }

                Section("关于") {
                    LabeledContent("版本", value: "1.0.0")
                    LabeledContent("支持格式", value: "TXT / PDF / Word / PPT / Markdown")
                }
            }
            .navigationTitle("设置")
            .onChange(of: appID) { tts.volcanoAppID = $0 }
            .onChange(of: token) { tts.volcanoToken = $0 }
            .onChange(of: useOnline) { player.useOnline = $0 }
            .onAppear {
                player.speed = UserDefaults.standard.object(forKey: "read_speed") as? Double ?? 1.0
            }
        }
    }

    private func testVoice() {
        Task {
            if let url = try? await tts.synthesizeOnline(text: testText, voice: player.voice,
                                                         speed: player.speed) {
                tts.lastError = nil
                let p = try? AVAudioPlayer(contentsOf: url)
                p?.play()
            } else {
                tts.lastError = "合成失败，请检查 AppID / Token"
            }
        }
    }
}

import AVFoundation
