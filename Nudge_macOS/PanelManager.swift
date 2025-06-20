import SwiftUI
import os

class PanelManager {
    static let shared = PanelManager()
    private var panel: FloatingPanel?
    private let log = OSLog(subsystem: "com.harshitgarg.Nudge_macOS", category: "PanelManager")
    
    @MainActor
    private let chatviewmodel_instance = ChatViewModel.shared

    private init() {}

    func showPanel() {
        if panel == nil {
            let contentView = AnyView(ChatView().frame(width: 500))
            panel = FloatingPanel(contentView: contentView)
        }
        
        // Center and show the panel
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let panelRect = panel!.frame
            let newOrigin = NSPoint(
                x: (screenRect.width - panelRect.width) / 2,
                y: (screenRect.height - panelRect.height) / 2 + screenRect.height * 0.2 // Position slightly higher
            )
            panel?.setFrameOrigin(newOrigin)
        }
        
        panel?.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async {
            self.chatviewmodel_instance.isChatVisible = true
        }
    }

    func hidePanel() {
        panel?.orderOut(nil)
        DispatchQueue.main.async {
            self.chatviewmodel_instance.isChatVisible = false
        }
    }
    
    func togglePanel() {
        if panel?.isVisible == true {
            hidePanel()
        } else {
            showPanel()
        }
    }

    func cleanup() {
        os_log("Cleaning up panel resources", log: log, type: .debug)
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
        
    }
}
