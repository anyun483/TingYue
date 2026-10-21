import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// 文档导入：文件选择器 / 外部「用听阅打开」
enum ImportService {

    /// 放开为所有文件（避免常见格式被文件选择器灰掉），格式由 ParserService 按扩展名校验
    static var pickerTypes: [UTType] {
        [.item]
    }

    /// 支持的扩展名白名单
    static let supportedExtensions = ["txt", "pdf", "docx", "pptx", "md", "markdown"]

    /// 复制进沙盒 → 解析 → 存纯文本 → 返回 Book（未入库）
    static func importFile(_ url: URL) throws -> Book {
        let secured = url.startAccessingSecurityScopedResource()
        defer { if secured { url.stopAccessingSecurityScopedResource() } }

        let ext = url.pathExtension.lowercased()
        guard supportedExtensions.contains(ext) else {
            throw ParseError.unsupportedFormat(ext)
        }
        let (title, text) = try ParserService.parse(fileURL: url)
        let fileName = UUID().uuidString
        let dest = BookStorage.booksDir.appendingPathComponent(fileName + ".txt")
        try text.data(using: .utf8)?.write(to: dest, options: .atomic)

        return Book(title: title, fileName: fileName,
                    format: url.pathExtension.lowercased())
    }
}

extension BookStore {
    /// 外部打开导入入口（onOpenURL），失败时通过通知弹出错误
    @MainActor
    func importFromOutside(_ url: URL) {
        do {
            let book = try ImportService.importFile(url)
            books.insert(book, at: 0)
            save()
        } catch {
            NotificationCenter.default.post(
                name: .init("tingyue.importError"), object: nil,
                userInfo: ["message": error.localizedDescription])
        }
    }
}
