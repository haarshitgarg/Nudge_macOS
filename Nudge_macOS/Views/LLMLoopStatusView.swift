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
    
    @State private var animationPhase: Double = 0
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .rotationEffect(.degrees(animationPhase))
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: animationPhase)
                
                Text("LLM Processing...")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Loading indicator
                ProgressView()
                    .scaleEffect(0.8)
            }
            
            // Current Tool Section
            if !currentTool.isEmpty {
                HStack {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.callout)
                        .foregroundColor(.orange)
                    
                    Text("Using tool: \(currentTool)")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.orange.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Recent Messages Section
            if !llmMessages.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Activity:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(llmMessages.suffix(3).indices, id: \.self) { index in
                                Text(llmMessages.suffix(3)[index])
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(.gray.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                    }
                    .frame(maxHeight: 80)
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.blue.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            withAnimation {
                animationPhase = 360
            }
        }
    }
}

#Preview {
    LLMLoopStatusView(
        currentTool: "get_ui_elements",
        llmMessages: [
            "Goal identified: open_safari",
            "Knowledge updated: Safari application is being located",
            "Tool called: get_ui_elements with arguments: {...}"
        ]
    )
    .frame(width: 400)
    .padding()
}