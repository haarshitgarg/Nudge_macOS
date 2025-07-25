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
    case shrinking = "shrinking"
    case sparkles = "sparkles"
    case transitioning = "transitioning"
    case thinking = "thinking"
    case responding = "responding"
    case expanding = "expanding"
    
    var isInteractionEnabled: Bool {
        switch self {
        case .input, .responding:
            return true
        case .shrinking, .sparkles, .transitioning, .thinking, .expanding:
            return false
        }
    }
}

// MARK: - ChatViewModel
@MainActor
class ChatViewModel: ObservableObject {
    public static let shared = ChatViewModel()
    
    let log = OSLog(subsystem: "Harshit.Nudge", category: "ChatViewModel")
    
    public let shortcutManager = ShortcutManager()
    public let navClient = NudgeNavClient()
    
    @Published public var llmLoopRunning: Bool = false
    @Published public var currentTool: String = ""
    @Published public var llmMessages: [String] = []
    
    // MARK: - UI Transition State Management
    @Published public var uiState: UITransitionState = .input
    @Published public var isTransitioning: Bool = false
    @Published public var transitionProgress: Double = 0.0
    @Published public var showInputView: Bool = true
    @Published public var showSparklesView: Bool = false
    @Published public var showThinkingView: Bool = false
    
    // MARK: - Agent Bubble State Management
    @Published public var showAgentBubble: Bool = false
    @Published public var agentBubbleMessage: AgentBubbleMessage?
    private var bubbleTimer: Timer?
    
    // MARK: - User Action Prompt State Management
    @Published public var showUserActionPrompt: Bool = false
    @Published public var userActionMessage: String?
    private var actionPromptTimer: Timer?
    
    
    
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
        
        try navClient.sendMessageToMCPClient(msg)
    }
    
    public func respondLLM(_ msg: String) async throws {
        // TODO: Send the response to the LLM
        guard uiState.isInteractionEnabled else { return }
        self.transitionToThinking()
        try navClient.respondToAgent(msg)
    }
    
    public func terminateAgent() throws {
        try navClient.interruptAgent()
    }
    
    
    
    // MARK: - UI Transition State Machine
    public func transitionToThinking() {
        guard uiState == .input else { return }
        
        isTransitioning = true
        
        // Instant transition: Input → Loading → Thinking
        uiState = .transitioning
        showInputView = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.uiState = .thinking
            self.showThinkingView = true
            self.isTransitioning = false
        }
    }
    
    public func transitionToResponding() {
        uiState = .responding
    }
    
    public func transitionToInput() {
        guard uiState == .thinking || uiState == .responding else { return }
        
        isTransitioning = true
        
        // Instant transition: Thinking → Loading → Input
        uiState = .transitioning
        showThinkingView = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.uiState = .input
            self.showInputView = true
            self.isTransitioning = false
        }
    }
    
    // MARK: - Agent Bubble Management
    public func showAgentBubble(message: String, type: AgentMessageType) {
        // Cancel any existing timer
        bubbleTimer?.invalidate()
        
        // Update bubble content
        agentBubbleMessage = AgentBubbleMessage(text: message, type: type)
        showAgentBubble = true
        
        // Auto-dismiss after 4 seconds
        bubbleTimer = Timer.scheduledTimer(withTimeInterval: 9.0, repeats: false) { _ in
            Task {
                await self.hideAgentBubble()
            }
        }
    }
    
    public func hideAgentBubble() {
        showAgentBubble = false
        bubbleTimer?.invalidate()
        bubbleTimer = nil
        
        // Clear message after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.agentBubbleMessage = nil
        }
    }
    
    public func showAgentThought(_ thought: String) {
        showAgentBubble(message: thought, type: .thought)
    }
    
    public func showToolExecution(_ toolName: String) {
        let message = "Using \(toolName) to assist you"
        showAgentBubble(message: message, type: .toolExecution)
    }
    
    public func showProgressMessage(_ message: String) {
        showAgentBubble(message: message, type: .progress)
    }
    
    public func showSuccessMessage(_ message: String) {
        showAgentBubble(message: message, type: .success)
    }
    
    public func showErrorMessage(_ message: String) {
        showAgentBubble(message: message, type: .error)
    }
    
    public func showLLMquery(_ query: String) {
        self.transitionToResponding()
    }
    
    // MARK: - User Action Prompt Management
    public func showUserActionPrompt(message: String) {
        // Cancel any existing timer
        actionPromptTimer?.invalidate()
        
        // Update prompt content
        userActionMessage = message
        showUserActionPrompt = true
        
        // Auto-dismiss after 12 seconds
        actionPromptTimer = Timer.scheduledTimer(withTimeInterval: 12.0, repeats: false) { _ in
            Task {
                await self.hideUserActionPrompt()
            }
        }
    }
    
    public func hideUserActionPrompt() {
        showUserActionPrompt = false
        actionPromptTimer?.invalidate()
        actionPromptTimer = nil
        
        // Clear message after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.userActionMessage = nil
        }
    }

    deinit {
        os_log("ChatViewModel is being deinitialized", log: log, type: .debug)
        // Note: Cannot call @MainActor cleanup() from deinit
        // Cleanup should be called explicitly before deinitialization
    }
    
    func cleanup() {
        os_log("Cleaning up ChatViewModel resources", log: log, type: .debug)
        
        // Cancel bubble timer
        bubbleTimer?.invalidate()
        bubbleTimer = nil
        
        // Cancel action prompt timer
        actionPromptTimer?.invalidate()
        actionPromptTimer = nil
        
        // Disconnect XPC clients (these are not MainActor isolated)
        Task.detached {
            await self.navClient.disconnect()
        }
    }
}

// MARK: - ShortcutManagerDelegate Implementation
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
        transitionToThinking()
        
        // Show agent bubble
        showProgressMessage("Starting analysis...")
    }
    
    func onLLMLoopFinished() {
        os_log("LLM loop finished - updating UI", log: log, type: .debug)
        llmLoopRunning = false
        currentTool = ""
        
        if uiState == .thinking || uiState == .responding {
            transitionToInput()
        }
        
        // Show completion message
        showSuccessMessage("Task completed successfully!")
    }
    
    func onToolCalled(toolName: String) {
        os_log("Tool called: %@ - updating UI", log: log, type: .debug, toolName)
        currentTool = toolName
        
//        // Transition to responding state when tool is called
//        if uiState == .thinking {
//            transitionToResponding()
//        }
        
        // Show tool execution bubble
        showToolExecution(toolName)
    }
    
    func onLLMMessage(_ message: String) {
        os_log("LLM message received in ChatViewModel: %@ - updating UI", log: log, type: .info, message)
        llmMessages.append(message)
        
        // Show agent thoughts in bubble
        showAgentThought(message)
    }
    
    func onUserMessage(_ message: String) {
        os_log("User message received: %@ - updating UI", log: log, type: .info, message)
        self.transitionToResponding()
        
        // Show user action prompt
        showUserActionPrompt(message: message)
    }
    
    func onError(_ error: String) {
        os_log("Error received: %@ - updating UI", log: log, type: .error, error)
        llmLoopRunning = false
        currentTool = ""
        llmMessages.append("Error: \(error)")
        transitionToInput()
        
        // Show error message in bubble
        showErrorMessage(error)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let chatShortcutPressed = Notification.Name("chatShortcutPressed")
}

