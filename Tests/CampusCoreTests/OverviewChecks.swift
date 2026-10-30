import Foundation
import CampusCore

@MainActor func overviewChecks() {
    Check.run("Overview: actual teaching week, cancelled workout and paused goals") {
        var state = Workspace(); var semester = Semester(); semester.start = "2026-09-07"; state.semester = semester
        var course = Course(); course.name = "单周课"; course.pattern = .odd; state.courses = [course]
        var workout = ScheduledWorkout(); workout.name = "取消训练"; workout.date = "2026-09-14"; workout.cancelled = true; state.trainingSchedule = [workout]
        try Check.equal(Overview.agenda(state, day: "2026-09-14").count, 0)
        try Check.equal(Overview.agenda(state, day: "2026-09-07").count, 1)
    }
    Check.run("Overview: overlaps detect collisions but not adjacent intervals") {
        var state = Workspace()
        var e = Activity(); e.title = "活动"; e.startDate = "2026-10-28"; e.endDate = e.startDate; e.startTime = "14:00"; e.endTime = "15:00"; state.activities = [e]
        var w = ScheduledWorkout(); w.name = "训练"; w.date = e.startDate; w.time = "14:30"; state.trainingSchedule = [w]
        let items = Overview.agenda(state, day: e.startDate)
        try Check.truth(Overview.overlaps(items[0], items: items), "overlap missing")
        state.trainingSchedule[0].time = "15:00"
        let adjacent = Overview.agenda(state, day: e.startDate)
        try Check.truth(!Overview.overlaps(adjacent[0], items: adjacent), "adjacent falsely overlapping")
    }
    Check.run("Overview: multi-day activities appear on intervening days") {
        var state = Workspace(); var e = Activity(); e.title = "比赛"; e.startDate = "2026-10-27"; e.endDate = "2026-10-30"; state.activities = [e]
        try Check.equal(Overview.agenda(state, day: "2026-10-28").count, 1)
        try Check.equal(Overview.agenda(state, day: "2026-10-31").count, 0)
    }
    Check.run("Overview: upcoming includes overdue and excludes paused and completed") {
        var state = Workspace(); var goal = LongGoal(); goal.title = "目标"; var m = Milestone(); m.title = "阶段"; m.criterion = "标准"
        var a = GoalAction(); a.title = "过期行动"; a.due = "2026-10-20"; m.actions = [a]; goal.milestones = [m]; state.goals = [goal]
        try Check.equal(Overview.upcoming(state, today: "2026-10-28").count, 1)
        state.goals[0].status = .paused
        try Check.equal(Overview.upcoming(state, today: "2026-10-28").count, 0)
    }
}
