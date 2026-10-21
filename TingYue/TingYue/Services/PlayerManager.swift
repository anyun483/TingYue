import Foundation
import AVFoundation
import MediaPlayer
import UIKit

/// 朗读播放器：句子队列 + 后台播放 + 锁屏控制 + 定时关闭
/// 在线模式：逐句调火山 TTS → AVAudioPlayer 播放
/// 离线模式：AVSpeechSynthesizer
final class PlayerManager: NSObject, ObservableObject {
    static let shared = PlayerManager()

    // MARK: - 状态
    @Published var isPlaying = false
    @Published var currentIndex = 0            // 当前句子索引
    @Published var sentences: [String] = []    // 全部分句
    @Published var voice: TTSManager.Voice
    @Published var speed: Double               // 0.5 ~ 2.0
    @Published var useOnline: Bool             // 优先在线豆包音色
    @Published var autoStopDate: Date?         // 定时关闭
    @Published var bookTitle: String = ""

    private var audioPlayer: AVAudioPlayer?
    private let synthesizer = AVSpeechSynthesizer()
    private var nextTimer: Timer?

    override private init() {
        self.voice = TTSManager.onlineVoices[0]
        self.speed = UserDefaults.standard.object(forKey: "read_speed") as? Double ?? 1.0
        self.useOnline = UserDefaults.standard.object(forKey: "use_online_tts") as? Bool ?? true
        super.init()
        synthesizer.delegate = self
        setupAudioSession()
        setupRemoteCommands()
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil
        ) { [weak self] _ in self?.checkAutoStop() }
    }

    private var currentBook: Book?

    // MARK: - 开始朗读
    func startReading(book: Book, text: String, fromIndex: Int = 0) {
        self.currentBook = book
        self.bookTitle = book.title
        self.sentences = ParserService.splitSentences(text)
        self.currentIndex = fromIndex
        playCurrent()
    }

    func stop() {
        isPlaying = false
        synthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        nextTimer?.invalidate()
    }

    // MARK: - 控制
    func togglePlay() { isPlaying ? pause() : resume() }

    func pause() {
        isPlaying = false
        synthesizer.pauseSpeaking(at: .word)
        audioPlayer?.pause()
    }

    func resume() {
        isPlaying = true
        if synthesizer.isPaused { synthesizer.continueSpeaking(); return }
        if let p = audioPlayer, p.duration > p.currentTime { p.play(); return }
        playCurrent()
    }

    func next() { currentIndex = min(currentIndex + 1, sentences.count - 1); playCurrent() }
    func previous() { currentIndex = max(currentIndex - 1, 0); playCurrent() }

    func setAutoStop(minutes: Int?) {
        autoStopDate = minutes.map { Date().addingTimeInterval(Double($0) * 60) }
    }

    private func checkAutoStop() {
        if let d = autoStopDate, Date() >= d { stop() }
    }

    // MARK: - 播放当前句
    private func playCurrent() {
        guard sentences.indices.contains(currentIndex) else { stop(); return }
        checkAutoStop()
        saveProgress()
        isPlaying = true
        let text = sentences[currentIndex]
        if useOnline && TTSManager.shared.volcanoAppID.count > 0 {
            speakOnline(text)
        } else {
            TTSManager.shared.usingOnline = false
            speakOffline(text)
        }
    }

    private func speakOnline(_ text: String) {
        Task { @MainActor in
            do {
                let url = try await TTSManager.shared.synthesizeOnline(
                    text: text, voice: voice, speed: speed)
                TTSManager.shared.usingOnline = true
                let p = try AVAudioPlayer(contentsOf: url)
                p.rate = 1.0
                p.delegate = self
                audioPlayer = p
                p.play()
            } catch {
                // 在线失败 → 降级系统 TTS
                TTSManager.shared.lastError = error.localizedDescription
                TTSManager.shared.usingOnline = false
                speakOffline(text)
            }
        }
    }

    private func speakOffline(_ text: String) {
        let utt = AVSpeechUtterance(string: text)
        utt.rate = Float(0.5 * speed)   // 系统 rate 0~1，1x≈0.5
        utt.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        synthesizer.speak(utt)
    }

    private func advance() {
        currentIndex += 1
        if currentIndex >= sentences.count { stop(); return }
        // 留 100ms 缓冲避免密集请求
        nextTimer?.invalidate()
        nextTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            self?.playCurrent()
        }
    }

    private func saveProgress() {
        guard var book = currentBook else { return }
        let total = sentences.reduce(0) { $0 + $1.count }
        let done = sentences[0..<currentIndex].reduce(0) { $0 + $1.count }
        book.charIndex = done
        book.progressRatio = total > 0 ? Double(done) / Double(total) : 0
        currentBook = book
        Task { @MainActor in
            BookStore.shared.update(book)
        }
    }

    // MARK: - 后台 & 锁屏
    private func setupAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func setupRemoteCommands() {
        let cc = MPRemoteCommandCenter.shared()
        cc.playCommand.addTarget { [weak self] _ in
            self?.resume(); return .success }
        cc.pauseCommand.addTarget { [weak self] _ in
            self?.pause(); return .success }
        cc.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlay(); return .success }
        cc.nextTrackCommand.addTarget { [weak self] _ in
            self?.next(); return .success }
        cc.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous(); return .success }
    }

    private func updateNowPlaying() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: sentences.indices.contains(currentIndex)
                ? sentences[currentIndex] : "",
            MPMediaItemPropertyArtist: "听阅 · \(bookTitle)",
            MPMediaItemPropertyPlaybackDuration: 0,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1 : 0
        ]
        if let p = audioPlayer {
            info[MPMediaItemPropertyPlaybackDuration] = p.duration
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = p.currentTime
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

// MARK: - 系统合成完成 → 下一句
extension PlayerManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.advance() }
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {}
}

// MARK: - 在线音频播完 → 下一句
extension PlayerManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ p: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { self.advance() }
    }
}
