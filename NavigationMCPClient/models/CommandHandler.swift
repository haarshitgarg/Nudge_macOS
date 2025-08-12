//
//  CommandHandler.swift
//  NavigationMCPClient
//
//  Created by Harshit Garg on 12/08/25.
//

import Foundation
import os
import NudgeLibrary

/// Protocol for command handlers
protocol CommandHandlerProtocol {
    func execute(content: String) throws -> String
}

/// Handler for memory commands (/memory)
class MemoryCommandHandler: CommandHandlerProtocol {
    private let log = OSLog(subsystem: "Harshit.Nudge", category: "MemoryCommandHandler")
    
    func execute(content: String) throws -> String {
        os_log("Processing memory command with content: %@", log: log, type: .info, content)
        
        try NudgeXMLManager.addMemoryItem(content)
        
        os_log("Memory item saved successfully", log: log, type: .info)
        return "Memory saved successfully to ~/Documents/Nudge/Nudge.xml"
    }
}

/// Handler for note commands (/note)
class NoteCommandHandler: CommandHandlerProtocol {
    private let log = OSLog(subsystem: "Harshit.Nudge", category: "NoteCommandHandler")
    
    func execute(content: String) throws -> String {
        os_log("Processing note command with content: %@", log: log, type: .info, content)
        
        try NudgeXMLManager.addNoteItem(content)
        
        os_log("Note item saved successfully", log: log, type: .info)
        return "Note saved successfully to ~/Documents/Nudge/Nudge.xml"
    }
}

/// Central dispatcher for handling parsed commands
class CommandDispatcher {
    private static let log = OSLog(subsystem: "Harshit.Nudge", category: "CommandDispatcher")
    
    /// Map of command types to their handlers
    private static let handlers: [CommandType: CommandHandlerProtocol] = [
        .memory: MemoryCommandHandler(),
        .note: NoteCommandHandler()
    ]
    
    /// Handles a parsed command by delegating to the appropriate handler
    /// - Parameter command: The parsed command to handle
    /// - Returns: Success message from the handler
    /// - Throws: NudgeError if command is unsupported or handler fails
    static func handle(_ command: ParsedCommand) throws -> String {
        os_log("Dispatching command: %@ with content: %@", log: log, type: .info, 
               command.type.rawValue, command.content)
        
        guard let handler = handlers[command.type] else {
            os_log("Unsupported command type: %@", log: log, type: .error, command.type.rawValue)
            throw NudgeError.unsupportedCommand(command.type.rawValue)
        }
        
        return try handler.execute(content: command.content)
    }
    
    /// Processes a user message and handles it if it's a valid command
    /// - Parameter message: The user input message
    /// - Returns: Tuple containing (isCommand: Bool, result: String?)
    ///   - isCommand: true if message was a command, false otherwise
    ///   - result: success message if command executed, nil if not a command
    /// - Throws: NudgeError for command validation or execution failures
    static func processMessage(_ message: String) throws -> (isCommand: Bool, result: String?) {
        guard let command = CommandParser.parseCommand(message) else {
            // Not a command
            return (isCommand: false, result: nil)
        }
        
        // Validate command has required content
        guard CommandParser.validateCommand(command) else {
            let errorMessage = getValidationErrorMessage(for: command.type)
            throw NudgeError.invalidCommandContent(errorMessage)
        }
        
        // Execute command
        let result = try handle(command)
        return (isCommand: true, result: result)
    }
    
    /// Gets user-friendly validation error messages for different command types
    private static func getValidationErrorMessage(for commandType: CommandType) -> String {
        switch commandType {
        case .memory:
            return "Memory command requires content. Usage: /memory <your content here>"
        case .note:
            return "Note command requires content. Usage: /note <your note here>"
        }
    }
}