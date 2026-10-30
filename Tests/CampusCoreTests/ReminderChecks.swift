import Foundation
import CampusCore

@MainActor func reminderChecks() {
    let now = Day.instant("2026-10-28", "10:00", zone: "Asia/Shanghai")!
    Check.run("Reminders: event and registration are separate; mutation replaces stale content") {
        var state = Workspace(); state.preferences.notifications = true
        var e = Activity(); e.title = "比赛"; e.startDate = "2026-10-30"; e.endDate = e.startDate
        e.registration = .pending; e.registrationDate = "2026-10-29"; state.activities = [e]
        let before = ReminderEngine.reminders(state, now: now)
        try Check.equal(before.count, 2)
        state.activities[0].location = "新场地"
        let changed = ReminderEngine.reminders(state, now: now)
        try Check.truth(changed.first(where: { $0.key.hasPrefix("event-") })?.id != before.first(where: { $0.key.hasPrefix("event-") })?.id, "Changed notification retained stale identifier")
        state.activities[0].registration = .registered
        try Check.equal(ReminderEngine.reminders(state, now: now).count, 1)
        state.activities[0].attendance = .cancelled
        try Check.equal(ReminderEngine.reminders(state, now: now).count, 0)
    }
    Check.run("Reminders: delivered deduplication survives disk reopen") {
        try Check.temporary { url in
            var state = Workspace(); state.preferences.notifications = true
            var workout = ScheduledWorkout(); workout.name = "运动"; workout.date = "2026-10-28"; state.trainingSchedule = [workout]
            let r = ReminderEngine.reminders(state, now: now)[0]
            state.deliveredReminders[r.id] = now
            let disk = try DiskStore<Workspace>(directory: url); try disk.save(state)
            try Check.equal(ReminderEngine.reminders(try disk.load()!, now: now).count, 0)
        }
    }
    Check.run("Reminders: paused goals, completed stages and disabled modules are excluded") {
        var state = Workspace(); state.preferences.notifications = true
        var g = LongGoal(); g.title = "目标"; var m = Milestone(); m.title = "阶段"; m.criterion = "标准"
        var a = GoalAction(); a.title = "行动"; a.date = "2026-10-29"; m.actions = [a]; g.milestones = [m]; state.goals = [g]
        try Check.equal(ReminderEngine.reminders(state, now: now).count, 1)
        state.goals[0].status = .paused; try Check.equal(ReminderEngine.reminders(state, now: now).count, 0)
        state.goals[0].status = .active; state.goals[0].milestones[0].completed = true
        try Check.equal(ReminderEngine.reminders(state, now: now).count, 0)
        state.goals[0].milestones[0].completed = false; state.preferences.mutedModules = ["goals"]
        try Check.equal(ReminderEngine.reminders(state, now: now).count, 0)
    }
    Check.run("Workspace: complete export/restore preserves records, drafts and trash") {
        try Check.temporary { url in
            var state = Workspace(); var event = Activity(); event.title = "活动"
            state.activities = [event]; state.drafts["draft"] = Data("unfinished".utf8)
            var goal = LongGoal(); goal.title = "目标"
            state.trash = [TrashEntry(kind: "goal", name: goal.title, payload: try JSONEncoder().encode(goal))]
            let disk = try DiskStore<Workspace>(directory: url); try disk.save(state)
            let exported = try disk.encode(state); try disk.save(Workspace())
            try Check.equal(try disk.restore(exported), state)
            try state.restoreTrash(state.trash[0].id)
            try Check.equal(state.goals.first?.id, goal.id); try Check.equal(state.trash.count, 0)
        }
    }
    Check.run("Reminders: stale reminders older than catch-up window are not emitted") {
        var state = Workspace(); state.preferences.notifications = true
        var workout = ScheduledWorkout(); workout.name = "旧运动"; workout.date = "2026-10-20"; state.trainingSchedule = [workout]
        try Check.equal(ReminderEngine.reminders(state, now: now).count, 0)
    }
    Check.run("Workspace: every domain and relationship survives full disk round trip") {
        try Check.temporary { url in
            var state = Workspace(); var semester = Semester(); semester.start = "2026-09-07"; state.semester = semester
            var course = Course(); course.name = "课"; var exception = CourseException(); exception.originalDay = "2026-09-07"; course.exceptions = [exception]; state.courses = [course]
            var plan = TrainingPlan(); plan.name = "力量"; plan.exercises[0].name = "深蹲"; plan.exercises[0].sets[0].weight = "20"; plan.exercises[0].sets[0].reps = "10"; state.trainingPlans = [plan]
            var schedule = ScheduledWorkout(); schedule.name = plan.name; schedule.exercises = plan.exercises; state.trainingSchedule = [schedule]
            var log = WorkoutLog.start(schedule); log.exercises[0].sets[0].completed = true; log.minutes = "30"; state.workouts = [log]
            var goal = LongGoal(); goal.title = "目标"; var stage = Milestone(); stage.title = "阶段"; stage.criterion = "成果"; var action = GoalAction(); action.title = "行动"; stage.actions = [action]; goal.milestones = [stage]; state.goals = [goal]
            var event = Activity(); event.title = "活动"; event.preparation = [ChecklistItem(title: "材料")]; state.activities = [event]
            state.preferences.theme = "深色"; state.deliveredReminders["test"] = now
            state.drafts["new"] = try JSONEncoder().encode(Course())
            let store = try DiskStore<Workspace>(directory: url); try store.save(state)
            try Check.equal(try DiskStore<Workspace>(directory: url).load(), state)
        }
    }
}
