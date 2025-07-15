//
//  InputView.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 15/07/25.
//

import OSLog
import SwiftUI

// Input view for the Nudge macOS application
struct InputView: View {
    let log = OSLog(subsystem: "Harshit.Nudge", category: "InputView")
    var chatViewModel: ChatViewModel = ChatViewModel.shared
    @State private var query: String = ""
    
    private func sendAction() {
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
    
    var body: some View {
        VStack(spacing: 16) {
            // Main Input Bar
            HStack(spacing: 12) {
                // TEXT FIELD - Disappears instantly
                TextField("Type to Nudge", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20))
                    .disabled(!chatViewModel.uiState.isInteractionEnabled)
                    .opacity(chatViewModel.uiState == .input ? 1.0 : 0.0)
                    .onSubmit {sendAction()}
                
                // SPEECH BUTTON - Disappears instantly
                Button(action: { os_log("Not implemented yet", log: log, type: .debug)}) {
                    Image(systemName: "mic.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(!chatViewModel.uiState.isInteractionEnabled)
                .opacity(chatViewModel.uiState == .input ? 1.0 : 0.0)
            }
            
            //.shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            
            
        }
    }
}

#Preview {
    InputView()
}

