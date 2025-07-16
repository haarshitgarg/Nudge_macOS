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
        
        // Listen for dismiss notifications from the panel
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEscKeyEvent),
            name: .escKeyPressed,
            object: nil
        )
    }
    
    func showChat() {
        os_log("Showing chat panel", log: log, type: .debug)
        
        if panel == nil {
            let contentView = ChatView()
                .frame(minWidth: 500, maxWidth: 600, alignment: .center)
            panel = FloatingPanel(contentView: contentView)
        }
        
        // Center and show the panel
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let panelRect = panel!.frame
            let newOrigin = NSPoint(
                x: (screenRect.width - panelRect.width) / 2,
                y: (screenRect.height - panelRect.height) / 2
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
    
    @MainActor
    @objc private func handleEscKeyEvent() {
        os_log("Received escape key, hiding chat", log: log, type: .debug)
        if ChatViewModel.shared.uiState != .input {
            os_log("UI state is not input, hence terminating the agent execution", log: log, type: .debug)
            do {
                try ChatViewModel.shared.terminateAgent()
            } catch {
                os_log("Failed to terminate agent: %@", log: log, type: .fault, error.localizedDescription)
            }
        } else {
            hideChat()
        }
    }
    
    func cleanup() {
        os_log("Cleaning up panel resources", log: log, type: .debug)
        
        // Remove notification observers
        NotificationCenter.default.removeObserver(self)
        
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
