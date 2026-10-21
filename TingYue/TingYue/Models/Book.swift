import Foundation

/// 书籍模型（纯 Codable，iOS 16 兼容，无需 SwiftData）
struct Book: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var fileName: String          // 沙盒 Documents/Books 下的文件名
    var format: String            // txt / pdf / docx / pptx / md
    var createdAt: Date = Date()
    var progressRatio: Double = 0 // 0~1 阅读进度
    var charIndex: Int = 0        // 朗读/阅读位置（字符偏移）

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

/// 书架存储：JSON 文件持久化（iOS 16 兼容方案）
@MainActor
final class BookStore: ObservableObject {
    @Published var books: [Book] = []
    static let shared = BookStore()

    private var storeURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("books.json")
    }

    init() { load() }

    func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let list = try? JSONDecoder().decode([Book].self, from: data) else { return }
        books = list
    }

    func save() {
        if let data = try? JSONEncoder().encode(books) {
            try? data.write(to: storeURL, options: .atomic)
        }
    }

    @discardableResult
    func add(title: String, fileName: String, format: String) -> Book {
        var book = Book(title: title, fileName: fileName, format: format)
        books.insert(book, at: 0)
        save()
        // 返回前记录 id（值类型拷贝）
        return book
    }

    func insert(_ book: Book) {
        books.insert(book, at: 0)
        save()
    }

    func update(_ book: Book) {
        guard let i = books.firstIndex(where: { $0.id == book.id }) else { return }
        books[i] = book
        save()
    }

    func delete(_ book: Book) {
        books.removeAll { $0.id == book.id }
        try? FileManager.default.removeItem(at: book.textURL)
        save()
    }
}
