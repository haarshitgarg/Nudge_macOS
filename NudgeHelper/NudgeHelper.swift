//
//  NudgeHelper.swift
//  NudgeHelper
//
//  Created by Harshit Garg on 18/06/25.
//

import Foundation
import os

/// This object implements the protocol which we have defined. It provides the actual behavior for the service. It is 'exported' by the service to make it available to the process hosting the service over an NSXPCConnection.
class NudgeHelper: NSObject, NudgeHelperProtocol {
    private let log = OSLog(subsystem: "Harshit.NudgeHelper", category: "NudgeHelper")
    
    private let messageQueue = DispatchQueue(label: "com.harshit.nudgehelper.messagequeue", qos: .userInitiated, attributes: .concurrent)
    private var client: NudgeClientProtocol? = nil
    
    override init() {
        super.init()
        os_log("NudgeHelper initialized", log: log, type: .info)
    }
    
    @objc func sendChatMessage(message: String, with reply: @escaping (String) -> Void) {
        // Handle the chat message here
        os_log("Received chat message: %@", log: log, type: .info, message)
        messageQueue.async {
            let processedMessage = self.processMessaage(message)
            reply("Received and processed your message!, \(processedMessage)") // Indicate success
            os_log("Processed chat message and replied back", log: self.log, type: .info)
        }
    }
    
    @objc func setClient(_ client: NudgeClientProtocol) {
        // This method can be used to set the client if needed
        os_log("Client set for NudgeHelper", log: log, type: .info)
        self.client = client
    }
    
    private func processMessaage(_ message: String) -> String {
        sleep(5) // Simulating some processing delay
        let processedMessge = message + " - Processed by NudgeHelper"
        return processedMessge
    }
    
}

