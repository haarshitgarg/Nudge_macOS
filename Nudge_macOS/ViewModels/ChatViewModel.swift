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
    private var shortcutManager = ShortcutManager.shared
    private var delegateID: UUID? = nil
    
    @Published public var xcpMessage: [XPCMessage] = []
    
    init() {
        nudgeClient.connect()
        self.delegateID = shortcutManager.addDelegate(self)
    }
    
    deinit {
        guard let delegateID = self.delegateID else {
            return
        }
        shortcutManager.removeDelegate(delegateID)
    }
    
    public func fetchMessages() async throws {
        let reply = try await nudgeClient.sendMessage(message: "Sending dummy Message")
        self.xcpMessage.append(XPCMessage(content: reply))
    }
    
}

// Making chat view model as a delegate for ShortcutManager
extension ChatViewModel: ShortcutManagerDelegateProtocol {
    nonisolated func userRequestedToggleChat() {
        DispatchQueue.main.async {
            PanelManager.shared.togglePanel()
        }
    }
}
    
