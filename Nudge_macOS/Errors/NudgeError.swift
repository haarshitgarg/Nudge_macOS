//
//  NudgeError.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 18/06/25.
//
import Foundation

public enum NudgeError: Error, Sendable {
    case connectionFailed
    case invalidResponse
    case cannotGetTools
    case cannotParseToolArguments
    case openAIClientNotInitialized
    case noMessageFromOpenAI
    case cannotCreateMessageForOpenAI
    case noGoalFound
    case agentNotInitialized(description: String)
    case failedToSendMessageToOpenAI(descripiton: String)
    
    case agentStateVarMissing(description: String)
    case toolcalllistempty
    
    public var localizedDescription: String {
        switch self {
        case .connectionFailed:
            return "Failed to connect to the Nudge service."
        case .invalidResponse:
            return "Received an invalid response from the Nudge service."
        case .cannotGetTools:
            return "Unable to retrieve tools from the server."
        case .cannotParseToolArguments:
            return "Failed to parse tool arguments from the server."
        case .openAIClientNotInitialized:
            return "OpenAI client is not initialized."
        case .noMessageFromOpenAI:
            return "No message received from openAI"
        case .cannotCreateMessageForOpenAI:
            return "Cannot create a message for OpenAI"
        case .noGoalFound:
            return "LLM did not return any goal"
        case .agentNotInitialized(let description):
            return "Agent was not initialized properly because: \(description)"
        case .failedToSendMessageToOpenAI(let description):
            return "Failed to send message to OpenAI because: \(description)"
        case .agentStateVarMissing(let description):
            return "Agent state variable is missing: \(description)"
        case .toolcalllistempty:
            return "Tool call list is empty"
        }
    }
}
