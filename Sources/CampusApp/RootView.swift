import SwiftUI
import CampusCore

struct RootView: View {
    @Environment(AppStore.self) var store
    @Environment(\.accessibilityReduceMotion) var systemReduceMotion
    @Environment(\.accessibilityReduceTransparency) var systemReduceTransparency
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var notifications: NotificationService
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                if let sky = Assets.sky {
                    Image(nsImage: sky).resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height).clipped()
                }
                LinearGradient(colors: colorScheme == .dark ? [Color(red: 0.04, green: 0.13, blue: 0.24).opacity(0.42), Color(red: 0.08, green: 0.14, blue: 0.25).opacity(0.72)] : [.white.opacity(0.35), Color(red: 0.75, green: 0.85, blue: 0.93).opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }.ignoresSafeArea()
            HStack(spacing: 0) {
                sidebar
                VStack(spacing: 0) {
                    HStack {
                        Text("个人空间").font(.caption).foregroundStyle(.quiet)
                        Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(.tertiary)
                        Text(store.module.rawValue).font(.caption)
                        Spacer()
                        Button { store.saveNow() } label: {
                            Label(store.saveFailed ? "保存失败 · 重试" : "已保存到本机", systemImage: store.saveFailed ? "exclamationmark.icloud" : "checkmark.circle")
                                .font(.caption).foregroundStyle(store.saveFailed ? Color.orange : Color.secondary)
                        }.buttonStyle(.plain).help(store.savedAt.map { "最近保存：\($0.formatted(date: .omitted, time: .standard)) · 点击立即保存" } ?? "立即保存")
                    }.padding(.horizontal, 30).padding(.top, 24).padding(.bottom, 22)
                    ModuleContainer(module: store.module, store: store, notifications: notifications,
                                    reduceMotion: systemReduceMotion || store.data.preferences.reduceMotion)
                }
            }
        }
        .frame(minWidth: 1060, minHeight: 720)
        .preferredColorScheme(store.data.preferences.theme == "深色" ? .dark : store.data.preferences.theme == "浅色" ? .light : nil)
        .alert("操作未完成", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("知道了") { store.error = nil } } message: { Text(store.error ?? "") }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage).resizable().scaledToFit().frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 3) { Text("晴空物语").font(.system(size: 20, weight: .semibold, design: .rounded)); Text("A SKY FULL OF STORIES").font(.system(size: 7, weight: .medium)).tracking(1.1).foregroundStyle(.quiet) }
            }.padding(.horizontal, 24).padding(.top, 45).padding(.bottom, 42)
            Text("我的日常").font(.system(size: 10, weight: .semibold)).tracking(2).foregroundStyle(.quiet).padding(.horizontal, 28).padding(.bottom, 14)
            ForEach(Module.allCases) { module in
                Button { store.module = module } label: {
                    SidebarItem(module: module, selected: store.module == module)
                }.buttonStyle(.plain).padding(.horizontal, 14).padding(.bottom, 4).accessibilityIdentifier("nav-\(module.code)")
            }
            Spacer()
            VStack(alignment: .leading, spacing: 7) {
                Label("只属于你的空间", systemImage: "internaldrive").font(.caption.weight(.medium))
                Text("本地保存 · 无需联网").font(.system(size: 10)).foregroundStyle(.quiet)
            }.padding(22)
        }.frame(width: 205)
            .background(store.data.preferences.reduceTransparency || systemReduceTransparency ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor)) : AnyShapeStyle(.ultraThinMaterial))
            .overlay(alignment: .trailing) { Rectangle().fill(.white.opacity(0.12)).frame(width: 0.5) }
    }
}

private struct ModulePage: View {
    let module: Module
    var body: some View {
        ScrollView {
            Group {
                switch module {
                case .courses: CourseView()
                case .fitness: FitnessView()
                case .goals: GoalsView()
                case .activities: ActivitiesView()
                case .reading: ReadingView()
                case .settings: SettingsView()
                case .home: HomeView()
                }
            }.padding(.horizontal, 30).padding(.bottom, 30)
        }
    }
}

struct SidebarItem: View {
    var module: Module
    var selected: Bool
    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: module.icon).font(.system(size: 16)).frame(width: 22).foregroundStyle(selected ? module.tint : Color.secondary)
            Text(module.rawValue).font(.system(size: 13, weight: selected ? .semibold : .regular))
            Spacer()
            if selected { Circle().fill(module.tint).frame(width: 5, height: 5) }
        }.padding(.horizontal, 15).padding(.vertical, 14)
            .background(selected ? Color.primary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 15))
            .contentShape(Rectangle())
    }
}

/// Retain each native scroll view while attaching only the visible page to the render tree.
/// Opacity-only hiding keeps all material layers participating in SwiftUI layout/compositing.
private struct ModuleContainer: NSViewControllerRepresentable {
    var module: Module
    var store: AppStore
    var notifications: NotificationService
    var reduceMotion: Bool
    func makeNSViewController(context: Context) -> PageController { PageController() }
    func updateNSViewController(_ controller: PageController, context: Context) {
        controller.show(module, store: store, notifications: notifications, reduceMotion: reduceMotion)
    }

    final class PageController: NSViewController {
        private var pages: [Module: NSHostingController<AnyView>] = [:]
        private var current: Module?
        override func loadView() { view = NSView(); view.wantsLayer = true }
        func show(_ module: Module, store: AppStore, notifications: NotificationService, reduceMotion: Bool) {
            let appearance: NSAppearance.Name? = store.data.preferences.theme == "深色" ? .darkAqua : store.data.preferences.theme == "浅色" ? .aqua : nil
            if view.appearance?.name != appearance { view.appearance = appearance.flatMap(NSAppearance.init(named:)) }
            guard current != module else { return }
            let hadPage = current != nil
            if let current, let previous = pages[current] {
                previous.view.layer?.removeAllAnimations()
                previous.view.removeFromSuperview()
            }
            let page: NSHostingController<AnyView>
            if let cached = pages[module] { page = cached }
            else {
                page = NSHostingController(rootView: AnyView(ModulePage(module: module).environment(store).environmentObject(notifications)))
                page.sizingOptions = []
                pages[module] = page
                addChild(page)
            }
            current = module
            let content = page.view
            content.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(content)
            NSLayoutConstraint.activate([
                content.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                content.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                content.topAnchor.constraint(equalTo: view.topAnchor),
                content.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            content.alphaValue = 1
            if hadPage && !reduceMotion {
                // Animate the incoming page only; no stack of outgoing frosted-glass surfaces.
                let fade = CABasicAnimation(keyPath: "opacity")
                fade.fromValue = 0; fade.toValue = 1; fade.duration = 0.24
                fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
                content.wantsLayer = true
                content.layer?.add(fade, forKey: "module-arrival")
            }
        }
    }
}
