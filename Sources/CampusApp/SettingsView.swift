import SwiftUI
import ServiceManagement
import CampusCore

struct SettingsView: View {
    @Environment(AppStore.self) var store
    @EnvironmentObject var notifications: NotificationService
    @State private var backups: [URL] = []
    @State private var message: String?
    @State private var restoreBytes: Data?
    @State private var restoreSummary = ""
    @State private var showRestore = false
    @State private var showClear = false
    @State private var clearText = ""
    @State private var loginEnabled = SMAppService.mainApp.status == .enabled
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageTitle(eyebrow: "YOURS, AND ONLY YOURS", title: "数据与设置", subtitle: "所有记录都在这台 Mac 上，由你掌握。")
            if let message { Label(message, systemImage: "checkmark.circle").font(.callout).foregroundStyle(.mint) }
            VStack(alignment: .leading, spacing: 18) {
                Label("本地数据", systemImage: "internaldrive").font(.headline)
                Text(store.data.recordSummary).font(.callout).foregroundStyle(.quiet)
                Text(store.directory.path).font(.system(size: 11, design: .monospaced)).textSelection(.enabled).foregroundStyle(.quiet)
                HStack {
                    Button("立即保存", systemImage: "square.and.arrow.down") { store.saveNow(); message = store.saveFailed ? nil : "已保存到本机" }
                    Button("打开数据目录") { NSWorkspace.shared.open(store.directory) }
                    Button("导出全部数据") { Task { await exportData() } }
                    Button("导入恢复") { Task { if let url = await FilePanels.open(extensions: ["campusbackup", "json"]) { previewRestore(url) } } }
                }
                Text("有效操作立即保存；编辑草稿在停止输入后自动保存。Command+S 可主动保存。自动备份按日保留最近 7 份。").font(.caption).foregroundStyle(.quiet)
            }.glass()
            VStack(alignment: .leading, spacing: 18) {
                HStack { Label("备份与恢复", systemImage: "clock.arrow.circlepath").font(.headline); Spacer(); Button("立即备份") { do { _ = try store.disk?.backup(); reloadBackups(); message = "已创建完整本地备份" } catch { store.error = error.localizedDescription } }.accessibilityIdentifier("backup-now") }
                if backups.isEmpty { Text("还没有备份。保存更新或点击“立即备份”后会出现在这里。").font(.caption).foregroundStyle(.quiet) }
                ForEach(backups.prefix(8), id: \.path) { url in
                    HStack { Text(url.lastPathComponent).font(.system(size: 11, design: .monospaced)).lineLimit(1); Spacer(); Button("预览恢复") { previewRestore(url) }.controlSize(.small) }
                }
                if backups.count > 8 { Button("在 Finder 查看所有 \(backups.count) 份备份") { if let url = store.disk?.backupDirectory { NSWorkspace.shared.open(url) } } }
            }.glass()
            VStack(alignment: .leading, spacing: 18) {
                Label("外观与动效", systemImage: "circle.lefthalf.filled").font(.headline)
                Picker("主题", selection: preference(\.theme)) { ForEach(["跟随系统", "浅色", "深色"], id: \.self) { Text($0).tag($0) } }.pickerStyle(.segmented)
                Toggle("减少动态效果", isOn: preference(\.reduceMotion))
                Toggle("降低透明度，提高内容对比度", isOn: preference(\.reduceTransparency))
                Text("系统的减少动态效果和降低透明度偏好也会受到尊重。").font(.caption).foregroundStyle(.quiet)
            }.glass()
            VStack(alignment: .leading, spacing: 18) {
                Label("本地提醒", systemImage: "bell.badge").font(.headline)
                HStack {
                    Toggle("启用提醒", isOn: Binding(get: { store.data.preferences.notifications }, set: { enabled in
                        if enabled { Task { await notifications.authorize() } } else { store.act { $0.preferences.notifications = false } }
                    }))
                    Spacer(); Text(notifications.status).font(.caption).foregroundStyle(.quiet)
                    Button("发送测试通知") { Task { await notifications.testNotification() } }
                }
                Stepper("课程、训练与行动默认提前 \(store.data.preferences.reminderMinutes) 分钟", value: preference(\.reminderMinutes), in: 0...1440, step: 5)
                HStack {
                    ForEach([Module.courses, .fitness, .goals, .activities]) { module in
                        Toggle(module.rawValue, isOn: Binding(get: { !store.data.preferences.mutedModules.contains(module.code) }, set: { enabled in store.act { state in if enabled { state.preferences.mutedModules.remove(module.code) } else { state.preferences.mutedModules.insert(module.code) } } })).toggleStyle(.checkbox)
                    }
                }
                Text("活动的报名和开始提醒在活动详情中分别设置。关闭窗口后继续在菜单栏运行；完全退出后停止提醒。睡眠期间错过的近一天提醒会在恢复后合并提示。").font(.caption).foregroundStyle(.quiet)
                if let error = notifications.lastError { Text(error).font(.caption).foregroundStyle(.orange) }
                Divider()
                Toggle("登录 Mac 后自动启动", isOn: Binding(get: { loginEnabled }, set: { enabled in
                    do { if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }; loginEnabled = SMAppService.mainApp.status == .enabled }
                    catch { store.error = "无法更改登录启动：" + error.localizedDescription }
                }))
                Text("系统可能要求在“登录项与扩展”中允许。关闭后，重启电脑需打开晴空物语才能继续后台提醒。").font(.caption).foregroundStyle(.quiet)
            }.glass()
            VStack(alignment: .leading, spacing: 18) {
                Label("回收站", systemImage: "trash").font(.headline)
                if store.data.trash.isEmpty { Text("没有删除的记录。").foregroundStyle(.quiet).font(.callout) }
                ForEach(store.data.trash) { item in
                    HStack { Text(item.name); Spacer(); Text(item.removedAt.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.quiet); Button("恢复") { store.act { try $0.restoreTrash(item.id) } } }
                }
            }.glass()
            HStack { Text("晴空物语 1.1 · SwiftUI 原生桌面 · 无网络依赖").font(.caption).foregroundStyle(.quiet); Spacer(); Button("素材来源") { if let url = Assets.bundle.url(forResource: "Assets", withExtension: "md") { NSWorkspace.shared.open(url) } }; Button("清空全部数据", role: .destructive) { showClear = true } }
        }.onAppear { reloadBackups(); Task { await notifications.check() } }
            .onChange(of: store.module) { _, module in if module == .settings { reloadBackups(); Task { await notifications.check() } } }
            .alert("确认恢复这份数据？", isPresented: $showRestore) {
                Button("取消", role: .cancel) { restoreBytes = nil }
                Button("备份当前数据并恢复") {
                    guard let bytes = restoreBytes else { return }
                    do { try store.restore(bytes); message = "已恢复；恢复前的数据已备份"; reloadBackups() } catch { store.error = error.localizedDescription }
                    restoreBytes = nil
                }
            } message: { Text(restoreSummary + "\n当前工作空间会被替换。") }
            .alert("清空所有记录", isPresented: $showClear) {
                TextField("输入 清空", text: $clearText)
                Button("取消", role: .cancel) { clearText = "" }
                Button("备份并清空", role: .destructive) {
                    guard clearText == "清空" else { store.error = "确认文字不匹配，未清空。"; return }
                    do { _ = try store.disk?.backup(reason: "before-clear"); try store.commit { $0 = Workspace() }; reloadBackups(); clearText = "" } catch { store.error = error.localizedDescription }
                }
            } message: { Text("此操作会清空课程、训练、目标、活动、书籍与封面、草稿与回收站；确认前将创建完整备份。") }
    }
    private func preference<T>(_ path: WritableKeyPath<Preferences, T>) -> Binding<T> {
        Binding(get: { store.data.preferences[keyPath: path] }, set: { value in store.act { $0.preferences[keyPath: path] = value } })
    }
    private func reloadBackups() { do { backups = try store.disk?.backups() ?? [] } catch { store.error = error.localizedDescription } }
    private func exportData() async {
        guard let url = await FilePanels.save(name: "晴空物语-\(Day.today()).campusbackup") else { return }
        do { guard let disk = store.disk else { return }; try disk.encode(store.data).write(to: url, options: .atomic); message = "完整数据已导出" } catch { store.error = error.localizedDescription }
    }
    private func previewRestore(_ url: URL) {
        do {
            let bytes = try Data(contentsOf: url)
            guard let value = try store.disk?.decode(bytes) else { throw AppError("本地存储尚未就绪。") }
            restoreSummary = value.recordSummary; restoreBytes = bytes; showRestore = true
        } catch { store.error = error.localizedDescription }
    }
}
