//
//  NudgeXMLManager.swift
//  NavigationMCPClient
//
//  Created by Harshit Garg on 12/08/25.
//

import Foundation
import os
import NudgeLibrary

class NudgeXMLManager {
    private static let log = OSLog(subsystem: "Harshit.Nudge", category: "NudgeXMLManager")
    
    /// Gets the path to the Nudge.xml file
    private static var xmlFilePath: URL {
        get throws {
            let fileManager = FileManager.default
            guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                throw NudgeError.documentsDirectoryNotFound
            }
            let nudgeDirectoryPath = documentsPath.appendingPathComponent("Nudge")
            return nudgeDirectoryPath.appendingPathComponent("Nudge.xml")
        }
    }
    
    /// Gets the path to the Nudge directory
    private static var nudgeDirectoryPath: URL {
        get throws {
            let fileManager = FileManager.default
            guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                throw NudgeError.documentsDirectoryNotFound
            }
            return documentsPath.appendingPathComponent("Nudge")
        }
    }
    
    /// Ensures the Nudge directory and XML file exist
    static func ensureXMLFileExists() throws {
        let fileManager = FileManager.default
        let directoryPath = try nudgeDirectoryPath
        let filePath = try xmlFilePath
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: directoryPath.path) {
            try fileManager.createDirectory(at: directoryPath, withIntermediateDirectories: true, attributes: nil)
            os_log("Created Nudge directory at: %@", log: log, type: .info, directoryPath.path)
        }
        
        // Create XML file if it doesn't exist
        if !fileManager.fileExists(atPath: filePath.path) {
            let initialContent = """
<?xml version="1.0" encoding="UTF-8"?>
<nudge-memory>
</nudge-memory>
"""
            try initialContent.write(to: filePath, atomically: true, encoding: .utf8)
            os_log("Created Nudge.xml file at: %@", log: log, type: .info, filePath.path)
        }
    }
    
    /// Reads the entire XML content from the file
    static func readXMLContent() throws -> String {
        try ensureXMLFileExists()
        let filePath = try xmlFilePath
        return try String(contentsOf: filePath, encoding: .utf8)
    }
    
    /// Writes XML content to the file
    static func writeXMLContent(_ content: String) throws {
        let filePath = try xmlFilePath
        try content.write(to: filePath, atomically: true, encoding: .utf8)
        os_log("Updated Nudge.xml file", log: log, type: .info)
    }
    
    /// Appends content to a specific XML tag
    /// - Parameters:
    ///   - tag: The XML tag name (e.g., "things_to_remember")
    ///   - content: The content to append
    static func appendToXMLTag(_ tag: String, content: String) throws {
        var xmlContent = try readXMLContent()
        
        let openTag = "<\(tag)>"
        let closeTag = "</\(tag)>"
        
        // Check if the tag already exists
        if let startRange = xmlContent.range(of: openTag),
           let endRange = xmlContent.range(of: closeTag) {
            
            // Extract existing content between tags
            let existingContent = String(xmlContent[startRange.upperBound..<endRange.lowerBound])
            let trimmedContent = existingContent.trimmingCharacters(in: .whitespacesAndNewlines)
            let newItem = trimmedContent.isEmpty ? "\n\(content)\n" : "\n\(trimmedContent)\n\(content)\n"
            
            // Replace content between tags
            xmlContent = xmlContent.replacingCharacters(
                in: startRange.upperBound..<endRange.lowerBound,
                with: newItem
            )
        } else {
            // Add new tag section before closing </nudge-memory>
            let newSection = "\(openTag)\n\(content)\n\(closeTag)\n"
            if let insertPoint = xmlContent.range(of: "</nudge-memory>") {
                xmlContent = xmlContent.replacingCharacters(
                    in: insertPoint.lowerBound..<insertPoint.lowerBound,
                    with: newSection
                )
            } else {
                throw NudgeError.invalidXMLStructure
            }
        }
        
        try writeXMLContent(xmlContent)
    }
    
    /// Reads content from a specific XML tag
    /// - Parameter tag: The XML tag name
    /// - Returns: The content within the tag, or empty string if tag doesn't exist
    static func readFromXMLTag(_ tag: String) throws -> String {
        let xmlContent = try readXMLContent()
        let openTag = "<\(tag)>"
        let closeTag = "</\(tag)>"
        
        guard let startRange = xmlContent.range(of: openTag),
              let endRange = xmlContent.range(of: closeTag) else {
            return ""
        }
        
        let content = String(xmlContent[startRange.upperBound..<endRange.lowerBound])
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Convenience method to add a memory item
    /// - Parameter content: The memory content to add
    static func addMemoryItem(_ content: String) throws {
        try appendToXMLTag("things_to_remember", content: "- \(content)")
    }
    
    /// Convenience method to add a note item
    /// - Parameter content: The note content to add
    static func addNoteItem(_ content: String) throws {
        try appendToXMLTag("notes", content: "- \(content)")
    }
}