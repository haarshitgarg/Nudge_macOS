//
//  Types.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 21/06/25.
//

import Foundation
import MCP

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
    private let transport: MCPTransport
    private let host: String
    private let port: Int
    private var stream: Bool = true
    public let name: String
    
    init(name: String, transport: MCPTransport = .stdio, host: String = "localhost", port: Int = 8080, stream: Bool = true) {
        self.name = name
        self.id = UUID()
        self.transport = transport
        self.host = host
        self.port = port
        self.stream = stream
    }
    
    public func getTransport() -> Transport{
        switch transport {
        case .stdio:
            return StdioTransport()
        case .http:
            let url = URL(string: "http://\(host):\(port)/mcp")!
            let transport = HTTPClientTransport(endpoint: url, streaming: self.stream)
            return transport
        case .https:
            let url = URL(string: "https://\(host)/mcp")!
            let transport = HTTPClientTransport(endpoint: url, streaming: self.stream)
            return transport
        }
    }
}

// MARK: - Server Configuration Models
struct ServerConfig: Codable, Sendable {
    let name: String
    let host: String
    let port: Int
    let transport: String
    let requiresAccessibility: Bool
    let clientName: String 
}

struct ServersConfiguration: Codable, Sendable {
    let servers: [ServerConfig]
}
