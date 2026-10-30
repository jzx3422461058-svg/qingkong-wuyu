import Foundation
import AppKit
import UserNotifications
import CampusCore

@MainActor final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var status = "尚未检查"
    @Published var lastError: String?
    private let store: AppStore
    private let center = UNUserNotificationCenter.current()
    private var timer: Timer?
    private var task: Task<Void, Never>?
    private var checking = false
    private(set) var checkCount = 0
    var reveal: (() -> Void)?
    init(store: AppStore) { self.store = store; super.init(); center.delegate = self }
    func start() {
        store.afterCommit = { [weak self] in self?.scheduleRefresh() }
        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in Task { @MainActor in await self?.check() } }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in await self?.check() } }
        scheduleRefresh()
    }
    func scheduleRefresh() {
        task?.cancel()
        task = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(350)); await self?.check() } catch { }
        }
    }
    func authorize() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted { store.act { $0.preferences.notifications = true } }
            else { lastError = "通知权限未开启。可在系统设置 → 通知 → 晴空物语中允许通知。" }
            await check()
        } catch { lastError = error.localizedDescription }
    }
    func testNotification() async {
        await authorize()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }
        let content = UNMutableNotificationContent(); content.title = "晴空物语 · 提醒已就绪"; content.body = "这是一条本地测试通知。关闭窗口后，后台提醒仍会工作。"; content.sound = .default
        do { try await center.add(UNNotificationRequest(identifier: "qingyu-test", content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false))) }
        catch { lastError = error.localizedDescription }
    }
    func check() async {
        guard !checking else { return }; checking = true; defer { checking = false }
        checkCount += 1
        let settings = await center.notificationSettings()
        status = switch settings.authorizationStatus { case .authorized: "已允许系统通知"; case .denied: "系统通知被关闭"; case .notDetermined: "尚未授权"; default: "受系统限制" }
        guard store.bootError == nil, store.data.preferences.notifications, settings.authorizationStatus == .authorized else { return }
        let now = Date()
        let due = ReminderEngine.reminders(store.data, now: now).filter { $0.fire <= now }
        guard !due.isEmpty else { return }
        let content = UNMutableNotificationContent(); content.sound = .default
        if due.count == 1, let r = due.first {
            content.title = r.title; content.body = r.body
            content.userInfo = ["module": r.module, "target": r.targetID.uuidString]
        } else {
            content.title = "有 \(due.count) 项安排需要留意"
            content.body = due.prefix(3).map(\.title).joined(separator: "；")
            content.userInfo = ["module": "home"]
        }
        // No future requests are cached in the OS: current source data is checked every 20s,
        // so edits and deletes immediately invalidate old schedules while the window is hidden.
        do {
            try await center.add(UNNotificationRequest(identifier: "qingyu-" + due.map(\.id).joined(separator: "-"), content: content, trigger: nil))
            try store.commit { state in
                for r in due { state.deliveredReminders[r.id] = now }
                state.deliveredReminders = state.deliveredReminders.filter { $0.value > now.addingTimeInterval(-30 * 86400) }
            }
        } catch { lastError = "提醒未完成：" + error.localizedDescription }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .sound, .list] }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let module = response.notification.request.content.userInfo["module"] as? String
        let target = response.notification.request.content.userInfo["target"] as? String
        await MainActor.run {
            self.store.module = Module.code(module ?? "home")
            self.store.focusID = target.flatMap(UUID.init(uuidString:))
            self.reveal?()
        }
    }
}
