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
import NudgeLibrary

/// This object implements the protocol which we have defined. It provides the actual behavior for the service. It is 'exported' by the service to make it available to the process hosting the service over an NSXPCConnection.
class NavigationMCPClient: NSObject, NavigationMCPClientProtocol {
    private let log = OSLog(subsystem: "Harshit.Nudge", category: "NavigationMCPClient")
    private let log_llm = OSLog(subsystem: "Harshit.Nudge", category: "LLM")
    private let logger = Logger(label: "Harshit.Nudge")
    
    // MCP client variables
    private var serverDict: [MCPServer: ClientInfo] = [:]
    private var openAIClient: OpenAI? = nil
    private let jsonEncoder: JSONEncoder = JSONEncoder()
    private let jsonDecoder: JSONDecoder = JSONDecoder()
    private var nudgeAgent: NudgeAgent
    
    // Callback client for two-way communication
    // Using strong reference to prevent deallocation during async operations
    private var callbackClient: NavigationMCPClientCallbackProtocol?
    // ____________________
    
    override init() {
        self.nudgeAgent = try! NudgeAgent()
        super.init()
        
        os_log("NavigationMCPClient initialized - instance: %@", log: log, type: .debug, String(describing: self))
        jsonEncoder.outputFormatting = [.prettyPrinted]
        os_log("Initializing the nudge agent", log: log, type: .debug)
        
        try! self.nudgeAgent.defineWorkFlow()
        os_log("✅ Workflow compilation completed successfully", log: log, type: .info)
        
    }
    
    @objc func sendUserMessage(_ message: String) {
        os_log("Received user message: %@ on instance: %@", log: log, type: .debug, message, String(describing: self))
        Task {
            do {
                //try await communication_with_chatgpt(message)
                self.callbackClient?.onLLMLoopStarted()
                sleep(1)
                // Set the user query in the agent state before invoking
                let tools = self.getTools()
                os_log("Updating agent with %d tools", log: log, type: .debug, tools.count)
                self.nudgeAgent.updateTools(tools)
                self.nudgeAgent.state.data["user_query"] = message
                os_log("Set user query in agent state: %@", log: log, type: .debug, message)
                
                let final_state = try await self.nudgeAgent.invoke()
                self.callbackClient?.onLLMLoopFinished()
                os_log("Reached final state %@", log: log, type: .debug, final_state.debugDescription)
            } catch {
                os_log("Error while sending user message: %@", log: log, type: .error, error.localizedDescription)
                callbackClient?.onError("Error processing message: \(error.localizedDescription)")
            }
        }
    }
    
    @objc func setCallbackClient(_ client: NavigationMCPClientCallbackProtocol) {
        os_log("Setting callback client for two-way communication: %@", log: log, type: .debug, String(describing: client))
        self.callbackClient = client
        
        // Test the callback immediately
        os_log("Testing callback client with ping message", log: log, type: .debug)
        client.onLLMMessage("Callback client registered successfully")
        
        // Store a strong reference to prevent deallocation during async operations
        // The weak reference might be getting lost during async tasks
    }
    
    @objc func terminate() {
        os_log("Stopping all processes the xpc client. No of clients: %d", log: log, type: .debug, serverDict.count)
        for clientInfo in serverDict.values {
            if let pid = clientInfo.process?.processIdentifier  {
                os_log("Termination process with PID: %@", log: log, type: .debug, String(pid))
                kill(pid, SIGKILL)
                clientInfo.process?.waitUntilExit()
            } else {
                os_log("No PID to kill", log: log, type: .debug)
            }
        }
        
        // TODO: when I make it two way communication I might need to mark client as nil
    }
    
    @objc func ping(_ message: String) {
        os_log("Received ping message: %@", log: log, type: .debug, message)
    }
    
    // MARK: - Start the MCP client settings from here
    public func setupMCPClient() async {
        os_log("Setting up MCP Client...", log: log, type: .debug)
        // Setup the All necessary navigation
        // This is just a dummy server will not be required
        let navServer = MCPServer(name: "NavServer")
        var navClientInfo = ClientInfo()
        
        navClientInfo.mcp_tools = await NudgeLibrary.shared.getNavTools()
        do { try getNavTools(client: &navClientInfo)}
        catch {os_log("Error in navclient", log: log, type: .error)}
        serverDict[navServer] = navClientInfo
        os_log("Tools received from nudge %{public}d", log: log, type: .debug, navClientInfo.mcp_tools.count)
        
        // Load server configuration
        loadServerConfig()
        
        // Process all servers sequentially to ensure proper loading
        for server in serverDict.keys {
            do {
                os_log("Trying to connect to server: %@", log: log, type: .info, server.name)
                switch server.transport {
                case .http:
                    let transport = HTTPClientTransport(
                        endpoint: URL(string: server.address ?? "http://localhost:8081")!,
                        logger: logger
                    )
                    try await serverDict[server]?.client?.connect(transport: transport)
                    try await getTools(server)
                    break
                case .https:
                    break
                case .stdio:
                    try await setupStdioClient(server)
                    try await getTools(server)
                    break
                default:
                    break
                }
                os_log("Successfully connected to server: %@", log: log, type: .info, server.name)
            } catch {
                os_log("Failed to connect to server %@ with error: %@", log: log, type: .error, server.name, error.localizedDescription)
            }
        }
        
        os_log("MCP Client setup completed. Total tools loaded: %d", log: log, type: .info, getTools().count)
    }
    
    private func getTools() -> [ChatQuery.ChatCompletionToolParam] {
        var chat_gpt_tools: [ChatQuery.ChatCompletionToolParam] = []
        for clientInfo in self.serverDict.values { chat_gpt_tools.append(contentsOf: clientInfo.chat_gpt_tools) }
        os_log("Got %d tools in chat gpt", log: log, type: .debug, chat_gpt_tools.count)
        
        return chat_gpt_tools
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
        try await serverDict[server]?.client?.connect(transport: transport)
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
    
    private func getTools(_ server: MCPServer) async throws {
        os_log("Fetching tools from server %@", log: log, type: .debug, server.name)
        let response = try await serverDict[server]?.client?.listTools()
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
    
    private func getNavTools( client: inout ClientInfo) throws {
        var chat_gpt_tools: [ChatQuery.ChatCompletionToolParam] = []
        for tool in client.mcp_tools {
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
        client.chat_gpt_tools = chat_gpt_tools
    }
    
    deinit {
        os_log("Deinitialising the xpc client", log: log, type: .debug)
    }
    
}

