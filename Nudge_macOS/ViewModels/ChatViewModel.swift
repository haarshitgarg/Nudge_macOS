//
//  ChatViewModel.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 18/06/25.
//

import Foundation
import SwiftUI
import os

@MainActor
class ChatViewModel: ObservableObject {
    // Panel manager inserts
    private var panel: FloatingPanel?
    
    //
    public static let shared = ChatViewModel()
    
    let log = OSLog(subsystem: "Harshit.Nudge", category: "ChatViewModel")
    
    public let nudgeClient = NudgeClient()
    public let shortcutManager = ShortcutManager()
    public let navClient = NudgeNavClient()
    
    @Published public var xcpMessage: [XPCMessage] = []
    @Published public var isChatVisible: Bool = false
    @Published public var isAccessibleDialog: Bool = false
    @Published public var animationPhase: Int = 0
    
    private var animationTimer: Timer?
    private var animationCounter: Int = 0
    private let maxAnimationCount: Int = 10
    
    
    private init() {
        shortcutManager.delegate = self
        do {
            try nudgeClient.connect()
            try navClient.connect()
            try navClient.sendPing()
        } catch { os_log("Failed to connect to NudgeClient: %@", log: log, type: .fault, error.localizedDescription) }
    }
    
    public func sendMessage(_ msg: String) async throws {
        let reply = try await nudgeClient.sendMessage(message: msg)
        try navClient.sendMessageToMCPClient(msg)
        self.xcpMessage.append(XPCMessage(content: reply))
    }
    
    public func startAnimation() {
        animationTimer?.invalidate()
        animationCounter = 0
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.animationCounter += 1
                if self.animationCounter >= self.maxAnimationCount {
                    self.stopAnimation()
                } else {
                    self.animationPhase = self.animationPhase % 2 == 0 ? 1 : 0
                }
            }

        }
    }
    
    public func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        animationPhase = 0
    }

    deinit {
        os_log("ChatViewModel is being deinitialized", log: log, type: .debug)
    }
}

// Panel Manager Extension
extension ChatViewModel {
    func showPanel() {
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
                y: (screenRect.height - panelRect.height) / 2 + screenRect.height * 0.2 // Position slightly higher
            )
            panel?.setFrameOrigin(newOrigin)
        }
        
        self.isChatVisible = true
        panel?.makeKeyAndOrderFront(nil)
    }
    
    func hidePanel() {
        self.isChatVisible = false
        panel?.orderOut(nil)
    }
    
    func togglePanel() {
        if panel?.isVisible == true {
            hidePanel()
        } else {
            showPanel()
        }
    }
    
    func cleanupPanel() {
        os_log("Cleaning up panel resources", log: log, type: .debug)
        self.panel?.orderOut(nil)
        panel?.close()
        panel = nil
    }
}

extension ChatViewModel: NudgeDelegateProtocol {
    func notifyShortcutPressed() {
        os_log("Shortcut pressed notification received in ChatViewModel", log: log, type: .info)
    }
}

extension ChatViewModel: ShortcutManagerDelegate {
    func shortcutManagerDidNotHaveAccessibilityPermissions() {
        os_log("ShortcutManager did not have accessibility permissions", log: log, type: .error)
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        let _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func shortcutManagerDidReceiveChatShortcut() {
        os_log("ShortcutManager did receive chat shortcut", log: log, type: .info)
        self.togglePanel()
    }
}

