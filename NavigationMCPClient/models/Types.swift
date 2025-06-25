//
//  Types.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 21/06/25.
//

import Foundation
import Logging
import MCP
import System

let logger = Logger(label: "Harshit.Nudge")

enum MCPTransport: String, Codable, Sendable {
    case stdio
    case http
    case https
    
    var description: String {
        switch self {
        case .stdio:
            return "Standard Input/Output"
        case .http:
            return "HTTP"
        case .https:
            return "HTTPS"
        }
    }
}

struct MCPServer: Codable, Sendable, Hashable {
    private let id: UUID
    public let transport: MCPTransport
    public let address: String?
    private var stream: Bool = true
    public let name: String
    
    init(name: String, transport: MCPTransport, address: String?, stream: Bool = true) {
        self.id = UUID()
        self.transport = transport
        self.address = address
        self.stream = stream
        self.name = name
    }
}

// MARK: - Server Configuration Models
struct ServerConfig: Codable, Sendable {
    let name: String
    let address: String?
    let transport: String
    let requiresAccessibility: Bool
    let clientName: String 
}

struct ServersConfiguration: Codable, Sendable {
    let servers: [ServerConfig]
}

// MARK: - LLM RELATED EVERYTHING
struct LLMQuery: Codable, Sendable {
    let role: String
    let content: String
}

