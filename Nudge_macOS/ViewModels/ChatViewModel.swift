//
//  ChatViewModel.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 18/06/25.
//

import Foundation
import SwiftUI
import os

@MainActor
class ChatViewModel: ObservableObject {
    public static let shared = ChatViewModel()
    
    let log = OSLog(subsystem: "com.harshitgarg.nudge", category: "ChatViewModel")
    
    public let nudgeClient = NudgeClient()
    
    @Published public var xcpMessage: [XPCMessage] = []
    @Published public var isChatVisible: Bool = false
    @Published public var isAccessibleDialog: Bool = false
    @Published public var animationPhase: Int = 0
    
    private var animationTimer: Timer?
    private var animationCounter: Int = 0
    private let maxAnimationCount: Int = 10
    
    
    private init() {
        do { try nudgeClient.connect()
        } catch { os_log("Failed to connect to NudgeClient: %@", log: log, type: .fault, error.localizedDescription) }
    }
    
    public func sendMessage(_ msg: String) async throws {
        let reply = try await nudgeClient.sendMessage(message: msg)
        self.xcpMessage.append(XPCMessage(content: reply))
    }
    
    public func startAnimation() {
        animationTimer?.invalidate()
        animationCounter = 0
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.animationCounter += 1
                if self.animationCounter >= self.maxAnimationCount {
                    self.stopAnimation()
                } else {
                    self.animationPhase = self.animationPhase % 2 == 0 ? 1 : 0
                }
            }

        }
    }
    
    public func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        animationPhase = 0
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

