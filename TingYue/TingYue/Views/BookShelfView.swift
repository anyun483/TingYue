import SwiftUI
import UniformTypeIdentifiers

struct BookShelfView: View {
    @EnvironmentObject private var store: BookStore
    @State private var showPicker = false
    @State private var importError: String?
    @State private var importing = false

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 16)]

    var body: some View {
        NavigationStack {
            Group {
                if store.books.isEmpty {
                    emptyView
                } else {
                    gridView
                }
            }
            .navigationTitle("听阅")
            .navigationDestination(for: Book.self) { ReaderView(book: $0) }
            .toolbar {
                Button { showPicker = true } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
            .overlay { if importing { ProgressView("正在解析文档…") } }
            .fileImporter(isPresented: $showPicker, allowedContentTypes: ImportService.pickerTypes,
                          allowsMultipleSelection: false) { result in
                guard case .success(let urls) = result, let url = urls.first else { return }
                importFile(url)
            }
            .alert("导入失败", isPresented: .init(get: { importError != nil },
                                             set: { if !$0 { importError = nil } })) {
                Button("好", role: .cancel) {}
            } message: { Text(importError ?? "") }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "books.vertical")
                .font(.system(size: 56)).foregroundStyle(.tertiary)
            Text("书架空空的，导入一份文档开始吧").foregroundStyle(.secondary)
        }
    }

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(store.books) { book in
                    NavigationLink(value: book) { BookCell(book: book) }
                        .contextMenu {
                            Button(role: .destructive) { store.delete(book) } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                }
            }
            .padding()
        }
    }

    private func importFile(_ url: URL) {
        importing = true
        Task.detached {
            do {
                let book = try ImportService.importFile(url)
                await MainActor.run {
                    store.addExisting(book)
                    importing = false
                }
            } catch {
                let msg = error.localizedDescription
                await MainActor.run {
                    importError = msg
                    importing = false
                }
            }
        }
    }
}

struct BookCell: View {
    let book: Book
    private var icon: (String, Color) {
        switch book.format {
        case "pdf": return ("doc.richtext", .red)
        case "docx": return ("doc.fill", .blue)
        case "pptx": return ("rectangle.stack.fill", .orange)
        default: return ("text.book.closed.fill", .green)
        }
    }
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(icon.1.opacity(0.15))
                Image(systemName: icon.0).font(.system(size: 34)).foregroundStyle(icon.1)
                VStack {
                    Spacer()
                    ProgressView(value: book.progressRatio)
                        .tint(.orange).padding(6)
                }
            }
            .aspectRatio(0.72, contentMode: .fit)
            Text(book.title).lineLimit(1).font(.footnote)
            Text("\(Int(book.progressRatio * 100))%").font(.caption2).foregroundStyle(.secondary)
        }
    }
}
