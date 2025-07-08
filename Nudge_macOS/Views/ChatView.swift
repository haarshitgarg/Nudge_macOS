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
        ZStack {
            // Input View
            if chatViewModel.showInputView {
                VStack(spacing: 16) {
                    // Main Input Bar
                    HStack(spacing: 12) {
                        // IMAGE EVERYTING. TO PUT LOGO HERE
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                            .scaleEffect(self.chatViewModel.animationPhase == 1 ? 1.2 : 1.0)
                            .rotationEffect(.degrees(self.chatViewModel.animationPhase == 1 ? 10 : 0))
                            .animation(.easeInOut(duration: 1), value: chatViewModel.animationPhase)
                        
                        // TEXT FIELD EVERYTHIN
                        TextField("Type to Nudge", text: $query)
                            .textFieldStyle(.plain)
                            .font(.system(size: 20))
                            .disabled(!chatViewModel.uiState.isInteractionEnabled)
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
                        
                        // SPEECH BUTTON. NOT IMPLEMENTED YET
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
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous)))
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
                        .blur(radius: 4))
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
                .inputTransition(
                    uiState: chatViewModel.uiState,
                    progress: chatViewModel.transitionProgress
                )
            }
            
            // Thinking View
            if chatViewModel.showThinkingView {
                LLMLoopStatusView(
                    currentTool: chatViewModel.currentTool,
                    llmMessages: chatViewModel.llmMessages,
                    uiState: chatViewModel.uiState,
                    transitionProgress: chatViewModel.transitionProgress
                )
                .thinkingTransition(
                    uiState: chatViewModel.uiState,
                    progress: chatViewModel.transitionProgress
                )
            }
        }
        .padding()
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

