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
import LangGraph

/// This object implements the protocol which we have defined. It provides the actual behavior for the service. It is 'exported' by the service to make it available to the process hosting the service over an NSXPCConnection.
class NavigationMCPClient: NSObject, NavigationMCPClientProtocol {
    private let log = OSLog(subsystem: "Harshit.Nudge", category: "NavigationMCPClient")
    private let log_llm = OSLog(subsystem: "Harshit.Nudge", category: "LLM")
    private let logger = Logger(label: "Harshit.Nudge")
    
    // Agent Varibles
    private var nudgeAgent: NudgeAgent
    private var configs: [String: RunnableConfig] = [:]

    // MCP client variables
    private var serverDict: [MCPServer: ClientInfo] = [:]
    private var openAIClient: OpenAI? = nil
    private let jsonEncoder: JSONEncoder = JSONEncoder()
    private let jsonDecoder: JSONDecoder = JSONDecoder()
    
    // Callback client for two-way communication
    // Using strong reference to prevent deallocation during async operations
    private var callbackClient: NavigationMCPClientCallbackProtocol?
    // ____________________
    
    override init() {
        self.nudgeAgent = try! NudgeAgent()
        super.init()
        
        self.nudgeAgent.serverDelegate = self

        os_log("NavigationMCPClient initialized", log: log, type: .info)
        jsonEncoder.outputFormatting = [.prettyPrinted]
        
        try! self.nudgeAgent.defineWorkFlow()
        os_log("✅ Workflow compilation completed successfully", log: log, type: .info)
        
    }
    
    @objc func sendUserMessage(_ message: String, threadId: String = "default") {
        os_log("Processing user message: %@", log: log, type: .info, message)
        Task {
            do {
                self.callbackClient?.onLLMLoopStarted()
                sleep(1)
                
                var runableConfig: RunnableConfig
                var final_state: NudgeAgentState?
                
                if let config = configs[threadId] {
                    runableConfig = config
                } else {
                    runableConfig = RunnableConfig(threadId: threadId)
                    configs[threadId] = runableConfig
                }
                
                self.nudgeAgent.state.data["user_query"] = message
                let initVal: ( lastState: NudgeAgentState?, nodes: [String]) = (nil, [])
                let result = try await self.nudgeAgent.agent?.stream(.args(self.nudgeAgent.state.data), config: runableConfig).reduce(initVal, { partialResult, output in
                    return (output.state, partialResult.1 + [output.node])
                })
                
                final_state = result?.lastState
                
                // Final state summary for debugging
                os_log("Agent completed - iterations: %d, errors: %d", log: log, type: .info, final_state?.no_of_iteration ?? 0, final_state?.no_of_errors ?? 0)
                guard let agent_response = final_state?.agent_outcome?.last?.choices.first?.message.content?.data(using: .utf8) else {
                    os_log("No agent response found in final state", log: log, type: .error)
                    throw NudgeError.noAgentResponseFound
                }
                let message: agentResponse = try JSONDecoder().decode(agentResponse.self, from: agent_response)
                
                if message.ask_user != nil {
                    self.callbackClient?.onUserMessage(message.ask_user!)
                }
                
                else if message.finished != nil {
                    self.callbackClient?.onLLMLoopFinished()
                }
                
                else if message.agent_thought != nil {
                    self.callbackClient?.onLLMLoopFinished()
                }

                
            } catch {
                os_log("Error while sending user message: %@", log: log, type: .error, error.localizedDescription)
                callbackClient?.onError("Error processing message: \(error.localizedDescription)")
            }
        }
    }
    
    @objc func respondLLMAgent(_ message: String, threadId: String) {
        os_log("Processing agent response on thread: %@", log: log, type: .info, threadId)
        Task {
            self.callbackClient?.onLLMLoopStarted()
            sleep(1)
            do {
                var final_state: NudgeAgentState?
                
                guard var runableConfig = configs[threadId] else {
                    os_log("No runnable config found for thread ID: %@", log: log, type: .error, threadId)
                    throw NudgeError.noRunnableConfigFound
                }
                
                
                guard let checkpoint = try self.nudgeAgent.getState(config: runableConfig) else {
                    os_log("No checkpoint found for thread ID: %@", log: log, type: .error, threadId)
                    throw NudgeError.noCheckpointFound
                }
                
                
                //checkpoint = try checkpoint.updateState(values: ["temp_user_response": "\(message)"], channels: NudgeAgentState.schema)
                runableConfig = runableConfig.with(update: {$0.checkpointId = checkpoint.id})
                runableConfig = try await self.nudgeAgent.updateState(config: runableConfig, state: ["temp_user_response": "\(message)"])

                
                let initVal: ( lastState: NudgeAgentState?, nodes: [String]) = (nil, [])
                let result = try await self.nudgeAgent.agent?.stream(.resume, config: runableConfig).reduce(initVal, { partialResult, output in
                    return (output.state, partialResult.1 + [output.node])
                })
                
                final_state = result?.lastState
                
                //final_state = try await self.nudgeAgent.resume(config: runableConfig, partialState: checkpoint.state)
                
                
                
                guard let agent_response = final_state?.agent_outcome?.last?.choices.first?.message.content?.data(using: .utf8) else {
                    os_log("No agent response found in final state", log: log, type: .error)
                    throw NudgeError.noAgentResponseFound
                }
                let message: agentResponse = try JSONDecoder().decode(agentResponse.self, from: agent_response)
                
                if message.ask_user != nil {
                    self.callbackClient?.onUserMessage(message.ask_user!)
                }
                
                else if message.finished != nil {
                    self.callbackClient?.onLLMLoopFinished()
                }
                
                else if message.agent_thought != nil {
                    self.callbackClient?.onLLMLoopFinished()
                }

                
            } catch {
                os_log("Error while sending user response: %@", log: log, type: .error, error.localizedDescription)
                callbackClient?.onError("Error processing response from user: \(error.localizedDescription)")
            }
        }
        
    }
    
    @objc func setCallbackClient(_ client: NavigationMCPClientCallbackProtocol) {
        os_log("Callback client registered", log: log, type: .info)
        self.callbackClient = client
        
        client.onLLMMessage("Callback client registered successfully")
    }
    
    @objc func interruptAgentExecution() {
        os_log("Agent execution interrupted", log: log, type: .info)
        self.nudgeAgent.interruptAgent()
    }
    
    @objc func terminate() {
        os_log("Terminating XPC client processes", log: log, type: .info)
        for clientInfo in serverDict.values {
            if let pid = clientInfo.process?.processIdentifier  {
                kill(pid, SIGKILL)
                clientInfo.process?.waitUntilExit()
            } else {
            }
        }
        
        // TODO: when I make it two way communication I might need to mark client as nil
        self.callbackClient = nil
    }
    
    @objc func ping(_ message: String) {
    }
    
    // MARK: - Start the MCP client settings from here
    public func setupMCPClient() async {
        os_log("Setting up MCP Client", log: log, type: .info)
        // Setup the All necessary navigation
        // This is just a dummy server will not be required
        let navServer = MCPServer(name: "NavServer")
        var navClientInfo = ClientInfo()
        
        navClientInfo.mcp_tools = await NudgeLibrary.shared.getNavTools()
        do { try getNavTools(client: &navClientInfo)}
        catch {os_log("Error in navclient", log: log, type: .error)}
        serverDict[navServer] = navClientInfo
        
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
        
        os_log("MCP Client setup completed - %d tools loaded", log: log, type: .info, getTools().count)
        initialiseAgentState()
    }
    
    private func getTools() -> [ChatQuery.ChatCompletionToolParam] {
        var chat_gpt_tools: [ChatQuery.ChatCompletionToolParam] = []
        for clientInfo in self.serverDict.values { chat_gpt_tools.append(contentsOf: clientInfo.chat_gpt_tools) }
        
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
        serverDict[server]?.process = Process()
        serverDict[server]?.process?.executableURL = URL(fileURLWithPath: executablePath)
        serverDict[server]?.process?.arguments = [""]
        serverDict[server]?.process?.standardInput = serverInputPipe
        serverDict[server]?.process?.standardOutput = serverOutputPipe
        try serverDict[server]?.process?.run()
        try await serverDict[server]?.client?.connect(transport: transport)
    }

    private func loadServerConfig() {
        var serverConfigs: [ServerConfig] = []
        
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
            
                
            // Iterate through each server configuration
            for (index, serverConfig) in serverConfigs.enumerated() {
                
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
        let response = try await serverDict[server]?.client?.listTools()
        serverDict[server]?.mcp_tools = response?.tools ?? []
        var chat_gpt_tools: [ChatQuery.ChatCompletionToolParam] = []
        for tool in response?.tools ?? [] {
            
            let schema_data = try jsonEncoder.encode(tool.inputSchema)
            
            let tool_schema = try jsonDecoder.decode(AnyJSONSchema.self, from: schema_data)
            
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
            
            let schema_data = try jsonEncoder.encode(tool.inputSchema)
            
            let tool_schema = try jsonDecoder.decode(AnyJSONSchema.self, from: schema_data)
            
            let function: ChatQuery.ChatCompletionToolParam.FunctionDefinition = ChatQuery.ChatCompletionToolParam.FunctionDefinition(
                name: tool.name,
                description: tool.description,
                parameters: tool_schema
            )
            chat_gpt_tools.append(ChatQuery.ChatCompletionToolParam(function: function))
        }
        client.chat_gpt_tools = chat_gpt_tools
    }
    
    private func initialiseAgentState() {
        let tools = self.getTools()
        self.nudgeAgent.updateTools(tools)
    }
    
    deinit {
    }
    
}

// MARK: - Delegation protocol from NudgeAgent
extension NavigationMCPClient: NudgeAgentDelegate {
    func agentFacedError(error: String) {
        self.callbackClient?.onError(error)
    }
    
    func agentRespondedWithThought(thought: String) {
        self.callbackClient?.onLLMMessage(thought)
    }
    
    func agentCalledTool(toolName: String) {
        self.callbackClient?.onToolCalled(toolName: toolName)
    }
    
    func agentAskedUserForInput(question: String) {
        self.callbackClient?.onUserMessage(question)
        self.nudgeAgent.agent?.pause()
    }
}

