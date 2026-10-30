import Foundation
import CryptoKit
import Darwin

public enum DurableFile {
    /// Flush the replacement before its atomic rename, then flush the containing directory.
    public static func write(_ data: Data, to url: URL) throws {
        let temporary = url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp")
        defer { try? FileManager.default.removeItem(at: temporary) }
        try data.write(to: temporary, options: .withoutOverwriting)
        let descriptor = Darwin.open(temporary.path, O_RDWR)
        guard descriptor >= 0 else { throw POSIXError(.EIO) }
        let flush = fsync(descriptor)
        if flush == 0 { _ = fcntl(descriptor, F_FULLFSYNC) }
        _ = close(descriptor)
        guard flush == 0 else { throw POSIXError(.EIO) }
        guard rename(temporary.path, url.path) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let directory = Darwin.open(url.deletingLastPathComponent().path, O_RDONLY)
        if directory >= 0 { _ = fsync(directory); _ = close(directory) }
    }
}

public protocol ValidatedDocument: Codable, Sendable {
    func validate() throws
}

public struct AppError: LocalizedError, Equatable, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

private struct Envelope: Codable {
    var version: Int
    var payload: Data
    var checksum: String
}

/// One validated, atomic snapshot per commit. A failed write never changes the in-memory document.
public final class DiskStore<Document: ValidatedDocument> {
    public let directory: URL
    public var file: URL { directory.appendingPathComponent("workspace.json") }
    public var backupDirectory: URL { directory.appendingPathComponent("Backups", isDirectory: true) }
    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()
    private let writer: (Data, URL) throws -> Void

    public init(directory: URL, writer: @escaping (Data, URL) throws -> Void = { data, url in
        try DurableFile.write(data, to: url)
    }) throws {
        self.directory = directory
        self.writer = writer
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
    }

    private func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public func encode(_ document: Document) throws -> Data {
        try document.validate()
        let payload = try encoder.encode(document)
        return try encoder.encode(Envelope(version: 1, payload: payload, checksum: digest(payload)))
    }

    public func decode(_ data: Data) throws -> Document {
        let envelope = try decoder.decode(Envelope.self, from: data)
        guard envelope.version == 1 else { throw AppError("数据版本不受支持，原数据未改变。") }
        guard digest(envelope.payload) == envelope.checksum else { throw AppError("数据完整性校验失败，请从备份恢复。") }
        let document = try decoder.decode(Document.self, from: envelope.payload)
        try document.validate()
        return document
    }

    public func load() throws -> Document? {
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        return try decode(Data(contentsOf: file))
    }

    public func save(_ document: Document) throws {
        let data = try encode(document)
        if FileManager.default.fileExists(atPath: file.path) { try dailyBackup() }
        try writer(data, file)
    }

    @discardableResult public func backup(reason: String = "manual") throws -> URL {
        let data = try Data(contentsOf: file)
        _ = try decode(data)
        let name = "\(reason)-\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString.prefix(8)).campusbackup"
        let url = backupDirectory.appendingPathComponent(name)
        try DurableFile.write(data, to: url)
        return url
    }

    private func dailyBackup() throws {
        let day = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let url = backupDirectory.appendingPathComponent("daily-\(day).campusbackup")
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        let data = try Data(contentsOf: file)
        _ = try decode(data)
        try DurableFile.write(data, to: url)
        let daily = try backups().filter { $0.lastPathComponent.hasPrefix("daily-") }.sorted { $0.lastPathComponent > $1.lastPathComponent }
        for old in daily.dropFirst(7) { try FileManager.default.removeItem(at: old) }
    }

    public func backups() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: [.contentModificationDateKey])
            .filter { $0.pathExtension == "campusbackup" }
            .sorted {
                let first = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let second = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return first > second
            }
    }

    public func restore(_ data: Data) throws -> Document {
        let document = try decode(data)
        if FileManager.default.fileExists(atPath: file.path) {
            // A damaged primary is preserved too, without blocking recovery from a valid backup.
            let previous = try Data(contentsOf: file)
            let url = backupDirectory.appendingPathComponent("before-restore-\(UUID().uuidString).campusbackup")
            try DurableFile.write(previous, to: url)
        }
        try writer(try encode(document), file)
        return document
    }
}
