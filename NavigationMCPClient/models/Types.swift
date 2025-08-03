//
//  Types.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 21/06/25.
//

import Foundation
import Logging
import MCP
import OpenAI

enum MCPTransport: String, Codable, Sendable {
    case stdio
    case http
    case https
    
}

struct MCPServer: Codable, Sendable, Hashable {
    private let id: UUID
    public let transport: MCPTransport?
    public let address: String?
    public let name: String
    
    init(name: String, transport: MCPTransport, address: String?) {
        self.id = UUID()
        self.transport = transport
        self.address = address
        self.name = name
    }
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.transport = nil
        self.address = nil
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

// MARK: - Client related structures
struct ClientInfo {
    public var process: Process?
    public var chat_gpt_tools: [ChatQuery.ChatCompletionToolParam]
    public var mcp_tools: [MCP.Tool]
    public var client: Client?
    
    init(client: Client) {
        self.client = client
        chat_gpt_tools = []
        mcp_tools = []
    }
    
    init() {
        self.client = nil
        chat_gpt_tools = []
        mcp_tools = []
    }
}

// MARK: - Agent related structures

// Agent response struct
struct AgentResponse: Codable {
    let ask_user: String?
    let finished: String?
    let agent_thought: String?
}

struct ClipboardContent: Codable {
    let message: String
    let meta_data: String
    
    init(message: String, meta_data: String) {
        self.message = message
        self.meta_data = meta_data
    }
}
