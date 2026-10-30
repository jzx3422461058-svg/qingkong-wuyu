import Foundation

public enum Day {
    public static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        c.locale = Locale(identifier: "en_US_POSIX")
        return c
    }
    public static func date(_ value: String) -> Date? {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard value.count == 10, parts.count == 3,
              let d = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)),
              string(d, zone: "UTC") == value else { return nil }
        return d
    }
    public static func string(_ date: Date, zone: String = TimeZone.current.identifier) -> String {
        var c = calendar; c.timeZone = TimeZone(identifier: zone) ?? calendar.timeZone
        let p = c.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", p.year!, p.month!, p.day!)
    }
    public static func today(zone: String = TimeZone.current.identifier) -> String { string(Date(), zone: zone) }
    public static func add(_ value: String, days: Int) -> String {
        guard let date = date(value), let result = calendar.date(byAdding: .day, value: days, to: date) else { return value }
        return string(result, zone: "UTC")
    }
    public static func distance(_ start: String, _ end: String) -> Int? {
        guard let a = date(start), let b = date(end) else { return nil }
        return calendar.dateComponents([.day], from: a, to: b).day
    }
    public static func weekday(_ value: String) -> Int {
        guard let date = date(value) else { return 1 }
        return (calendar.component(.weekday, from: date) + 5) % 7 + 1
    }
    public static func monday(_ value: String) -> String { add(value, days: 1 - weekday(value)) }
    public static func minutes(_ time: String) -> Int? {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard time.count == 5, time.range(of: "^[0-9]{2}:[0-9]{2}$", options: .regularExpression) != nil, parts.count == 2, (0...23).contains(parts[0]), (0...59).contains(parts[1]) else { return nil }
        return parts[0] * 60 + parts[1]
    }
    public static func instant(_ day: String, _ time: String, zone: String) -> Date? {
        guard let d = date(day), let m = minutes(time), let tz = TimeZone(identifier: zone) else { return nil }
        var c = calendar; c.timeZone = tz
        var components = calendar.dateComponents([.year, .month, .day], from: d)
        components.hour = m / 60; components.minute = m % 60
        return c.date(from: components)
    }
    public static func validateOptional(_ value: String, name: String) throws {
        if !value.isEmpty && date(value) == nil { throw AppError("\(name)请使用 YYYY-MM-DD 格式。") }
    }
}

public struct LessonPeriod: Codable, Equatable, Sendable {
    public var start: String
    public var end: String
    public init(_ start: String = "08:00", _ end: String = "08:45") { self.start = start; self.end = end }
}

public struct Semester: Codable, Equatable, Sendable {
    public var name = "我的学期"
    public var start = Day.monday(Day.today())
    public var weekCount = 20
    public var timeZone = "Asia/Shanghai"
    public var periods = [LessonPeriod("08:00", "08:45"), LessonPeriod("08:55", "09:40"), LessonPeriod("10:00", "10:45"), LessonPeriod("10:55", "11:40"), LessonPeriod("14:00", "14:45"), LessonPeriod("14:55", "15:40"), LessonPeriod("16:00", "16:45"), LessonPeriod("16:55", "17:40"), LessonPeriod("19:00", "19:45"), LessonPeriod("19:55", "20:40")]
    public init() {}
    public func week(on day: String) -> Int? {
        guard let days = Day.distance(start, day), days >= 0, days < weekCount * 7 else { return nil }
        return days / 7 + 1
    }
    public func validate() throws {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty, Day.date(start) != nil, Day.weekday(start) == 1 else { throw AppError("请填写学期名称，并将第一周起始日设为周一。") }
        guard (1...52).contains(weekCount), TimeZone(identifier: timeZone) != nil, (1...20).contains(periods.count) else { throw AppError("请检查学期周数、时区和节次数量。") }
        var previous = -1
        for (index, period) in periods.enumerated() {
            guard let a = Day.minutes(period.start), let b = Day.minutes(period.end), a < b, a >= previous else { throw AppError("第 \(index + 1) 节时间无效或与上一节重叠。") }
            previous = b
        }
    }
}
