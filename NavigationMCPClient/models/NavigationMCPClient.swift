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
        jsonEncoder.outputFormatting = [.prettyPrinted]
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
        let system_message_query = """
        You are a smart NAVIGATION ASSISTANT. You will receive user queries that will require you to navigate across various applications in mac.
        You need to check the user queries and then based on the tools available, you will do the following:
        1. Reply back to user about your plan
        2. make the necessary tool call
        
        you will be asked to do things like: "find me "xyz" button in safar" and you are supposed to formulate a sequence of tool calls that could get
        you that like: open_application -> get_application_stat -> get_ui_elements -> click_the_ui_e
        
        Your will also analyse the results from the tool calls and then revise your plan accordingly
        """
        let system_message: ChatQuery.ChatCompletionMessageParam = ChatQuery.ChatCompletionMessageParam(role: .system, content: system_message_query)!
        var messages: [ChatQuery.ChatCompletionMessageParam] = [system_message, ChatQuery.ChatCompletionMessageParam(role: .user, content: query)!]
        
        // making a list of available tools
        var chat_gpt_tools: [ChatQuery.ChatCompletionToolParam] = []
        for clientInfo in self.serverDict.values { chat_gpt_tools.append(contentsOf: clientInfo.chat_gpt_tools) }

        let initial_query: ChatQuery = ChatQuery(
            messages: messages,
            model: "gpt-4o-2024-08-06",
            tools: chat_gpt_tools)
        
        os_log("Sending query to OpenAI", log: log, type: .debug)
        let initail_response_chatgpt = try await openAIClient.chats(query: initial_query)
        
        os_log("------------------------------------------------------", log: log, type: .debug)
        os_log("Received response from OpenAI: %@", log: log, type: .debug, initail_response_chatgpt.choices.first?.message.content ?? "No content")
        os_log("The tool calls list from OpenAI: %@", log: log, type: .debug, initail_response_chatgpt.choices.first?.message.toolCalls?.description ?? "No content")
        os_log("------------------------------------------------------", log: log, type: .debug)

        var tool_call_list: [ChatQuery.ChatCompletionMessageParam.AssistantMessageParam.ToolCallParam] = []
        guard let message_from_openAI = initail_response_chatgpt.choices.first?.message else {
            throw NudgeError.noMessageFromOpenAI
        }
        
        guard let openAIToolCalls = message_from_openAI.toolCalls else {
            os_log("No tool calls from open AI", log: log, type: .debug)
            return
        }
        
        tool_call_list.append(contentsOf: openAIToolCalls)
        while (!tool_call_list.isEmpty) {
            os_log("Processing tool calls from OpenAI response", log: log, type: .debug)
            let curr_tool = tool_call_list.first!
            tool_call_list.remove(at: 0)
            os_log("Tool call: %@", log: log, type: .debug, curr_tool.function.name)
            for (_, clientInfo) in serverDict {
                if let tool = clientInfo.mcp_tools.first(where: {$0.name == curr_tool.function.name}) {
                    os_log("Found tool: %@", log: log, type: .debug, tool.name)
                    os_log("Calling tool with arguments: %@", log: log, type: .debug, String(describing: curr_tool.function.arguments))
                    guard let argumentsData = curr_tool.function.arguments.data(using: .utf8) else {
                        os_log("Failed to convert arguments to Data", log: log, type: .error)
                        throw NudgeError.cannotParseToolArguments
                    }
                    let arguemnt_dict: [String: Value]  = try jsonDecoder.decode([String: Value].self, from: argumentsData)
                    os_log("Decoded arguments: %@", log: log, type: .debug, String(describing: arguemnt_dict))
                    let tool_result = try await clientInfo.client.callTool(name: tool.name, arguments: arguemnt_dict)
                    os_log("Tool result: %@", log: log, type: .debug, String(describing: tool_result.content))
                    
                    guard let new_assistant_message =  ChatQuery.ChatCompletionMessageParam(role: .assistant, content: message_from_openAI.content ?? "", toolCalls: [curr_tool]) else {
                        break
                    }
                    
                    guard let new_message = ChatQuery.ChatCompletionMessageParam(role: .tool, content: tool_result.content.description, toolCallId: curr_tool.id) else {
                        break
                    }
                    messages.append(new_assistant_message)
                    messages.append(new_message)
                    let query: ChatQuery = ChatQuery(
                        messages: messages,
                        model: "gpt-4o-2024-08-06"
                        )
                    
                    os_log("Sending query to OpenAI", log: log, type: .debug)
                    let openAIResponse = try await openAIClient.chats(query: query)
                    os_log("------------------------------------------------------", log: log, type: .debug)
                    os_log("Received response from OpenAI: %@", log: log, type: .debug, openAIResponse.choices.first?.message.content ?? "No content")
                    os_log("The tool calls list from OpenAI: %@", log: log, type: .debug, openAIResponse.choices.first?.message.toolCalls ?? "No content")
                    os_log("------------------------------------------------------", log: log, type: .debug)
                    //messages.append(new_message)
                    guard let openAIToolCalls = openAIResponse.choices.first?.message.toolCalls else {
                        os_log("Cannot find any more tool calls.", log: log, type: .debug)
                        break
                    }
                    tool_call_list.append(contentsOf: openAIToolCalls)
                    break
                }
            }
            
            // Loop over again.
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

