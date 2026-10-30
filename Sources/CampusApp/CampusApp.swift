import SwiftUI

@main struct CampusApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = DesktopDelegate()
        app.delegate = delegate
        app.run()
    }
}

@MainActor final class DesktopDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let store = AppStore()
    var window: NSWindow!
    var statusItem: NSStatusItem?
    var notifications: NotificationService!
    var probe: RuntimeProbe?
    func applicationDidFinishLaunching(_ notification: Notification) {
        if !QA.enabled, let other = NSRunningApplication.runningApplications(withBundleIdentifier: "local.qingyu.campus").first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            other.activate(); NSApp.terminate(nil); return
        }
        buildMenu()
        QA.prepare(store)
        notifications = NotificationService(store: store)
        notifications.reveal = { [weak self] in self?.showWindow() }
        notifications.start()
        if QA.enabled && ProcessInfo.processInfo.arguments.contains("--test-notification") {
            Task { await notifications.testNotification(); QA.reportNotificationStatus(notifications, store: store) }
        }
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 850), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "晴空物语"; window.titleVisibility = .hidden; window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false; window.delegate = self; window.minSize = NSSize(width: 1060, height: 720)
        window.contentViewController = NSHostingController(rootView: LaunchView().environment(store).environmentObject(notifications))
        window.center(); window.setFrameAutosaveName("QingyuMainWindow"); showWindow()
        if QA.enabled && ProcessInfo.processInfo.arguments.contains("--minimum-window") { window.setContentSize(NSSize(width: 1060, height: 720)) }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "cloud.sun", accessibilityDescription: "晴空物语")
        let menu = NSMenu(); menu.addItem(withTitle: "打开晴空物语", action: #selector(showWindow), keyEquivalent: "").target = self
        menu.addItem(.separator()); menu.addItem(withTitle: "退出晴空物语", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem?.menu = menu
        QA.captureIfRequested()
        if QA.enabled && ProcessInfo.processInfo.arguments.contains("--runtime-check") {
            probe = RuntimeProbe()
            Task { await probe?.run(delegate: self) }
        }
        if QA.enabled && ProcessInfo.processInfo.arguments.contains("--notification-check") {
            Task { await NotificationProbe.run(delegate: self) }
        }
    }
    @objc func showWindow() { window?.makeKeyAndOrderFront(nil); NSApp.activate() }
    @objc func save() { store.saveNow(); NotificationCenter.default.post(name: .saveWorkspace, object: nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NotificationCenter.default.post(name: .flushDraft, object: nil)
        return !store.saveFailed
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if store.bootError != nil { return .terminateNow }
        NotificationCenter.default.post(name: .flushDraft, object: nil)
        if store.saveFailed { return .terminateCancel }
        store.saveNow(); return store.saveFailed ? .terminateCancel : .terminateNow
    }
    private func buildMenu() {
        let bar = NSMenu()
        let appItem = NSMenuItem(); let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于晴空物语", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator()); appMenu.addItem(withTitle: "隐藏晴空物语", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "退出晴空物语", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu; bar.addItem(appItem)
        let fileItem = NSMenuItem(); let file = NSMenu(title: "文件")
        file.addItem(withTitle: "立即保存", action: #selector(save), keyEquivalent: "s").target = self
        file.addItem(withTitle: "打开主窗口", action: #selector(showWindow), keyEquivalent: "0").target = self
        file.addItem(withTitle: "关闭窗口（后台运行）", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileItem.submenu = file; bar.addItem(fileItem)
        let editItem = NSMenuItem(); let edit = NSMenu(title: "编辑")
        for (name, selector, key) in [("撤销", "undo:", "z"), ("剪切", "cut:", "x"), ("复制", "copy:", "c"), ("粘贴", "paste:", "v"), ("全选", "selectAll:", "a")] {
            edit.addItem(withTitle: name, action: Selector(selector), keyEquivalent: key)
        }
        editItem.submenu = edit; bar.addItem(editItem); NSApp.mainMenu = bar
    }
}

struct LaunchView: View {
    @Environment(AppStore.self) var store
    @State private var recoveryError: String?
    var body: some View {
        if let error = store.bootError {
            VStack(spacing: 20) {
                Text("数据未能安全加载").font(.title); Text(error); Text("原文件已保留，请通过备份恢复。")
                Button("打开数据目录") { NSWorkspace.shared.open(store.directory) }
                Button("选择备份恢复") {
                    Task {
                    guard let url = await FilePanels.open(extensions: ["campusbackup", "json"]) else { return }
                    do { try store.restore(Data(contentsOf: url)) } catch { recoveryError = error.localizedDescription }
                    }
                }
                if let recoveryError { Text(recoveryError).foregroundStyle(.red) }
            }.padding(40).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else { RootView() }
    }
}
