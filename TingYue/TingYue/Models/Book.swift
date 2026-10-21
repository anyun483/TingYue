import Foundation
import SwiftData

@Model
final class Book {
    var id: UUID
    var title: String
    var fileName: String          // 沙盒 Documents/Books 下的文件名
    var format: String            // txt / pdf / docx / pptx / md
    var createdAt: Date
    var progressRatio: Double     // 0~1 阅读进度
    var charIndex: Int            // 朗读/阅读位置（字符偏移）

    init(title: String, fileName: String, format: String) {
        self.id = UUID()
        self.title = title
        self.fileName = fileName
        self.format = format
        self.createdAt = Date()
        self.progressRatio = 0
        self.charIndex = 0
    }

    var textURL: URL {
        BookStorage.booksDir.appendingPathComponent(fileName + ".txt")
    }
}

enum BookStorage {
    static var booksDir: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Books", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
