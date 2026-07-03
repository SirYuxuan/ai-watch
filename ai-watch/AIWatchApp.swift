//
//  AIWatchApp.swift
//  ai-watch
//
//  Created by Sir丶雨轩 on 2026/7/2.
//

import SwiftUI

@main
struct AIWatchApp: App {
    @StateObject private var monitor = QuotaMonitor()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(monitor)
                .frame(width: 440, height: 620)
        } label: {
            Image(systemName: monitor.menuBarSymbol)
        }
        .menuBarExtraStyle(.window)
    }
}
