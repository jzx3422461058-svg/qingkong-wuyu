import Foundation

public enum ExerciseKind: String, Codable, CaseIterable, Sendable { case strength = "力量", cardio = "有氧" }
public struct ExerciseSet: Codable, Equatable, Identifiable, Sendable {
    public var id = UUID()
    public var weight = ""
    public var reps = ""
    public var completed = false
    public init() {}
}
public struct Exercise: Codable, Equatable, Identifiable, Sendable {
    public var id = UUID()
    public var name = ""
    public var kind: ExerciseKind = .strength
    public var sets = [ExerciseSet()]
    public var minutes = ""
    public var distance = ""
    public var completed = false
    public var skipped = false
    public init() {}
    public func validate(actual: Bool) throws {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { throw AppError("请填写动作或运动名称。") }
        guard !sets.isEmpty else { throw AppError("力量动作至少保留一组。") }
        try Workspace.unique(sets.map(\.id))
        if skipped { return }
        if kind == .strength {
            for set in sets {
                try FitnessMath.number(set.weight, name: "重量", minimum: 0)
                try FitnessMath.number(set.reps, name: "次数", minimum: 1, integer: true)
                if actual && set.completed && (set.weight.isEmpty || set.reps.isEmpty) { throw AppError("已完成的组请填写实际重量和次数，自重可填 0 kg。") }
            }
        } else {
            try FitnessMath.number(minutes, name: "时长", minimum: 0.01)
            try FitnessMath.number(distance, name: "距离", minimum: 0)
            if actual && completed && minutes.isEmpty { throw AppError("已完成的有氧训练请填写实际时长。") }
        }
    }
    public var hasCompleted: Bool { !skipped && (kind == .strength ? sets.contains(where: \.completed) : completed) }
}
public struct TrainingPlan: Codable, Equatable, Identifiable, Sendable {
    public var id = UUID()
    public var name = ""
    public var exercises: [Exercise] = [Exercise()]
    public var notes = ""
    public init() {}
    public func validate() throws {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty, !exercises.isEmpty else { throw AppError("请填写方案名称，并添加至少一个动作。") }
        try Workspace.unique(exercises.map(\.id)); for exercise in exercises { try exercise.validate(actual: false) }
    }
}
public struct ScheduledWorkout: Codable, Equatable, Identifiable, Sendable {
    public var id = UUID()
    public var name = ""
    public var date = Day.today()
    public var time = "18:00"
    public var duration = 60
    public var exercises: [Exercise] = []
    public var cancelled = false
    public init() {}
    public func validate() throws {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty, Day.date(date) != nil, Day.minutes(time) != nil, (1...1440).contains(duration) else { throw AppError("请检查训练名称、日期、时间和预计时长。") }
        for exercise in exercises { try exercise.validate(actual: false) }
        try Workspace.unique(exercises.map(\.id))
    }
}
public struct WorkoutLog: Codable, Equatable, Identifiable, Sendable {
    public var id = UUID()
    public var scheduleID: UUID?
    public var name = ""
    public var date = Day.today()
    public var minutes = ""
    public var exercises = [Exercise()]
    public var notes = ""
    public var finished = true
    public init() {}
    public func validate() throws {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty, Day.date(date) != nil else { throw AppError("请填写训练名称和有效日期。") }
        try FitnessMath.number(minutes, name: "本次训练总时长", minimum: 0.01)
        try Workspace.unique(exercises.map(\.id))
        for exercise in exercises { try exercise.validate(actual: true) }
        if finished && !exercises.contains(where: \.hasCompleted) { throw AppError("请至少勾选一组或一项实际完成的训练，或先保存为进行中。") }
    }
    public static func start(_ schedule: ScheduledWorkout) -> WorkoutLog {
        var log = WorkoutLog(); log.scheduleID = schedule.id; log.name = schedule.name; log.date = schedule.date; log.exercises = schedule.exercises
        for i in log.exercises.indices {
            log.exercises[i].completed = false; log.exercises[i].skipped = false
            for j in log.exercises[i].sets.indices { log.exercises[i].sets[j].completed = false }
        }
        return log
    }
}
public enum FitnessMath {
    public static func number(_ text: String, name: String, minimum: Double, integer: Bool = false) throws {
        if text.isEmpty { return }
        guard let number = Double(text), number.isFinite, number >= minimum, number <= 1_000_000, !integer || number.rounded() == number else { throw AppError("\(name)必须是有效的\(integer ? "整数" : "数值")，且不小于 \(minimum)。") }
    }
    public static func volume(_ exercise: Exercise) -> Double? {
        guard exercise.kind == .strength, !exercise.skipped else { return nil }
        let values = exercise.sets.filter(\.completed).compactMap { set -> Double? in
            guard let w = Double(set.weight), let reps = Double(set.reps) else { return nil }
            return w * reps
        }
        return values.isEmpty ? nil : values.reduce(0, +)
    }
    public static func trend(name: String, logs: [WorkoutLog]) -> [(day: String, volume: Double)] {
        var days: [String: Double] = [:]
        for log in logs where log.finished {
            let volumes = log.exercises.filter { $0.name == name }.compactMap(volume)
            if !volumes.isEmpty { days[log.date, default: 0] += volumes.reduce(0, +) }
        }
        return days.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }
}
