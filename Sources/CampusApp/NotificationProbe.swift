import AppKit
import UserNotifications
import CampusCore

@MainActor enum NotificationProbe {
    static func run(delegate: DesktopDelegate) async {
        let center = UNUserNotificationCenter.current()
        let permission = await center.notificationSettings()
        var report = "Permission: \(permission.authorizationStatus.rawValue)\n"
        do {
            guard permission.authorizationStatus == .authorized else { throw AppError("Notification authorization is not enabled; real delivery remains pending.") }
            var state = Workspace()
            var workout = ScheduledWorkout(); workout.name = "后台提醒验证"; workout.date = Day.today(zone: "Asia/Shanghai")
            let target = Date().addingTimeInterval(120)
            let formatter = DateFormatter(); formatter.timeZone = TimeZone(identifier: "Asia/Shanghai"); formatter.dateFormat = "HH:mm"
            workout.date = Day.string(target, zone: "Asia/Shanghai"); workout.time = formatter.string(from: target)
            state.trainingSchedule = [workout]; state.preferences.reminderMinutes = 2; state.preferences.notifications = true
            delegate.window.performClose(nil)
            try delegate.store.commit { $0 = state }
            try await Task.sleep(for: .seconds(3))
            let delivered = await center.deliveredNotifications()
            let matched = delivered.contains { ($0.request.content.userInfo["target"] as? String) == workout.id.uuidString }
            report += "Main window hidden: \(!delegate.window.isVisible)\n"
            report += "macOS notification center confirms delivery for test workout: \(matched)\n"
            report += "Persisted notification deduplication records: \(delegate.store.data.deliveredReminders.count)\n"
            report += "Visible banner appearance depends on notification style and Focus settings; not asserted by this probe.\n"
            center.removeDeliveredNotifications(withIdentifiers: delivered.filter { ($0.request.content.userInfo["target"] as? String) == workout.id.uuidString }.map { $0.request.identifier })
        } catch { report += "NOT VERIFIED: \(error.localizedDescription)\n" }
        try? report.write(to: delegate.store.directory.appendingPathComponent("notification-delivery.txt"), atomically: true, encoding: .utf8)
        NSApp.terminate(nil)
    }
}
