import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum ReadingStatus: String, Codable, CaseIterable, Sendable {
    case planned = "计划阅读", finished = "已经读完"
}

public struct ReadingBook: Codable, Equatable, Identifiable, Sendable {
    public var id = UUID()
    public var title = ""
    public var author = ""
    public var category = ""
    public var status: ReadingStatus = .planned
    public var finishedOn = ""
    public var notes = ""
    /// Self-contained image bytes travel with drafts, trash and complete backups.
    public var cover: Data?
    public var addedAt = Date()
    public init() {}
    public var categoryLabel: String { category.isEmpty ? "未分类" : category }
    public mutating func setStatus(_ next: ReadingStatus, today: String) {
        status = next
        if next == .finished && finishedOn.isEmpty { finishedOn = today }
        if next == .planned { finishedOn = "" }
    }
    public mutating func normalize() {
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        author = author.trimmingCharacters(in: .whitespacesAndNewlines)
        category = category.trimmingCharacters(in: .whitespacesAndNewlines)
        if category == "未分类" { category = "" }
    }
    public func validate() throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw AppError("请填写书名。") }
        guard category.count <= 40 else { throw AppError("分类名称请控制在 40 字以内。") }
        try Day.validateOptional(finishedOn, name: "读完日期")
        guard status == .finished || finishedOn.isEmpty else { throw AppError("计划阅读的书不能填写读完日期。") }
        if let cover { try BookCover.validate(cover) }
    }
}

public enum BookCover {
    public static let maximumBytes = 512 * 1024
    public static func importImage(at url: URL) throws -> Data {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0 && size <= 30 * 1024 * 1024 else { throw AppError("请选择不超过 30 MB 的封面图片。") }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 960,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw AppError("无法读取这张图片，请选择有效的 PNG、JPEG、HEIC 或 WebP 图片。") }
        let result = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(result, UTType.jpeg.identifier as CFString, 1, nil) else { throw AppError("无法准备封面。") }
        CGImageDestinationAddImage(destination, thumb, [kCGImageDestinationLossyCompressionQuality: 0.78] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw AppError("封面转换失败，原封面未改变。") }
        let data = result as Data
        try validate(data)
        return data
    }
    public static func validate(_ data: Data) throws {
        guard !data.isEmpty, data.count <= maximumBytes,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetStatus(source) == .statusComplete,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              (1...960).contains(width), (1...960).contains(height)
        else { throw AppError("封面数据无效或过大，请重新选择图片。") }
    }
}

public enum ReadingShelf {
    public static func categories(_ books: [ReadingBook]) -> [String] {
        Set(books.map(\.category).filter { !$0.isEmpty }).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
    public static func filter(_ books: [ReadingBook], status: ReadingStatus?, category: String?, query: String) -> [ReadingBook] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return books.filter {
            (status == nil || $0.status == status) && (category == nil || $0.category == category) &&
            (query.isEmpty || $0.title.localizedStandardContains(query) || $0.author.localizedStandardContains(query))
        }.sorted { $0.addedAt > $1.addedAt }
    }
}

extension Workspace {
    /// Empty target removes a category while retaining every book and cover.
    public mutating func renameBookCategory(_ source: String, to target: String) throws {
        let target = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard target.count <= 40 else { throw AppError("分类名称请控制在 40 字以内。") }
        let category = target == "未分类" ? "" : target
        for i in books.indices where books[i].category == source { books[i].category = category }
        // A saved edit draft must not resurrect the old category when reopened.
        for (key, bytes) in drafts where key.hasPrefix("book-") {
            if var draft = try? JSONDecoder().decode(ReadingBook.self, from: bytes), draft.category == source {
                draft.category = category; drafts[key] = try JSONEncoder().encode(draft)
            }
        }
    }
}
