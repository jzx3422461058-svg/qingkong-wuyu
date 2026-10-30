import Foundation
import CampusCore

@MainActor func courseChecks() {
    var semester = Semester(); semester.start = "2026-09-07"; semester.weekCount = 20
    var course = Course(); course.name = "马克思主义基本原理"; course.pattern = .odd; course.location = "北楼 101"
    Check.run("Course: semester weeks, odd/even and boundaries") {
        try semester.validate(); try course.validate(in: semester)
        try Check.equal(semester.week(on: "2026-09-06"), nil)
        try Check.equal(semester.week(on: "2026-09-13"), 1)
        try Check.equal(semester.week(on: "2026-09-14"), 2)
        try Check.equal(CourseCalendar.occurrences(on: "2026-09-07", semester: semester, courses: [course]).count, 1)
        try Check.equal(CourseCalendar.occurrences(on: "2026-09-14", semester: semester, courses: [course]).count, 0)
        try Check.equal(semester.week(on: "2027-01-25"), nil)
    }
    Check.run("Course: one occurrence moved without changing following weeks") {
        var changed = course; var e = CourseException()
        e.originalDay = "2026-09-07"; e.cancelled = false; e.targetDay = "2026-09-08"; e.location = "南楼 202"
        changed.exceptions = [e]; try changed.validate(in: semester)
        try Check.equal(CourseCalendar.occurrences(on: "2026-09-07", semester: semester, courses: [changed]).count, 0)
        try Check.equal(CourseCalendar.occurrences(on: "2026-09-08", semester: semester, courses: [changed]).first?.location, "南楼 202")
        try Check.equal(CourseCalendar.occurrences(on: "2026-09-21", semester: semester, courses: [changed]).count, 1)
    }
    Check.run("Course: invalid dates, empty parity and overlapping periods rejected") {
        try Check.equal(Day.date("2026-02-30"), nil)
        try Check.equal(Day.minutes("8:000"), nil)
        var invalid = course; invalid.weeks = "2"; try Check.rejects { try invalid.validate(in: semester) }
        invalid.weeks = "1-99"; try Check.rejects { try invalid.validate(in: semester) }
        var invalidSemester = semester; invalidSemester.periods[1].start = "08:30"
        try Check.rejects { try invalidSemester.validate() }
    }
    Check.run("Course: CSV BOM, quoted commas, CRLF, preview and duplicate handling") {
        let text = "\u{feff}课程,地点,星期,开始节次,结束节次,周次,单双周\r\n\"原理,导论\",北楼,1,1,2,\"1,3,5\",单周\r\n"
        let parsed = try CourseImport.parse(text, semester: semester)
        try Check.equal(parsed.first?.name, "原理,导论")
        let once = CourseImport.merge(parsed, existing: [], replace: false, policy: .skip)
        try Check.equal(CourseImport.merge(parsed, existing: once, replace: false, policy: .skip).count, 1)
        try Check.equal(CourseImport.merge(parsed, existing: once, replace: false, policy: .keep).count, 2)
        try Workspace.unique(CourseImport.merge(parsed, existing: once, replace: false, policy: .keep).map(\.id))
        try Check.rejects { _ = try CourseImport.parse("课程,地点\nx,y", semester: semester) }
        try Check.rejects { _ = try CSV.rows("\"unclosed") }
    }
    Check.run("Course: conflicts are retained; update preserves IDs and exceptions") {
        var other = course; other.id = UUID(); other.name = "另一课程"
        let occurrences = CourseCalendar.occurrences(on: "2026-09-07", semester: semester, courses: [course, other])
        try Check.equal(occurrences.count, 2)
        try Check.truth(CourseCalendar.conflicts(occurrences[0], among: occurrences), "overlap not detected")
        var updated = course; updated.id = UUID(); updated.location = "新教室"
        let result = CourseImport.merge([updated], existing: [course], replace: false, policy: .update)
        try Check.equal(result.first?.id, course.id); try Check.equal(result.first?.location, "新教室")
    }
    Check.run("Course: timezone conversion is independent of system timezone") {
        let date = Day.instant("2026-09-07", "08:00", zone: "Asia/Shanghai")!
        try Check.equal(ISO8601DateFormatter().string(from: date), "2026-09-07T00:00:00Z")
    }
    Check.run("Course: semester switching preserves prior courses and removes stale drafts") {
        var state = Workspace(); state.semester = semester; state.courses = [course]; state.drafts["course-new"] = Data("old".utf8)
        var next = Semester(); next.start = "2027-02-22"; next.name = "春季"
        try state.newSemester(next); try state.validate()
        try Check.equal(state.courses.count, 0); try Check.equal(state.archivedSemesters.count, 1)
        try state.switchSemester(state.archivedSemesters[0].id); try state.validate()
        try Check.equal(state.courses.first?.id, course.id); try Check.equal(state.semester?.start, semester.start)
        try Check.equal(state.drafts["course-new"], nil)
    }
}
