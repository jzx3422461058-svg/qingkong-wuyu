import Foundation
import CampusCore

@MainActor func activityChecks() {
    Check.run("Activities: registration and attendance remain independent") {
        var event = Activity(); event.title = "学术讲座"; event.registration = .registered
        try event.validate(); try Check.equal(event.attendance, .upcoming)
        event.attendance = .attended; try Check.equal(event.registration, .registered)
    }
    Check.run("Activities: volunteer totals count actual attended service only") {
        var a = Activity(); a.title = "志愿服务"; a.category = "志愿服务"; a.volunteerHours = "3.5"; a.attendance = .attended
        var b = a; b.id = UUID(); b.attendance = .upcoming
        var c = a; c.id = UUID(); c.category = "讲座"
        try Check.equal(Activity.attendedHours([a,b,c]), 3.5)
    }
    Check.run("Activities: invalid interval, deadline and unsafe link rejected") {
        var event = Activity(); event.title = "讲座"; event.endTime = "13:00"
        try Check.rejects { try event.validate() }
        event.endTime = "16:00"; event.registrationDate = event.startDate; event.registrationTime = "15:00"
        try Check.rejects { try event.validate() }
        event.registrationDate = ""; event.link = "javascript:alert(1)"
        try Check.rejects { try event.validate() }
        event.link = "https://example.com"; try event.validate()
    }
    Check.run("Activities: preparation completion is distinct from participation") {
        var event = Activity(); event.title = "比赛"; var item = ChecklistItem(title: "带上学生证"); item.done = true
        event.preparation = [item]; try event.validate()
        try Check.equal(event.preparationProgress, "1 / 1"); try Check.equal(event.attendance, .upcoming)
    }
}
