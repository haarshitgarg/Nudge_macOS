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
        
        do {
            try self.nudgeAgent.defineWorkFlow()
        } catch {
            os_log("Nudge Agent workflow returned with error: %{public}@", log: log, type: .debug, error.localizedDescription)
        }
        
    }
    
    @objc func sendUserMessage(_ message: String) {
        os_log("Received user message: %@ on instance: %@", log: log, type: .debug, message, String(describing: self))
        Task {
            do {
                //try await communication_with_chatgpt(message)
                self.callbackClient?.onLLMLoopStarted()
                
                // Set the user query in the agent state before invoking
                self.nudgeAgent.state.data["user_query"] = message
                os_log("Set user query in agent state: %@", log: log, type: .debug, message)
                
                let final_state = try await self.nudgeAgent.invoke()
                self.callbackClient?.onLLMLoopFinished()
                os_log("Reached final state", log: log, type: .debug)
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
    public func setupMCPClient() {
        os_log("Setting up MCP Client...", log: log, type: .debug)
        // Setup the All necessary navigation
        // This is just a dummy server will not be required
        let navServer = MCPServer(name: "NavServer")
        var navClientInfo = ClientInfo()
        Task {
            navClientInfo.mcp_tools = await NudgeLibrary.shared.getNavTools()
            do { try getNavTools(client: &navClientInfo)}
            catch {os_log("Error in navclient", log: log, type: .error)}
            serverDict[navServer] = navClientInfo
            os_log("Tools received from nudge %{public}d", log: log, type: .debug, navClientInfo.mcp_tools.count)
        }
        
        
        
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
    
    private func formatUIElementsToString(_ elements: [UIElementInfo]) -> String {
        var result = "UI Elements Found:\n"
        
        func formatElement(_ element: UIElementInfo, depth: Int = 0) -> String {
            let indent = String(repeating: "  ", count: depth)
            var elementString = "\(indent)- ID: \(element.element_id)\n"
            elementString += "\(indent)  Description: \(element.description)\n"
            
            if !element.children.isEmpty {
                elementString += "\(indent)  Children (\(element.children.count)):\n"
                for child in element.children {
                    elementString += formatElement(child, depth: depth + 2)
                }
            }
            
            return elementString
        }
        
        for element in elements {
            result += formatElement(element)
        }
        
        return result
    }
    
    private func communication_with_chatgpt(_ query: String) async throws {
        // Notify client that LLM loop is starting
        os_log("Notifying callback client: LLM loop started. Callback client exists: %@", log: log, type: .debug, callbackClient != nil ? "YES" : "NO")
        if let client = callbackClient {
            os_log("Calling onLLMLoopStarted on callback client", log: log, type: .debug)
            client.onLLMLoopStarted()
        } else {
            os_log("ERROR: Callback client is nil when trying to notify LLM loop started", log: log, type: .error)
        }
        
        // I have 3 different llm agents.
        // 1. defines the initial state:
        // 2. updates the state etc based on tool results. (no tools given to it)
        // 3. use the mcp tools to perform various activities
        if openAIClient == nil {
            os_log("Initializing OpenAI client with API key", log: log, type: .debug)
            self.openAIClient = OpenAI(apiToken: Secrets.open_ai_key)
        }
        guard let openAIClient = openAIClient else {
            os_log("OpenAI client is not initialized", log: log, type: .error)
            throw NudgeError.openAIClientNotInitialized
        }
        
        var retryCount = 0
        
        // User message
        guard let user_query = ChatQuery.ChatCompletionMessageParam(role: .user, content: query) else {
            throw NudgeError.cannotCreateMessageForOpenAI
        }
        
        // agent definitions
        let init_agent_sys_msg: String = """
        You are a smart llm agent that is part of a navigation tool. Your job is to define a short goal from the user query. 
        You will be given a user query, based on that you need to return a goal. For example:
        "user": "I want to open the browser"
        "you": "open_safari"
        
        "user": "I want you to open the tool that you use to inspect accessibility elements"
        "you": "open_accessibility_inspector"
        
        "user": "I want to block my calendar"
        "you": "add_new_event_in_calendar"
        """
        
        let update_agent_sys_msg: String = """
        You are a smart llm agent which is part of a navigation tool. You are responsible for summarizing the knowledge of what the agent has done,
        based on current state and previous action. You will get an input explaining the goal, last action and current knowledge,
        you are supposed to return the updated knowledge. Example:
        "input": "goal: add_new_event_in_calendar, last_action: search for new event button, last_server_respons: found the button, knowledge: calendar is open, need to find button to create event"
        "output": "calendar is open, we have found the button for new event"
        """
        
        let mcp_agent_sys_msg: String = """
        You are a smart NAVIGATION ASSISTANT. you will be give a goal, last_action, last_server_response and knowledge along with appropriate tools.
        Based on that you need to formulate the next step to reach the goal. For example:
        "input": "goal: add_a_new_event_in_calendar, last_action: open_application, last_server_respons: calendar is now open, knowledge: "
        
        Your will analyse the input and based on that decide the calls to be made. If no tool call is required you send a success message to the user
        """
        
        guard let init_agent_sys_query: ChatQuery.ChatCompletionMessageParam = ChatQuery.ChatCompletionMessageParam(role: .system, content: init_agent_sys_msg) else {
            throw NudgeError.cannotCreateMessageForOpenAI
        }
        let init_agent_query: ChatQuery = ChatQuery(
            messages: [init_agent_sys_query, user_query],
            model: "gpt-4o-2024-08-06"
        )
        
        guard let update_agent_sys_query: ChatQuery.ChatCompletionMessageParam = ChatQuery.ChatCompletionMessageParam(role: .system, content: update_agent_sys_msg) else {
            throw NudgeError.cannotCreateMessageForOpenAI
        }
        
        guard let mcp_agent_sys_query: ChatQuery.ChatCompletionMessageParam = ChatQuery.ChatCompletionMessageParam(role: .system, content: mcp_agent_sys_msg) else {
            throw NudgeError.cannotCreateMessageForOpenAI
        }

        
        struct chatgptstate: Codable {
            var goal: String
            var last_action: String = ""
            var last_server_response: String = ""
            var error_count: Int = 0
            var knowledge: String = ""
        }
        
        
        // ALL ABOUT TOOLS
        var chat_gpt_tools: [ChatQuery.ChatCompletionToolParam] = []
        for clientInfo in self.serverDict.values { chat_gpt_tools.append(contentsOf: clientInfo.chat_gpt_tools) }
        os_log("Got %d tools in chat gpt", log: log, type: .debug)

        // DECIDE THE INITIAL STATE. USING A SEPERATE LLM QUERY TO FILL UP THE STATE
        let init_agent_response_chatgpt = try await openAIClient.chats(query: init_agent_query)
        guard let init_goal = init_agent_response_chatgpt.choices.first?.message.content else { throw NudgeError.noGoalFound}
        var openAI_state: chatgptstate = chatgptstate(goal: init_goal)
        
        // Notify client about the initial goal
        os_log("Notifying callback client: Goal identified. Callback client exists: %@", log: log, type: .debug, callbackClient != nil ? "YES" : "NO")
        if let client = callbackClient {
            os_log("Calling onLLMMessage for goal on callback client", log: log, type: .debug)
            client.onLLMMessage("Goal identified: \(init_goal)")
        } else {
            os_log("ERROR: Callback client is nil when trying to notify goal", log: log, type: .error)
        }

        // The actual loop. We keep running it for 15 retries or when the goal is reached
        while(retryCount < 6) {
            retryCount += 1
            
            // AGENTIC TASKS ARE PERFORMED FROM HERE
            
            // UPDATE THE GPT WITH THE CURRENT STATE OF THE TASK
            guard let update_user_message = ChatQuery.ChatCompletionMessageParam(
                role: .user,
                content: "goal: \(openAI_state.goal), last_action: \(openAI_state.last_action), last_server_response: \(openAI_state.last_server_response), current_knowledge: \(openAI_state.knowledge)") else {
                throw NudgeError.cannotCreateMessageForOpenAI
            }
            
            let update_agent_query: ChatQuery = ChatQuery(
                messages: [update_agent_sys_query, update_user_message],
                model: "gpt-4o-2024-08-06"
            )
            let update_agent_response_chatgpt = try await openAIClient.chats(query: update_agent_query)
            openAI_state.knowledge = update_agent_response_chatgpt.choices.first?.message.content ?? ""
            
            // Notify client about knowledge update
            callbackClient?.onLLMMessage("Knowledge updated: \(openAI_state.knowledge)")

            // REQUEST THE LLM WITH THE GIVEN TOOLS TO PERFORM THE TASK
            guard let mcp_user_message = ChatQuery.ChatCompletionMessageParam(
                role: .user,
                content: "goal: \(openAI_state.goal), last_action: \(openAI_state.last_action), last_server_response: \(openAI_state.last_server_response), knowledge: \(openAI_state.knowledge). What will you do next?") else {
                throw NudgeError.cannotCreateMessageForOpenAI
            }
            let mcp_agent_query: ChatQuery = ChatQuery(
                messages: [mcp_agent_sys_query, mcp_user_message],
                model: "gpt-4o-2024-08-06",
                tools: chat_gpt_tools)
            let mcp_agent_response_chatgpt = try await openAIClient.chats(query: mcp_agent_query)
            os_log("------------------------------------------------------", log: log, type: .debug)
            os_log("Received response from OpenAI: %@", log: log, type: .debug, mcp_agent_response_chatgpt.choices.first?.message.content ?? "No content")
            os_log("The tool calls list from OpenAI: %@", log: log, type: .debug, mcp_agent_response_chatgpt.choices.first?.message.toolCalls?.description ?? "No content")
            os_log("------------------------------------------------------", log: log, type: .debug)
            
            // Notify client about LLM response
            if let content = mcp_agent_response_chatgpt.choices.first?.message.content {
                callbackClient?.onLLMMessage("LLM Response: \(content)")
            }

            var tool_call_list: [ChatQuery.ChatCompletionMessageParam.AssistantMessageParam.ToolCallParam] = []
            guard let mcp_message_from_openAI = mcp_agent_response_chatgpt.choices.first?.message else {
                throw NudgeError.noMessageFromOpenAI
            }
            guard let openAIToolCalls = mcp_message_from_openAI.toolCalls else {
                os_log("No tool calls from open AI", log: log, type: .debug)
                callbackClient?.onLLMLoopFinished()
                return
            }
            tool_call_list.append(contentsOf: openAIToolCalls)
            while (!tool_call_list.isEmpty) {
                os_log("---------------------------------------", log: log_llm, type: .debug)
                os_log("Iteration no: %d, no of tools: %d", log: log_llm, type: .debug, retryCount, tool_call_list.count)
                
                os_log("Knowledge: %{public}@", log: log_llm, type: .debug, openAI_state.knowledge)
                
                os_log("Processing tool calls from OpenAI response", log: log, type: .debug)
                let curr_tool = tool_call_list.first!
                tool_call_list.remove(at: 0)
                let functionName = curr_tool.function.name
                os_log("Tool call: %@", log: log, type: .debug, functionName)
                guard let argumentsData = curr_tool.function.arguments.data(using: .utf8) else {
                    os_log("Failed to convert arguments to Data", log: log, type: .error)
                    throw NudgeError.cannotParseToolArguments
                }
                let arguemnt_dict: [String: Value]  = try jsonDecoder.decode([String: Value].self, from: argumentsData)
                os_log("Decoded arguments: %@", log: log, type: .debug, String(describing: arguemnt_dict))
                
                // Notify client about tool call
                callbackClient?.onToolCalled(toolName: functionName, arguments: curr_tool.function.arguments)
                
                var server_response = ""
                
                do {
                    switch functionName {
                    case "get_ui_elements":
                        os_log("Calling get_ui_elements", log: log, type: .debug)
                        let ui_element_tree: [UIElementInfo] = try await NudgeLibrary.shared.getUIElements(arguments: arguemnt_dict)
                        server_response = formatUIElementsToString(ui_element_tree)
                        break
                    case "click_element_by_id":
                        os_log("Calling click_element_by_id", log: log, type: .debug)
                        try await NudgeLibrary.shared.clickElement(arguments: arguemnt_dict)
                        server_response = "Successfully clicked the UI element"
                        break
                    case "update_ui_element_tree":
                        os_log("calling update ui_element_tree", log: log, type: .debug)
                        let ui_element_tree = try await NudgeLibrary.shared.updateUIElementTree(arguments: arguemnt_dict)
                        server_response = formatUIElementsToString(ui_element_tree)
                        break
                    default:
                        break
                    }

                } catch {
                    server_response = "Server responded with the following error: \(error.localizedDescription)"
                }
                
                // Update the state with the server response for the next iteration
                openAI_state.last_action = curr_tool.function.name
                openAI_state.last_server_response = server_response
                
                // NOT DOING ANYTHING WITH THE ONLINE SERVER YET
            }


            // UPDATE IF GOAL REACHED
        }
        
        // Notify client that LLM loop has finished
        callbackClient?.onLLMLoopFinished()
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

