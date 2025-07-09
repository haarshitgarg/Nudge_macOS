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
    @StateObject private var chatViewModel: ChatViewModel = ChatViewModel.shared
    
    private let log = OSLog(subsystem: "Harshit.Nudge", category: "ChatView")
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main container with consistent height
            ZStack(alignment: .topLeading) {
                // Full Input View - Only visible in input state
                if chatViewModel.showInputView {
                    VStack(spacing: 16) {
                        // Main Input Bar
                        HStack(spacing: 12) {
                            // Seamless transition icon (sparkles → loading)
                            SeamlessTransitionView(
                                uiState: chatViewModel.uiState,
                                animationPhase: chatViewModel.animationPhase
                            )
                            
                            // TEXT FIELD - Disappears instantly
                            TextField("Type to Nudge", text: $query)
                                .textFieldStyle(.plain)
                                .font(.system(size: 20))
                                .disabled(!chatViewModel.uiState.isInteractionEnabled)
                                .opacity(chatViewModel.uiState == .input ? 1.0 : 0.0)
                                .onSubmit {
                                    guard chatViewModel.uiState.isInteractionEnabled else { return }
                                    DispatchQueue.main.async {
                                        let message = query
                                        query = ""
                                        Task {
                                            do { try await self.chatViewModel.sendMessage(message)
                                            } catch { os_log("Failed to send message: %@", log: log, type: .fault, error.localizedDescription) }
                                        }
                                    }
                                }
                            
                            // SPEECH BUTTON - Disappears instantly
                            Button(action: {
                                // Handle speech action
                                os_log("Not implemented yet", log: log, type: .debug)
                            }) {
                                Image(systemName: "mic.fill")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(!chatViewModel.uiState.isInteractionEnabled)
                            .opacity(chatViewModel.uiState == .input ? 1.0 : 0.0)
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
                            .opacity(chatViewModel.uiState == .input ? 1.0 : 0.0)
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
                            .blur(radius: 4)
                            .opacity(chatViewModel.uiState == .input ? 1.0 : 0.0)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    
                        // Suggestion Pill - Disappears instantly
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
                        .opacity(chatViewModel.uiState == .input ? 1.0 : 0.0)
                    }
                }
                
                // Loading State - Positioned at top left (same as sparkles)
                if chatViewModel.uiState == .transitioning || chatViewModel.showThinkingView {
                    HStack(alignment: .top, spacing: 12) {
                        // Loading icon - always in same position as sparkles
                        SeamlessTransitionView(
                            uiState: chatViewModel.uiState,
                            animationPhase: chatViewModel.animationPhase
                        )
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
                            .opacity(chatViewModel.uiState == .transitioning || chatViewModel.uiState == .thinking ? 1.0 : 0.0)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                        
                        // Content area - only appears in thinking state
                        if chatViewModel.showThinkingView {
                            VStack(alignment: .leading, spacing: 12) {
                                // Status text
                                VStack(alignment: .leading, spacing: 4) {
                                    
                                    if !chatViewModel.currentTool.isEmpty {
                                        Text("Tool: \(chatViewModel.currentTool)")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.primary)
                                    } else {
                                        Text("Let me think...")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.primary)
                                            .opacity(chatViewModel.currentTool.isEmpty ? 1.0 : 0.0)
                                    }
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
                                                colors: [.purple.opacity(0.6), .pink.opacity(0.6), .orange.opacity(0.6)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 2
                                        )
                                        .blur(radius: 2)
                                )
                                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                                
                                // Dynamic tool information
                                if !chatViewModel.llmMessages.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        ForEach(chatViewModel.llmMessages.suffix(3), id: \.self) { message in
                                            HStack {
                                                Circle()
                                                    .fill(Color.green)
                                                    .frame(width: 6, height: 6)
                                                
                                                Text(message)
                                                    .font(.system(size: 11, weight: .regular))
                                                    .foregroundColor(.primary)
                                                    .lineLimit(2)
                                                
                                                Spacer()
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 4)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.secondary.opacity(0.1))
                                            )
                                            .transition(.opacity)
                                        }
                                    }
                                    .animation(.easeInOut(duration: 0.2), value: chatViewModel.llmMessages.count)
                                }
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading) // Remove fixed width, allow full width
        }
        .padding(.horizontal, 40) // Increase horizontal padding significantly
        .padding(.vertical, 20) // Increase vertical padding
        .frame(maxWidth: .infinity, alignment: .center) // Center the content with full width
        .scaleEffect(self.chatViewModel.animationPhase == 1 ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 1.0), value: self.chatViewModel.animationPhase)
        .onAppear {
            self.chatViewModel.startAnimation()
        }
        .onDisappear {
            self.chatViewModel.stopAnimation()
        }
    }
}

#Preview {
    ChatView()
        .frame(width: 500)
        .background(Color(red: 0.2, green: 0.25, blue: 0.2))
}

