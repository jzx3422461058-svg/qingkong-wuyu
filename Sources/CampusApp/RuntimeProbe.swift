import SwiftUI
import QuartzCore
import CampusCore

/// Only runs with --qa --data-dir --runtime-check; records real main-thread display callbacks.
@MainActor final class RuntimeProbe: NSObject {
    private var link: CADisplayLink?
    private var previous: CFTimeInterval?
    private var intervals: [Double] = []
    @objc private func frame(_ link: CADisplayLink) {
        let now = CACurrentMediaTime()
        if let previous { intervals.append((now - previous) * 1000) }
        previous = now
    }
    func run(delegate: DesktopDelegate) async {
        guard let content = delegate.window.contentView else { return }
        link = content.displayLink(target: self, selector: #selector(frame(_:)))
        link?.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 60, preferred: 60)
        link?.add(to: .main, forMode: .common)
        do {
            try await Task.sleep(for: .seconds(1))
            intervals.removeAll(); previous = nil
            for index in 0..<24 {
                delegate.store.module = Module.allCases[index % Module.allCases.count]
                try await Task.sleep(for: .milliseconds(350))
            }
            link?.invalidate(); link = nil
            let sorted = intervals.sorted()
            let median = sorted.isEmpty ? 0 : sorted[sorted.count / 2]
            let p95 = sorted.isEmpty ? 0 : sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))]
            delegate.store.module = .courses
            try await Task.sleep(for: .milliseconds(350))
            let scroll = findScrollView(content)
            scroll?.contentView.scroll(to: NSPoint(x: 0, y: 180))
            if let scroll { scroll.reflectScrolledClipView(scroll.contentView) }
            let offset = scroll?.contentView.bounds.origin.y ?? 0
            delegate.store.module = .activities
            try await Task.sleep(for: .milliseconds(350))
            delegate.store.module = .courses
            try await Task.sleep(for: .milliseconds(350))
            let restoredOffset = findScrollView(content)?.contentView.bounds.origin.y ?? 0
            let restoredScroll = offset > 0 && abs(offset - restoredOffset) < 1
            let before = delegate.notifications.checkCount
            delegate.window.performClose(nil)
            let hidden = !delegate.window.isVisible
            try await Task.sleep(for: .seconds(23))
            let backgroundTick = delegate.notifications.checkCount > before
            delegate.showWindow(); delegate.store.module = .home
            let report = """
            Navigation transitions: 24
            Main-thread display callback samples: \(sorted.count)
            Requested display callback rate: 60 Hz
            Display callback median interval ms: \(String(format: "%.2f", median))
            Display callback p95 interval ms: \(String(format: "%.2f", p95))
            Display callback max interval ms: \(String(format: "%.2f", sorted.last ?? 0))
            Note: callback cadence measures main-thread responsiveness, not GPU-rendered frame rate.
            Course scroll position preserved after navigation: \(restoredScroll) (\(offset) -> \(restoredOffset))
            Main window hidden on close: \(hidden)
            Notification scheduler continued while hidden: \(backgroundTick)
            Main window reopened: \(delegate.window.isVisible)
            Notification permission: \(delegate.notifications.status)
            """
            try report.write(to: delegate.store.directory.appendingPathComponent("runtime-check.txt"), atomically: true, encoding: .utf8)
        } catch {
            try? error.localizedDescription.write(to: delegate.store.directory.appendingPathComponent("runtime-check-error.txt"), atomically: true, encoding: .utf8)
        }
        NSApp.terminate(nil)
    }
    private func findScrollView(_ view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView { return scroll }
        return view.subviews.lazy.compactMap { self.findScrollView($0) }.first
    }
}
