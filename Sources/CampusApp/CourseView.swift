import SwiftUI
import CampusCore

struct CourseView: View {
    @Environment(AppStore.self) var store
    @State private var week = 1
    @State private var editing: Course?
    @State private var semesterEditor = false
    @State private var creatingSemester = false
    @State private var importEditor = false
    @State private var adjustment: CourseOccurrence?
    @State private var listMode = false
    private var semester: Semester? { store.data.semester }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageTitle(eyebrow: "YOUR WEEK, IN FOCUS", title: "课程表", subtitle: "让每一节课，都有清晰的位置。")
            HStack {
                if let semester {
                    Button { week = max(1, week - 1) } label: { Image(systemName: "chevron.left") }.disabled(week <= 1)
                    Text("第 \(week) 周").font(.headline).monospacedDigit()
                    Button { week = min(semester.weekCount, week + 1) } label: { Image(systemName: "chevron.right") }.disabled(week >= semester.weekCount)
                    Button("本周") { week = semester.week(on: Day.today(zone: semester.timeZone)) ?? 1 }
                    Text(semester.name).font(.caption).foregroundStyle(.quiet)
                }
                Spacer()
                Button { listMode.toggle() } label: { Image(systemName: listMode ? "calendar" : "list.bullet") }.help("切换周视图／全部课程")
                Menu("学期") {
                    Button("编辑当前学期") { creatingSemester = false; semesterEditor = true }
                    Button("建立新学期（保留当前课表）") { creatingSemester = true; semesterEditor = true }
                    if !store.data.archivedSemesters.isEmpty {
                        Divider()
                        ForEach(store.data.archivedSemesters) { archived in
                            Button("切换到 \(archived.semester.name)") {
                                do { _ = try store.disk?.backup(reason: "before-semester"); try store.commit { try $0.switchSemester(archived.id) }; week = 1 } catch { store.error = error.localizedDescription }
                            }
                        }
                    }
                }
                Button("导入课表", systemImage: "square.and.arrow.down") { importEditor = true }.disabled(semester == nil).accessibilityIdentifier("import-courses")
                Button("添加课程", systemImage: "plus") { editing = Course() }.buttonStyle(.borderedProminent).disabled(semester == nil).accessibilityIdentifier("add-course")
            }
            if let semester {
                if semester.week(on: Day.today(zone: semester.timeZone)) == nil { Label("今天不在当前学期内，正在浏览第 \(week) 周。", systemImage: "info.circle").font(.callout).foregroundStyle(.quiet) }
                if listMode { courseList(semester) } else { weekGrid(semester) }
            } else {
                EmptyCard(icon: "calendar.badge.plus", title: "从你的第一张课表开始", detail: "先设置学期起始日和节次时间，再添加课程或导入整理好的课表。")
                Button("设置我的学期") { semesterEditor = true }.buttonStyle(.borderedProminent)
            }
        }
        .onAppear {
            if let s = semester { week = min(s.weekCount, store.courseWeek ?? s.week(on: Day.today(zone: s.timeZone)) ?? 1) }
            if let id = store.focusID { editing = store.data.courses.first { $0.id == id }; store.focusID = nil }
        }
        .onDisappear { store.courseWeek = week }
        .onChange(of: store.data.semester) { _, semester in if let semester { week = min(max(1, week), semester.weekCount) } }
        .onChange(of: store.focusID) { _, id in if store.module == .courses, let id { editing = store.data.courses.first { $0.id == id }; store.focusID = nil } }
        .sheet(isPresented: $semesterEditor) { semesterSheet }
        .sheet(isPresented: $importEditor) { CourseImportSheet().environment(store) }
        .sheet(item: $editing) { course in courseSheet(course) }
        .sheet(item: $adjustment) { occurrence in exceptionSheet(occurrence) }
    }

    private func weekGrid(_ semester: Semester) -> some View {
        let start = Day.add(semester.start, days: (week - 1) * 7)
        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("节次").font(.caption).foregroundStyle(.quiet).frame(width: 44)
                ForEach(1...7, id: \.self) { day in
                    let date = Day.add(start, days: day - 1)
                    VStack(spacing: 5) {
                        Text(["一", "二", "三", "四", "五", "六", "日"][day - 1]).font(.headline)
                        Text(String(date.suffix(5))).font(.caption2).monospacedDigit().foregroundStyle(.quiet)
                    }.frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(date == Day.today(zone: semester.timeZone) ? Color.blue.opacity(0.22) : .clear, in: RoundedRectangle(cornerRadius: 12))
                }
            }.padding(.bottom, 12)
            ForEach(semester.periods.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 8) {
                    VStack(spacing: 4) { Text("\(index + 1)").font(.callout.weight(.medium)); Text(semester.periods[index].start).font(.system(size: 9)).foregroundStyle(.quiet) }.frame(width: 44).padding(.top, 12)
                    ForEach(1...7, id: \.self) { day in
                        let date = Day.add(start, days: day - 1)
                        let all = CourseCalendar.occurrences(on: date, semester: semester, courses: store.data.courses)
                        let entries = all.filter { $0.startPeriod <= index + 1 && $0.endPeriod >= index + 1 }
                        VStack(spacing: 5) {
                            ForEach(entries) { occurrence in
                                Button { adjustment = occurrence } label: {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(occurrence.name).font(.system(size: 11, weight: .semibold)).lineLimit(2)
                                        if occurrence.startPeriod == index + 1 {
                                            Text(occurrence.location.isEmpty ? "地点待补充" : occurrence.location).font(.system(size: 10)).foregroundStyle(.quiet).lineLimit(2)
                                            Text("\(occurrence.startPeriod)—\(occurrence.endPeriod) 节\(occurrence.adjusted ? " · 调整" : "")").font(.system(size: 9)).foregroundStyle(.quiet)
                                        }
                                        if CourseCalendar.conflicts(occurrence, among: all) { Text("时间重叠").font(.system(size: 9)).foregroundStyle(.orange) }
                                    }.frame(maxWidth: .infinity, alignment: .leading).padding(9)
                                        .background([Color.blue, .teal, .purple, .orange, .indigo][abs(occurrence.color % 5)].opacity(0.22), in: RoundedRectangle(cornerRadius: 12))
                                }.buttonStyle(.plain).contextMenu {
                                    Button("编辑整个课程") { editing = store.data.courses.first { $0.id == occurrence.courseID } }
                                    Button("调整本次上课") { adjustment = occurrence }
                                }
                            }
                        }.frame(maxWidth: .infinity, minHeight: 58, alignment: .top)
                            .background(.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 10))
                    }
                }.padding(.vertical, 3)
            }
        }.glass(16)
    }

    private func courseList(_ semester: Semester) -> some View {
        VStack(spacing: 12) {
            if store.data.courses.isEmpty { EmptyCard(icon: "books.vertical", title: "还没有课程", detail: "导入截图整理后的 CSV，或手动添加第一门课。") }
            ForEach(store.data.courses) { course in
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(course.name).font(.headline)
                        Text("周\(["一", "二", "三", "四", "五", "六", "日"][course.weekday - 1]) · \(course.startPeriod)—\(course.endPeriod) 节 · \(course.weeks) 周 · \(course.pattern.rawValue)").font(.caption).foregroundStyle(.quiet)
                        Text(course.location.isEmpty ? "地点待补充" : course.location).font(.callout)
                        ForEach(course.exceptions) { exception in
                            HStack {
                                Text("\(exception.originalDay) · \(exception.cancelled ? "停课" : "调至 " + exception.targetDay)").font(.caption).foregroundStyle(.orange)
                                Button("恢复原安排") { store.act { state in
                                    guard let i = state.courses.firstIndex(where: { $0.id == course.id }) else { return }
                                    state.courses[i].exceptions.removeAll { $0.id == exception.id }
                                } }.controlSize(.small)
                            }
                        }
                    }
                    Spacer()
                    Button("编辑") { editing = course }
                    Button("复制") { var c = course; c.id = UUID(); c.exceptions = []; editing = c }
                    Button(role: .destructive) { store.archive(course, kind: "course", name: course.name) { $0.courses.removeAll { $0.id == course.id } } } label: { Image(systemName: "trash") }.help("移到回收站")
                }.glass()
            }
        }
    }

    private var semesterSheet: some View {
        EditorSheet(title: creatingSemester ? "建立新学期" : "学期与节次", key: creatingSemester ? "semester-new" : "semester", initial: creatingSemester ? Semester() : semester ?? Semester()) { value in
            Field(label: "学期名称", value: value.name)
            HStack { DateField(title: "第一教学周的周一", value: value.start); Stepper("\(value.wrappedValue.weekCount) 周", value: value.weekCount, in: 1...52) }
            Field(label: "教学时区", value: value.timeZone, prompt: "Asia/Shanghai")
            Text("以下时间只是初始模板，请按你的学校核对。修改学期会校验已有课程。").font(.caption).foregroundStyle(.quiet)
            ForEach(value.wrappedValue.periods.indices, id: \.self) { i in
                HStack { Text("第 \(i + 1) 节").frame(width: 55); TextField("08:00", text: value.periods[i].start); Text("—"); TextField("08:45", text: value.periods[i].end) }.textFieldStyle(.roundedBorder)
            }
            HStack { Button("添加节次") { value.wrappedValue.periods.append(LessonPeriod("21:00", "21:45")) }; Button("删除末节") { if value.wrappedValue.periods.count > 1 { value.wrappedValue.periods.removeLast() } } }
        } save: { value, state in
            try value.validate()
            if creatingSemester { try state.newSemester(value); week = 1 } else { state.semester = value; week = min(week, value.weekCount) }
        }
    }

    private func courseSheet(_ course: Course) -> some View {
        EditorSheet(title: course.name.isEmpty ? "添加课程" : "编辑课程", key: store.data.courses.contains(where: { $0.id == course.id }) ? "course-\(course.id)" : "course-new", initial: course) { value in
            Field(label: "课程名称", value: value.name)
            Field(label: "上课地点", value: value.location, prompt: "可稍后补充")
            Picker("星期", selection: value.weekday) { ForEach(1...7, id: \.self) { Text("周\(["一", "二", "三", "四", "五", "六", "日"][$0 - 1])").tag($0) } }
            HStack { Stepper("开始：\(value.wrappedValue.startPeriod) 节", value: value.startPeriod, in: 1...(semester?.periods.count ?? 10)); Stepper("结束：\(value.wrappedValue.endPeriod) 节", value: value.endPeriod, in: 1...(semester?.periods.count ?? 10)) }
            Field(label: "教学周次", value: value.weeks, prompt: "1-16 或 1,3,5")
            Picker("周次规则", selection: value.pattern) { ForEach(WeekPattern.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
            Text("单次补课可添加一条安排，并只填写对应教学周。已有单次调整会随课程保留。").font(.caption).foregroundStyle(.quiet)
        } save: { value, state in
            guard let semester = state.semester else { throw AppError("请先配置学期。") }
            try value.validate(in: semester)
            if let i = state.courses.firstIndex(where: { $0.id == value.id }) { state.courses[i] = value } else { state.courses.append(value) }
        }
    }

    private func exceptionSheet(_ occurrence: CourseOccurrence) -> some View {
        var initial = CourseException(); initial.originalDay = occurrence.originalDay; initial.targetDay = occurrence.day
        initial.startPeriod = occurrence.startPeriod; initial.endPeriod = occurrence.endPeriod; initial.location = occurrence.location
        if let existing = store.data.courses.first(where: { $0.id == occurrence.courseID })?.exceptions.first(where: { $0.originalDay == occurrence.originalDay }) { initial = existing }
        return EditorSheet(title: "调整本次 · \(occurrence.name)", key: "exception-\(occurrence.id)", initial: initial) { value in
            Text("原上课日期：\(occurrence.originalDay)").foregroundStyle(.quiet)
            Toggle("本次停课", isOn: value.cancelled)
            if !value.wrappedValue.cancelled {
                DateField(title: "改到日期", value: value.targetDay)
                HStack { Stepper("开始 \(value.wrappedValue.startPeriod) 节", value: value.startPeriod, in: 1...20); Stepper("结束 \(value.wrappedValue.endPeriod) 节", value: value.endPeriod, in: 1...20) }
                Field(label: "地点", value: value.location)
            }
            Text("只调整这一次上课，其他教学周保持不变。").font(.callout).foregroundStyle(.quiet)
        } save: { value, state in
            guard let i = state.courses.firstIndex(where: { $0.id == occurrence.courseID }) else { throw AppError("课程已不存在。") }
            state.courses[i].exceptions.removeAll { $0.originalDay == occurrence.originalDay }
            state.courses[i].exceptions.append(value)
        }
    }
}

struct CourseImportSheet: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) var dismiss
    @State private var courses: [Course] = []
    @State private var replace = false
    @State private var policy: DuplicatePolicy = .skip
    @State private var error: String?
    @State private var filename = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("导入你的课程表").font(.title2.weight(.semibold))
            Text("把课表截图发给助手，核对识别结果后，在这里导入整理好的 CSV 文件。").font(.callout).foregroundStyle(.quiet)
            HStack {
                Button("选择 CSV 文件") {
                    Task {
                    guard let url = await FilePanels.open(extensions: ["csv"]), let semester = store.data.semester else { return }
                    do { let parsed = try CourseImport.parse(String(contentsOf: url, encoding: .utf8), semester: semester); courses = parsed; filename = url.lastPathComponent; error = nil }
                    catch { self.error = error.localizedDescription; courses = [] }
                    }
                }.buttonStyle(.borderedProminent).accessibilityIdentifier("choose-csv")
                Button("导出格式模板") {
                    Task {
                    guard let url = await FilePanels.save(name: "课表模板.csv") else { return }
                    do { try CourseImport.template.write(to: url, atomically: true, encoding: .utf8) } catch { self.error = error.localizedDescription }
                    }
                }
                Text(filename).font(.caption).foregroundStyle(.quiet)
            }
            if let error { Text(error).foregroundStyle(.red) }
            if !courses.isEmpty {
                Toggle("替换当前学期全部课程（自动创建恢复点）", isOn: $replace)
                Picker("重复记录", selection: $policy) { ForEach(DuplicatePolicy.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                Text("预览 · \(courses.count) 条安排，确认前不会修改课表").font(.headline)
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach($courses) { $course in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack { TextField("课程", text: $course.name); TextField("地点", text: $course.location) }.textFieldStyle(.roundedBorder)
                                HStack {
                                    Picker("星期", selection: $course.weekday) { ForEach(1...7, id: \.self) { Text("\($0)").tag($0) } }.frame(width: 100)
                                    Stepper("\(course.startPeriod)—\(course.endPeriod) 节", value: $course.startPeriod, in: 1...20)
                                    Stepper("结束 \(course.endPeriod)", value: $course.endPeriod, in: 1...20)
                                }
                                HStack { TextField("周次", text: $course.weeks).textFieldStyle(.roundedBorder); Picker("规则", selection: $course.pattern) { ForEach(WeekPattern.allCases, id: \.self) { Text($0.rawValue).tag($0) } } }
                                Text("星期 \(course.weekday) · \(course.startPeriod)—\(course.endPeriod) 节 · \(course.weeks) 周 · \(course.pattern.rawValue)").font(.caption).foregroundStyle(.quiet)
                                if let s = store.data.semester, let weeks = try? course.validWeeks(max: s.weekCount) {
                                    Text("日期：" + weeks.sorted().prefix(5).map { Day.add(s.start, days: ($0 - 1) * 7 + course.weekday - 1) }.joined(separator: "、") + (weeks.count > 5 ? "…" : "")).font(.caption2).foregroundStyle(.quiet)
                                }
                            }
                            Divider()
                        }
                    }
                }
            } else { Spacer(); Image(systemName: "doc.badge.arrow.up").font(.system(size: 50, weight: .ultraLight)).frame(maxWidth: .infinity).foregroundStyle(.quiet); Spacer() }
            HStack {
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("确认导入") {
                    do {
                        if replace { _ = try store.disk?.backup(reason: "before-import") }
                        try store.commit { $0.courses = CourseImport.merge(courses, existing: $0.courses, replace: replace, policy: policy) }
                        dismiss()
                    } catch { self.error = error.localizedDescription }
                }.buttonStyle(.borderedProminent).disabled(courses.isEmpty).accessibilityIdentifier("confirm-import")
            }
        }.padding(28).frame(width: 700, height: 640)
    }
}
