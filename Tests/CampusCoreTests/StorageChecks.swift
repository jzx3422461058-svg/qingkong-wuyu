import Foundation
import CampusCore

private struct Fixture: ValidatedDocument, Equatable {
    var value: Int
    func validate() throws { if value < 0 { throw AppError("invalid") } }
}

@MainActor func storageChecks() {
    Check.run("Storage: reopen and invalid commit preserves data") {
        try Check.temporary { url in
            let store = try DiskStore<Fixture>(directory: url)
            try Check.equal(try store.load(), nil)
            try store.save(Fixture(value: 42))
            try Check.rejects { try store.save(Fixture(value: -1)) }
            try Check.equal(try DiskStore<Fixture>(directory: url).load(), Fixture(value: 42))
        }
    }
    Check.run("Storage: failed write and backup recovery") {
        try Check.temporary { url in
            let store = try DiskStore<Fixture>(directory: url)
            try store.save(Fixture(value: 1))
            let backup = try store.backup()
            let failing = try DiskStore<Fixture>(directory: url, writer: { _, _ in throw AppError("disk full") })
            try Check.rejects { try failing.save(Fixture(value: 2)) }
            try Check.equal(try store.load()?.value, 1)
            try store.save(Fixture(value: 3))
            try Check.equal(try store.restore(Data(contentsOf: backup)).value, 1)
            try Check.equal(try store.load()?.value, 1)
        }
    }
    Check.run("Storage: corrupt restore preserves primary; damaged primary recovers") {
        try Check.temporary { url in
            let store = try DiskStore<Fixture>(directory: url)
            try store.save(Fixture(value: 9))
            let backup = try store.backup()
            try Check.rejects { _ = try store.restore(Data("broken".utf8)) }
            try Check.equal(try store.load()?.value, 9)
            try Data("broken".utf8).write(to: store.file)
            try Check.rejects { _ = try store.load() }
            _ = try store.restore(Data(contentsOf: backup))
            try Check.equal(try store.load()?.value, 9)
        }
    }
    Check.run("Storage: tampered payload fails checksum") {
        try Check.temporary { url in
            let store = try DiskStore<Fixture>(directory: url)
            let data = try store.encode(Fixture(value: 5))
            var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            object["checksum"] = "invalid"
            try Check.rejects { _ = try store.decode(JSONSerialization.data(withJSONObject: object)) }
        }
    }
    Check.run("Storage: daily retention keeps seven snapshots and preserves manual backups") {
        try Check.temporary { url in
            let store = try DiskStore<Fixture>(directory: url)
            try store.save(Fixture(value: 1))
            let manual = try store.backup()
            let snapshot = try store.encode(Fixture(value: 1))
            for day in 1...10 { try snapshot.write(to: store.backupDirectory.appendingPathComponent(String(format: "daily-2020-01-%02d.campusbackup", day))) }
            try store.save(Fixture(value: 2))
            try Check.equal(try store.backups().filter { $0.lastPathComponent.hasPrefix("daily-") }.count, 7)
            try Check.truth(FileManager.default.fileExists(atPath: manual.path), "manual backup was incorrectly pruned")
            try Check.truth(try FileManager.default.contentsOfDirectory(atPath: url.path).allSatisfy { !$0.hasSuffix(".tmp") }, "temporary write file leaked")
        }
    }
    Check.run("Storage: unsupported backup version fails without changing saved data") {
        try Check.temporary { url in
            let store = try DiskStore<Fixture>(directory: url); try store.save(Fixture(value: 7))
            var object = try JSONSerialization.jsonObject(with: store.encode(Fixture(value: 8))) as! [String: Any]
            object["version"] = 99
            try Check.rejects { _ = try store.restore(JSONSerialization.data(withJSONObject: object)) }
            try Check.equal(try store.load()?.value, 7)
        }
    }
}
