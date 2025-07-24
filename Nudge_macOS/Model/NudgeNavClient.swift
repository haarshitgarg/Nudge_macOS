//
//  NudgeNavClient.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 21/06/25.
//

import Foundation
import os

// Protocol for NudgeNavClient to communicate with ChatViewModel
@MainActor
protocol NudgeNavClientDelegate: AnyObject {
    func onLLMLoopStarted()
    func onLLMLoopFinished()
    func onToolCalled(toolName: String)
    func onLLMMessage(_ message: String)
    func onUserMessage(_ message: String)
    func onError(_ error: String)
}

class NudgeNavClient: NSObject {
    private let log = OSLog(subsystem: "Harshit.Nudge", category: "NudgeNavClient")
    
    // XPC Variables
    private var connection: NSXPCConnection?
    
    // Callback delegate
    weak var delegate: NudgeNavClientDelegate?
    
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
        
        let serviceInterface = NSXPCInterface(with: NavigationMCPClientProtocol.self)
        let callbackInterface = NSXPCInterface(with: NavigationMCPClientCallbackProtocol.self)
        serviceInterface.setInterface(callbackInterface, for: #selector(NavigationMCPClientProtocol.setCallbackClient(_:)), argumentIndex: 0, ofReply: false)
        
        connection.remoteObjectInterface = serviceInterface
        connection.exportedInterface = callbackInterface
        connection.exportedObject = self
        connection.resume()
        
        os_log("Connected to NAV MCP client service", log: log, type: .info)
        
        // Register callback client
        os_log("About to register callback client", log: log, type: .info)
        registerCallbackClient()
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
        
        proxy?.sendUserMessage(message, threadId: "Thread 1")
        
        os_log("Message sent to MCP client: %@", log: log, type: .debug, message)
    }
    
    public func respondToAgent(_ message: String) throws {
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
        
        proxy?.respondLLMAgent(message, threadId: "Thread 1")
    }
    
    public func interruptAgent() throws {
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
        
        proxy?.interruptAgentExecution()
    }
    
    public func registerCallbackClient() {
        guard let connection = connection else {
            os_log("Connection is not established", log: log, type: .error)
            return
        }
        
        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            os_log("Error occurred while registering callback: %@", log: self.log, type: .error, error.localizedDescription)
        } as? NavigationMCPClientProtocol
        
        proxy?.setCallbackClient(self)
        os_log("Registered callback client", log: log, type: .debug)
    }
    
    public func sendPing() throws {
        guard let connection = connection else {
            os_log("Connection is not established", log: log, type: .error)
            throw NudgeError.connectionFailed
        }
        
        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            os_log("Error occurred while sending message: %@", log: self.log, type: .error, error.localizedDescription)
        } as? NavigationMCPClientProtocol
        
        proxy?.ping("Hello")
        
    }
    
    func disconnect() {
        os_log("Disconnecting the xpc connection with nav client", log: log, type: .debug)
        os_log("Deinitialising the NudgeNavClient", log: log, type: .debug)
        let proxy = connection?.remoteObjectProxyWithErrorHandler { error in
            os_log("Error occured while disconnection: %@", log: self.log, type: .debug, error.localizedDescription)
        } as? NavigationMCPClientProtocol
        proxy?.terminate()
        self.connection?.invalidate()
    }
    
    deinit {
        self.disconnect()
    }
}

// MARK: - NavigationMCPClientCallbackProtocol Implementation
extension NudgeNavClient: NavigationMCPClientCallbackProtocol {
    @objc func onLLMLoopStarted() {
        os_log("LLM loop started via XPC callback", log: log, type: .info)
        Task { @MainActor in
            self.delegate?.onLLMLoopStarted()
        }
    }
    
    @objc func onLLMLoopFinished() {
        os_log("LLM loop finished", log: log, type: .debug)
        Task { @MainActor in
            delegate?.onLLMLoopFinished()
        }
    }
    
    @objc func onToolCalled(toolName: String) {
        os_log("Tool called: %@", log: log, type: .debug, toolName)
        Task { @MainActor in
            delegate?.onToolCalled(toolName: toolName)
        }
    }
    
    @objc func onLLMMessage(_ message: String) {
        os_log("LLM message received via XPC: %@", log: log, type: .info, message)
        Task { @MainActor in
            self.delegate?.onLLMMessage(message)
        }
    }
    
    @objc func onUserMessage(_ message: String) {
        os_log("User message received: %@", log: log, type: .info, message)
        
        Task { @MainActor in
            self.delegate?.onUserMessage(message)
            
        }
        
        // TODO: Handle request from LLM for user input
    }
    
    @objc func onError(_ error: String) {
        os_log("Error: %@", log: log, type: .error, error)
        Task { @MainActor in
            delegate?.onError(error)
        }
    }
}
