import Foundation
import CryptoKit

public struct Reminder: Equatable, Identifiable, Sendable {
    public var key: String
    public var title: String
    public var body: String
    public var fire: Date
    public var module: String
    public var targetID: UUID
    public var id: String {
        let signature = "\(key)|\(fire.timeIntervalSince1970)|\(title)|\(body)"
        return SHA256.hash(data: Data(signature.utf8)).prefix(16).map { String(format: "%02x", $0) }.joined()
    }
}

public enum ReminderEngine {
    /// Recomputed from current records: deleted/cancelled/finished objects cannot leave stale reminders.
    public static func reminders(_ state: Workspace, now: Date) -> [Reminder] {
        guard state.preferences.notifications else { return [] }
        let zone = state.semester?.timeZone ?? "Asia/Shanghai"
        let day = Day.string(now, zone: zone)
        var result: [Reminder] = []
        func add(key: String, title: String, body: String, date: String, time: String, lead: Int, module: String, target: UUID) {
            guard !state.preferences.mutedModules.contains(module), let instant = Day.instant(date, time, zone: zone) else { return }
            let fire = instant.addingTimeInterval(-Double(lead) * 60)
            // Include a bounded catch-up window; past weeks do not cause notification floods.
            guard fire >= now.addingTimeInterval(-86400), fire <= now.addingTimeInterval(14 * 86400) else { return }
            result.append(Reminder(key: key, title: title, body: body, fire: fire, module: module, targetID: target))
        }
        if let semester = state.semester {
            for offset in -1...15 {
                let date = Day.add(day, days: offset)
                for c in CourseCalendar.occurrences(on: date, semester: semester, courses: state.courses) {
                    let time = semester.periods[c.startPeriod - 1].start
                    add(key: "course-\(c.id)", title: "即将上课 · \(c.name)", body: "\(date) \(time) · \(c.location.isEmpty ? "地点待补充" : c.location)", date: date, time: time, lead: state.preferences.reminderMinutes, module: "courses", target: c.courseID)
                }
            }
        }
        for workout in state.trainingSchedule where !workout.cancelled && !state.workouts.contains(where: { $0.scheduleID == workout.id && $0.finished }) {
            add(key: "workout-\(workout.id)", title: "训练时间 · \(workout.name)", body: "\(workout.date) \(workout.time) · 预计 \(workout.duration) 分钟", date: workout.date, time: workout.time, lead: state.preferences.reminderMinutes, module: "fitness", target: workout.id)
        }
        for goal in state.goals where goal.status == .active {
            for stage in goal.milestones where !stage.completed {
                for action in stage.actions where action.status == .pending {
                    let date = !action.date.isEmpty ? action.date : action.due
                    if !date.isEmpty { add(key: "action-\(action.id)", title: action.title, body: "\(goal.title) · \(stage.title)", date: date, time: action.reminderTime, lead: state.preferences.reminderMinutes, module: "goals", target: goal.id) }
                }
            }
        }
        for activity in state.activities where activity.attendance == .upcoming {
            add(key: "event-\(activity.id)", title: "活动即将开始 · \(activity.title)", body: "\(activity.startDate) \(activity.startTime) · \(activity.location)", date: activity.startDate, time: activity.startTime, lead: activity.eventLead, module: "activities", target: activity.id)
            if activity.registration == .pending && !activity.registrationDate.isEmpty {
                add(key: "registration-\(activity.id)", title: "报名即将截止 · \(activity.title)", body: "截止 \(activity.registrationDate) \(activity.registrationTime)", date: activity.registrationDate, time: activity.registrationTime, lead: activity.registrationLead, module: "activities", target: activity.id)
            }
        }
        return result.filter { state.deliveredReminders[$0.id] == nil }.sorted { $0.fire < $1.fire }
    }
}

extension Workspace {
    public mutating func restoreTrash(_ id: UUID) throws {
        guard let item = trash.first(where: { $0.id == id }) else { throw AppError("回收站记录不存在。") }
        let decoder = JSONDecoder()
        switch item.kind {
        case "book": books.append(try decoder.decode(ReadingBook.self, from: item.payload))
        case "course": courses.append(try decoder.decode(Course.self, from: item.payload))
        case "plan": trainingPlans.append(try decoder.decode(TrainingPlan.self, from: item.payload))
        case "schedule": trainingSchedule.append(try decoder.decode(ScheduledWorkout.self, from: item.payload))
        case "workout": workouts.append(try decoder.decode(WorkoutLog.self, from: item.payload))
        case "goal": goals.append(try decoder.decode(LongGoal.self, from: item.payload))
        case "activity": activities.append(try decoder.decode(Activity.self, from: item.payload))
        default: throw AppError("此类型暂不支持恢复。")
        }
        trash.removeAll { $0.id == id }
        try validate()
    }
    public var recordSummary: String {
        "\(courses.count) 条课程安排 · \(trainingPlans.count) 套训练方案 · \(workouts.count) 次训练记录 · \(goals.count) 个目标 · \(activities.count) 场活动 · \(books.count) 本书"
    }
}
