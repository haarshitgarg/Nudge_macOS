//
//  Nudge_macOSApp.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 18/06/25.
//

import SwiftUI

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
    func applicationDidFinishLaunching(_ notification: Notification) {
        // You can show the panel on launch if you want
        PanelManager.shared.showPanel()
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        PanelManager.shared.cleanup()
    }
}
