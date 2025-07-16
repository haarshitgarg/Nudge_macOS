//
//  NavigationMCPClientCallbackProtocol.swift
//  NavigationMCPClient
//
//  Created by Harshit Garg on 06/07/25.
//

import Foundation

/// Protocol for callbacks from NavigationMCPClient to the main app
@objc public protocol NavigationMCPClientCallbackProtocol {
    /// Called when the LLM loop starts processing
    func onLLMLoopStarted()
    
    /// Called when the LLM loop finishes processing
    func onLLMLoopFinished()
    
    /// Called when a tool is called during processing
    /// - Parameters:
    ///   - toolName: Name of the tool being called
    ///   - arguments: Tool arguments as JSON string
    func onToolCalled(toolName: String)
    
    /// Called when the LLM sends a message or response
    /// - Parameter message: The message from the LLM
    func onLLMMessage(_ message: String)
    
    /// Called when the LLM request for user input
    /// - Parameter message: The message from the LLM
    func onUserMessage(_ message: String)
    
    /// Called when an error occurs during processing
    /// - Parameter error: Description of the error
    func onError(_ error: String)
}
