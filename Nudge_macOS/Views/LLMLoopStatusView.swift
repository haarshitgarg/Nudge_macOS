//
//  LLMLoopStatusView.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 06/07/25.
//

import SwiftUI

struct LLMLoopStatusView: View {
    let currentTool: String
    let llmMessages: [String]
    let uiState: UITransitionState
    let transitionProgress: Double
    
    @State private var animationPhase: Double = 0
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Loading animation (always on left)
            LoadingView()
                .loadingTransition(
                    uiState: uiState,
                    progress: transitionProgress
                )
            
            // Content area (appears beside loading)
            VStack(alignment: .leading, spacing: 12) {
                // Status text
                VStack(alignment: .leading, spacing: 4) {
                    Text("LLM IS THINKING...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    
                    if !currentTool.isEmpty {
                        Text("Tool: \(currentTool)")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondary)
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
                
                // Dynamic tool information panel
                if !llmMessages.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(llmMessages.suffix(3), id: \.self) { message in
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
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: llmMessages.count)
                }
            }
            .contentTransition(
                uiState: uiState,
                progress: transitionProgress
            )
            
            Spacer()
        }
        .frame(height: 48)
    }
}

#Preview {
    LLMLoopStatusView(
        currentTool: "get_ui_elements",
        llmMessages: [
            "Goal identified: open_safari",
            "Knowledge updated: Safari application is being located",
            "Tool called: get_ui_elements with arguments: {...}"
        ],
        uiState: .thinking,
        transitionProgress: 1.0
    )
    .frame(width: 400)
    .padding()
}
