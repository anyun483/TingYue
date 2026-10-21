import Foundation
import SwiftUI
import PDFKit
import ZIPFoundation

/// 文档解析服务：把 txt / pdf / docx / pptx / md 统一转成纯文本
enum ParserService {

    /// 解析导入的文件，返回 (书名, 纯文本)。失败抛错。
    static func parse(fileURL url: URL) throws -> (title: String, text: String) {
        let ext = url.pathExtension.lowercased()
        let title = url.deletingPathExtension().lastPathComponent
        let text: String
        switch ext {
        case "txt": text = try parseTXT(url)
        case "pdf": text = try parsePDF(url)
        case "docx": text = try parseDocx(url)
        case "pptx": text = try parsePptx(url)
        case "md", "markdown": text = try parseMarkdown(url)
        default: throw ParseError.unsupportedFormat(ext)
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ParseError.noTextLayer
        }
        return (title, text)
    }

    // MARK: - TXT（自动识别 UTF-8 / GBK）
    static func parseTXT(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        if let s = String(data: data, encoding: .utf8) { return s }
        let enc = CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
        if let s = String(data: data, encoding: String.Encoding(rawValue: enc)) { return s }
        throw ParseError.decodingFailed
    }

    // MARK: - PDF（PDFKit 提取文字层）
    static func parsePDF(_ url: URL) throws -> String {
        guard let doc = PDFDocument(url: url) else { throw ParseError.cannotOpen }
        var pages: [String] = []
        for i in 0..<doc.pageCount {
            if let page = doc.page(at: i), let content = page.string {
                pages.append(content.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        return pages.joined(separator: "\n\n")
    }

    // MARK: - DOCX（解压取 word/document.xml 的 <w:t> 文本）
    static func parseDocx(_ url: URL) throws -> String {
        let xml = try extractZipEntry(url, entryPath: "word/document.xml")
        return extractTaggedText(xml: xml, tag: "w:t", joinNewlineTag: "w:p")
    }

    // MARK: - PPTX（每页 slideN.xml 的 <a:t>，按页分组）
    static func parsePptx(_ url: URL) throws -> String {
        let archive = try Archive(url: url, accessMode: .read)
        var slides: [(Int, String)] = []
        for entry in archive where
            entry.path.hasPrefix("ppt/slides/slide") && entry.path.hasSuffix(".xml") {
            let numStr = entry.path
                .replacingOccurrences(of: "ppt/slides/slide", with: "")
                .replacingOccurrences(of: ".xml", with: "")
            let num = Int(numStr) ?? 0
            let xml = try extractEntry(archive, entry)
            let text = extractTaggedText(xml: xml, tag: "a:t", joinNewlineTag: "a:p")
            if !text.isEmpty { slides.append((num, text)) }
        }
        slides.sort { $0.0 < $1.0 }
        return slides.map { "【第 \($0.0) 页】\n\($0.1)" }.joined(separator: "\n\n")
    }

    // MARK: - Markdown（去语法标记）
    static func parseMarkdown(_ url: URL) throws -> String {
        var s = try parseTXT(url)
        let patterns = [#"^#{1,6}\s*"#, #"\*\*"#, #"\*"#, #"`"#, #"!\[.*?\]\(.*?\)"#,
                        #"\[(.*?)\]\(.*?\)"#]
        for p in patterns { s = s.replacingOccurrences(of: p, with: "$1", options: .regularExpression) }
        return s
    }

    // MARK: - helpers
    private static func extractZipEntry(_ url: URL, entryPath: String) throws -> String {
        guard let archive = try? Archive(url: url, accessMode: .read),
              let entry = archive.first(where: { $0.path == entryPath }) else {
            throw ParseError.cannotOpen
        }
        let xml = try extractEntry(archive, entry)
        return xml
    }

    /// ZIPFoundation consumer API
    private static func extractEntry(_ archive: Archive, _ entry: Entry) throws -> String {
        var data = Data()
        _ = try archive.extract(entry) { chunk in data.append(chunk) }
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// 提取 XML 中 <tag>…</tag> 文本；joinNewlineTag 的每个出现处换行
    private static func extractTaggedText(xml: String, tag: String, joinNewlineTag: String) -> String {
        var text = xml
        // 先在段落标签处插入换行符
        let paraPattern = "<\(joinNewlineTag)[ >]"
        text = text.replacingOccurrences(of: paraPattern, with: "\n¶<\(joinNewlineTag) ",
                                          options: .regularExpression)
        let pattern = "<\(tag)[^>]*>(.*?)</\(tag)>"
        var result = ""
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
            let ns = text as NSString
            regex.enumerateMatches(in: text, range: NSRange(location: 0, length: ns.length)) { m, _, _ in
                guard let m = m, m.numberOfRanges > 1 else { return }
                var seg = ns.substring(with: m.range(at: 1))
                // XML 实体解码
                seg = seg.replacingOccurrences(of: "&amp;", with: "&")
                         .replacingOccurrences(of: "&lt;", with: "<")
                         .replacingOccurrences(of: "&gt;", with: ">")
                         .replacingOccurrences(of: "&quot;", with: "\"")
                result += seg
            }
        }
        // ¶ 标记处换行
        result = result.replacingOccurrences(of: "¶", with: "\n")
        // 压缩多余空行
        return result.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
    }

    /// 分句：朗读与高亮的基本单位
    static func splitSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        var current = ""
        for ch in text {
            current.append(ch)
            if "。！？!?；;\n".contains(ch) {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { sentences.append(trimmed) }
                current = ""
            }
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { sentences.append(tail) }
        return sentences
    }
}

enum ParseError: LocalizedError {
    case unsupportedFormat(String), noTextLayer, cannotOpen, decodingFailed
    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let e): return "暂不支持的格式：.\(e)（支持 txt/pdf/docx/pptx/md）"
        case .noTextLayer: return "文档没有可提取的文字（扫描版 PDF 需 OCR，暂不支持）"
        case .cannotOpen: return "文件无法打开或已损坏"
        case .decodingFailed: return "文本编码无法识别"
        }
    }
}
