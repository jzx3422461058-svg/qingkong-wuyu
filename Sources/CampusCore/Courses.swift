import Foundation

public struct SemesterArchive: Codable, Equatable, Identifiable, Sendable {
    public var id = UUID()
    public var semester: Semester
    public var courses: [Course]
    public init(semester: Semester, courses: [Course]) { self.semester = semester; self.courses = courses }
}

public enum WeekPattern: String, Codable, CaseIterable, Sendable { case all = "每周", odd = "单周", even = "双周" }
public struct CourseException: Codable, Equatable, Identifiable, Sendable {
    public var id = UUID()
    public var originalDay = Day.today()
    public var cancelled = true
    public var targetDay = Day.today()
    public var startPeriod = 1
    public var endPeriod = 2
    public var location = ""
    public init() {}
}
public struct Course: Codable, Equatable, Identifiable, Sendable {
    public var id = UUID()
    public var name = ""
    public var location = ""
    public var weekday = 1
    public var startPeriod = 1
    public var endPeriod = 2
    public var weeks = "1-16"
    public var pattern: WeekPattern = .all
    public var exceptions: [CourseException] = []
    public var color = 0
    public init() {}
    public var identityKey: String { "\(name.trimmingCharacters(in: .whitespaces))|\(weekday)|\(startPeriod)|\(endPeriod)|\((try? validWeeks(max: 52).sorted().map(String.init).joined(separator: ",")) ?? weeks)" }
    public var fingerprint: String { identityKey + "|" + location }
    public func validWeeks(max: Int) throws -> Set<Int> {
        let normalized = weeks.replacingOccurrences(of: "，", with: ",").replacingOccurrences(of: "、", with: ",").replacingOccurrences(of: "—", with: "-").replacingOccurrences(of: "–", with: "-").replacingOccurrences(of: "第", with: "").replacingOccurrences(of: "周", with: "").replacingOccurrences(of: " ", with: "")
        var result = Set<Int>()
        for token in normalized.split(separator: ",", omittingEmptySubsequences: false) {
            let p = token.split(separator: "-", omittingEmptySubsequences: false)
            guard (1...2).contains(p.count), let first = Int(p[0]), let last = Int(p.last!), first >= 1, last >= first, last <= max else { throw AppError("\(name.isEmpty ? "课程" : name)：周次应为 1-16 或 1,3,5，且不能超过学期范围。") }
            result.formUnion(first...last)
        }
        result = result.filter { pattern == .all || (pattern == .odd ? $0 % 2 == 1 : $0 % 2 == 0) }
        guard !result.isEmpty else { throw AppError("\(name)：周次与单双周规则没有交集。") }
        return result
    }
    public func validate(in semester: Semester) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw AppError("请输入课程名称。") }
        guard (1...7).contains(weekday), startPeriod >= 1, endPeriod >= startPeriod, endPeriod <= semester.periods.count else { throw AppError("\(name)：星期或节次超出范围。") }
        let valid = try validWeeks(max: semester.weekCount)
        var dates = Set<String>()
        for e in exceptions {
            guard let w = semester.week(on: e.originalDay), valid.contains(w), Day.weekday(e.originalDay) == weekday, dates.insert(e.originalDay).inserted else { throw AppError("单次调整必须对应原课程的一次上课日期，且不能重复。") }
            if !e.cancelled {
                guard semester.week(on: e.targetDay) != nil, e.startPeriod >= 1, e.endPeriod >= e.startPeriod, e.endPeriod <= semester.periods.count else { throw AppError("调课日期或节次超出学期范围。") }
            }
        }
    }
}

public struct CourseOccurrence: Equatable, Identifiable, Sendable {
    public var id: String { courseID.uuidString + originalDay }
    public var courseID: UUID
    public var name: String
    public var location: String
    public var day: String
    public var originalDay: String
    public var startPeriod: Int
    public var endPeriod: Int
    public var adjusted: Bool
    public var color: Int
}

public enum CourseCalendar {
    public static func occurrences(on day: String, semester: Semester, courses: [Course]) -> [CourseOccurrence] {
        var result: [CourseOccurrence] = []
        for course in courses {
            if let week = semester.week(on: day), course.weekday == Day.weekday(day), (try? course.validWeeks(max: semester.weekCount).contains(week)) == true,
               !course.exceptions.contains(where: { $0.originalDay == day }) {
                result.append(CourseOccurrence(courseID: course.id, name: course.name, location: course.location, day: day, originalDay: day, startPeriod: course.startPeriod, endPeriod: course.endPeriod, adjusted: false, color: course.color))
            }
            for e in course.exceptions where !e.cancelled && e.targetDay == day {
                result.append(CourseOccurrence(courseID: course.id, name: course.name, location: e.location, day: day, originalDay: e.originalDay, startPeriod: e.startPeriod, endPeriod: e.endPeriod, adjusted: true, color: course.color))
            }
        }
        return result.sorted { ($0.startPeriod, $0.name) < ($1.startPeriod, $1.name) }
    }
    public static func conflicts(_ occurrence: CourseOccurrence, among all: [CourseOccurrence]) -> Bool {
        all.contains { $0.id != occurrence.id && $0.day == occurrence.day && $0.startPeriod <= occurrence.endPeriod && $0.endPeriod >= occurrence.startPeriod }
    }
}

public enum DuplicatePolicy: String, CaseIterable, Sendable { case skip = "跳过重复", keep = "保留两份", update = "更新地点" }
public enum CourseImport {
    public static let template = "课程,地点,星期,开始节次,结束节次,周次,单双周\n示例课程,待补充,1,1,2,1-16,每周\n"
    public static func parse(_ text: String, semester: Semester) throws -> [Course] {
        let rows = try CSV.rows(text)
        let expected = ["课程", "地点", "星期", "开始节次", "结束节次", "周次", "单双周"]
        guard rows.first == expected else { throw AppError("CSV 表头应为：" + expected.joined(separator: ",")) }
        var courses: [Course] = []
        for (index, row) in rows.dropFirst().enumerated() {
            guard row.count == 7, let weekday = Int(row[2]), let start = Int(row[3]), let end = Int(row[4]), let pattern = WeekPattern(rawValue: row[6]) else { throw AppError("第 \(index + 2) 行：列数、星期、节次或单双周格式不正确。") }
            var course = Course()
            course.name = row[0]; course.location = row[1]; course.weekday = weekday
            course.startPeriod = start; course.endPeriod = end; course.weeks = row[5]; course.pattern = pattern; course.color = index % 5
            try course.validate(in: semester)
            courses.append(course)
        }
        guard !courses.isEmpty else { throw AppError("文件没有可导入的课程。") }
        return courses
    }
    public static func merge(_ incoming: [Course], existing: [Course], replace: Bool, policy: DuplicatePolicy) -> [Course] {
        var result = replace ? [] : existing
        for course in incoming {
            if policy == .update, let index = result.firstIndex(where: { $0.identityKey == course.identityKey }) {
                result[index].location = course.location
            } else if policy == .keep || !result.contains(where: { $0.fingerprint == course.fingerprint }) {
                var copy = course
                if result.contains(where: { $0.id == copy.id }) { copy.id = UUID() }
                result.append(copy)
            }
        }
        return result
    }
}

public enum CSV {
    public static func rows(_ input: String) throws -> [[String]] {
        let chars = Array(input.replacingOccurrences(of: "\u{feff}", with: "").replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n"))
        var rows: [[String]] = [], row: [String] = [], field = ""
        var quoted = false, closed = false, i = 0
        func addField() { row.append(field.trimmingCharacters(in: .whitespaces)); field = ""; closed = false }
        func addRow() { addField(); if row.contains(where: { !$0.isEmpty }) { rows.append(row) }; row = [] }
        while i < chars.count {
            let c = chars[i]
            if quoted {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" { field.append("\""); i += 1 }
                    else { quoted = false; closed = true }
                } else { field.append(c) }
            } else if c == "," { addField() }
            else if c == "\n" { addRow() }
            else if c == "\"" && field.isEmpty && !closed { quoted = true }
            else {
                guard !closed && c != "\"" else { throw AppError("CSV 引号格式不正确。") }
                field.append(c)
            }
            i += 1
        }
        guard !quoted else { throw AppError("CSV 存在未闭合的引号。") }
        if !field.isEmpty || !row.isEmpty || closed { addRow() }
        return rows
    }
}
