//
//  ChatViewModel.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 18/06/25.
//

import Foundation

@MainActor
class ChatViewModel: ObservableObject {
    private var nudgeClient = NudgeClient.shared
    
    @Published public var xcpMessage: [XPCMessage] = []
    
    init() {
        nudgeClient.connect()
    }
    
    public func fetchMessages() async throws {
        let reply = try await nudgeClient.sendMessage(message: "Sending dummy Message")
        self.xcpMessage.append(XPCMessage(content: reply))
    }
}
