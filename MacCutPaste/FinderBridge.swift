import Foundation

enum FinderBridge {
    enum FinderBridgeError: LocalizedError {
        case scriptFailed(String)
        case invalidResult

        var errorDescription: String? {
            switch self {
            case .scriptFailed(let message):
                return message
            case .invalidResult:
                return "Could not read the Finder AppleScript result."
            }
        }
    }

    static func selectedItemURLs() -> [URL] {
        (try? selectedItemURLsOrThrow()) ?? []
    }

    static func selectedItemURLsOrThrow() throws -> [URL] {
        let script = """
        tell application "Finder"
            set selectedItems to selection as alias list
            set output to ""
            repeat with selectedItem in selectedItems
                set output to output & POSIX path of selectedItem & linefeed
            end repeat
            return output
        end tell
        """

        return try runPathListScript(script)
    }

    static func frontWindowFolderURL() -> URL? {
        let script = """
        tell application "Finder"
            if (count of Finder windows) > 0 then
                return POSIX path of ((target of front Finder window) as alias)
            else
                return POSIX path of (desktop as alias)
            end if
        end tell
        """

        do {
            let path = try runStringScript(script).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else { return nil }
            return URL(fileURLWithPath: path, isDirectory: true)
        } catch {
            return nil
        }
    }

    private static func runPathListScript(_ source: String) throws -> [URL] {
        let output = try runStringScript(source)

        return output
            .split(separator: "\n")
            .map(String.init)
            .filter { !$0.isEmpty }
            .map { URL(fileURLWithPath: $0) }
    }

    private static func runStringScript(_ source: String) throws -> String {
        var errorInfo: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            throw FinderBridgeError.invalidResult
        }

        let descriptor = script.executeAndReturnError(&errorInfo)

        if let errorInfo {
            let message = errorInfo[NSAppleScript.errorMessage] as? String ?? "Could not run the Finder AppleScript."
            throw FinderBridgeError.scriptFailed(message)
        }

        return descriptor.stringValue ?? ""
    }
}
