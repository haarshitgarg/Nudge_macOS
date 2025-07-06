//
//  FloatingChatManager.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 06/07/25.
//

import SwiftUI
import os

@MainActor
class FloatingChatManager: ObservableObject {
    private var panel: FloatingPanel?
    
    @Published var isVisible: Bool = false
    
    private let log = OSLog(subsystem: "Harshit.Nudge", category: "FloatingChatManager")
    
    init() {
        os_log("FloatingChatManager initialized", log: log, type: .debug)
    }
    
    func showChat() {
        os_log("Showing chat panel", log: log, type: .debug)
        
        if panel == nil {
            let contentView = ChatView().frame(width: 500)
            panel = FloatingPanel(contentView: contentView)
        }
        
        // Center and show the panel
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let panelRect = panel!.frame
            let newOrigin = NSPoint(
                x: (screenRect.width - panelRect.width) / 2,
                y: (screenRect.height - panelRect.height) / 2 + screenRect.height * 0.2
            )
            panel?.setFrameOrigin(newOrigin)
        }
        
        isVisible = true
        panel?.makeKeyAndOrderFront(nil)
    }
    
    func hideChat() {
        os_log("Hiding chat panel", log: log, type: .debug)
        isVisible = false
        panel?.orderOut(nil)
    }
    
    func toggleChat() {
        if panel?.isVisible == true {
            hideChat()
        } else {
            showChat()
        }
    }
    
    func cleanup() {
        os_log("Cleaning up panel resources", log: log, type: .debug)
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
        isVisible = false
    }
    
    deinit {
        os_log("FloatingChatManager is being deinitialized", log: log, type: .debug)
        // Note: Cannot call @MainActor cleanup() from deinit
        // Cleanup should be called explicitly before deinitialization
    }
}
