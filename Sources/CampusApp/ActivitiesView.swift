import SwiftUI
import CampusCore

struct ActivitiesView: View {
    @Environment(AppStore.self) var store
    @State private var editing: Activity?
    @State private var category = "全部"
    @State private var status = "全部"
    @State private var query = ""
    private var filtered: [Activity] {
        store.data.activities.filter { (category == "全部" || $0.category == category) && (status == "全部" || $0.attendance.rawValue == status) && (query.isEmpty || $0.title.contains(query) || $0.startDate.contains(query)) }.sorted { ($0.startDate, $0.startTime) < ($1.startDate, $1.startTime) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageTitle(eyebrow: "BEYOND THE CLASSROOM", title: "各类活动", subtitle: "让每一次参与，都留下自己的收获。")
            HStack(spacing: 16) {
                Stat(title: "即将参与", value: "\(store.data.activities.filter { $0.attendance == .upcoming }.count)", suffix: "场")
                Stat(title: "已经参加", value: "\(store.data.activities.filter { $0.attendance == .attended }.count)", suffix: "场")
                Stat(title: "实际志愿时长", value: Activity.attendedHours(store.data.activities).formatted(.number.precision(.fractionLength(0...1))), suffix: "小时")
            }
            HStack {
                TextField("搜索名称或日期", text: $query).textFieldStyle(.roundedBorder).frame(maxWidth: 220)
                Picker("类别", selection: $category) { Text("全部").tag("全部"); ForEach(Set(Activity.categories + store.data.activities.map(\.category)).sorted(), id: \.self) { Text($0).tag($0) } }.frame(width: 150)
                Picker("参与", selection: $status) { Text("全部").tag("全部"); ForEach(AttendanceStatus.allCases, id: \.self) { Text($0.rawValue).tag($0.rawValue) } }.frame(width: 150)
                Spacer(); Button("添加活动", systemImage: "plus") { editing = Activity() }.buttonStyle(.borderedProminent).accessibilityIdentifier("add-activity")
            }
            if filtered.isEmpty { EmptyCard(icon: "sparkles", title: store.data.activities.isEmpty ? "大学生活，不止课堂" : "没有符合筛选的活动", detail: "讲座、比赛、社团与志愿服务，在这里管理准备与参与。") }
            ForEach(filtered) { event in eventCard(event) }
        }
        .onAppear { category = store.activityCategory; status = store.activityStatus; query = store.activityQuery; focus() }
        .onDisappear { store.activityCategory = category; store.activityStatus = status; store.activityQuery = query }
        .onChange(of: store.focusID) { _, _ in focus() }
        .sheet(item: $editing) { event in
            EditorSheet(title: "活动与参与记录", key: event.title.isEmpty ? "activity-new" : "activity-\(event.id)", initial: event) { value in
                Field(label: "活动名称", value: value.title)
                HStack { Field(label: "类别（可自定义）", value: value.category); Field(label: "主办方（选填）", value: value.organizer) }
                Field(label: "地点", value: value.location)
                HStack { DateField(title: "开始日期", value: value.startDate); Field(label: "开始时间", value: value.startTime) }
                HStack { DateField(title: "结束日期", value: value.endDate); Field(label: "结束时间", value: value.endTime) }
                Divider()
                Picker("报名状态", selection: value.registration) { ForEach(RegistrationStatus.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                if value.wrappedValue.registration != .unnecessary {
                    HStack { DateField(title: "报名截止日期（选填）", value: value.registrationDate); Field(label: "截止时间", value: value.registrationTime) }
                    Stepper("报名提前 \(value.wrappedValue.registrationLead) 分钟提醒", value: value.registrationLead, in: 0...10080, step: 60)
                }
                Stepper("活动提前 \(value.wrappedValue.eventLead) 分钟提醒", value: value.eventLead, in: 0...10080, step: 15)
                Text("提醒需在数据与设置中开启系统通知。").font(.caption).foregroundStyle(.quiet)
                Divider()
                Text("准备清单").font(.headline)
                ForEach(value.preparation) { item in
                    HStack { Toggle("完成", isOn: item.done).labelsHidden(); TextField("需要准备什么", text: item.title).textFieldStyle(.roundedBorder); Button { value.wrappedValue.preparation.removeAll { $0.id == item.wrappedValue.id } } label: { Image(systemName: "minus.circle") } }
                }
                Button("添加准备事项") { value.wrappedValue.preparation.append(ChecklistItem()) }
                Divider()
                Picker("参与状态", selection: value.attendance) { ForEach(AttendanceStatus.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                Field(label: "备注", value: value.notes)
                Field(label: "参与收获／总结", value: value.summary)
                if value.wrappedValue.category == "志愿服务" { Field(label: "实际志愿时长（小时）", value: value.volunteerHours) }
                Field(label: "参考链接（选填，主动点击才打开）", value: value.link, prompt: "https://…")
            } save: { value, state in
                try value.validate()
                if let i = state.activities.firstIndex(where: { $0.id == value.id }) { state.activities[i] = value } else { state.activities.append(value) }
            }
        }
    }
    private func focus() {
        guard store.module == .activities, let id = store.focusID else { return }
        editing = store.data.activities.first { $0.id == id }; store.focusID = nil
    }
    private func eventCard(_ event: Activity) -> some View {
        HStack(alignment: .top, spacing: 26) {
            VStack(spacing: 5) {
                Text(String(event.startDate.suffix(2))).font(.system(size: 34, weight: .light, design: .rounded))
                Text(String(event.startDate.prefix(7))).font(.caption).foregroundStyle(.quiet)
                Text(event.startTime).font(.caption).monospacedDigit().padding(.top, 6)
            }.frame(width: 70).padding(.top, 3)
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(event.category).font(.caption.weight(.medium)).padding(.horizontal, 10).padding(.vertical, 5).background(.purple.opacity(0.18), in: Capsule())
                    Text(event.attendance.rawValue).font(.caption).foregroundStyle(.quiet)
                    Spacer()
                    Button("详情／编辑") { editing = event }
                    Button(role: .destructive) { store.archive(event, kind: "activity", name: event.title) { $0.activities.removeAll { $0.id == event.id } } } label: { Image(systemName: "trash") }
                }
                Text(event.title).font(.title3.weight(.semibold))
                HStack(spacing: 18) {
                    Label(event.location.isEmpty ? "地点待补充" : event.location, systemImage: "mappin.and.ellipse")
                    if !event.organizer.isEmpty { Text(event.organizer) }
                }.font(.callout).foregroundStyle(.quiet)
                if event.registration != .unnecessary {
                    HStack {
                        Label(event.registration.rawValue, systemImage: event.registration == .registered ? "checkmark.seal" : "ticket")
                        if !event.registrationDate.isEmpty { Text("截止 \(event.registrationDate) \(event.registrationTime)") }
                        Spacer()
                        if event.registration == .pending { Button("标记已报名") { update(event.id) { $0.registration = .registered } }.controlSize(.small) }
                    }.font(.caption).foregroundStyle(event.registration == .pending ? Color.orange : Color.secondary)
                }
                if !event.preparation.isEmpty {
                    Divider()
                    Text("准备事项 · \(event.preparationProgress)").font(.caption).foregroundStyle(.quiet)
                    ForEach(event.preparation) { item in
                        Toggle(item.title, isOn: Binding(get: { item.done }, set: { new in update(event.id) { e in if let i = e.preparation.firstIndex(where: { $0.id == item.id }) { e.preparation[i].done = new } } })).toggleStyle(.checkbox)
                    }
                }
                if !event.summary.isEmpty { Text(event.summary).font(.callout).foregroundStyle(.quiet) }
                if !event.link.isEmpty, let url = URL(string: event.link) { Button("打开参考链接", systemImage: "arrow.up.right") { NSWorkspace.shared.open(url) }.controlSize(.small) }
            }
        }.glass()
    }
    private func update(_ id: UUID, change: (inout Activity) -> Void) {
        store.act { state in if let i = state.activities.firstIndex(where: { $0.id == id }) { change(&state.activities[i]) } }
    }
}
