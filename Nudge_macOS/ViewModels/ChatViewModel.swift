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
    public static let shared = ChatViewModel()
    
    let log = OSLog(subsystem: "com.harshitgarg.nudge", category: "ChatViewModel")
    
    public let nudgeClient = NudgeClient()
    
    @Published public var xcpMessage: [XPCMessage] = []
    @Published public var isChatVisible: Bool = false
    @Published public var isAccessibleDialog: Bool = false
    
    private init() {
        do { try nudgeClient.connect()
        } catch { os_log("Failed to connect to NudgeClient: %@", log: log, type: .fault, error.localizedDescription) }
    }
    
    public func sendMessage(_ msg: String) async throws {
        let reply = try await nudgeClient.sendMessage(message: msg)
        self.xcpMessage.append(XPCMessage(content: reply))
    }
    
    deinit {
        os_log("ChatViewModel is being deinitialized", log: log, type: .debug)
    }
}

extension ChatViewModel: NudgeDelegateProtocol {
    func notifyShortcutPressed() {
        os_log("Shortcut pressed notification received in ChatViewModel", log: log, type: .info)
    }
}

