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

    /// 复制进沙盒 → 解析 → 存纯文本 → 建 Book 模型
    static func importFile(_ url: URL, context: ModelContext) throws -> Book {
        let secured = url.startAccessingSecurityScopedResource()
        defer { if secured { url.stopAccessingSecurityScopedResource() } }

        let (title, text) = try ParserService.parse(fileURL: url)
        let fileName = UUID().uuidString
        let dest = BookStorage.booksDir.appendingPathComponent(fileName + ".txt")
        try text.data(using: .utf8)?.write(to: dest, options: .atomic)

        let book = Book(title: title, fileName: fileName,
                        format: url.pathExtension.lowercased())
        context.insert(book)
        try context.save()
        return book
    }
}
