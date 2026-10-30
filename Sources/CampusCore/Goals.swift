import Foundation

public enum GoalStatus: String, Codable, CaseIterable, Sendable { case active = "进行中", paused = "暂停", completed = "已完成", archived = "已归档" }
public enum ActionStatus: String, Codable, CaseIterable, Sendable { case pending = "待完成", done = "已完成", cancelled = "已取消" }
public struct GoalAction: Codable, Equatable, Identifiable, Sendable {
    public var id = UUID()
    public var title = ""
    public var date = ""
    public var due = ""
    public var reminderTime = "09:00"
    public var status: ActionStatus = .pending
    public var notes = ""
    public init() {}
    public func validate() throws {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { throw AppError("请输入具体行动。") }
        try Day.validateOptional(date, name: "执行日期"); try Day.validateOptional(due, name: "截止日期")
        guard Day.minutes(reminderTime) != nil else { throw AppError("行动提醒时间格式应为 HH:mm。") }
        if !date.isEmpty && !due.isEmpty && date > due { throw AppError("执行日期不能晚于截止日期。") }
    }
}
public struct Milestone: Codable, Equatable, Identifiable, Sendable {
    public var id = UUID()
    public var title = ""
    public var criterion = ""
    public var due = ""
    public var completed = false
    public var actions: [GoalAction] = []
    public init() {}
    public func validate() throws {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty, !criterion.trimmingCharacters(in: .whitespaces).isEmpty else { throw AppError("请填写阶段名称和可判断的完成标准。") }
        try Day.validateOptional(due, name: "阶段截止日期")
        try Workspace.unique(actions.map(\.id)); for action in actions { try action.validate() }
    }
}
public struct LongGoal: Codable, Equatable, Identifiable, Sendable {
    public var id = UUID()
    public var title = ""
    public var detail = ""
    public var start = ""
    public var due = ""
    public var status: GoalStatus = .active
    public var milestones: [Milestone] = []
    public init() {}
    public var allActions: [GoalAction] { milestones.flatMap(\.actions) }
    public var actionProgress: Double? {
        let active = allActions.filter { $0.status != .cancelled }
        return active.isEmpty ? nil : Double(active.filter { $0.status == .done }.count) / Double(active.count)
    }
    public var milestoneProgress: String { "\(milestones.filter(\.completed).count) / \(milestones.count)" }
    public func validate() throws {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { throw AppError("请输入目标名称。") }
        try Day.validateOptional(start, name: "目标起始日"); try Day.validateOptional(due, name: "目标截止日")
        if !start.isEmpty && !due.isEmpty && start > due { throw AppError("目标起始日不能晚于截止日。") }
        try Workspace.unique(milestones.map(\.id)); try Workspace.unique(allActions.map(\.id))
        for milestone in milestones { try milestone.validate() }
    }
    public mutating func moveAction(_ id: UUID, to targetID: UUID) throws {
        guard let source = milestones.firstIndex(where: { $0.actions.contains { $0.id == id } }), let target = milestones.firstIndex(where: { $0.id == targetID }), let index = milestones[source].actions.firstIndex(where: { $0.id == id }) else { throw AppError("行动或目标阶段已不存在。") }
        if source == target { return }
        let action = milestones[source].actions.remove(at: index)
        milestones[target].actions.append(action)
    }
    public mutating func shiftMilestone(_ id: UUID, offset: Int) {
        guard let i = milestones.firstIndex(where: { $0.id == id }), milestones.indices.contains(i + offset) else { return }
        milestones.swapAt(i, i + offset)
    }
}
