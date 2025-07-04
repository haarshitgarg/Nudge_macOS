//
//  NudgeClient.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 18/06/25.
//

import Foundation
import ApplicationServices
import os

@MainActor
protocol NudgeDelegateProtocol {
    func notifyShortcutPressed()
}


class NudgeClient: NSObject {
    private var connection: NSXPCConnection?
    
    private let log = OSLog(subsystem: "Harshit.Nudge", category: "NudgeClient")
    
    override init() {
        
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
        
        let helperInterface = NSXPCInterface(with: NudgeHelperProtocol.self)
        let clientInterface = NSXPCInterface(with: NudgeClientProtocol.self)
        helperInterface.setInterface(clientInterface, for: #selector(NudgeHelperProtocol.setClient(_:)), argumentIndex: 0, ofReply: false)
        
        connection.remoteObjectInterface = helperInterface
        connection.exportedInterface = clientInterface
        connection.exportedObject = self
        connection.resume()
        
        os_log("Connected to NudgeHelper service", log: log, type: .info)
        
        registerClient()
    }
    
    public func registerClient() {
        guard let connection = connection else {
            os_log("Connection is not established", log: log, type: .error)
            return
        }
        let helper = connection.remoteObjectProxyWithErrorHandler { error in
            os_log("Error occurred while registering client: %@", log: self.log, type: .error, error.localizedDescription)
        } as? NudgeHelperProtocol
        
        helper?.setClient(self)
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
    
    

    deinit {
        self.disconnect()
    }
    
    public func disconnect() {
        os_log("Disconnecting from NudgeHelper service...", log: log, type: .debug)
        let proxy = connection?.remoteObjectProxyWithErrorHandler { error in
            os_log("Error occurred while disconnecting: %@", log: self.log, type: .error, error.localizedDescription)
        } as? NudgeHelperProtocol
        proxy?.terminate()
        self.connection?.invalidate()
    }
    
}

extension NudgeClient: NudgeClientProtocol {
    func notifyShortcutPressed() {
        os_log("Keyboard shortcut pressed, Opening chat panel...", log: log, type: .info)
        // Toggle open chat panel here later
    }
    
}
