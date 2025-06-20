//
//  ChatView.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 20/06/25.
//

import SwiftUI
import os

struct ChatView: View {
    @State private var query: String = ""
    @State private var animationTimer: Timer?
    @State private var animationCount: Int = 0
    @State private var animationPhase: Int = 0
    @StateObject private var chatViewModel: ChatViewModel = ChatViewModel.shared
    
    private let maxAnimationCount: Int = 5
    
    private let log = OSLog(subsystem: "com.harshitgarg.Nudge", category: "ChatView")

    var body: some View {
        VStack(spacing: 16) {
            // Main Input Bar
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .scaleEffect(animationPhase == 1 ? 1.2 : 1.0)
                    .rotationEffect(.degrees(animationPhase == 1 ? 15 : 0))

                TextField("Type to Nudge", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20))

                Button(action: {
                    // Handle speech action
                    os_log("Not implemented yet", log: log, type: .debug)
                }) {
                    Image(systemName: "mic.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    LinearGradient(
                        colors: [.purple.opacity(0.4), .blue.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Color.clear.background(.regularMaterial)
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.purple, .pink, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .blur(radius: animationPhase == 1 ? 8 : 4)
            )
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)

            // Suggestion Pill
            HStack {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("How to open extensions in safari?")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
        }
        .padding()
        .scaleEffect(animationPhase == 1 ? 1.01 : 1.0)
        .onReceive(chatViewModel.$isChatVisible) { isVisible in
            if isVisible {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
        
    }
    
    public func startAnimation() {
        os_log("Starting animation", log: log, type: .debug)
        animationCount = 0
        animationTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
            animationCount += 1
            if animationCount > maxAnimationCount {
                stopAnimation()
            }
            withAnimation(.easeInOut(duration: 1.25)) {
                animationPhase = animationPhase % 2 == 0 ? 1 : 0
            }
        }
    }
    
    public func stopAnimation() {
        os_log("Stopping animation", log: log, type: .debug)
        animationPhase = 0
        animationTimer?.invalidate()
        animationTimer = nil
    }
}

#Preview {
    ChatView()
        .frame(width: 500)
        .background(Color(red: 0.2, green: 0.25, blue: 0.2))
}

