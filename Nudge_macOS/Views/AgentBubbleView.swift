//
//  Background.swift
//  Nudge_macOS
//
//  Created by CLAUDE (NOT REVIEWED JUST TESTED) on 18/06/25.
//

import SwiftUI

struct AgentBubbleView: View {
    let message: String
    let messageType: AgentMessageType
    @State private var displayedText: String = ""
    @State private var showCursor: Bool = false
    @State private var isTyping: Bool = false
    @State private var typingTimer: Timer?
    @State private var cursorTimer: Timer?
    @State private var messageId: UUID = UUID()
    
    var body: some View {
        HStack {
            // Icon based on message type
            Text(messageType.icon)
                .font(.system(size: 16))
                .foregroundColor(.primary)
            
            // Message content with typing animation
            Text(displayedText + (showCursor && isTyping ? "|" : ""))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    .purple.opacity(0.6),
                                    .pink.opacity(0.6),
                                    .orange.opacity(0.6)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .onAppear {
            let newMessageId = UUID()
            messageId = newMessageId
            startTypingAnimation()
        }
        .onDisappear {
            stopTypingAnimation()
        }
        .onChange(of: message) {
            let newMessageId = UUID()
            messageId = newMessageId
            stopTypingAnimation()
            startTypingAnimation()
        }
    }
    
    private func startTypingAnimation() {
        // Stop any existing timers first
        stopTypingAnimation()
        
        displayedText = ""
        isTyping = true
        showCursor = true
        
        let currentMessageId = messageId
        
        // Start cursor blinking
        cursorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            // Check if message changed during animation
            guard currentMessageId == messageId else { return }
            showCursor.toggle()
        }
        
        // Start typing animation
        var currentIndex = 0
        typingTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { timer in
            // Check if message changed during animation
            guard currentMessageId == messageId else {
                timer.invalidate()
                return
            }
            
            if currentIndex < message.count {
                let index = message.index(message.startIndex, offsetBy: currentIndex)
                displayedText = String(message[..<message.index(after: index)])
                currentIndex += 1
            } else {
                timer.invalidate()
                isTyping = false
                showCursor = false
                cursorTimer?.invalidate()
            }
        }
    }
    
    private func stopTypingAnimation() {
        typingTimer?.invalidate()
        cursorTimer?.invalidate()
        isTyping = false
        showCursor = false
    }
}

enum AgentMessageType {
    case thought
    case toolExecution
    case progress
    case success
    case error
    
    var icon: String {
        switch self {
        case .thought:
            return "💭"
        case .toolExecution:
            return "⚙️"
        case .progress:
            return "📊"
        case .success:
            return "✅"
        case .error:
            return "❌"
        }
    }
}

struct AgentBubbleContainerView: View {
    @ObservedObject var chatViewModel: ChatViewModel
    
    var body: some View {
        VStack {
            if chatViewModel.showAgentBubble, let bubbleMessage = chatViewModel.agentBubbleMessage {
                AgentBubbleView(
                    message: bubbleMessage.text,
                    messageType: bubbleMessage.type
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: chatViewModel.showAgentBubble)
            }
        }
    }
}

struct AgentBubbleMessage {
    let text: String
    let type: AgentMessageType
}

#Preview {
    VStack {
        AgentBubbleView(
            message: "I need to analyze the current screen elements and find the settings button...",
            messageType: .thought
        )
        .frame(width: 300, alignment: .leading)
        .padding()

        AgentBubbleView(
            message: "Using get_ui_elements to scan the screen",
            messageType: .toolExecution
        )
        .frame(width: 300, alignment: .leading)
        .padding()
        
        AgentBubbleView(
            message: "Task completed successfully!",
            messageType: .success
        )
        .frame(width: 300, alignment: .leading)
        .padding()
    }
    .background(Color.black.opacity(0.1))
    .frame(width: 400, height: 500, alignment: .center)
}
