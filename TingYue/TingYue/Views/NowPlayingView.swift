import SwiftUI

/// 「正在听」页：当前书目卡片 + 歌词式滚动 + 播放控制
struct NowPlayingView: View {
    @ObservedObject private var player = PlayerManager.shared
    @State private var autoStopMinutes: Int?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if player.sentences.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "waveform")
                            .font(.system(size: 56)).foregroundStyle(.tertiary)
                        Text("还没有正在听的内容").foregroundStyle(.secondary)
                        Text("去书架打开一本书，点击任意句子开始朗读")
                            .font(.footnote).foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // 歌词式滚动文本
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 14) {
                                ForEach(player.sentences.indices, id: \.self) { i in
                                    Text(player.sentences[i])
                                        .font(.system(size: 20,
                                                      weight: i == player.currentIndex ? .semibold : .regular))
                                        .foregroundStyle(i == player.currentIndex && player.isPlaying
                                                         ? Color.orange : Color.secondary)
                                        .id(i)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .onChange(of: player.currentIndex) { i in
                            withAnimation { proxy.scrollTo(i, anchor: .center) }
                        }
                    }

                    // 播放控制面板
                    VStack(spacing: 16) {
                        Text(player.bookTitle).font(.headline).lineLimit(1)

                        HStack(spacing: 44) {
                            Button { player.previous() } label: {
                                Image(systemName: "backward.end.fill").font(.title2)
                            }
                            Button { player.togglePlay() } label: {
                                Image(systemName: player.isPlaying
                                      ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 64)).foregroundStyle(.orange)
                            }
                            Button { player.next() } label: {
                                Image(systemName: "forward.end.fill").font(.title2)
                            }
                        }
                        .buttonStyle(.plain)

                        HStack {
                            Image(systemName: "gauge.with.dots.needle.50percent")
                            Slider(value: Binding(get: { player.speed },
                                                  set: { player.speed = $0 }),
                                   in: 0.5...2.0, step: 0.1)
                            Text(String(format: "%.1fx", player.speed))
                                .font(.caption.monospacedDigit())
                        }

                        Menu {
                            Button("15 分钟") { autoStopMinutes = 15; player.setAutoStop(minutes: 15) }
                            Button("30 分钟") { autoStopMinutes = 30; player.setAutoStop(minutes: 30) }
                            Button("60 分钟") { autoStopMinutes = 60; player.setAutoStop(minutes: 60) }
                            Button("取消定时", role: .destructive) {
                                autoStopMinutes = nil; player.setAutoStop(minutes: nil)
                            }
                        } label: {
                            Label(autoStopMinutes == nil ? "定时关闭" : "已定时 \(autoStopMinutes!) 分钟",
                                  systemImage: "moon.zzz")
                                .font(.footnote)
                        }
                    }
                    .padding()
                    .background(.bar)
                }
            }
            .navigationTitle("正在听")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
