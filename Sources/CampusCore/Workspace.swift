import Foundation

public struct Preferences: Codable, Equatable, Sendable {
    public var theme = "跟随系统"
    public var reduceMotion = false
    public var reduceTransparency = false
    public var notifications = false
    public var reminderMinutes = 15
    public var mutedModules: Set<String> = []
    public init() {}
}
public struct TrashEntry: Codable, Equatable, Identifiable, Sendable {
    public var id = UUID()
    public var kind: String
    public var name: String
    public var payload: Data
    public var removedAt = Date()
    public init(kind: String, name: String, payload: Data) { self.kind = kind; self.name = name; self.payload = payload }
}
public struct Workspace: ValidatedDocument, Equatable {
    public var semester: Semester?
    public var courses: [Course] = []
    public var archivedSemesters: [SemesterArchive] = []
    public var trainingPlans: [TrainingPlan] = []
    public var trainingSchedule: [ScheduledWorkout] = []
    public var workouts: [WorkoutLog] = []
    public var goals: [LongGoal] = []
    public var activities: [Activity] = []
    public var books: [ReadingBook] = []
    public var preferences = Preferences()
    public var drafts: [String: Data] = [:]
    public var trash: [TrashEntry] = []
    public var deliveredReminders: [String: Date] = [:]
    public init() {}
    enum CodingKeys: String, CodingKey { case books, semester, courses, archivedSemesters, trainingPlans, trainingSchedule, workouts, goals, activities, preferences, drafts, trash, deliveredReminders }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        semester = try c.decodeIfPresent(Semester.self, forKey: .semester)
        courses = try c.decodeIfPresent([Course].self, forKey: .courses) ?? []
        archivedSemesters = try c.decodeIfPresent([SemesterArchive].self, forKey: .archivedSemesters) ?? []
        trainingPlans = try c.decodeIfPresent([TrainingPlan].self, forKey: .trainingPlans) ?? []
        trainingSchedule = try c.decodeIfPresent([ScheduledWorkout].self, forKey: .trainingSchedule) ?? []
        workouts = try c.decodeIfPresent([WorkoutLog].self, forKey: .workouts) ?? []
        goals = try c.decodeIfPresent([LongGoal].self, forKey: .goals) ?? []
        activities = try c.decodeIfPresent([Activity].self, forKey: .activities) ?? []
        books = try c.decodeIfPresent([ReadingBook].self, forKey: .books) ?? []
        preferences = try c.decodeIfPresent(Preferences.self, forKey: .preferences) ?? Preferences()
        drafts = try c.decodeIfPresent([String: Data].self, forKey: .drafts) ?? [:]
        trash = try c.decodeIfPresent([TrashEntry].self, forKey: .trash) ?? []
        deliveredReminders = try c.decodeIfPresent([String: Date].self, forKey: .deliveredReminders) ?? [:]
    }
    public func validate() throws {
        if let semester {
            try semester.validate()
            for course in courses { try course.validate(in: semester) }
        } else if !courses.isEmpty { throw AppError("请先配置学期。") }
        try Self.unique(courses.map(\.id))
        try Self.unique(archivedSemesters.map(\.id))
        for archived in archivedSemesters { try archived.semester.validate(); try Self.unique(archived.courses.map(\.id)); for course in archived.courses { try course.validate(in: archived.semester) } }
        try Self.unique(trainingPlans.map(\.id)); try Self.unique(trainingSchedule.map(\.id)); try Self.unique(workouts.map(\.id))
        for plan in trainingPlans { try plan.validate() }
        for schedule in trainingSchedule { try schedule.validate() }
        for workout in workouts { try workout.validate() }
        try Self.unique(workouts.compactMap(\.scheduleID))
        try Self.unique(goals.map(\.id)); for goal in goals { try goal.validate() }
        try Self.unique(activities.map(\.id)); for activity in activities { try activity.validate() }
        try Self.unique(books.map(\.id)); for book in books { try book.validate() }
        guard (0...1440).contains(preferences.reminderMinutes) else { throw AppError("提醒提前时间必须在 0—1440 分钟之间。") }
    }
    public static func unique(_ ids: [UUID]) throws {
        guard Set(ids).count == ids.count else { throw AppError("数据存在重复标识，操作未执行。") }
    }
    public mutating func newSemester(_ next: Semester) throws {
        try next.validate()
        if let current = semester { archivedSemesters.append(SemesterArchive(semester: current, courses: courses)) }
        semester = next; courses = []
        drafts = drafts.filter { !$0.key.hasPrefix("course-") && !$0.key.hasPrefix("exception-") }
    }
    public mutating func switchSemester(_ id: UUID) throws {
        guard let index = archivedSemesters.firstIndex(where: { $0.id == id }) else { throw AppError("历史学期不存在。") }
        let selected = archivedSemesters.remove(at: index)
        if let current = semester { archivedSemesters.append(SemesterArchive(semester: current, courses: courses)) }
        semester = selected.semester; courses = selected.courses
        drafts = drafts.filter { !$0.key.hasPrefix("course-") && !$0.key.hasPrefix("exception-") && $0.key != "semester" }
    }
}
