import SwiftUI

struct MenuBarView: View {
    @ObservedObject var controller: CutPasteController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status: \(controller.statusText)")

            Divider()

            Button("Check Permissions") {
                controller.checkPermissions()
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 280)
    }
}
