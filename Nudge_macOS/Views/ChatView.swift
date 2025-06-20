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
    @State private var isAnimating: Bool = false
    
    private let log = OSLog(subsystem: "com.harshitgarg.Nudge", category: "ChatView")

    var body: some View {
        VStack(spacing: 16) {
            // Main Input Bar
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .rotationEffect(.degrees(isAnimating ? 15 : 0))

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
                    .blur(radius: isAnimating ? 8 : 4)
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
        .scaleEffect(isAnimating ? 1.01 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    ChatView()
        .frame(width: 500)
        .background(Color(red: 0.2, green: 0.25, blue: 0.2))
}

