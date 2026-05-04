import AppKit
import Carbon.HIToolbox
import Combine

final class CutPasteController: ObservableObject {
    @Published private(set) var statusText = "Running"
    @Published private(set) var pendingItems: [URL] = []
    @Published private(set) var lastError: String?
    @Published private(set) var debugText = "Keyboard monitor is starting"

    private let hud = HUDWindowController()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init() {
        LoginItemManager.enableLaunchAtLogin()
        PermissionManager.requestAccessibilityIfNeeded()
        PermissionManager.triggerFinderAutomationPrompt()
        startKeyboardMonitor()
    }

    deinit {
        stopKeyboardMonitor()
    }

    func checkPermissions() {
        let isAccessibilityTrusted = PermissionManager.requestAccessibilityIfNeeded()

        if !isAccessibilityTrusted {
            statusText = "Accessibility permission required"
            debugText = "Opening Accessibility settings"
            lastError = "Enable MacCutPaste in Privacy & Security > Accessibility."
            PermissionManager.openPrivacySettings()
            return
        }

        do {
            _ = try FinderBridge.selectedItemURLsOrThrow()
            statusText = "Permissions OK"
            debugText = "Accessibility and Finder Automation are available"
            lastError = nil
        } catch {
            statusText = "Finder Automation required"
            debugText = "Opening Automation settings"
            lastError = "Enable Finder under MacCutPaste in Privacy & Security > Automation. Details: \(error.localizedDescription)"
            PermissionManager.openAutomationSettings()
        }

        restartKeyboardMonitor()
    }

    private func startKeyboardMonitor() {
        guard eventTap == nil else { return }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: keyboardCallback,
            userInfo: userInfo
        ) else {
            statusText = "Accessibility permission required"
            debugText = "Keyboard monitor failed to start"
            lastError = "Could not start the keyboard monitor. Grant Accessibility permission, then restart the app."
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        CGEvent.tapEnable(tap: tap, enable: true)
        debugText = "Keyboard monitor active"
    }

    private func stopKeyboardMonitor() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
    }

    private func restartKeyboardMonitor() {
        stopKeyboardMonitor()
        startKeyboardMonitor()
    }

    fileprivate func handleKeyDown(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        if let eventTap, !CGEvent.tapIsEnabled(tap: eventTap) {
            CGEvent.tapEnable(tap: eventTap, enable: true)
            debugText = "Keyboard monitor re-enabled"
        }

        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder" else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        let hasCommand = flags.contains(.maskCommand)
        let hasControl = flags.contains(.maskControl)

        guard hasCommand || hasControl else {
            return Unmanaged.passUnretained(event)
        }

        switch keyCode {
        case kVK_ANSI_X:
            debugText = "Captured Cmd/Ctrl+X in Finder"
            markSelectedItemsForMove()
            return nil
        case kVK_ANSI_V:
            debugText = "Captured Cmd/Ctrl+V in Finder"
            movePendingItemsToFinderLocation()
            return nil
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func markSelectedItemsForMove() {
        let selectedItems: [URL]

        do {
            selectedItems = try FinderBridge.selectedItemURLsOrThrow()
        } catch {
            pendingItems = []
            statusText = "Finder selection error"
            lastError = error.localizedDescription
            return
        }

        guard !selectedItems.isEmpty else {
            pendingItems = []
            statusText = "No selection"
            lastError = "No file or folder is selected in Finder."
            return
        }

        pendingItems = selectedItems
        statusText = "\(selectedItems.count) item(s) marked to move"
        lastError = nil
        hud.show(
            message: "Marked to move",
            detail: selectedItems.count == 1 ? selectedItems[0].lastPathComponent : "\(selectedItems.count) items",
            symbolName: "scissors"
        )
    }

    private func movePendingItemsToFinderLocation() {
        guard !pendingItems.isEmpty else {
            statusText = "No pending items"
            lastError = "Select files in Finder first, then press Cmd+X or Ctrl+X."
            return
        }

        guard let destinationFolder = FinderBridge.frontWindowFolderURL() else {
            statusText = "Destination not found"
            lastError = "Could not read the Finder destination folder."
            return
        }

        do {
            for sourceURL in pendingItems {
                let destinationURL = uniqueDestinationURL(
                    for: sourceURL.lastPathComponent,
                    in: destinationFolder
                )
                try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            }

            statusText = "\(pendingItems.count) item(s) moved"
            hud.show(
                message: "Moved",
                detail: pendingItems.count == 1 ? pendingItems[0].lastPathComponent : "\(pendingItems.count) items",
                symbolName: "checkmark.circle.fill"
            )
            pendingItems = []
            lastError = nil
        } catch {
            statusText = "Move failed"
            lastError = error.localizedDescription
        }
    }

    private func uniqueDestinationURL(for fileName: String, in folderURL: URL) -> URL {
        let fileManager = FileManager.default
        let originalURL = folderURL.appendingPathComponent(fileName)

        guard fileManager.fileExists(atPath: originalURL.path) else {
            return originalURL
        }

        let baseName = (fileName as NSString).deletingPathExtension
        let fileExtension = (fileName as NSString).pathExtension

        var counter = 2
        while true {
            let candidateName: String
            if fileExtension.isEmpty {
                candidateName = "\(baseName) \(counter)"
            } else {
                candidateName = "\(baseName) \(counter).\(fileExtension)"
            }

            let candidateURL = folderURL.appendingPathComponent(candidateName)
            if !fileManager.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }

            counter += 1
        }
    }
}

private let keyboardCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard type == .keyDown, let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let controller = Unmanaged<CutPasteController>
        .fromOpaque(userInfo)
        .takeUnretainedValue()

    return controller.handleKeyDown(event)
}
