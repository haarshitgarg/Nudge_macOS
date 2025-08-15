//
//  CommandParser.swift
//  NavigationMCPClient
//
//  Created by Harshit Garg on 12/08/25.
//

import Foundation

enum CommandType: String, CaseIterable {
    case memory = "memory"
    case note = "note"
    case initialise = "init"
    
    var xmlTag: String {
        switch self {
        case .memory:
            return "things_to_remember"
        case .note:
            return "notes"
        case .initialise:
            return "apps"
        }
    }
}

struct ParsedCommand {
    let type: CommandType
    let content: String
}

class CommandParser {
    
    /// Parses a message to detect slash commands and extract their content
    /// - Parameter message: The user input message
    /// - Returns: ParsedCommand if a valid command is found, nil otherwise
    static func parseCommand(_ message: String) -> ParsedCommand? {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if message starts with a slash
        guard trimmedMessage.hasPrefix("/") else {
            return nil
        }
        
        // Try to match each command type
        for commandType in CommandType.allCases {
            let commandPrefix = "/\(commandType.rawValue)"
            
            if trimmedMessage.hasPrefix(commandPrefix) {
                let content: String
                
                if trimmedMessage == commandPrefix {
                    // Just the command without content (e.g., "/memory")
                    content = ""
                } else if trimmedMessage.hasPrefix("\(commandPrefix) ") {
                    // Command with content (e.g., "/memory some content")
                    content = String(trimmedMessage.dropFirst(commandPrefix.count + 1))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    // Command followed by non-space character (invalid format)
                    continue
                }
                
                return ParsedCommand(type: commandType, content: content)
            }
        }
        
        return nil
    }
    
    /// Validates that a parsed command has the required content
    /// - Parameter command: The parsed command to validate
    /// - Returns: True if valid, false otherwise
    static func validateCommand(_ command: ParsedCommand) -> Bool {
        switch command.type {
        case .memory:
            return !command.content.isEmpty
        case .note:
            return !command.content.isEmpty
        case .initialise:
            return command.content.isEmpty // Initialise command does not require content
        }
    }
}


