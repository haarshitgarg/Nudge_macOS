//
//  NudgeNavClient.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 21/06/25.
//

import Foundation
import os

class NudgeNavClient: NSObject {
    private let log = OSLog(subsystem: "Harshit.Nudge", category: "NudgeNavClient")
    
    // XPC Variables
    private var connection: NSXPCConnection?
    
    override init() {
        super.init()
    }
    
    public func connect() throws {
        os_log("Connecting to NAV MCP client service...", log: log, type: .debug)
        if connection != nil {
            os_log("Already connected to NAV MCP client service", log: log, type: .info)
            return
        }
        
        connection = NSXPCConnection(serviceName: "Harshit.NavigationMCPClient")
        guard let connection = connection else {
            os_log("Failed to create NSXPCConnection", log: log, type: .error)
            throw NudgeError.connectionFailed
        }
        
        connection.remoteObjectInterface = NSXPCInterface(with: NavigationMCPClientProtocol.self)
        connection.resume()
        
        os_log("Connected to NAV MCP client service", log: log, type: .info)
    }
    
    public func sendMessageToMCPClient(_ message: String) throws {
        if connection == nil  {
            os_log("Connection is not established", log: log, type: .error)
            try self.connect()
        }
        guard let connection = connection else {
            os_log("Connection is not established", log: log, type: .error)
            throw NudgeError.connectionFailed
        }
        
        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            os_log("Error occurred while getting the proxy: %@", log: self.log, type: .error, error.localizedDescription)
        } as? NavigationMCPClientProtocol
        
        proxy?.sendUserMessage(message)
        
        os_log("Message sent to MCP client: %@", log: log, type: .debug, message)
    }
}
