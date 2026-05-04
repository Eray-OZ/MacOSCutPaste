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
        MenuBarExtra("MacCutPaste", systemImage: "scissors") {
            MenuBarView(controller: controller)
        }
        .menuBarExtraStyle(.window)
    }
}
