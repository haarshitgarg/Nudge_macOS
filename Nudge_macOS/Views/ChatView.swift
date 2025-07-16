//
//  ChatView.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 20/06/25.
//

import SwiftUI
import os

struct ChatView: View {
    @StateObject private var chatViewModel: ChatViewModel = ChatViewModel.shared
    
    private let log = OSLog(subsystem: "Harshit.Nudge", category: "ChatView")
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main container with consistent height
            ZStack(alignment: .topLeading) {
                HStack {
                    if chatViewModel.uiState == .input {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                        InputView(textFieldText: "Type to Nudge")
                    }
                    else {
                       // TODO: Add a thinking loop here. Probably my LoadingView
                        InputView(textFieldText: "Press Esc to cancel")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Background()
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
                            lineWidth: 4
                        )
                        .blur(radius: 2)
                )
            }
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .center)
            
            // Agent bubble container
            AgentBubbleContainerView(chatViewModel: chatViewModel)
                .frame(maxWidth: 300, alignment: .leading)
        }
        .padding(.horizontal, 40) // Increase horizontal padding significantly
        .padding(.vertical, 10) // Increase vertical padding
        .frame(maxWidth: .infinity, alignment: .center) // Center the content with full width
    }
}

#Preview {
    ChatView()
        .frame(width: 500, height: 600)
        .background(Color(red: 0.2, green: 0.25, blue: 0.2))
}

