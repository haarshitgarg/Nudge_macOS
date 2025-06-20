//
//  NudgeClient.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 18/06/25.
//

import Foundation
import os

class NudgeClient {
    public static let shared = NudgeClient()
    private var connection: NSXPCConnection?
    
    private let log = OSLog(subsystem: "Harshit.NudgeClient", category: "NudgeClient")
    
    private init() {
        
    }
    
    public func connect() throws {
        os_log("Connecting to NudgeHelper service...", log: log, type: .debug)
        if connection != nil {
            os_log("Already connected to NudgeHelper service", log: log, type: .info)
            return
        }
        connection = NSXPCConnection(serviceName: "Harshit.NudgeHelper")
        guard let connection = connection else {
            os_log("Failed to create NSXPCConnection", log: log, type: .error)
            throw NudgeError.connectionFailed
        }
        connection.remoteObjectInterface = NSXPCInterface(with: NudgeHelperProtocol.self)
        connection.exportedInterface = NSXPCInterface(with: NudgeClientProtocol.self)
        connection.exportedObject = self
        
        connection.resume()
        
//        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
//            os_log("Error occurred while connecting to NudgeHelper: %@", log: self.log, type: .error, error.localizedDescription)
//        } as? NudgeHelperProtocol
//        proxy?.setClient(self.xpcResponseClient)
        os_log("Connected to NudgeHelper service", log: log, type: .info)
    }
    
    public func sendMessage(message: String) async throws -> String {
        guard let connection = connection else {
            os_log("Connection is not established", log: log, type: .error)
            throw NudgeError.connectionFailed
        }
        
        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            os_log("Error occurred while sending message: %@", log: self.log, type: .error, error.localizedDescription)
        } as? NudgeHelperProtocol
        
        let reply: String = try await withCheckedThrowingContinuation { continuation in
            proxy?.sendChatMessage(message: message) { response in
                os_log("Received reply from NudgeHelper: %@", log: self.log, type: .info, response)
                continuation.resume(returning: response)
            }
        }
        
        return reply;
        
    }
    
}

extension NudgeClient: NudgeClientProtocol {
    func notifyShortcutPressed() {
        os_log("Keyboard shortcut pressed, Opening chat panel...", log: log, type: .info)
        // Toggle open chat panel here later
    }
}
