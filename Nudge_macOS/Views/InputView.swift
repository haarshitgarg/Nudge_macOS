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
    @State public var textFieldText: String
    let log = OSLog(subsystem: "Harshit.Nudge", category: "InputView")
    var chatViewModel: ChatViewModel = ChatViewModel.shared
    @State private var query: String = ""
    
    private func changeTextFieldText(_ newText: String) {
        self.textFieldText = newText
    }
    
    private func sendAction() {
        guard chatViewModel.uiState.isInteractionEnabled else { return }
        DispatchQueue.main.async {
            let message = query
            query = ""
            Task {
                do {
                    if chatViewModel.uiState == .input {
                        try await self.chatViewModel.sendMessage(message)
                    }
                    else if chatViewModel.uiState == .responding {
                        try await self.chatViewModel.respondLLM(message)
                    }

                } catch { os_log("Failed to send message: %@", log: log, type: .fault, error.localizedDescription) }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Main Input Bar
            HStack(spacing: 12) {
                // TEXT FIELD - Disappears instantly
                TextField(self.textFieldText, text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20))
                    .disabled(!chatViewModel.uiState.isInteractionEnabled)
                    .onSubmit {sendAction()}
                
                // SPEECH BUTTON - Triggers debug logging when pressed
                Button(action: {
                    // For now, the microphone button triggers agent state debug logging
                    // This is useful for UI tests and debugging
                    let formatter = DateFormatter()
                    formatter.dateFormat = "HH:mm:ss"
                    let timestamp = formatter.string(from: Date())
                    let debugMessage = "__DEBUG_DUMP_STATE_FOR_TEST__MicButton_\(timestamp)"
                    
                    Task {
                        do {
                            try await self.chatViewModel.sendMessage(debugMessage)
                            os_log("🎤 Debug state dump triggered via microphone button", log: log, type: .info)
                        } catch {
                            os_log("Failed to send debug message: %@", log: log, type: .fault, error.localizedDescription)
                        }
                    }
                }) {
                    Image(systemName: "mic.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            //.shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            
            
        }
    }
}

#Preview {
    InputView(textFieldText: "Type to Nudge")
}

