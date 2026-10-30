import SwiftUI
import CampusCore

private struct StageEdit: Identifiable { var id: UUID { stage.id }; var goalID: UUID; var stage: Milestone }
private struct ActionEdit: Identifiable { var id: UUID { action.id }; var goalID: UUID; var stageID: UUID; var action: GoalAction }

struct GoalsView: View {
    @Environment(AppStore.self) var store
    @Environment(\.accessibilityReduceMotion) var systemReduceMotion
    @State private var goalEditor: LongGoal?
    @State private var stageEditor: StageEdit?
    @State private var actionEditor: ActionEdit?
    @State private var expanded: UUID?
    @State private var showArchived = false
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageTitle(eyebrow: "SMALL STEPS, LONG HORIZONS", title: "长期计划", subtitle: "把远方的目标，放进今天的一小步。")
            HStack { Text("目标 → 阶段 → 行动").font(.callout).foregroundStyle(.quiet); Spacer(); Toggle("显示归档", isOn: $showArchived).toggleStyle(.switch).controlSize(.small); Button("建立目标", systemImage: "plus") { goalEditor = LongGoal() }.buttonStyle(.borderedProminent).accessibilityIdentifier("add-goal") }
            if store.data.goals.isEmpty { EmptyCard(icon: "flag.checkered", title: "你想走向哪里？", detail: "考证、阅读、科研或职业准备，从一个清晰的目标开始。") }
            ForEach(store.data.goals.filter { showArchived || $0.status != .archived }) { goal in
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 18) {
                        Image(systemName: "flag.checkered").font(.title2).foregroundStyle(.orange).frame(width: 36, height: 44)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(goal.title).font(.title3.weight(.semibold))
                            if !goal.detail.isEmpty { Text(goal.detail).font(.callout).foregroundStyle(.quiet) }
                            Text("\(goal.status.rawValue)\(goal.due.isEmpty ? "" : " · 截止 " + goal.due)").font(.caption).foregroundStyle(.quiet)
                        }
                        Spacer()
                        Menu { Button("编辑目标") { goalEditor = goal }; Button("移到回收站", role: .destructive) { store.archive(goal, kind: "goal", name: goal.title) { $0.goals.removeAll { $0.id == goal.id } } } } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 25)
                    }
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(value: goal.actionProgress ?? 0).tint(.orange)
                            Text(goal.actionProgress.map { "行动完成率 \(Int($0 * 100))%" } ?? "尚未拆解有效行动").font(.caption).foregroundStyle(.quiet)
                        }
                        Text("阶段 \(goal.milestoneProgress)").font(.caption).foregroundStyle(.quiet)
                        Button(expanded == goal.id ? "收起阶段" : "展开阶段") { withAnimation(systemReduceMotion || store.data.preferences.reduceMotion ? nil : .easeInOut(duration: 0.22)) { expanded = expanded == goal.id ? nil : goal.id } }
                    }
                    if expanded == goal.id {
                        Divider()
                        ForEach(Array(goal.milestones.enumerated()), id: \.element.id) { index, stage in stageRow(stage, goal: goal, index: index) }
                        Button("添加阶段里程碑", systemImage: "plus.circle") { stageEditor = StageEdit(goalID: goal.id, stage: Milestone()) }
                    }
                }.glass()
            }
        }
        .onAppear { if let id = store.focusID { expanded = id; store.focusID = nil } else if expanded == nil { expanded = store.expandedGoal ?? store.data.goals.first { $0.status == .active }?.id } }
        .onDisappear { store.expandedGoal = expanded }
        .onChange(of: store.focusID) { _, id in if store.module == .goals, let id { expanded = id; store.focusID = nil } }
        .sheet(item: $goalEditor) { goal in
            EditorSheet(title: "长期目标", key: goal.title.isEmpty ? "goal-new" : "goal-\(goal.id)", initial: goal) { value in
                Field(label: "目标名称", value: value.title)
                Field(label: "为什么做／最终成果", value: value.detail)
                HStack { DateField(title: "开始日期（选填）", value: value.start); DateField(title: "截止日期（选填）", value: value.due) }
                Picker("状态", selection: value.status) { ForEach(GoalStatus.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                Text("阶段与目标的完成由你确认，不会因为时间过去而自动完成。").font(.caption).foregroundStyle(.quiet)
            } save: { value, state in
                try value.validate()
                if let i = state.goals.firstIndex(where: { $0.id == value.id }) { state.goals[i] = value } else { state.goals.append(value) }
                expanded = value.id
            }
        }
        .sheet(item: $stageEditor) { edit in
            EditorSheet(title: "阶段里程碑", key: "stage-\(edit.goalID)-\(edit.stage.title.isEmpty ? "new" : edit.stage.id.uuidString)", initial: edit.stage) { value in
                Field(label: "阶段名称", value: value.title)
                Field(label: "完成标准（必填）", value: value.criterion, prompt: "例如：完成文献笔记并形成一页综述")
                DateField(title: "截止日期（选填）", value: value.due)
                Toggle("我确认此阶段已完成", isOn: value.completed)
            } save: { value, state in
                try value.validate()
                guard let i = state.goals.firstIndex(where: { $0.id == edit.goalID }) else { throw AppError("目标已不存在。") }
                if let j = state.goals[i].milestones.firstIndex(where: { $0.id == value.id }) { state.goals[i].milestones[j] = value } else { state.goals[i].milestones.append(value) }
            }
        }
        .sheet(item: $actionEditor) { edit in
            EditorSheet(title: "具体行动", key: "action-\(edit.stageID)-\(edit.action.title.isEmpty ? "new" : edit.action.id.uuidString)", initial: edit.action) { value in
                Field(label: "要做什么", value: value.title)
                HStack { DateField(title: "执行日期（选填）", value: value.date); DateField(title: "截止日期（选填）", value: value.due) }
                Field(label: "当天提醒时间", value: value.reminderTime, prompt: "09:00")
                Picker("状态", selection: value.status) { ForEach(ActionStatus.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                Field(label: "备注", value: value.notes)
            } save: { value, state in
                try value.validate()
                guard let i = state.goals.firstIndex(where: { $0.id == edit.goalID }), let j = state.goals[i].milestones.firstIndex(where: { $0.id == edit.stageID }) else { throw AppError("目标或阶段已不存在。") }
                if let k = state.goals[i].milestones[j].actions.firstIndex(where: { $0.id == value.id }) { state.goals[i].milestones[j].actions[k] = value } else { state.goals[i].milestones[j].actions.append(value) }
            }
        }
    }

    private func stageRow(_ stage: Milestone, goal: LongGoal, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: stage.completed ? "checkmark.circle.fill" : "circle.dotted").foregroundStyle(stage.completed ? Color.mint : Color.orange)
                VStack(alignment: .leading, spacing: 5) { Text("\(index + 1). \(stage.title)").font(.headline); Text(stage.criterion).font(.caption).foregroundStyle(.quiet) }
                Spacer()
                if !stage.due.isEmpty { Text(stage.due).font(.caption).foregroundStyle(.quiet) }
                Button { mutateGoal(goal.id) { $0.shiftMilestone(stage.id, offset: -1) } } label: { Image(systemName: "arrow.up") }.disabled(index == 0)
                Button { mutateGoal(goal.id) { $0.shiftMilestone(stage.id, offset: 1) } } label: { Image(systemName: "arrow.down") }.disabled(index == goal.milestones.count - 1)
                Button("编辑") { stageEditor = StageEdit(goalID: goal.id, stage: stage) }
            }
            ForEach(stage.actions) { action in
                HStack(spacing: 10) {
                    Button { mutateGoal(goal.id) { g in if let j = g.milestones.firstIndex(where: { $0.id == stage.id }), let k = g.milestones[j].actions.firstIndex(where: { $0.id == action.id }) { g.milestones[j].actions[k].status = action.status == .done ? .pending : .done } } } label: { Image(systemName: action.status == .done ? "checkmark.circle.fill" : action.status == .cancelled ? "minus.circle" : "circle").foregroundStyle(action.status == .done ? Color.mint : .secondary) }.buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(action.title).strikethrough(action.status == .done).foregroundStyle(action.status == .pending ? .primary : .secondary)
                        if !action.date.isEmpty || !action.due.isEmpty { Text("\(action.date.isEmpty ? "未排期" : action.date)\(action.due.isEmpty ? "" : " · 截止 " + action.due)").font(.caption2).foregroundStyle(.quiet) }
                    }
                    Spacer()
                    Menu {
                        Button("编辑行动") { actionEditor = ActionEdit(goalID: goal.id, stageID: stage.id, action: action) }
                        if goal.milestones.count > 1 {
                            Menu("移到其他阶段") { ForEach(goal.milestones.filter { $0.id != stage.id }) { target in Button(target.title) { store.act { state in guard let i = state.goals.firstIndex(where: { $0.id == goal.id }) else { return }; try state.goals[i].moveAction(action.id, to: target.id) } } } }
                        }
                        Button("取消此行动") { mutateGoal(goal.id) { g in if let j = g.milestones.firstIndex(where: { $0.id == stage.id }), let k = g.milestones[j].actions.firstIndex(where: { $0.id == action.id }) { g.milestones[j].actions[k].status = .cancelled } } }
                    } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 25)
                }.padding(12).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
            }
            Button("添加行动", systemImage: "plus") { actionEditor = ActionEdit(goalID: goal.id, stageID: stage.id, action: GoalAction()) }.controlSize(.small)
        }.padding(16).background(.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 18))
    }
    private func mutateGoal(_ id: UUID, change: (inout LongGoal) -> Void) {
        store.act { state in if let i = state.goals.firstIndex(where: { $0.id == id }) { change(&state.goals[i]) } }
    }
}
