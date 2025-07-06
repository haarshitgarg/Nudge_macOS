import SwiftUI
import os

// MARK: - Notification Names
extension Notification.Name {
    static let dismissChatPanel = Notification.Name("dismissChatPanel")
}

class FloatingPanel: NSPanel {
    private let log = OSLog(subsystem: "Harshit.Nudge", category: "FloatingPanel")
    private var keyEventMonitor: Any?
    
    init(contentView: some View) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Allow the panel to float over all other windows, including fullscreen apps
        self.isFloatingPanel = true
        self.level = .screenSaver // Higher level to ensure it shows above fullscreen
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Make the panel transparent
        self.isOpaque = false
        self.backgroundColor = .clear

        // Set the content view
        self.contentView = NSHostingView(rootView: contentView)
        
        // Set up key event monitoring for escape key
        setupKeyEventMonitoring()
    }
    
    // Override to allow the panel to become key window for text input
    override var canBecomeKey: Bool {
        return true
    }
    
    // Override to accept first responder status for key events
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    private func setupKeyEventMonitoring() {
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            // Only handle events if this panel is visible and key
            if self.isVisible && (self.isKeyWindow || self.isMainWindow) {
                os_log("Key event detected, keyCode: %d", log: self.log, type: .debug, event.keyCode)
                
                // Check for escape key (keyCode 53)
                if event.keyCode == 53 {
                    os_log("Escape key pressed, dismissing panel", log: self.log, type: .debug)
                    NotificationCenter.default.post(name: .dismissChatPanel, object: nil)
                    return nil // Consume the event
                }
            }
            
            return event // Pass through other events
        }
    }
    
    deinit {
        // Clean up resources if needed
        os_log("FloatingPanel is being deinitialized", log: log, type: .debug)
        
        // Remove key event monitor
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        self.contentView = nil
    }
}
