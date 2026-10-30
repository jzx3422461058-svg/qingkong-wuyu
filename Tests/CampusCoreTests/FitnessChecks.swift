import Foundation
import CampusCore

@MainActor func fitnessChecks() {
    Check.run("Fitness: actual sets remain independent from plan") {
        var exercise = Exercise(); exercise.name = "深蹲"; exercise.sets[0].weight = "40"; exercise.sets[0].reps = "10"
        var schedule = ScheduledWorkout(); schedule.name = "下肢"; schedule.exercises = [exercise]
        var log = WorkoutLog.start(schedule)
        log.exercises[0].sets[0].weight = "35"; log.exercises[0].sets[0].completed = true
        try log.validate()
        try Check.equal(schedule.exercises[0].sets[0].weight, "40")
        try Check.equal(FitnessMath.volume(log.exercises[0]), 350)
    }
    Check.run("Fitness: missing data is not zero; unfinished and skipped work excluded") {
        var exercise = Exercise(); exercise.name = "深蹲"
        try Check.equal(FitnessMath.volume(exercise), nil)
        exercise.sets[0].completed = true
        try Check.rejects { try exercise.validate(actual: true) }
        exercise.sets[0].weight = "20"; exercise.sets[0].reps = "8"; exercise.skipped = true
        try Check.equal(FitnessMath.volume(exercise), nil)
    }
    Check.run("Fitness: cardio validates applicable fields and rejects invalid numbers") {
        var run = Exercise(); run.name = "跑步"; run.kind = .cardio; run.completed = true; run.minutes = "30"; run.distance = "5"
        try run.validate(actual: true)
        try Check.equal(FitnessMath.volume(run), nil)
        run.minutes = "-1"; try Check.rejects { try run.validate(actual: true) }
        run.minutes = "nan"; try Check.rejects { try run.validate(actual: true) }
    }
    Check.run("Fitness: trends aggregate matching completed exercises by day") {
        var log = WorkoutLog(); log.name = "练习"; log.date = "2026-10-20"; log.exercises[0].name = "卧推"
        log.exercises[0].sets[0].weight = "40"; log.exercises[0].sets[0].reps = "5"; log.exercises[0].sets[0].completed = true
        var other = log; other.id = UUID(); other.exercises[0].name = "深蹲"
        var unfinished = log; unfinished.id = UUID(); unfinished.finished = false
        let trend = FitnessMath.trend(name: "卧推", logs: [log, other, unfinished])
        try Check.equal(trend.count, 1); try Check.equal(trend.first?.volume, 200)
    }
}
