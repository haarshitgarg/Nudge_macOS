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
    
    public var getDescription: String {
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
        }
    }
}
