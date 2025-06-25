//
//  NavigationMCPClient.swift
//  NavigationMCPClient
//
//  Created by Harshit Garg on 21/06/25.
//

import Foundation
import Logging
import MCP
import os
import OpenAI
import System



/// This object implements the protocol which we have defined. It provides the actual behavior for the service. It is 'exported' by the service to make it available to the process hosting the service over an NSXPCConnection.
class NavigationMCPClient: NSObject, NavigationMCPClientProtocol {
    private let log = OSLog(subsystem: "Harshit.Nudge", category: "NavigationMCPClient")
    private let logger = Logger(label: "Harshit.Nudge")
    
    // MCP client variables
    private var serverDict: [MCPServer: ClientInfo] = [:]
    private var openAIClient: OpenAI? = nil
    private let jsonEncoder: JSONEncoder = JSONEncoder()
    private let jsonDecoder: JSONDecoder = JSONDecoder()
    // ____________________
    
    override init() {
        super.init()
        
        setupMCPClient()
        os_log("NavigationMCPClient initialized", log: log, type: .debug)
    }
    
    @objc func sendUserMessage(_ message: String) {
        os_log("Received user message: %@", log: log, type: .debug, message)
        Task {
            do {
                //try await self.debugPrintServers()
                try await communication_with_chatgpt(message)
            } catch {
                os_log("Error while sending user message: %@", log: log, type: .error, error.localizedDescription)
            }
        }
    }
    
    @objc func terminate() {
        os_log("Stopping all processes the xpc client", log: log, type: .debug)
        for clientInfo in serverDict.values {
            guard let pid = clientInfo.process?.processIdentifier else {
                os_log("No PID to kill", log: log, type: .debug)
                return
            }
            os_log("Termination process with PID: %@", log: log, type: .debug, String(pid))
            kill(pid, SIGKILL)
        }
        
        // TODO: when I make it two way communication I might need to mark client as nil
    }
    
    // MARK: - Start the MCP client settings from here
    private func setupMCPClient() {
        os_log("Setting up MCP Client...", log: log, type: .debug)
        // Load server configuration
        loadServerConfig()
        for server in serverDict.keys {
            Task {
                do {
                    os_log("Trying to connect to server: %@", log: log, type: .info, server.name)
                    switch server.transport {
                    case .http:
                        let transport = HTTPClientTransport(
                            endpoint: URL(string: server.address ?? "http://localhost:8081")!,
                            logger: logger
                        )
                        try await serverDict[server]?.client.connect(transport: transport)
                        try await getTools(server)
                        break
                    case .https:
                        break
                    case .stdio:
                        try await setupStdioClient(server)
                        try await getTools(server)
                        break
                    }
                    os_log("Successfully connected to server: %@", log: log, type: .info, server.name)
                } catch {
                    os_log("Failed to connect to server %@ with error: %@", log: log, type: .error, server.name, error.localizedDescription)
                }
            }
        }
    }
    
    private func setupStdioClient(_ server: MCPServer) async throws {
        let serverInputPipe = Pipe()
        let serverOutputPipe = Pipe()
        let serverInput: FileDescriptor = FileDescriptor(rawValue: serverInputPipe.fileHandleForWriting.fileDescriptor)
        let serverOutput: FileDescriptor = FileDescriptor(rawValue: serverOutputPipe.fileHandleForReading.fileDescriptor)
        let transport = StdioTransport(
            input: serverOutput,
            output: serverInput,
            logger: logger
        )
        let executablePath = Bundle.main.path(forResource: "NudgeServer", ofType: nil)!
        os_log("Executable path: %@", log: log, type: .debug, executablePath)
        serverDict[server]?.process = Process()
        serverDict[server]?.process?.executableURL = URL(fileURLWithPath: executablePath)
        serverDict[server]?.process?.arguments = [""]
        serverDict[server]?.process?.standardInput = serverInputPipe
        serverDict[server]?.process?.standardOutput = serverOutputPipe
        try serverDict[server]?.process?.run()
        os_log("Running the client process to start server...", log: log, type: .debug)
        try await serverDict[server]?.client.connect(transport: transport)
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
                       serverConfig.address ?? "no address as stdio transport",
                       serverConfig.transport,
                       serverConfig.clientName,
                       serverConfig.requiresAccessibility ? "true" : "false")
                
                let server = MCPServer(
                    name: serverConfig.name,
                    transport: MCPTransport(rawValue: serverConfig.transport) ?? .stdio,
                    address: serverConfig.address
                )
                let client = Client(name: serverConfig.clientName, version: "1.0.0")
                self.serverDict[server] = ClientInfo(client: client)
            }
            
        } catch {
            os_log("Error loading server configuration: %@", log: log, type: .error, error.localizedDescription)
        }
    }
    
    private func communication_with_chatgpt(_ query: String) async throws {
        // Initialize openAI client if not already initialized
        if openAIClient == nil {
            os_log("Initializing OpenAI client with API key", log: log, type: .debug)
            self.openAIClient = OpenAI(apiToken: Secrets.open_ai_key)
        }
        guard let openAIClient = openAIClient else {
            os_log("OpenAI client is not initialized", log: log, type: .error)
            throw NudgeError.openAIClientNotInitialized
        }
        
        // Message to be sent to OpenAI
        let messages: [ChatQuery.ChatCompletionMessageParam] = [ChatQuery.ChatCompletionMessageParam(role: .user, content: query)!]
        var chat_gpt_tools: [ChatQuery.ChatCompletionToolParam] = []
        for clientInfo in self.serverDict.values {
            chat_gpt_tools.append(contentsOf: clientInfo.chat_gpt_tools)
        }

        let llm_query: ChatQuery = ChatQuery(
            messages: messages,
            model: "gpt-4o-2024-08-06",
            tools: chat_gpt_tools)
        
        os_log("Sending query to OpenAI", log: log, type: .debug)
        let openAIResponse = try await openAIClient.chats(query: llm_query)
        
        os_log("Received response from OpenAI: %@", log: log, type: .debug, openAIResponse.choices.first?.message.content ?? "No content")
        os_log("------------------------------------------------------", log: log, type: .debug)
        os_log("The tool calls list from OpenAI: %@", log: log, type: .debug, openAIResponse.choices.first?.message.toolCalls ?? "No content")

        if openAIResponse.choices.first?.message.toolCalls != nil {
            os_log("Processing tool calls from OpenAI response", log: log, type: .debug)
            for toolCall in openAIResponse.choices.first!.message.toolCalls! {
                os_log("Tool call: %@", log: log, type: .debug, toolCall.function.name)
                for (_, clientInfo) in serverDict {
                    if let tool = clientInfo.mcp_tools.first(where: {$0.name == toolCall.function.name}) {
                        os_log("Found tool: %@", log: log, type: .debug, tool.name)
                        os_log("Calling tool with arguments: %@", log: log, type: .debug, String(describing: toolCall.function.arguments))
                        guard let argumentsData = toolCall.function.arguments.data(using: .utf8) else {
                            os_log("Failed to convert arguments to Data", log: log, type: .error)
                            throw NudgeError.cannotParseToolArguments
                        }
                        let arguemnt_dict: [String: Value]  = try jsonDecoder.decode([String: Value].self, from: argumentsData)
                        os_log("Decoded arguments: %@", log: log, type: .debug, String(describing: arguemnt_dict))
                        let tool_result = try await clientInfo.client.callTool(name: tool.name, arguments: arguemnt_dict)
                        os_log("Tool result: %@", log: log, type: .debug, String(describing: tool_result.content))
                        break
                    }
                }
            }
        }
    }
    
    private func getTools(_ server: MCPServer) async throws {
        os_log("Fetching tools from server %@", log: log, type: .debug, server.name)
        let response = try await serverDict[server]?.client.listTools()
        serverDict[server]?.mcp_tools = response?.tools ?? []
        var chat_gpt_tools: [ChatQuery.ChatCompletionToolParam] = []
        for tool in response?.tools ?? [] {
            os_log("Processing tool: %@", log: log, type: .debug, tool.name)
            
            let schema_data = try jsonEncoder.encode(tool.inputSchema)
            os_log("Encoded tool schema data: %@", log: log, type: .debug, String(data: schema_data, encoding: .utf8) ?? "No data")
            
            let tool_schema = try jsonDecoder.decode(AnyJSONSchema.self, from: schema_data)
            os_log("Decoded tool schema: %@", log: log, type: .debug, String(describing: tool_schema))
            
            let function: ChatQuery.ChatCompletionToolParam.FunctionDefinition = ChatQuery.ChatCompletionToolParam.FunctionDefinition(
                name: tool.name,
                description: tool.description,
                parameters: tool_schema
            )
            chat_gpt_tools.append(ChatQuery.ChatCompletionToolParam(function: function))
        }
        self.serverDict[server]?.chat_gpt_tools = chat_gpt_tools
    }
    
    deinit {
        os_log("Deinitialising the xpc client", log: log, type: .debug)
    }
    
}

// MARK: ALL DEBUG FUNCTIONS
extension NavigationMCPClient {
    func debugPrintServers() async throws {
        for clientInfo in serverDict.values {
            let client = clientInfo.client
            os_log("Client Name: %@, Version: %@", log: log, type: .debug, client.name, client.version)
            let (tools, _) = try await client.listTools()
            os_log("Tools for client %@: %@", log: log, type: .debug, client.name, tools.map { $0.name }.joined(separator: ", "))
        }
    }
}

