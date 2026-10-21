import SwiftUI
import Combine

/// 阅读页：分句显示 + 点击任意句从该句朗读 + 高亮跟随
struct ReaderView: View {
    let book: Book
    @StateObject private var player = PlayerManager.shared
    @AppStorage("font_size") private var fontSize: Double = 18
    @AppStorage("night_mode") private var nightMode = false
    @State private var sentences: [String] = []
    @State private var showSettings = false
    @State private var followCancellable: AnyCancellable?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(sentences.indices, id: \.self) { i in
                        SentenceRow(text: sentences[i],
                                    isCurrent: i == player.currentIndex && player.isPlaying,
                                    fontSize: fontSize)
                            .id(i)
                            .onTapGesture {
                                player.startReading(book: book,
                                                    text: sentences.joined(separator: "\n"),
                                                    fromIndex: i)
                                withAnimation { proxy.scrollTo(i, anchor: .center) }
                            }
                    }
                }
                .padding()
            }
            .background(nightMode ? Color(red: 0.11, green: 0.11, blue: 0.12) : Color(.systemBackground))
            .preferredColorScheme(nightMode ? .dark : nil)
            .onAppear {
                if sentences.isEmpty {
                    sentences = loadSentences()
                    // 恢复进度
                    if book.charIndex > 0, let idx = indexForCharOffset(book.charIndex) {
                        player.startReading(book: book,
                                            text: sentences.joined(separator: "\n"),
                                            fromIndex: idx)
                        player.pause()
                        proxy.scrollTo(idx, anchor: .center)
                    }
                }
                followCancellable = player.$currentIndex
                    .receive(on: DispatchQueue.main)
                    .sink { i in
                        guard player.isPlaying else { return }
                        withAnimation { proxy.scrollTo(i, anchor: .center) }
                    }
            }
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button { player.previous() } label: { Image(systemName: "backward.end") }
                Button { player.togglePlay() } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title)
                }
                Button { player.next() } label: { Image(systemName: "forward.end") }
                Spacer()
                Menu {
                    Picker("音色", selection: $player.voice) {
                        ForEach(TTSManager.onlineVoices) { v in
                            Text(v.name + "（豆包）").tag(v)
                        }
                    }
                    Text("未配置豆包时自动使用系统离线音色").font(.caption)
                } label: { Image(systemName: "person.wave.2") }
                Button { showSettings = true } label: { Image(systemName: "textformat") }
            }
        }
        .sheet(isPresented: $showSettings) {
            ReaderSettingsSheet(fontSize: $fontSize, nightMode: $nightMode,
                                speed: Binding(get: { player.speed },
                                               set: { player.speed = $0 }))
                .presentationDetents([.height(300)])
        }
    }

    private func loadSentences() -> [String] {
        guard let text = try? String(contentsOf: book.textURL, encoding: .utf8) else { return [] }
        return ParserService.splitSentences(text)
    }

    /// 字符偏移 → 句子索引（恢复进度用）
    private func indexForCharOffset(_ offset: Int) -> Int? {
        var acc = 0
        for (i, s) in sentences.enumerated() {
            if acc >= offset { return i }
            acc += s.count
        }
        return nil
    }
}

/// 单句视图（拆分以避免整棵 View 树类型检查超时）
struct SentenceRow: View {
    let text: String
    let isCurrent: Bool
    let fontSize: Double

    var body: some View {
        Text(text)
            .font(.system(size: fontSize))
            .padding(.horizontal, 4)
            .background(isCurrent ? Color.orange.opacity(0.25) : Color.clear)
            .cornerRadius(6)
    }
}

/// 字号 / 夜间 / 语速 浮层
struct ReaderSettingsSheet: View {
    @Binding var fontSize: Double
    @Binding var nightMode: Bool
    @Binding var speed: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("字号") {
                    Slider(value: $fontSize, in: 12...30, step: 1)
                    Text("示例：听阅读书，声声入耳")
                        .font(.system(size: fontSize))
                }
                Section("朗读语速（\(String(format: "%.1f", speed))x）") {
                    Slider(value: $speed, in: 0.5...2.0, step: 0.1)
                }
                Section("外观") {
                    Toggle("夜间模式", isOn: $nightMode)
                }
            }
            .navigationTitle("阅读设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("完成") { dismiss() } }
        }
    }
}
