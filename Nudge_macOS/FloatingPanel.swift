import SwiftUI

class FloatingPanel: NSPanel {
    init(contentView: AnyView) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Allow the panel to float over all other windows, including fullscreen apps
        self.isFloatingPanel = true
        self.level = .screenSaver
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
} 
