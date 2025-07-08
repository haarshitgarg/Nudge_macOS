//
//  ChatViewModel.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 18/06/25.
//

import Foundation
import SwiftUI
import os

// MARK: - UI Transition States
enum UITransitionState: String, CaseIterable {
    case input = "input"
    case transitioning = "transitioning"
    case thinking = "thinking"
    case responding = "responding"
    
    var isInteractionEnabled: Bool {
        switch self {
        case .input:
            return true
        case .transitioning, .thinking, .responding:
            return false
        }
    }
}

@MainActor
class ChatViewModel: ObservableObject {
    public static let shared = ChatViewModel()
    
    let log = OSLog(subsystem: "Harshit.Nudge", category: "ChatViewModel")
    
    public let shortcutManager = ShortcutManager()
    public let navClient = NudgeNavClient()
    
    @Published public var animationPhase: Int = 0
    @Published public var isLoading: Bool = false
    @Published public var llmLoopRunning: Bool = false
    @Published public var currentTool: String = ""
    @Published public var llmMessages: [String] = []
    
    // MARK: - UI Transition State Management
    @Published public var uiState: UITransitionState = .input
    @Published public var isTransitioning: Bool = false
    @Published public var transitionProgress: Double = 0.0
    @Published public var showInputView: Bool = true
    @Published public var showThinkingView: Bool = false
    
    private var animationTimer: Timer?
    private var animationCounter: Int = 0
    
    
    private init() {
        shortcutManager.delegate = self
        navClient.delegate = self
        do {
            try navClient.connect()
            try navClient.sendPing()
        } catch { os_log("Failed to connect to NudgeClient: %@", log: log, type: .fault, error.localizedDescription) }
    }
    
    public func sendMessage(_ msg: String) async throws {
        guard uiState.isInteractionEnabled else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        // Initiate transition to thinking state
        transitionToThinking()
        
        try navClient.sendMessageToMCPClient(msg)
    }
    
    public func startAnimation() {
        animationTimer?.invalidate()
        animationCounter = 0
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.animationCounter += 1
                if self.animationCounter >= 10 {
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
    
    // MARK: - UI Transition State Machine
    public func transitionToThinking() {
        guard uiState == .input else { return }
        
        isTransitioning = true
        uiState = .transitioning
        transitionProgress = 0.0
        
        // Show both views during transition so animations can work
        showInputView = true
        showThinkingView = true
        
        // After a brief moment, change to thinking state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.uiState = .thinking
            self.isTransitioning = false
            self.showInputView = false
            self.transitionProgress = 1.0
        }
    }
    
    public func transitionToInput() {
        guard uiState == .thinking else { return }
        
        isTransitioning = true
        uiState = .transitioning
        transitionProgress = 1.0
        
        // Show both views during transition so animations can work
        showInputView = true
        showThinkingView = true
        
        // After a brief moment, change to input state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.uiState = .input
            self.isTransitioning = false
            self.showThinkingView = false
            self.transitionProgress = 0.0
        }
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

// MARK: - NudgeNavClientDelegate Implementation
extension ChatViewModel: NudgeNavClientDelegate {
    func onLLMLoopStarted() {
        os_log("LLM loop started in ChatViewModel - updating UI", log: log, type: .info)
        llmLoopRunning = true
        currentTool = ""
        llmMessages.removeAll()
        startAnimation()
        transitionToThinking()
    }
    
    func onLLMLoopFinished() {
        os_log("LLM loop finished - updating UI", log: log, type: .debug)
        llmLoopRunning = false
        currentTool = ""
        stopAnimation()
        transitionToInput()
    }
    
    func onToolCalled(toolName: String, arguments: String) {
        os_log("Tool called: %@ - updating UI", log: log, type: .debug, toolName)
        currentTool = toolName
    }
    
    func onLLMMessage(_ message: String) {
        os_log("LLM message received in ChatViewModel: %@ - updating UI", log: log, type: .info, message)
        llmMessages.append(message)
    }
    
    func onError(_ error: String) {
        os_log("Error received: %@ - updating UI", log: log, type: .error, error)
        llmLoopRunning = false
        currentTool = ""
        stopAnimation()
        llmMessages.append("Error: \(error)")
        transitionToInput()
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let chatShortcutPressed = Notification.Name("chatShortcutPressed")
}

