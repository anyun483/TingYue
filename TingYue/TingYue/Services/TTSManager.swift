import Foundation
import AVFoundation

/// TTS 统一封装：火山引擎豆包音色（在线）+ 系统离线兜底
final class TTSManager: NSObject, ObservableObject {
    static let shared = TTSManager()

    // MARK: - 音色定义
    struct Voice: Identifiable, Codable {
        let id: String            // 火山 voice_type 或系统 voice identifier
        let name: String
        let isOnline: Bool
    }

    /// 豆包同源音色（火山引擎大模型音色），需在设置页填 Access Token 后可用
    static let onlineVoices: [Voice] = [
        Voice(id: "BV001_streaming", name: "阳光青年", isOnline: true),
        Voice(id: "BV700_streaming", name: "温柔淑女", isOnline: true),
        Voice(id: "BV705_streaming", name: "甜美女声", isOnline: true),
        Voice(id: "BV002_streaming", name: "磁性大叔", isOnline: true),
        Voice(id: "BV701_streaming", name: "活泼少年", isOnline: true),
    ]

    @Published var usingOnline = false      // 当前一次合成是否走了在线
    @Published var lastError: String?

    // 用户配置（Keychain 级别简单存 UserDefaults，自用 App 足够）
    var volcanoAppID: String {
        get { UserDefaults.standard.string(forKey: "volcano_appid") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "volcano_appid") }
    }
    var volcanoToken: String {
        get { UserDefaults.standard.string(forKey: "volcano_token") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "volcano_token") }
    }

    // MARK: - 在线合成（火山引擎 /api/v1/tts，HTTP 返回 JSON，data 为 base64 mp3）
    func synthesizeOnline(text: String, voice: Voice, speed: Double) async throws -> URL {
        guard !volcanoAppID.isEmpty, !volcanoToken.isEmpty else {
            throw TTSError.notConfigured
        }
        var req = URLRequest(url: URL(string: "https://openspeech.bytedance.com/api/v1/tts")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer;\(volcanoToken)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "app": ["appid": volcanoAppID, "token": "access_token",
                    "cluster": "volcano_tts"],
            "user": ["uid": UIDevice.current.identifierForVendor?.uuidString ?? "tingyue"],
            "audio": ["voice_type": voice.id, "encoding": "mp3",
                      "speed_ratio": speed,
                      "sample_rate": 24000],
            "request": [
                "reqid": UUID().uuidString,
                "text": String(text.prefix(1024)),   // 单次请求上限 1024 字符
                "text_type": "plain",
                "operation": "query"
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 30

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw TTSError.httpError }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              obj["code"] as? Int == 3000,
              let b64 = obj["data"] as? String,
              let audio = Data(base64Encoded: b64) else {
            throw TTSError.apiError
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tts_\(UUID().uuidString).mp3")
        try audio.write(to: url)
        return url
    }
}

enum TTSError: LocalizedError {
    case notConfigured, httpError, apiError
    var errorDescription: String? {
        switch self {
        case .notConfigured: return "未配置火山引擎 AppID/Token"
        case .httpError: return "网络请求失败"
        case .apiError: return "豆包语音服务返回异常"
        }
    }
}
