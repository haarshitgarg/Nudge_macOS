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
    public static let shared = ChatViewModel()
    
    let log = OSLog(subsystem: "Harshit.Nudge", category: "ChatViewModel")
    
    public let shortcutManager = ShortcutManager()
    public let navClient = NudgeNavClient()
    
    @Published public var xcpMessage: [XPCMessage] = []
    @Published public var isAccessibleDialog: Bool = false
    @Published public var animationPhase: Int = 0
    @Published public var isLoading: Bool = false
    
    private var animationTimer: Timer?
    private var animationCounter: Int = 0
    private let maxAnimationCount: Int = 10
    
    
    private init() {
        shortcutManager.delegate = self
        do {
            try navClient.connect()
            try navClient.sendPing()
        } catch { os_log("Failed to connect to NudgeClient: %@", log: log, type: .fault, error.localizedDescription) }
    }
    
    public func sendMessage(_ msg: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        try navClient.sendMessageToMCPClient(msg)
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
        // Note: Cannot call @MainActor cleanup() from deinit
        // Cleanup should be called explicitly before deinitialization
    }
    
    func cleanup() {
        os_log("Cleaning up ChatViewModel resources", log: log, type: .debug)
        stopAnimation()
        
        // Disconnect XPC clients (these are not MainActor isolated)
        Task.detached {
            await self.navClient.disconnect()
        }
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
        // This will be handled by the FloatingChatManager now
        // We'll use NotificationCenter to communicate this event
        NotificationCenter.default.post(name: .chatShortcutPressed, object: nil)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let chatShortcutPressed = Notification.Name("chatShortcutPressed")
}

