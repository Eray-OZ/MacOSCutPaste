//
//  MacCutPasteApp.swift
//  MacCutPaste
//
//  Created by Eray ÖZ on 4.05.2026.
//

import SwiftUI

@main
struct MacCutPasteApp: App {
    @StateObject private var controller = CutPasteController()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(controller: controller)
        } label: {
            if controller.pendingItems.isEmpty {
                Image(systemName: "scissors")
            } else {
                Label("Cut: \(controller.pendingItems.count)", systemImage: "scissors")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
