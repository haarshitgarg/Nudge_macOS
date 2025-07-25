//
//  UserActionPromptView.swift
//  Nudge_macOS
//
//  Created by Claude on 25/07/25.
//

import SwiftUI

struct UserActionPromptView: View {
    let message: String
    let onDismiss: () -> Void
    @State private var isVisible: Bool = false
    @State private var displayedText: String = ""
    @State private var typingTimer: Timer?
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Message with typing animation
                Text(displayedText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
                
                // Dismiss button
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .opacity(isVisible ? 1.0 : 0.0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        .yellow.opacity(0.8),
                                        .orange.opacity(0.8),
                                        .red.opacity(0.6)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 2
                            )
                    )
            )
            .shadow(color: .yellow.opacity(0.3), radius: 8, x: 0, y: 4)
            .scaleEffect(isVisible ? 1.0 : 0.95)
            .opacity(isVisible ? 1.0 : 0.0)
        }
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            stopTypingAnimation()
        }
    }
    
    private func startAnimation() {
        // Start with scale/fade animation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            isVisible = true
        }
        
        // Start typing animation after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            startTypingAnimation()
        }
    }
    
    private func startTypingAnimation() {
        displayedText = ""
        var currentIndex = 0
        
        typingTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            if currentIndex < message.count {
                let index = message.index(message.startIndex, offsetBy: currentIndex)
                displayedText = String(message[..<message.index(after: index)])
                currentIndex += 1
            } else {
                timer.invalidate()
            }
        }
    }
    
    private func stopTypingAnimation() {
        typingTimer?.invalidate()
        typingTimer = nil
    }
}

struct UserActionPromptContainerView: View {
    @ObservedObject var chatViewModel: ChatViewModel
    
    var body: some View {
        VStack {
            if chatViewModel.showUserActionPrompt, let message = chatViewModel.userActionMessage {
                UserActionPromptView(
                    message: message,
                    onDismiss: {
                        chatViewModel.hideUserActionPrompt()
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: chatViewModel.showUserActionPrompt)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        UserActionPromptView(
            message: "🔍 Please navigate to System Preferences → Privacy & Security",
            onDismiss: {}
        )
        .frame(width: 350)
        
        UserActionPromptView(
            message: "👆 Click on the 'General' tab in the current window",
            onDismiss: {}
        )
        .frame(width: 350)
        
        UserActionPromptView(
            message: "⌨️ Please type your password when prompted",
            onDismiss: {}
        )
        .frame(width: 350)
    }
    .padding()
    .background(Color.black.opacity(0.1))
    .frame(width: 400, height: 300)
}
