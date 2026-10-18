import AppKit
import SwiftUI
import VoiceNotesCore

@MainActor
final class DictationHUD {
    private static let topMargin: CGFloat = 10

    private var panel: NSPanel?

    func attach(_ dictation: DictationController, settings: AppSettings) {
        let hosting = FirstClickHostingView(
            rootView: DictationHUDShortcutView(dictation: dictation, settings: settings)
        )
        hosting.sizingOptions = [.intrinsicContentSize]
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.contentView = hosting
        self.panel = panel
    }

    func update(for phase: DictationPhase) {
        guard let panel else { return }
        guard phase != .idle else {
            panel.orderOut(nil)
            return
        }
        guard !panel.isVisible else { return }
        panel.setContentSize(panel.contentView?.fittingSize ?? .zero)
        position(panel)
        panel.orderFrontRegardless()
    }

    private func position(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2, y: visible.maxY - size.height - Self.topMargin))
    }
}

private final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

private struct DictationHUDShortcutView: View {
    let dictation: DictationController
    let settings: AppSettings

    var body: some View {
        DictationHUDView(dictation: dictation, shortcut: settings.dictationHotKey.displayString)
            .padding(6)
    }
}
