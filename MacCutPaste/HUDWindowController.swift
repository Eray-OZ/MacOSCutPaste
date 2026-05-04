import AppKit
import SwiftUI

@MainActor
final class HUDWindowController {
    private var window: NSWindow?
    private var dismissWorkItem: DispatchWorkItem?

    func show(message: String, detail: String? = nil, symbolName: String = "scissors") {
        dismissWorkItem?.cancel()

        let contentView = HUDView(message: message, detail: detail, symbolName: symbolName)
        let hostingView = NSHostingView(rootView: contentView)
        let targetWindow = window ?? makeWindow()

        targetWindow.contentView = hostingView
        position(targetWindow)
        targetWindow.alphaValue = 0
        targetWindow.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            targetWindow.animator().alphaValue = 1
        }

        let workItem = DispatchWorkItem { [weak self, weak targetWindow] in
            guard let self, let targetWindow else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                targetWindow.animator().alphaValue = 0
            } completionHandler: {
                targetWindow.orderOut(nil)
            }
            self.dismissWorkItem = nil
        }

        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: workItem)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 92),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.ignoresMouseEvents = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.window = window
        return window
    }

    private func position(_ window: NSWindow) {
        guard let screenFrame = NSScreen.main?.visibleFrame else { return }

        let size = window.frame.size
        let x = screenFrame.midX - size.width / 2
        let y = screenFrame.maxY - size.height - 56
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

private struct HUDView: View {
    let message: String
    let detail: String?
    let symbolName: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbolName)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 4) {
                Text(message)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)

                if let detail {
                    Text(detail)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(width: 340, height: 92)
        .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
    }
}
