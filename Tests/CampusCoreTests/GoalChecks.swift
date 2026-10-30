import Foundation
import CampusCore

@MainActor func goalChecks() {
    Check.run("Goals: empty goals and cancelled-only goals have no artificial progress") {
        var goal = LongGoal(); goal.title = "英语六级"
        try Check.equal(goal.actionProgress, nil)
        var milestone = Milestone(); milestone.title = "词汇"; milestone.criterion = "完成两轮复习"
        var action = GoalAction(); action.title = "第一轮"; action.status = .cancelled; milestone.actions = [action]; goal.milestones = [milestone]
        try goal.validate(); try Check.equal(goal.actionProgress, nil)
    }
    Check.run("Goals: action progress excludes cancelled actions; stages stay explicit") {
        var goal = LongGoal(); goal.title = "目标"
        var stage = Milestone(); stage.title = "阶段"; stage.criterion = "达到验收条件"
        var done = GoalAction(); done.title = "完成项"; done.status = .done
        var pending = GoalAction(); pending.title = "待办项"
        var cancelled = GoalAction(); cancelled.title = "取消项"; cancelled.status = .cancelled
        stage.actions = [done, pending, cancelled]; goal.milestones = [stage]
        try Check.equal(goal.actionProgress, 0.5); try Check.equal(goal.milestoneProgress, "0 / 1")
        try Check.equal(goal.status, .active)
    }
    Check.run("Goals: moving actions and reordering preserves identifiers and values") {
        var goal = LongGoal(); goal.title = "目标"
        var a = Milestone(); a.title = "一"; a.criterion = "完成一"
        var b = Milestone(); b.title = "二"; b.criterion = "完成二"
        var action = GoalAction(); action.title = "阅读"; a.actions = [action]; goal.milestones = [a,b]
        try goal.moveAction(action.id, to: b.id); goal.shiftMilestone(b.id, offset: -1)
        try goal.validate(); try Check.equal(goal.milestones[0].id, b.id)
        try Check.equal(goal.milestones[0].actions.first?.id, action.id)
        try Check.equal(goal.allActions.count, 1)
    }
    Check.run("Goals: missing criteria and impossible dates rejected") {
        var stage = Milestone(); stage.title = "阶段"; try Check.rejects { try stage.validate() }
        var action = GoalAction(); action.title = "行动"; action.date = "2026-10-30"; action.due = "2026-10-20"
        try Check.rejects { try action.validate() }
    }
}
