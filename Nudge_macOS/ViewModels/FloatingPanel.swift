import SwiftUI
import os

class FloatingPanel: NSPanel {
    private let log = OSLog(subsystem: "Harshit.Nudge", category: "FloatingPanel")
    
    init(contentView: some View) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Allow the panel to float over all other windows, including fullscreen apps
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Make the panel transparent
        self.isOpaque = false
        self.backgroundColor = .clear

        // Set the content view
        self.contentView = NSHostingView(rootView: contentView)
    }
    
    // Override to allow the panel to become key window for text input
    override var canBecomeKey: Bool {
        return true
    }
    
    deinit {
        // Clean up resources if needed
        os_log("FloatingPanel is being deinitialized", log: log, type: .debug)
        self.contentView = nil
    }
}
