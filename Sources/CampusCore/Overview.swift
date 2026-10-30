import Foundation

public struct AgendaItem: Identifiable, Equatable, Sendable {
    public var id: String
    public var targetID: UUID
    public var module: String
    public var title: String
    public var detail: String
    public var start: Date
    public var end: Date
    public var completed: Bool
}
public enum Overview {
    public static func agenda(_ state: Workspace, day: String) -> [AgendaItem] {
        let zone = state.semester?.timeZone ?? "Asia/Shanghai"
        var result: [AgendaItem] = []
        if let semester = state.semester {
            for c in CourseCalendar.occurrences(on: day, semester: semester, courses: state.courses) {
                guard let start = Day.instant(day, semester.periods[c.startPeriod - 1].start, zone: zone), let end = Day.instant(day, semester.periods[c.endPeriod - 1].end, zone: zone) else { continue }
                result.append(AgendaItem(id: c.id, targetID: c.courseID, module: "courses", title: c.name, detail: c.location.isEmpty ? "地点待补充" : c.location, start: start, end: end, completed: false))
            }
        }
        for s in state.trainingSchedule where s.date == day && !s.cancelled {
            guard let start = Day.instant(day, s.time, zone: zone) else { continue }
            result.append(AgendaItem(id: s.id.uuidString, targetID: s.id, module: "fitness", title: s.name, detail: "预计 \(s.duration) 分钟", start: start, end: start.addingTimeInterval(Double(s.duration) * 60), completed: state.workouts.contains { $0.scheduleID == s.id && $0.finished }))
        }
        for e in state.activities where e.startDate <= day && e.endDate >= day && e.attendance != .cancelled && e.attendance != .missed {
            guard let start = Day.instant(e.startDate, e.startTime, zone: zone), let end = Day.instant(e.endDate, e.endTime, zone: zone) else { continue }
            result.append(AgendaItem(id: e.id.uuidString, targetID: e.id, module: "activities", title: e.title, detail: e.location.isEmpty ? e.category : e.location, start: start, end: end, completed: e.attendance == .attended))
        }
        for g in state.goals where g.status == .active {
            for stage in g.milestones where !stage.completed {
                for a in stage.actions where a.status != .cancelled && (a.date == day || a.date.isEmpty && a.due == day) {
                    guard let start = Day.instant(day, a.reminderTime, zone: zone) else { continue }
                    result.append(AgendaItem(id: a.id.uuidString, targetID: g.id, module: "goals", title: a.title, detail: g.title, start: start, end: start, completed: a.status == .done))
                }
            }
        }
        return result.sorted { $0.start < $1.start }
    }
    public static func overlaps(_ item: AgendaItem, items: [AgendaItem]) -> Bool {
        guard item.start < item.end, !item.completed else { return false }
        return items.contains { $0.id != item.id && !$0.completed && $0.start < $0.end && $0.start < item.end && item.start < $0.end }
    }
    public static func upcoming(_ state: Workspace, today: String) -> [(goal: LongGoal, action: GoalAction)] {
        let end = Day.add(today, days: 7)
        var result: [(goal: LongGoal, action: GoalAction)] = []
        for goal in state.goals where goal.status == .active {
            for stage in goal.milestones where !stage.completed {
                for action in stage.actions where action.status == .pending && !action.due.isEmpty && action.due <= end {
                    result.append((goal: goal, action: action))
                }
            }
        }
        return result.sorted { $0.action.due < $1.action.due }
    }
}
