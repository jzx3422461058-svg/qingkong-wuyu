import SwiftUI
import CampusCore

@MainActor enum Assets {
    static let sky: NSImage? = {
        guard let url = bundle.url(forResource: "Sky", withExtension: "jpg"), let source = NSImage(contentsOf: url) else { return nil }
        // Decode once, away from SwiftUI's repeated body evaluation during transitions.
        if let image = source.cgImage(forProposedRect: nil, context: nil, hints: nil) { return NSImage(cgImage: image, size: source.size) }
        return source
    }()
    static var bundle: Bundle {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("Campus_CampusApp.bundle"), let bundle = Bundle(url: url) { return bundle }
        return .module
    }
}

@MainActor enum QA {
    static var enabled: Bool { ProcessInfo.processInfo.arguments.contains("--qa") && ProcessInfo.processInfo.arguments.contains("--data-dir") }
    static func prepare(_ store: AppStore) {
        guard enabled else { return }
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--theme"), i + 1 < args.count { store.act { $0.preferences.theme = args[i + 1] } }
        if args.contains("--reduce-motion") { store.act { $0.preferences.reduceMotion = true; $0.preferences.reduceTransparency = true } }
        if let i = args.firstIndex(of: "--module"), i + 1 < args.count { store.module = Module.allCases.first { String(describing: $0) == args[i+1] || $0.rawValue == args[i+1] } ?? .courses }
        if store.data.semester == nil {
            store.act { state in
                var semester = Semester(); semester.start = Day.monday(Day.add(Day.today(zone: "Asia/Shanghai"), days: -49)); semester.name = "测试学期 · 独立验证数据"
                state.semester = semester
                for i in 0..<5 {
                    var c = Course(); c.name = ["马克思主义基本原理", "大学英语", "中国近现代史纲要", "体育", "思想政治教育学原理"][i]
                    c.location = ["北教学楼 203", "外语楼 102", "南教学楼 406", "体育馆", "文科楼 305"][i]
                    c.weekday = i + 1; c.startPeriod = i % 2 == 0 ? 1 : 3; c.endPeriod = c.startPeriod + 1; c.color = i
                    state.courses.append(c)
                }
            }
        }
        if store.data.trainingPlans.isEmpty {
            store.act { state in
                var plan = TrainingPlan(); plan.name = "全身力量 · 测试方案"; plan.exercises[0].name = "深蹲"
                plan.exercises[0].sets[0].weight = "40"; plan.exercises[0].sets[0].reps = "10"
                state.trainingPlans = [plan]
                var schedule = ScheduledWorkout(); schedule.name = plan.name; schedule.exercises = plan.exercises
                state.trainingSchedule = [schedule]
            }
        }
        if store.data.goals.isEmpty {
            store.act { state in
                var goal = LongGoal(); goal.title = "准备英语六级 · 测试目标"; goal.detail = "用每一天的小行动，完成一个学期的积累。"
                var stage = Milestone(); stage.title = "建立学习节奏"; stage.criterion = "完成一套真题并整理薄弱项"
                var action = GoalAction(); action.title = "完成第一套阅读练习"; action.date = Day.today(); stage.actions = [action]; goal.milestones = [stage]; state.goals = [goal]
            }
        }
        if store.data.activities.isEmpty {
            store.act { state in
                var event = Activity(); event.title = "青年学术分享会 · 测试活动"; event.location = "图书馆报告厅"; event.organizer = "学院学术部"; event.category = "讲座"
                event.registration = .registered; event.preparation = [ChecklistItem(title: "带上学生证与笔记本")]; state.activities = [event]
            }
        }
    }
    static func reportNotificationStatus(_ service: NotificationService, store: AppStore) {
        guard enabled else { return }
        Task {
            await service.check()
            let text = "Notification permission: \(service.status)\nLast error: \(service.lastError ?? "none")\n"
            try? text.write(to: store.directory.appendingPathComponent("notification-status.txt"), atomically: true, encoding: .utf8)
        }
    }
    static func captureIfRequested() {
        guard enabled else { return }
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--capture"), i + 1 < args.count else { return }
        let path = args[i + 1]
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            guard let window = NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil }), let view = window.contentView else { return }
            window.displayIfNeeded()
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            if let png = bitmap.representation(using: .png, properties: [:]) { try? png.write(to: URL(fileURLWithPath: path)) }
            if args.contains("--quit-after-capture") { NSApp.terminate(nil) }
        }
    }
}
