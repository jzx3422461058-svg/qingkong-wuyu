import SwiftUI
import CampusCore

struct HomeView: View {
    @Environment(AppStore.self) var store
    @Environment(\.accessibilityReduceMotion) var systemReduceMotion
    @State private var now = Date()
    private var zone: String { store.data.semester?.timeZone ?? "Asia/Shanghai" }
    private var today: String { Day.string(now, zone: zone) }
    private var agenda: [AgendaItem] { Overview.agenda(store.data, day: today) }
    private var next: AgendaItem? { agenda.first { !$0.completed && $0.end >= now } }
    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    PageTitle(eyebrow: "MAKE ROOM FOR WHAT MATTERS", title: greeting, subtitle: "在自己的节奏里，把今天过得清楚一点。")
                    VStack(alignment: .trailing, spacing: 7) {
                        Text(dateLabel).font(.callout.weight(.medium))
                        Text(store.data.semester.flatMap { $0.week(on: today) }.map { "第 \($0) 教学周" } ?? "今天，自由安排").font(.caption).foregroundStyle(.quiet)
                    }.padding(.top, 16)
                }
                HStack(spacing: 22) {
                    GeometryReader { geometry in
                        let scale = min(geometry.size.width / 500, 1)
                        ZStack {
                            orbit(.reading, size: 116, x: 100, y: 216, scale: scale)
                            orbit(.courses, size: 130, x: 193, y: 72, scale: scale)
                            orbit(.goals, size: 112, x: 345, y: 85, scale: scale)
                            orbit(.activities, size: 112, x: 420, y: 224, scale: scale)
                            orbit(.settings, size: 100, x: 351, y: 359, scale: scale)
                            orbit(.fitness, size: 138, x: 190, y: 360, scale: scale)
                            OrbButton(module: .home, size: 158 * scale, subtitle: "\(agenda.count) 项今日安排", today: String(today.suffix(2))) {
                                withAnimation(systemReduceMotion || store.data.preferences.reduceMotion ? nil : .easeInOut(duration: 0.25)) { proxy.scrollTo("agenda", anchor: .top) }
                            }.position(x: 264 * scale, y: 218 * scale)
                        }.frame(width: 500 * scale, height: 440 * scale)
                    }.frame(minWidth: 380, maxWidth: 520).frame(height: 430)
                    VStack(alignment: .leading, spacing: 22) {
                        Text("接 下 来").font(.caption.weight(.medium)).tracking(2).foregroundStyle(.quiet)
                        if let next {
                            Image(systemName: Module.code(next.module).icon).font(.system(size: 30, weight: .light)).foregroundStyle(Module.code(next.module).tint)
                            Text(next.title).font(.system(size: 23, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                            Text(time(next.start)).font(.system(size: 34, weight: .light, design: .rounded)).monospacedDigit()
                            Text(next.detail).font(.callout).foregroundStyle(.quiet)
                            Button("查看安排", systemImage: "arrow.up.right") { navigate(next) }.buttonStyle(.bordered)
                        } else {
                            Image(systemName: "sun.horizon").font(.system(size: 38, weight: .ultraLight)).foregroundStyle(.orange)
                            Text("留一点空白\n给自己。").font(.system(size: 26, weight: .light)).lineSpacing(6)
                            Text("今天没有接下来的安排。\n从左侧圆形入口开始规划。 ").font(.callout).foregroundStyle(.quiet).lineSpacing(4)
                        }
                        Spacer(minLength: 0)
                        Divider()
                        HStack { Label("本地空间", systemImage: "internaldrive"); Spacer(); Image(systemName: "checkmark.shield") }.font(.caption).foregroundStyle(.quiet)
                    }.frame(minHeight: 310, alignment: .topLeading).glass(24).frame(width: 290)
                    Spacer(minLength: 0)
                }
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack { Text("今日时间线").font(.headline); Spacer(); Text("\(agenda.count) 项").font(.caption).foregroundStyle(.quiet) }
                        if agenda.isEmpty { Text("还没有安排。添加课程、训练或活动后，会自动汇总到这里。").font(.callout).foregroundStyle(.quiet).padding(.vertical, 25) }
                        ForEach(agenda) { item in
                            Button { navigate(item) } label: {
                                HStack(alignment: .top, spacing: 14) {
                                    Text(time(item.start)).font(.system(size: 12, weight: .medium, design: .rounded)).monospacedDigit().frame(width: 48, alignment: .leading).foregroundStyle(.quiet)
                                    RoundedRectangle(cornerRadius: 2).fill(Module.code(item.module).tint).frame(width: 3, height: 36)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(item.title).font(.callout.weight(.medium)).strikethrough(item.completed)
                                        Text(item.detail).font(.caption).foregroundStyle(.quiet)
                                        if Overview.overlaps(item, items: agenda) { Label("与其他安排重叠", systemImage: "exclamationmark.circle").font(.caption2).foregroundStyle(.orange) }
                                    }
                                    Spacer()
                                    Image(systemName: item.completed ? "checkmark.circle.fill" : "chevron.right").font(.caption).foregroundStyle(item.completed ? Color.mint : Color.secondary)
                                }.padding(.vertical, 8).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                    }.glass().id("agenda")
                    VStack(alignment: .leading, spacing: 20) {
                        Text("把目光放远一点").font(.headline)
                        let goals = store.data.goals.filter { $0.status == .active }
                        if goals.isEmpty { Text("建立一个长期目标，再把它拆成可执行的小步骤。").font(.callout).foregroundStyle(.quiet); Button("建立我的目标") { store.module = .goals } }
                        ForEach(goals.prefix(3)) { goal in
                            Button { store.focusID = goal.id; store.module = .goals } label: {
                                VStack(alignment: .leading, spacing: 9) { HStack { Text(goal.title).font(.callout.weight(.medium)); Spacer(); Text(goal.actionProgress.map { "\(Int($0 * 100))%" } ?? "待拆解").font(.caption).foregroundStyle(.quiet) }; ProgressView(value: goal.actionProgress ?? 0).tint(.orange) }
                            }.buttonStyle(.plain)
                        }
                        let upcoming = Overview.upcoming(store.data, today: today)
                        if !upcoming.isEmpty {
                            Divider(); Text("近期截止").font(.caption).foregroundStyle(.quiet)
                            ForEach(upcoming.prefix(4), id: \.action.id) { entry in
                                Button { store.focusID = entry.goal.id; store.module = .goals } label: {
                                    HStack { Text(entry.action.title).font(.caption); Spacer(); Text(entry.action.due < today ? "已逾期" : String(entry.action.due.suffix(5))).font(.caption).foregroundStyle(entry.action.due < today ? Color.orange : Color.secondary) }
                                }.buttonStyle(.plain)
                            }
                        }
                    }.frame(maxWidth: 340).glass()
                }
            }
        }.onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { if store.module == .home && NSApp.windows.contains(where: \.isVisible) { now = $0 } }
            .onChange(of: store.module) { _, module in if module == .home { now = Date() } }
    }
    private func orbit(_ module: Module, size: CGFloat, x: CGFloat, y: CGFloat, scale: CGFloat) -> some View {
        OrbButton(module: module, size: size * scale, subtitle: "", today: nil) { store.module = module }.position(x: x * scale, y: y * scale)
    }
    private func navigate(_ item: AgendaItem) { store.focusID = item.targetID; store.module = Module.code(item.module) }
    private func time(_ date: Date) -> String { let f = DateFormatter(); f.timeZone = TimeZone(identifier: zone); f.dateFormat = "HH:mm"; return f.string(from: date) }
    private var greeting: String {
        var c = Calendar.current; c.timeZone = TimeZone(identifier: zone)!
        switch c.component(.hour, from: now) { case 5..<11: return "早上好，新的开始。"; case 11..<14: return "中午好，慢一点也好。"; case 14..<18: return "下午好，继续向前。"; default: return "晚上好，回到自己的节奏。" }
    }
    private var dateLabel: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.timeZone = TimeZone(identifier: zone); f.dateFormat = "M月d日 EEEE"; return f.string(from: now)
    }
}

struct OrbButton: View {
    @Environment(AppStore.self) var store
    @Environment(\.accessibilityReduceMotion) var systemReduceMotion
    @Environment(\.accessibilityReduceTransparency) var systemReduceTransparency
    @Environment(\.colorScheme) var scheme
    @State private var hovered = false
    var module: Module; var size: CGFloat; var subtitle: String; var today: String?
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if let today { Text(today).font(.system(size: size * 0.29, weight: .ultraLight, design: .rounded)).monospacedDigit() }
                else { Image(systemName: module.icon).font(.system(size: size * 0.26, weight: .light)).symbolRenderingMode(.hierarchical) }
                Text(module.rawValue).font(.system(size: 12, weight: .medium))
                if !subtitle.isEmpty { Text(subtitle).font(.system(size: 9)).foregroundStyle(.quiet) }
            }.frame(width: size, height: size)
                .background(store.data.preferences.reduceTransparency || systemReduceTransparency ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor)) : AnyShapeStyle(.ultraThinMaterial), in: Circle())
                .background(Circle().fill(module.tint.opacity(scheme == .dark ? 0.23 : 0.13)))
                .overlay(Circle().strokeBorder(LinearGradient(colors: [.white.opacity(hovered ? 0.7 : 0.38), module.tint.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                .shadow(color: module.tint.opacity(hovered ? 0.2 : 0.07), radius: hovered ? 22 : 12, y: 8)
                .contentShape(Circle())
        }.buttonStyle(OrbPress(reduce: systemReduceMotion || store.data.preferences.reduceMotion))
            .scaleEffect(hovered ? 1.045 : 1)
            .animation(systemReduceMotion || store.data.preferences.reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82), value: hovered)
            .onHover { hovered = $0 }.help("打开\(module.rawValue)")
            .accessibilityLabel(module.rawValue).accessibilityIdentifier("orbit-\(module.code)")
    }
}
struct OrbPress: ButtonStyle {
    var reduce: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.96 : 1).brightness(configuration.isPressed ? -0.03 : 0)
            .animation(reduce ? nil : .easeOut(duration: 0.13), value: configuration.isPressed)
    }
}
