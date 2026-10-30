import SwiftUI
import Observation
import CampusCore

@MainActor @Observable final class AppStore {
    private(set) var data = Workspace()
    var error: String?
    var bootError: String?
    var savedAt: Date?
    var saveFailed = false
    var module: Module = .home
    var focusID: UUID?
    private(set) var disk: DiskStore<Workspace>?
    let directory: URL
    var afterCommit: (() -> Void)?
    var courseWeek: Int?
    var fitnessTab = "训练安排"
    var expandedGoal: UUID?
    var activityCategory = "全部"
    var activityStatus = "全部"
    var activityQuery = ""

    init() {
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "--data-dir"), index + 1 < args.count {
            directory = URL(fileURLWithPath: args[index + 1], isDirectory: true)
        } else {
            directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Qingyu", isDirectory: true)
        }
        do {
            let disk = try DiskStore<Workspace>(directory: directory)
            self.disk = disk
            if let loaded = try disk.load() { data = loaded }
            else { try disk.save(data) }
            savedAt = Date()
        } catch { bootError = error.localizedDescription }
    }

    func commit(_ change: (inout Workspace) throws -> Void) throws {
        guard bootError == nil, let disk else { throw AppError("数据未能安全加载，请先恢复。") }
        var next = data
        try change(&next)
        do {
            try disk.save(next)
            data = next; savedAt = Date(); saveFailed = false
            afterCommit?()
        } catch { saveFailed = true; throw error }
    }
    func act(_ change: (inout Workspace) throws -> Void) {
        do { try commit(change) } catch { self.error = error.localizedDescription }
    }
    func saveNow() { act { _ in } }
    func restore(_ bytes: Data) throws {
        let storage = try disk ?? DiskStore<Workspace>(directory: directory)
        data = try storage.restore(bytes)
        disk = storage; bootError = nil; saveFailed = false; savedAt = Date(); afterCommit?()
    }
    func draft<T: Decodable>(_ key: String, fallback: T) -> T {
        guard let bytes = data.drafts[key], let draft = try? JSONDecoder().decode(T.self, from: bytes) else { return fallback }
        return draft
    }
    func saveDraft<T: Encodable>(_ key: String, value: T) {
        do { let bytes = try JSONEncoder().encode(value); if data.drafts[key] != bytes { try commit { $0.drafts[key] = bytes } } }
        catch { self.error = error.localizedDescription }
    }
    func archive<T: Encodable>(_ object: T, kind: String, name: String, change: (inout Workspace) -> Void) {
        do {
            let payload = try JSONEncoder().encode(object)
            try commit { state in
                state.trash.insert(TrashEntry(kind: kind, name: name, payload: payload), at: 0)
                change(&state)
            }
        } catch { self.error = error.localizedDescription }
    }
}

enum Module: String, CaseIterable, Identifiable {
    case home = "首页纵览", courses = "课程表", fitness = "健身计划", goals = "长期计划", activities = "各类活动", reading = "阅读书单", settings = "数据与设置"
    var id: String { rawValue }
    var code: String {
        switch self { case .home: "home"; case .courses: "courses"; case .fitness: "fitness"; case .goals: "goals"; case .activities: "activities"; case .reading: "reading"; case .settings: "settings" }
    }
    static func code(_ value: String) -> Module { allCases.first { $0.code == value } ?? .home }
    var icon: String {
        switch self { case .home: "square.grid.2x2.fill"; case .courses: "calendar"; case .fitness: "figure.strengthtraining.traditional"; case .goals: "flag.checkered"; case .activities: "sparkles"; case .reading: "books.vertical.fill"; case .settings: "slider.horizontal.3" }
    }
    var tint: Color {
        switch self { case .home: .cyan; case .courses: .blue; case .fitness: .mint; case .goals: .orange; case .activities: .purple; case .reading: .teal; case .settings: .gray }
    }
}

extension Notification.Name {
    static let saveWorkspace = Notification.Name("Qingyu.saveWorkspace")
    static let flushDraft = Notification.Name("Qingyu.flushDraft")
}
