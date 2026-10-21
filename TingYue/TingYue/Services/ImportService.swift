import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// 文档导入：文件选择器 / 外部「用听阅打开」
enum ImportService {

    static var pickerTypes: [UTType] {
        [.text, .pdf, .plainText,
         UTType(filenameExtension: "docx") ?? .data,
         UTType(filenameExtension: "pptx") ?? .data,
         UTType(filenameExtension: "md") ?? .data]
    }

    /// 复制进沙盒 → 解析 → 存纯文本 → 入库
    static func importFile(_ url: URL) throws -> Book {
        let secured = url.startAccessingSecurityScopedResource()
        defer { if secured { url.stopAccessingSecurityScopedResource() } }

        let (title, text) = try ParserService.parse(fileURL: url)
        let fileName = UUID().uuidString
        let dest = BookStorage.booksDir.appendingPathComponent(fileName + ".txt")
        try text.data(using: .utf8)?.write(to: dest, options: .atomic)

        return Book(title: title, fileName: fileName,
                    format: url.pathExtension.lowercased())
    }
}

extension BookStore {
    /// 外部打开导入入口（onOpenURL）
    @MainActor
    func importFromOutside(_ url: URL) {
        guard let book = try? ImportService.importFile(url) else { return }
        addExisting(book)
    }

    @MainActor
    func addExisting(_ book: Book) {
        books.insert(book, at: 0)
        save()
    }
}
