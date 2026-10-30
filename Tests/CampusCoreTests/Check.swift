import Foundation
import CampusCore

@MainActor enum Check {
    static var passed = 0
    static var failed = 0
    static func run(_ name: String, _ body: () throws -> Void) {
        do { try body(); passed += 1; print("PASS \(name)") }
        catch { failed += 1; print("FAIL \(name): \(error)") }
    }
    static func equal<T: Equatable>(_ a: T, _ b: T, _ message: String = "values differ") throws {
        if a != b { throw AppError("\(message): \(a) != \(b)") }
    }
    static func truth(_ condition: Bool, _ message: String) throws {
        if !condition { throw AppError(message) }
    }
    static func rejects(_ body: () throws -> Void) throws {
        do { try body() } catch { return }
        throw AppError("Expected operation to fail")
    }
    static func temporary(_ body: (URL) throws -> Void) throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try body(url)
    }
}

@main struct CheckRunner {
    @MainActor static func main() {
        storageChecks()
        courseChecks()
        fitnessChecks()
        goalChecks()
        activityChecks()
        reminderChecks()
        overviewChecks()
        readingChecks()
        print("\n\(Check.passed) passed; \(Check.failed) failed")
        if Check.failed > 0 { exit(1) }
    }
}
