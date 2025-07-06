//
//  Nudge_macOSApp.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 18/06/25.
//

import SwiftUI
import os

@main
struct Nudge_macOSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var chatViewModel = ChatViewModel.shared
    @StateObject private var floatingChatManager = FloatingChatManager()

    var body: some Scene {
        
        MenuBarExtra("Nudge", systemImage: "sparkles") {
            ContentView()
        }
        .environmentObject(floatingChatManager)
        
        
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let log = OSLog(subsystem: "Harshit.Nudge", category: "MainAppDelegate")
    private var floatingChatManager: FloatingChatManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        os_log("Application finished launching", log: log, type: .debug)
        
        // Get the floating chat manager from the environment
        floatingChatManager = FloatingChatManager()
        
        // Show the panel on launch if you want
        floatingChatManager?.showChat()
        
        // Listen for keyboard shortcut notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleChatShortcut),
            name: .chatShortcutPressed,
            object: nil
        )
    }
    
    @MainActor
    @objc private func handleChatShortcut() {
        floatingChatManager?.toggleChat()
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        os_log("Application is terminating, cleaning up resources", log: log, type: .debug)
        
        // Clean up resources on main actor
        Task { @MainActor in
            floatingChatManager?.cleanup()
            ChatViewModel.shared.cleanup()
        }
        
        // Remove notification observers
        NotificationCenter.default.removeObserver(self)
        
        Thread.sleep(forTimeInterval: 2)
        os_log("Finished terminations steps. Will close the app", log: log, type: .info)
        exit(0)
    }
}
