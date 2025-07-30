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
        
        // Listen for dismiss notifications from the panel
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEscKeyEvent),
            name: .escKeyPressed,
            object: nil
        )
    }
    
    func showChat() {
        
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
        if ChatViewModel.shared.uiState != .input {
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
        
        // Remove notification observers
        NotificationCenter.default.removeObserver(self)
        
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
        isVisible = false
    }
    
    deinit {
        // Note: Cannot call @MainActor cleanup() from deinit
        // Cleanup should be called explicitly before deinitialization
    }
}
