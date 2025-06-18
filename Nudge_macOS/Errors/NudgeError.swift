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
    
    public var getDescription: String {
        switch self {
        case .connectionFailed:
            return "Failed to connect to the Nudge service."
        case .invalidResponse:
            return "Received an invalid response from the Nudge service."
        }
    }
}
