import SwiftUI
import CampusCore

struct Glass: ViewModifier {
    @Environment(AppStore.self) var store
    @Environment(\.accessibilityReduceTransparency) var systemReduceTransparency
    var padding: CGFloat = 22
    func body(content: Content) -> some View {
        content.frame(maxWidth: .infinity, alignment: .leading).padding(padding)
            .background(store.data.preferences.reduceTransparency || systemReduceTransparency ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor)) : AnyShapeStyle(.ultraThinMaterial), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.15), lineWidth: 0.7))
            .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
    }
}
extension View { func glass(_ padding: CGFloat = 22) -> some View { modifier(Glass(padding: padding)) } }

struct PageTitle: View {
    var eyebrow: String
    var title: String
    var subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(eyebrow.uppercased()).font(.system(size: 11, weight: .semibold, design: .rounded)).tracking(2.5).foregroundStyle(.quiet)
            Text(title).font(.system(size: 32, weight: .semibold, design: .rounded))
            Text(subtitle).font(.system(size: 13)).foregroundStyle(.quiet)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 8)
    }
}
struct EmptyCard: View {
    var icon: String; var title: String; var detail: String
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon).font(.system(size: 35, weight: .light)).foregroundStyle(.quiet)
            Text(title).font(.title3.weight(.medium))
            Text(detail).font(.callout).foregroundStyle(.quiet).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 44).glass()
    }
}
struct Field: View {
    var label: String
    @Binding var value: String
    var prompt = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).font(.caption).foregroundStyle(.quiet)
            TextField(prompt, text: $value).textFieldStyle(.roundedBorder).accessibilityLabel(label).accessibilityIdentifier("field-\(label)")
        }
    }
}
struct DateField: View {
    var title: String; @Binding var value: String
    var body: some View { Field(label: title, value: $value, prompt: "YYYY-MM-DD") }
}
struct Stat: View {
    var title: String; var value: String; var suffix = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.caption).foregroundStyle(.quiet)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value).font(.system(size: 30, weight: .medium, design: .rounded)).monospacedDigit()
                Text(suffix).font(.caption).foregroundStyle(.quiet)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).glass()
    }
}

struct EditorSheet<Value: Codable & Equatable, Content: View>: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) var dismiss
    @State private var value: Value
    @State private var error: String?
    @State private var completed = false
    @State private var loaded = false
    let title: String
    let key: String
    let content: (Binding<Value>) -> Content
    let save: (Value, inout Workspace) throws -> Void
    init(title: String, key: String, initial: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content, save: @escaping (Value, inout Workspace) throws -> Void) {
        self.title = title; self.key = key; _value = State(initialValue: initial); self.content = content; self.save = save
    }
    private func submit() {
        NSApp.keyWindow?.makeFirstResponder(nil)
        do {
            try store.commit { state in try save(value, &state); state.drafts.removeValue(forKey: key) }
            completed = true; dismiss()
        } catch { self.error = error.localizedDescription }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Text(title).font(.title2.weight(.semibold)); Spacer(); Button { dismiss() } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).keyboardShortcut(.cancelAction).help("关闭并保留草稿").accessibilityIdentifier("editor-close") }.padding(24)
            Divider()
            ScrollView { VStack(alignment: .leading, spacing: 18) { content($value) }.padding(24) }
            Divider()
            if let error { Text(error).font(.callout).foregroundStyle(.red).padding(.horizontal, 24).padding(.top, 12) }
            HStack {
                Text("编辑内容会保存为草稿；确认后生效").font(.caption).foregroundStyle(.quiet)
                Spacer()
                Button("丢弃草稿") {
                    do { try store.commit { $0.drafts.removeValue(forKey: key) }; completed = true; dismiss() }
                    catch { self.error = error.localizedDescription }
                }
                Button("保存", action: submit).buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).accessibilityIdentifier("editor-save")
            }.padding(24)
        }.frame(width: 620, height: 640)
            .onAppear { if !loaded { value = store.draft(key, fallback: value); loaded = true } }
            .task(id: value) {
                do { try await Task.sleep(for: .milliseconds(750)); if loaded && !completed { store.saveDraft(key, value: value) } } catch { }
            }
            .onDisappear { if loaded && !completed { store.saveDraft(key, value: value) } }
            .onReceive(NotificationCenter.default.publisher(for: .saveWorkspace)) { _ in submit() }
            .onReceive(NotificationCenter.default.publisher(for: .flushDraft)) { _ in if loaded && !completed { store.saveDraft(key, value: value) } }
    }
}

enum FilePanels {
    @MainActor private static var busy = false
    @MainActor static func open(extensions: [String]) async -> URL? {
        guard !busy else { return nil }; busy = true; defer { busy = false }
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.allowedContentTypes = extensions.compactMap { UTType(filenameExtension: $0) }
        return await withCheckedContinuation { continuation in
            panel.begin { response in continuation.resume(returning: response == .OK ? panel.url : nil) }
        }
    }
    @MainActor static func save(name: String) async -> URL? {
        guard !busy else { return nil }; busy = true; defer { busy = false }
        let panel = NSSavePanel(); panel.nameFieldStringValue = name
        return await withCheckedContinuation { continuation in
            panel.begin { response in continuation.resume(returning: response == .OK ? panel.url : nil) }
        }
    }
}
import UniformTypeIdentifiers

struct QuietStyle: ShapeStyle {
    func resolve(in environment: EnvironmentValues) -> Color {
        environment.colorScheme == .dark ? Color.white.opacity(0.78) : Color(red: 0.20, green: 0.27, blue: 0.34)
    }
}
extension ShapeStyle where Self == QuietStyle { static var quiet: QuietStyle { QuietStyle() } }
