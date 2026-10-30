import SwiftUI
import Charts
import CampusCore

struct FitnessView: View {
    @Environment(AppStore.self) var store
    @State private var tab = "训练安排"
    @State private var planEditor: TrainingPlan?
    @State private var scheduleEditor: ScheduledWorkout?
    @State private var logEditor: WorkoutLog?
    @State private var trendExercise = ""
    @State private var historySearch = ""
    private var completed: [WorkoutLog] { store.data.workouts.filter(\.finished) }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageTitle(eyebrow: "STRONGER, AT YOUR PACE", title: "健身计划", subtitle: "计划给你方向，记录看见改变。")
            HStack(spacing: 16) {
                Stat(title: "实际完成", value: "\(completed.count)", suffix: "次训练")
                Stat(title: "已记录时长", value: "\(Int(completed.compactMap { Double($0.minutes) }.reduce(0, +)))", suffix: "分钟")
                Stat(title: "我的方案", value: "\(store.data.trainingPlans.count)", suffix: "套")
            }
            HStack {
                Picker("视图", selection: $tab) { ForEach(["训练安排", "方案库", "训练记录"], id: \.self) { Text($0) } }.pickerStyle(.segmented).frame(width: 300)
                Spacer()
                Button(tab == "方案库" ? "新建方案" : tab == "训练安排" ? "安排训练" : "记录训练", systemImage: "plus") {
                    if tab == "方案库" { planEditor = TrainingPlan() }
                    else if tab == "训练安排" { scheduleEditor = ScheduledWorkout() }
                    else { logEditor = WorkoutLog() }
                }.buttonStyle(.borderedProminent).accessibilityIdentifier("add-fitness")
            }
            if tab == "方案库" { plans }
            else if tab == "训练安排" { schedules }
            else { history }
        }
        .onAppear { tab = store.fitnessTab; focus() }
        .onDisappear { store.fitnessTab = tab }
        .onChange(of: store.focusID) { _, _ in focus() }
        .sheet(item: $planEditor) { plan in
            EditorSheet(title: "训练方案", key: plan.name.isEmpty ? "plan-new" : "plan-\(plan.id)", initial: plan) { value in
                Field(label: "方案名称", value: value.name, prompt: "例如：上肢训练")
                ExerciseFields(exercises: value.exercises, actual: false)
                Field(label: "备注", value: value.notes)
            } save: { value, state in
                try value.validate()
                if let i = state.trainingPlans.firstIndex(where: { $0.id == value.id }) { state.trainingPlans[i] = value } else { state.trainingPlans.append(value) }
            }
        }
        .sheet(item: $scheduleEditor) { schedule in scheduleSheet(schedule) }
        .sheet(item: $logEditor) { log in logSheet(log) }
    }
    private func focus() {
        guard store.module == .fitness, let id = store.focusID else { return }
        if let s = store.data.trainingSchedule.first(where: { $0.id == id }) {
            tab = "训练安排"; logEditor = store.data.workouts.first { $0.scheduleID == id } ?? WorkoutLog.start(s)
        }
        store.focusID = nil
    }
    private var plans: some View {
        VStack(spacing: 14) {
            if store.data.trainingPlans.isEmpty { EmptyCard(icon: "dumbbell", title: "建立你的训练方案", detail: "力量训练按组规划，有氧训练按时长与距离规划。") }
            ForEach(store.data.trainingPlans) { plan in
                HStack(spacing: 20) {
                    Image(systemName: "dumbbell.fill").font(.title).foregroundStyle(.mint).frame(width: 44)
                    VStack(alignment: .leading, spacing: 8) { Text(plan.name).font(.headline); Text(plan.exercises.map(\.name).joined(separator: " · ")).font(.caption).foregroundStyle(.quiet) }
                    Spacer()
                    Button("安排") { var s = ScheduledWorkout(); s.name = plan.name; s.exercises = plan.exercises; scheduleEditor = s }
                    Button("编辑") { planEditor = plan }
                    Button(role: .destructive) { store.archive(plan, kind: "plan", name: plan.name) { $0.trainingPlans.removeAll { $0.id == plan.id } } } label: { Image(systemName: "trash") }
                }.glass()
            }
        }
    }
    private var schedules: some View {
        VStack(spacing: 14) {
            if store.data.trainingSchedule.isEmpty { EmptyCard(icon: "figure.run", title: "给运动留一点时间", detail: "选择已有方案，或直接建立一次训练安排。") }
            ForEach(store.data.trainingSchedule.sorted { ($0.date, $0.time) < ($1.date, $1.time) }) { schedule in
                let log = store.data.workouts.first { $0.scheduleID == schedule.id }
                HStack(spacing: 20) {
                    VStack(spacing: 4) { Text(String(schedule.date.suffix(5))).font(.title3.weight(.medium)).monospacedDigit(); Text(schedule.time).font(.caption).foregroundStyle(.quiet) }.frame(width: 70)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(schedule.name).font(.headline)
                        Text("预计 \(schedule.duration) 分钟 · \(schedule.cancelled ? "已取消" : log?.finished == true ? "已完成" : "待训练")").font(.caption).foregroundStyle(.quiet)
                    }
                    Spacer()
                    if !schedule.cancelled { Button(log == nil ? "记录实际训练" : "查看记录") { logEditor = log ?? WorkoutLog.start(schedule) }.buttonStyle(.borderedProminent) }
                    Menu {
                        Button("编辑安排") { scheduleEditor = schedule }
                        Button("复制到新日期") { var s = schedule; s.id = UUID(); s.date = Day.today(); s.cancelled = false; scheduleEditor = s }
                        Button(schedule.cancelled ? "恢复安排" : "取消本次") { store.act { state in if let i = state.trainingSchedule.firstIndex(where: { $0.id == schedule.id }) { state.trainingSchedule[i].cancelled.toggle() } } }
                        Button("移到回收站", role: .destructive) { store.archive(schedule, kind: "schedule", name: schedule.name) { $0.trainingSchedule.removeAll { $0.id == schedule.id } } }
                    } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 25)
                }.glass()
            }
        }
    }
    private var history: some View {
        let names = Set(completed.flatMap(\.exercises).filter { $0.kind == .strength }.map(\.name)).sorted()
        let trend = FitnessMath.trend(name: trendExercise, logs: completed)
        return VStack(alignment: .leading, spacing: 16) {
            if !names.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack { Text("动作训练量趋势").font(.headline); Spacer(); Picker("动作", selection: $trendExercise) { Text("选择动作").tag(""); ForEach(names, id: \.self) { Text($0).tag($0) } }.frame(width: 220) }
                    if trend.count >= 2 {
                        Chart(Array(trend.enumerated()), id: \.offset) { _, point in
                            LineMark(x: .value("日期", point.day), y: .value("训练量 kg·次", point.volume)).foregroundStyle(.mint).interpolationMethod(.monotone)
                            PointMark(x: .value("日期", point.day), y: .value("训练量 kg·次", point.volume)).foregroundStyle(.mint)
                        }.frame(height: 170)
                        Text("只统计同一动作已完成组的重量 × 次数；不含跳过或进行中的训练。").font(.caption).foregroundStyle(.quiet)
                    } else { Text(trendExercise.isEmpty ? "选择一个动作，查看它的变化。" : "记录至少两天的实际训练后显示趋势。").foregroundStyle(.quiet).padding(.vertical, 25) }
                }.glass()
            }
            TextField("搜索训练名称或日期", text: $historySearch).textFieldStyle(.roundedBorder)
            if store.data.workouts.isEmpty { EmptyCard(icon: "chart.xyaxis.line", title: "从第一次记录开始", detail: "不预填训练成绩，每一次进步都来自你的真实记录。") }
            ForEach(store.data.workouts.filter { historySearch.isEmpty || $0.name.contains(historySearch) || $0.date.contains(historySearch) }.sorted { $0.date > $1.date }) { log in
                HStack {
                    VStack(alignment: .leading, spacing: 8) { Text(log.name).font(.headline); Text("\(log.date) · \(log.finished ? "已完成" : "进行中") · \(log.minutes.isEmpty ? "时长未记录" : log.minutes + " 分钟")").font(.caption).foregroundStyle(.quiet) }
                    Spacer(); Button("详情／修改") { logEditor = log }
                    Button(role: .destructive) { store.archive(log, kind: "workout", name: log.name) { $0.workouts.removeAll { $0.id == log.id } } } label: { Image(systemName: "trash") }
                }.glass()
            }
        }
    }
    private func scheduleSheet(_ schedule: ScheduledWorkout) -> some View {
        EditorSheet(title: "安排一次训练", key: store.data.trainingSchedule.contains(where: { $0.id == schedule.id }) ? "schedule-\(schedule.id)" : "schedule-new", initial: schedule) { value in
            if !store.data.trainingPlans.isEmpty {
                Menu("使用已有方案") { ForEach(store.data.trainingPlans) { plan in Button(plan.name) { value.wrappedValue.name = plan.name; value.wrappedValue.exercises = plan.exercises } } }
            }
            Field(label: "训练名称", value: value.name)
            HStack { DateField(title: "日期", value: value.date); Field(label: "开始时间", value: value.time, prompt: "18:00") }
            Stepper("预计 \(value.wrappedValue.duration) 分钟", value: value.duration, in: 5...360, step: 5)
            ExerciseFields(exercises: value.exercises, actual: false)
        } save: { value, state in
            try value.validate()
            if let i = state.trainingSchedule.firstIndex(where: { $0.id == value.id }) { state.trainingSchedule[i] = value } else { state.trainingSchedule.append(value) }
        }
    }
    private func logSheet(_ log: WorkoutLog) -> some View {
        EditorSheet(title: "实际训练记录", key: log.scheduleID.map { "workout-schedule-\($0)" } ?? (store.data.workouts.contains(where: { $0.id == log.id }) ? "workout-\(log.id)" : "workout-new"), initial: log) { value in
            Field(label: "训练名称", value: value.name)
            HStack { DateField(title: "实际日期", value: value.date); Field(label: "总时长（分钟，可留空）", value: value.minutes) }
            ExerciseFields(exercises: value.exercises, actual: true)
            Field(label: "训练感受与备注", value: value.notes)
            Toggle("本次训练已完成", isOn: value.finished)
        } save: { value, state in
            try value.validate()
            if let i = state.workouts.firstIndex(where: { $0.id == value.id }) { state.workouts[i] = value } else { state.workouts.append(value) }
        }
    }
}

struct ExerciseFields: View {
    @Binding var exercises: [Exercise]
    var actual: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach($exercises) { $exercise in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        TextField("动作／运动名称", text: $exercise.name).textFieldStyle(.roundedBorder)
                        Picker("类型", selection: $exercise.kind) { ForEach(ExerciseKind.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.labelsHidden().frame(width: 95)
                        Button { exercises.removeAll { $0.id == exercise.id } } label: { Image(systemName: "minus.circle") }.buttonStyle(.plain)
                    }
                    if actual { Toggle("跳过此动作", isOn: $exercise.skipped).font(.caption) }
                    if !exercise.skipped {
                        if exercise.kind == .strength {
                            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, _ in
                                HStack {
                                    Text("\(index + 1) 组").font(.caption).frame(width: 36)
                                    TextField("kg", text: $exercise.sets[index].weight).textFieldStyle(.roundedBorder)
                                    Text("kg").font(.caption).foregroundStyle(.quiet)
                                    TextField("次数", text: $exercise.sets[index].reps).textFieldStyle(.roundedBorder)
                                    Text("次").font(.caption).foregroundStyle(.quiet)
                                    if actual { Toggle("完成", isOn: $exercise.sets[index].completed).toggleStyle(.checkbox) }
                                    Button { if exercise.sets.count > 1 { exercise.sets.remove(at: index) } } label: { Image(systemName: "minus") }.disabled(exercise.sets.count <= 1)
                                }
                            }
                            Button("添加一组") { exercise.sets.append(ExerciseSet()) }.controlSize(.small)
                        } else {
                            HStack { Field(label: "时长（分钟）", value: $exercise.minutes); Field(label: "距离（km，可留空）", value: $exercise.distance) }
                            if actual { Toggle("已完成", isOn: $exercise.completed) }
                        }
                    }
                }.padding(14).background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14))
            }
            Button("添加动作／有氧运动", systemImage: "plus") { exercises.append(Exercise()) }
        }
    }
}
