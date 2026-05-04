import Foundation
import ServiceManagement

enum LoginItemManager {
    static func enableLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .notRegistered {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Could not enable launch at login: \(error.localizedDescription)")
        }
    }
}
