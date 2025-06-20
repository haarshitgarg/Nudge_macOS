//
//  ChatViewModel.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 18/06/25.
//

import Foundation
import os

@MainActor
class ChatViewModel: ObservableObject {
    let log = OSLog(subsystem: "com.harshitgarg.nudge", category: "ChatViewModel")
    
    private var nudgeClient = NudgeClient.shared
    
    @Published public var xcpMessage: [XPCMessage] = []
    
    init() {
        do { try nudgeClient.connect()
        } catch { os_log("Failed to connect to NudgeClient: %@", log: log, type: .fault, error.localizedDescription) }
    }
    
    public func fetchMessages() async throws {
        let reply = try await nudgeClient.sendMessage(message: "Sending dummy Message")
        self.xcpMessage.append(XPCMessage(content: reply))
    }
}
