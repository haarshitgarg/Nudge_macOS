//
//  NavigationMCPClient.swift
//  NavigationMCPClient
//
//  Created by Harshit Garg on 21/06/25.
//

import Foundation
import os
import MCP
import OpenAI



/// This object implements the protocol which we have defined. It provides the actual behavior for the service. It is 'exported' by the service to make it available to the process hosting the service over an NSXPCConnection.
class NavigationMCPClient: NSObject, NavigationMCPClientProtocol {
    private let log = OSLog(subsystem: "Harshit.Nudge", category: "NavigationMCPClient")
    
    // MCP client variables
    private var servers: [MCPServer: Client] = [:]
    private var openAIClient: OpenAI
    // ____________________
    
    override init() {
        self.openAIClient = OpenAI(apiToken: Secrets.open_ai_key)
        super.init()
        
        setupMCPClient()
        os_log("NavigationMCPClient initialized", log: log, type: .debug)
    }
    
    @objc func sendUserMessage(_ message: String) {
        os_log("Received user message: %@", log: log, type: .debug, message)
        Task {
            do {
                //try await self.debugPrintServers()
                try await communicateWithLLM(message)
            } catch {
                os_log("Error while sending user message: %@", log: log, type: .error, error.localizedDescription)
            }
        }
    }
    
    // MARK: - Start the MCP client settings from here
    private func setupMCPClient() {
        os_log("Setting up MCP Client...", log: log, type: .debug)
        // Load server configuration
        loadServerConfig()
        // self.client = Client(name: "NudgeClient", version: "1.0")
        for server in servers.keys {
            Task {
                do {
                    os_log("Trying to connect to server: %@", log: log, type: .info, server.name)
                    try await servers[server]?.connect(transport: server.getTransport())
                    os_log("Successfully connected to server: %@", log: log, type: .info, server.name)
                } catch {
                    os_log("Failed to connect to server %@ with error: %@", log: log, type: .error, server.name, error.localizedDescription)
                }
            }
        }
    }
    
    private func loadServerConfig() {
        var serverConfigs: [ServerConfig] = []
        os_log("Loading server configuration...", log: log, type: .debug)
        
        // Get the path to the servers.json file
        guard let bundlePath = Bundle.main.path(forResource: "servers", ofType: "json") else {
            os_log("Could not find servers.json file in bundle", log: log, type: .error)
            return
        }
        
        do {
            // Read the JSON data from the file
            let jsonData = try Data(contentsOf: URL(fileURLWithPath: bundlePath))
            
            // Decode the JSON into our configuration structure
            let config = try JSONDecoder().decode(ServersConfiguration.self, from: jsonData)
            
            // Store the server configurations
            serverConfigs = config.servers
            
            os_log("Successfully loaded %d server configurations", log: log, type: .debug, config.servers.count)
            
            // Iterate through each server configuration
            for (index, serverConfig) in serverConfigs.enumerated() {
                os_log("Server %d: %@ (%@:%d, protocol: %@, requiresAccessibility: %@)",
                       log: log, type: .debug, 
                       index + 1, 
                       serverConfig.name, 
                       serverConfig.host, 
                       serverConfig.port, 
                       serverConfig.transport,
                       serverConfig.clientName,
                       serverConfig.requiresAccessibility ? "true" : "false")
                
                let server = MCPServer(
                    name: serverConfig.name,
                    transport: MCPTransport(rawValue: serverConfig.transport) ?? .stdio,
                    host: serverConfig.host,
                    port: serverConfig.port
                )
                self.servers[server] = Client(name: serverConfig.clientName, version: "1.0.0")
            }
            
        } catch {
            os_log("Error loading server configuration: %@", log: log, type: .error, error.localizedDescription)
        }
    }
    
    private func communicateWithLLM(_ query: String) async throws {
        let messages: [ChatQuery.ChatCompletionMessageParam] = [ChatQuery.ChatCompletionMessageParam(role: .user, content: query)!]

        // Right now only getting tools from the first server for simplicity
        os_log("Fetching tools from servers...", log: log, type: .debug)
        guard let response = try await servers.first?.value.listTools()
        else {
            os_log("No tools available from any server", log: log, type: .error)
            throw NudgeError.cannotGetTools
        }
        let jsonEncoder: JSONEncoder = JSONEncoder()
        let jsonDecoder: JSONDecoder = JSONDecoder()
        
        let server_tools: [MCP.Tool] = response.0
        os_log("Received %d tools from server", log: log, type: .debug, server_tools.count)
        let data = try jsonEncoder.encode(server_tools)
        os_log("Encoded tools data: %@", log: log, type: .debug, String(data: data, encoding: .utf8) ?? "No data")
        //let openAITools: [ChatQuery.ChatCompletionToolParam] = try jsonDecoder.decode([ChatQuery.ChatCompletionToolParam].self, from: data)
        var chat_gpt_tools: [ChatQuery.ChatCompletionToolParam] = []
        for tool in server_tools {
            os_log("Processing tool: %@", log: log, type: .debug, tool.name)
            let data = try jsonEncoder.encode(tool.inputSchema)
            os_log("Encoded tool schema data: %@", log: log, type: .debug, String(data: data, encoding: .utf8) ?? "No data")
            let tool_schema = try jsonDecoder.decode(AnyJSONSchema.self, from: data)
            os_log("Decoded tool schema: %@", log: log, type: .debug, String(describing: tool_schema))
            let function: ChatQuery.ChatCompletionToolParam.FunctionDefinition = ChatQuery.ChatCompletionToolParam.FunctionDefinition(
                name: tool.name,
                description: tool.description,
                parameters: tool_schema
            )
            chat_gpt_tools.append(ChatQuery.ChatCompletionToolParam(function: function))
        }
            
            
        
        let llm_query: ChatQuery = ChatQuery(
            messages: messages,
            model: "gpt-4o-2024-08-06",
            tools: chat_gpt_tools)
        
        let temp_data = try! jsonEncoder.encode(llm_query)
        os_log("Sending query to OpenAI", log: log, type: .debug)
        
        os_log("Query: %@", log: log, type: .debug, String(data: temp_data, encoding: .utf8) ?? "No data")
        let openAIResponse = try await openAIClient.chats(query: llm_query)
        
        
        os_log("Received response from OpenAI: %@", log: log, type: .debug, openAIResponse.choices.first?.message.content ?? "No content")
    }
    
        
}

// MARK: ALL DEBUG FUNCTIONS
extension NavigationMCPClient {
    func debugPrintServers() async throws {
        for client in servers.values {
            os_log("Client Name: %@, Version: %@", log: log, type: .debug, client.name, client.version)
            let (tools, _) = try await client.listTools()
            os_log("Tools for client %@: %@", log: log, type: .debug, client.name, tools.map { $0.name }.joined(separator: ", "))
        }
    }
}

