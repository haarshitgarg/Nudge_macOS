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

    var body: some Scene {
        
        MenuBarExtra("Nudge", systemImage: "sparkles") {
            ContentView()
        }
        
        
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let log = OSLog(subsystem: "Harshit.Nudge", category: "MainAppDelegate")
    func applicationDidFinishLaunching(_ notification: Notification) {
        // You can show the panel on launch if you want
        os_log("Application finished launching", log: log, type: .debug)
        ChatViewModel.shared.togglePanel()
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        os_log("Application is terminating, cleaning up resources", log: log, type: .debug)
        ChatViewModel.shared.cleanupPanel()
        ChatViewModel.shared.nudgeClient.disconnect()
        ChatViewModel.shared.navClient.disconnect()
        Thread.sleep(forTimeInterval: 2)
        os_log("Finished terminations steps. Will close the app", log: log, type: .info)
        exit(0)
    }
}
