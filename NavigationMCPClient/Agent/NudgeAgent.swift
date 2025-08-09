//
//  NudgeAgent.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 11/07/25.
//

import Foundation
import LangGraph
import MCP
import OpenAI
import OSLog
import NudgeLibrary

extension String {
    func chunked(into size: Int) -> [String] {
        return stride(from: 0, to: count, by: size).map {
            let start = index(startIndex, offsetBy: $0)
            let end = index(start, offsetBy: min(size, count - $0))
            return String(self[start..<end])
        }
    }
}


// The nudge agent to do everything required
struct NudgeAgent {
    let log = OSLog(subsystem: "Harshit.Nudge", category: "Agent")
    let agent_log = OSLog(subsystem: "Harshit.Nudge", category: "AgentLog")
    // Define nodes here
    var workflow: StateGraph<NudgeAgentState>
    var state: NudgeAgentState
    let edge_mappings: [String: String] = [
        "tool_call": "tool_node",
        "ask_user": "user_node",
        "llm_call": "llm_node",
        "finish": "update_todos_node"
    ]
    
    let todo_edge_mappings: [String: String] = [
        "agent_call": "agent_rag_node",
        "finish": END,
        ]
    
    private let saver = MemoryCheckpointSaver()

    
    var serverDelegate: NudgeAgentDelegate?
    
    // Tools
    var chat_gpt_tools: [ChatQuery.ChatCompletionToolParam] = []
    private let jsonEncoder: JSONEncoder = JSONEncoder()
    private let jsonDecoder: JSONDecoder = JSONDecoder()
    

    // LLM Information
    var openAIClient: OpenAI
    
    var agent: StateGraph<NudgeAgentState>.CompiledGraph?
    
    init() throws {
        self.workflow = StateGraph(channels: NudgeAgentState.schema) { state in
            return NudgeAgentState(state)
        }
        // Initialise open AI
        self.openAIClient = OpenAI(apiToken: Secrets.open_ai_key)

        // Initialise State
        self.state = NudgeAgentState([:])
        try self.initialiseAgentState()
    }
    
    mutating func defineWorkFlow() throws {
        try self.workflow
            .addNode("todo_node", action: make_todo_list)
            .addNode("agent_rag_node", action: get_rag_context)
            .addNode("llm_node", action: contact_llm)
            .addNode("tool_node", action: tool_call)
            .addNode("update_todos_node", action: update_todos)
            .addNode("user_node", action: user_input)
            .addEdge(sourceId: START, targetId: "todo_node")
            .addEdge(sourceId: "todo_node", targetId: "agent_rag_node")
            .addEdge(sourceId: "agent_rag_node", targetId: "llm_node")
            .addConditionalEdge(sourceId: "llm_node", condition: edgeConditionForLLM, edgeMapping: self.edge_mappings)
            .addConditionalEdge(sourceId: "update_todos_node", condition: todoEdgeCondition, edgeMapping: self.todo_edge_mappings)
            .addEdge(sourceId: "tool_node", targetId: "llm_node")
            .addEdge(sourceId: "user_node", targetId: "llm_node")

        self.agent = try self.workflow.compile(config: CompileConfig(checkpointSaver: self.saver, interruptionsBefore: ["user_node"]))
    }
    
    
    // MARK: - Agent Actions
    func make_todo_list(Action: NudgeAgentState) async throws -> PartialAgentState {
        guard let systemInstructions = state.todos_instructions, let user_query = Action.user_query
        else { throw NudgeError.agentStateVarMissing(description: "The todos_instructions/user_query variable is missing") }

        guard let system_message_to_llm = ChatQuery.ChatCompletionMessageParam(role: .system, content: systemInstructions),
              let user_message_to_llm = ChatQuery.ChatCompletionMessageParam(role: .user, content: user_query)
        else { throw NudgeError.cannotCreateMessageForOpenAI }
        
        let messages = [system_message_to_llm, user_message_to_llm]
        let llm_query = ChatQuery(messages: messages, model: "gpt-4.1")
        
        guard let iteration: Int = Action.no_of_iteration else {
            self.serverDelegate?.agentFacedError(error: "Having trouble tracking progress...")
            throw NudgeError.agentStateVarMissing(description: "The no_of_iteration doesn't exist")
        }
        
        guard let result = try await performOpenAIRequestWithRetry(query: llm_query, iteration: iteration, maxRetries: 3).choices.first?.message.content?.data(using: .utf8)
        else {
            throw NudgeError.noMessageFromOpenAI
        }
        
        // TODO: Parse the result and update the todo list
        let todo_list = try JSONDecoder().decode(TodoList.self, from: result)
        return ["todo_list": todo_list]
    }
    
    func update_todos(Action: NudgeAgentState) async throws -> PartialAgentState {
        os_log("Updating todos", log: log, type: .info)
        let todo_list: TodoList = Action.todo_list?.removeFirst() ?? TodoList(todo_list: [])
        os_log("Todos left to process: %d", log: log, type: .info, todo_list.todo_list.count)
        
        return ["todo_list": todo_list]
    }
    
    func get_rag_context(Action: NudgeAgentState) async throws -> PartialAgentState {
        // TODO: Implement the logic to get rag context
        os_log("Nothing implemented in rag, will do later", log: log, type: .debug)
        return ["rag_input":"Make sure when you need to search for videos or creators on youtube, you put the query directly in the URL itself. It makes it much faster than opening the app and then searching it \n\n  When you want to play a vide check if the link in description has watch in it. It generally means this will link will play the video \n\n If you find information that is very specific you can store that information in the clipboard to be used later"]
    }

    func contact_llm(Action: NudgeAgentState) async throws -> PartialAgentState {
        logAgentState(Action, context: "contact_llm node")
        
        if let thought = Action.agent_outcome?.last?.choices.first?.message.content?.data(using: .utf8),
           let agent_thought = try? jsonDecoder.decode(AgentResponse.self, from: thought).agent_thought {
                self.serverDelegate?.agentRespondedWithThought(thought: agent_thought)
        }
        os_log("Successfully decoded agent thought", log: log, type: .info)
        
        let user_query: String = Action.todo_list?.getFirst() ?? "No todo found, notify user"
        let system_instructions: String = Action.system_instructions ?? "NO INSTRUCTIONS"
        
        let context = try buildContextFromState(Action)

        // Log the context being sent to LLM in a pretty format
        os_log("=== CONTEXT SENT TO LLM ===", log: agent_log, type: .info)
        logPrettyContext(context)
        os_log("===========================", log: agent_log, type: .info)

        guard let system_message_to_llm = ChatQuery.ChatCompletionMessageParam(role: .system, content: system_instructions),
              let developer_message_to_llm = ChatQuery.ChatCompletionMessageParam(role: .developer, content: context),
              let user_message_to_llm = ChatQuery.ChatCompletionMessageParam(role: .user, content: user_query)
        else { throw NudgeError.cannotCreateMessageForOpenAI }
        
        let messages = [system_message_to_llm, developer_message_to_llm, user_message_to_llm]
        let availableTools = Action.available_tools ?? []
        let llm_query = ChatQuery(messages: messages, model: "gpt-4.1", tools: availableTools)
        
        guard let iteration: Int = Action.no_of_iteration else {
            self.serverDelegate?.agentFacedError(error: "Having trouble tracking progress...")
            throw NudgeError.agentStateVarMissing(description: "The no_of_iteration doesn't exist")
        }
        
        let result = try await performOpenAIRequestWithRetry(query: llm_query, iteration: iteration, maxRetries: 3)
        
        // Log complete agent state at end of contact_llm
        logCompleteAgentState(Action)
        
        return ["no_of_iteration": iteration + 1, "agent_outcome": result]
    }
    
    func tool_call(Action: NudgeAgentState) async throws -> PartialAgentState {
        guard let errors = Action.no_of_errors, let iterations = Action.no_of_iteration
        else {
            self.serverDelegate?.agentFacedError(error: "Having trouble tracking execution state...")
            throw NudgeError.agentStateVarMissing(description: "Missing iteration or error tracking variables")
        }

        guard let tool_calls = Action.agent_outcome?.last?.choices.first?.message.toolCalls, let curr_tool = tool_calls.first
        else {
            os_log("Tool call list is empty", log: log, type: .error)
            return ["no_of_errors": errors + 1, "no_of_iteration": iterations + 1]
        }
        
        let function_name = curr_tool.function.name
        let function_arguments = curr_tool.function.arguments
        
        //logAgentState(Action, context: "tool_call node")
        os_log("Tool Being Called: %@", log: agent_log, type: .info, function_name)
        os_log("Tool Arguments: %@", log: agent_log, type: .info, function_arguments)
        
        self.serverDelegate?.agentCalledTool(toolName: function_name)
        
        guard let argumentsData = curr_tool.function.arguments.data(using: .utf8) else {
            os_log("Failed to convert arguments to Data", log: log, type: .error)
            self.serverDelegate?.agentFacedError(error: "Arguments for the tool call are not in correct format")
            throw NudgeError.cannotParseToolArguments
        }
        os_log("Decoding tool arguments from JSON", log: log, type: .info)
        let arguemnt_dict: [String: Value]  = try jsonDecoder.decode([String: Value].self, from: argumentsData)
        let result: PartialAgentState
        do {
            switch (curr_tool.function.name) {
            case "get_ui_elements":
                let ui_element_tree: [UIElementInfo] = try await NudgeLibrary.shared.getUIElements(arguments: arguemnt_dict)
                let server_response = formatUIElementsToString(ui_element_tree)
                result = [
                    "tool_call_result": "Called tool get_ui_elemets. It has returned the updated application state which is stored in current_application_state.",
                    "current_application_state": server_response,
                    "no_of_iteration": iterations + 1
                ]
            case "click_element_by_id":
                let clickResult = try await NudgeLibrary.shared.clickElement(arguments: arguemnt_dict)
                let uiTree = clickResult.uiTree
                if !clickResult.uiTree.isEmpty {
                    let server_response = formatUIElementsToString(uiTree)
                    result = [
                        "tool_call_result": "Called tool click_element_by_id. \(clickResult.message).",
                        "current_application_state": server_response,
                        "no_of_iteration": iterations + 1
                    ]
                } else {
                    result = [
                        "tool_call_result": "Called tool click_element_by_id. \(clickResult.message)",
                        "no_of_iteration": iterations + 1
                    ]
                }
            case "save_to_clipboard":
                guard let message: String = arguemnt_dict["message"]?.stringValue,
                      let meta_information: String = arguemnt_dict["meta_information"]?.stringValue
                else {
                    os_log("Failed to parse arguments for save_to_clipboard", log: log, type: .error)
                    throw NudgeError.cannotParseToolArguments
                }
                let clip_info: ClipboardContent = ClipboardContent(message: message, meta_data: meta_information)
                result = [
                    "tool_call_result": "Called tool save_to_clipboard. The clipboard information is stored in clip_content.",
                    "clip_content": clip_info,
                    "no_of_iteration": iterations + 1
                ]
            case "set_text_in_element" :
                let ui_element_tree = try await NudgeLibrary.shared.setTextInElement(arguments: arguemnt_dict)
                let server_response = formatUIElementsToString(ui_element_tree.uiTree)
                result = [
                    "tool_call_result": "Called tool set_text_in_element. Retured with message: \(ui_element_tree.message)",
                    "current_application_state": server_response,
                    "no_of_iteration": iterations + 1
                ]
            default:
                result = [
                    "tool_call_result": "The tool with name \(function_name) is not implemented or not supported by the server. Please look into the available tools or ask user for more help",
                    "no_of_errors": errors + 1,
                    "no_of_iteration": iterations + 1
                ]
            }
        } catch {
            let errorMessage = "The following error occured while performing the toolcall: \(error.localizedDescription)"
            result = [
                "current_application_state": errorMessage,
                "no_of_errors": errors + 1,
                "no_of_iteration": iterations + 1
            ]
        }
        
        // Log complete agent state at end of tool_call
        //logCompleteAgentState(Action)
        
        return result
    }
    
    func user_input(Action: NudgeAgentState) async throws -> PartialAgentState {
        //logAgentState(Action, context: "user_input node")
        //os_log("Temp User Response: %@", log: agent_log, type: .info, Action.temp_user_response ?? "None")
        if let agent_outcome = Action.agent_outcome, let lastMessage = agent_outcome.last?.choices.first?.message.content {
            //os_log("Agent Outcome (Last Message): %@", log: agent_log, type: .info, lastMessage)
        } else {
            //os_log("Agent Outcome: None", log: agent_log, type: .info)
        }
        
        os_log("Asking user for the input", log: log, type: .info)
        guard let agent_outcome = Action.agent_outcome,
              let message = agent_outcome.last?.choices.first?.message.content?.data(using: .utf8),
              let userResponse = Action.temp_user_response
        else {
            self.serverDelegate?.agentFacedError(error: "Having trouble understanding the current state...")
            throw NudgeError.agentStateVarMissing(description: "User input node is missing variables")
        }
        
        os_log("Decoding agent response from message", log: log, type: .info)
        let response: AgentResponse = try self.jsonDecoder.decode(AgentResponse.self, from: message)
        let result = ["chat_history": ["agent: \(response.ask_user ?? "No question asked")", "user: \(userResponse)"]]
        
        // Log complete agent state at end of user_input
        //logCompleteAgentState(Action)
        
        return result
    }
    
    // MARK: - Edge Conditions
    func todoEdgeCondition(Action: NudgeAgentState) async throws -> String {
        let todoList = Action.todo_list ?? TodoList(todo_list: [])
        if todoList.todo_list.isEmpty {
            return "finish"
        }
        return "agent_call"
    }

    func edgeConditionForLLM(Action: NudgeAgentState) async throws -> String {
        //logAgentState(Action, context: "edgeConditionForLLM")
        
        guard let errors = Action.no_of_errors,
              let iterations = Action.no_of_iteration else {
            self.serverDelegate?.agentFacedError(error: "Having trouble tracking execution state...")
            throw NudgeError.agentStateVarMissing(description: "Missing iteration or error tracking variables")
        }
        
        if (errors > 5 || iterations > 50) {
            os_log("Agent execution limits reached - stopping (errors: %d, iterations: %d)", log: log, type: .info, errors, iterations)
            //logCompleteAgentState(Action)
            return "finish"
        }
        // Based on the agent outcome decide if we need to go to the tool_call or end it
        if (Action.agent_outcome?.last?.choices.first?.message.toolCalls?.count ?? 0 > 0) {
            os_log("Agent requesting tool execution", log: log, type: .info)
            //logCompleteAgentState(Action)
            return "tool_call"
        }
        
        guard let response = Action.agent_outcome?.last?.choices.first?.message.content?.data(using: .utf8) else {
            self.serverDelegate?.agentFacedError(error: "Having trouble understanding the next step...")
            throw NudgeError.agentStateVarMissing(description: "The agent_outcome has no content")
        }
        os_log("Decoding agent response from response in edge condition", log: log, type: .info)
        os_log("Attempting to decode agent response from response: %{public}@", log: log, type: .info, String(data: response, encoding: .utf8) ?? "nil")
        do {
            os_log("Successfully decoded agent response from response in edge condition", log: log, type: .info)
            let message: AgentResponse = try JSONDecoder().decode(AgentResponse.self, from: response)
            if message.ask_user != nil {
                os_log("Agent needs user input", log: log, type: .info)
                //logCompleteAgentState(Action)
                return "ask_user"
            }
            if message.finished != nil {
                os_log("Agent completed task successfully", log: log, type: .info)
                //logCompleteAgentState(Action)
                return "finish"
            }
            if message.agent_thought != nil {
                // Log complete agent state at end of edgeConditionForLLM
                //logCompleteAgentState(Action)
                return "llm_call"
            }
        } catch {
            return "llm_call"
        }
        

        // Log complete agent state at end of edgeConditionForLLM
        //logCompleteAgentState(Action)
        return "finish"
    }
    
    // MARK: - Private functions
    
    private mutating func initialiseAgentState() throws {
        // Load system instructions from SystemInstructions.md
        if let systemInstructionsPath = Bundle.main.path(forResource: "SystemInstructions", ofType: "md") {
            let systemInstructions = try String(contentsOfFile: systemInstructionsPath, encoding: .utf8)
            self.state.data["system_instructions"] = systemInstructions
        } else {
            os_log("SystemInstructions.md not found in bundle", log: log, type: .error)
            throw NudgeError.agentNotInitialized(description: "SystemInstrcutions.md not found in bundle")
        }
        
        // Load rules from Nudge.md
        if let rulesPath = Bundle.main.path(forResource: "Nudge", ofType: "md") {
            let rules = try String(contentsOfFile: rulesPath, encoding: .utf8)
            self.state.data["rules"] = rules
        } else {
            os_log("Nudge.md not found in bundle", log: log, type: .error)
            throw NudgeError.agentNotInitialized(description: "Nudge.md not found in bundle")
        }
        
        if let todosPath = Bundle.main.path(forResource: "TodoInstructions", ofType: "md") {
            let todosInstruction = try String(contentsOfFile: todosPath, encoding: .utf8)
            self.state.data["todos_instructions"] = todosInstruction
        } else {
            os_log("TodosInstructions.md not found in bundle", log: log, type: .error)
            throw NudgeError.agentNotInitialized(description: "TodosInstructions.md not found in bundle")
        }
        
        // Initialize other state properties
        self.state.data["knowledge"] = [String]()
        self.state.data["no_of_iteration"] = 0
        self.state.data["no_of_errors"] = 0

    }
    
    
    private func performOpenAIRequestWithRetry(query: ChatQuery, iteration: Int, maxRetries: Int) async throws -> ChatResult {
        var retryCount = 0
        
        while retryCount <= maxRetries {
            do {
                let response = try await self.openAIClient.chats(query: query)
                os_log("OpenAI request successful", log: log, type: .info)
                
                // Log LLM response details
                if let message = response.choices.first?.message {
                    os_log("=== LLM RESPONSE LOG ===", log: agent_log, type: .info)
                    os_log("Message Content: %@", log: agent_log, type: .info, message.content ?? "None")
                    os_log("Tool Calls Count: %d", log: agent_log, type: .info, message.toolCalls?.count ?? 0)
                    if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                        for (index, toolCall) in toolCalls.enumerated() {
                            os_log("Tool Call %d: %@ with args: %@", log: agent_log, type: .info, index + 1, toolCall.function.name, toolCall.function.arguments)
                        }
                    }
                    os_log("========================", log: agent_log, type: .info)
                }
                
                return response
                
                
            } catch {
                retryCount += 1
                
                // Enhanced error logging with context
                var errorContext = "Model: \(query.model), Messages: \(query.messages.count)"
                
                // Analyze error type for better description
                var detailedError = error.localizedDescription
                if let nsError = error as NSError? {
                    errorContext += ", Domain: \(nsError.domain), Code: \(nsError.code)"
                    
                    // Add specific context for common errors
                    if nsError.domain == "NSCocoaErrorDomain" && nsError.code == 4865 {
                        detailedError = "JSON decoding error - likely system_fingerprint field issue. \(error.localizedDescription)"
                    } else if nsError.code == 401 {
                        detailedError = "Authentication failed - check API key. \(error.localizedDescription)"
                    } else if nsError.code == 429 {
                        detailedError = "Rate limit exceeded. \(error.localizedDescription)"
                    } else if nsError.code >= 500 {
                        detailedError = "OpenAI server error (HTTP \(nsError.code)). \(error.localizedDescription)"
                    }
                }
                
                os_log("OpenAI request failed (attempt %d/%d): %@ [%@]", log: log, type: .error, retryCount, maxRetries + 1, detailedError, errorContext)
                
                // Simple retry for rate limits and server errors
                if retryCount <= maxRetries {
                    let errorMessage = error.localizedDescription.lowercased()
                    if errorMessage.contains("rate limit") || errorMessage.contains("429") || 
                       errorMessage.contains("server error") || errorMessage.contains("500") ||
                       errorMessage.contains("502") || errorMessage.contains("503") {
                        let delay = retryCount * 2 // 2, 4, 6 seconds
                        os_log("Retrying in %d seconds", log: log, type: .info, delay)
                        try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
                        continue
                    }
                }
                
                // If not retryable or max retries exceeded, throw descriptive error
                let finalError = "\(detailedError) [\(errorContext)]"
                self.serverDelegate?.agentFacedError(error: "Having trouble connecting to AI service...")
                throw NudgeError.failedToSendMessageToOpenAI(descripiton: finalError)
            }
        }
        
        let maxRetriesError = "Max retries exceeded. Model: \(query.model), Messages: \(query.messages.count)"
        self.serverDelegate?.agentFacedError(error: "AI service is temporarily unavailable...")
        throw NudgeError.failedToSendMessageToOpenAI(descripiton: maxRetriesError)
    }
    
    private func buildContextFromState(_ state: NudgeAgentState) throws -> String {
        var contextComponents: [String] = []
        
        // Add rules if available
        if let rules = state.rules, !rules.isEmpty {
            contextComponents.append("## Navigation Rules\n\(rules)")
        }
        
        // Add knowledge if available
        if let knowledge = state.knowledge, !knowledge.isEmpty {
            let knowledgeString = knowledge.joined(separator: "\n- ")
            contextComponents.append("## System Knowledge\n- \(knowledgeString)")
        }
        
        // Add current application UI state if available
        if let currentAppState = state.current_application_state {
            contextComponents.append("## current_application_state\n\(currentAppState)")
        }
        
        // Add previous agent outcome if available
        if let message = state.agent_outcome?.last?.choices.first?.message.content?.data(using: .utf8) {
            os_log("Decoding agent message from content", log: log, type: .info)
            let agent_message = try self.jsonDecoder.decode(AgentResponse.self, from: message)
            os_log("Successfully decoded agent message", log: log, type: .info)
            if let thought = agent_message.agent_thought {
                contextComponents.append("## agent_thought\n\(thought)")
            }
        }
        
        // Add tool call result to the context
        if let tool_call_result = state.tool_call_result {
            contextComponents.append("## tool_call_result\n\(tool_call_result)")
        }
        
        // Add chat history to the context
        if let chat_history = state.chat_history {
            contextComponents.append("## chat_history\n")
            contextComponents.append(contentsOf: chat_history)
        }
        
        // Add clipboard content if available
        if let clip_content = state.clip_content {
            contextComponents.append("## clip_content\nMessage: \(clip_content.message)\nMeta Information: \(clip_content.meta_data)")
        }
        
        // RAG CONTEXT
        if let rag_input = state.rag_input {
            contextComponents.append("## Use full information about the task\n\(rag_input)")
        }
        
        // Join all components with double newlines for clear separation
        return contextComponents.isEmpty ? "No additional context available." : contextComponents.joined(separator: "\n\n")
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
    
    // MARK: - Public functions

    public func getState(config: RunnableConfig) throws -> Checkpoint? {
        return self.saver.get(config: config)
    }
    
    public func updateState(config: RunnableConfig, state: [String: Any]) async throws -> RunnableConfig {
        guard let agent = self.agent else {
            os_log("Agent is not initialized, cannot update state", log: log, type: .error)
            throw NudgeError.agentNotInitialized(description: "Agent variable is nil")
        }
        return try await agent.updateState(config: config, values: state)
    }
    
    public mutating func updateTools(_ tools: [ChatQuery.ChatCompletionToolParam]) {
        self.chat_gpt_tools = tools
        self.state.data["available_tools"] = tools
        os_log("Agent tools updated - %d available", log: log, type: .info, self.chat_gpt_tools.count)
    }
    
    public mutating func interruptAgent() {
        //self.agent?.interrupt("Agent interrupted by user")
        self.agent?.pause()
        os_log("Agent execution interrupted", log: log, type: .info)
    }
    
    public func writeCompleteAgentStateToFile(testID: String, reason: String = "Test failure", config: RunnableConfig) throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logDir = documentsPath.appendingPathComponent("NudgeUITestLogs")
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        
        let logFile = logDir.appendingPathComponent("\(testID)_\(timestamp)_complete_agent_state.json")
        
        guard let currState = try self.agent?.getCurrentState(config: config) else {
            throw NudgeError.agentNotInitialized(description: "Agent is not initialized when tried to get the current state logged")
        }

        var logContent = "=== COMPLETE AGENT STATE DUMP ===\n"
        logContent += "Test ID: \(testID)\n"
        logContent += "Reason: \(reason)\n"
        logContent += "Timestamp: \(Date())\n"
        logContent += "Agent Data Keys: \(Array(currState.data.keys).count)\n\n"
        
        // Iterate through all agent state data without any truncation
        for key in Array(currState.data.keys).sorted() {
            let value = currState.data[key]!
            
            if key == "agent_outcome" {
                // Special handling for agent_outcome to show only messages and tool calls
                if let outcomes = currState.value(key) as [ChatResult]? {
                    logContent += "\(key) (\(outcomes.count) outcomes):\n"
                    for (index, outcome) in outcomes.enumerated() {
                        if let message = outcome.choices.first?.message {
                            logContent += "  \(index + 1). Message: \(message.content ?? "None")\n"
                            if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                                logContent += "  \(index + 1). Tool Calls (\(toolCalls.count)):\n"
                                for toolCall in toolCalls {
                                    logContent += "    - \(toolCall.function.name): \(toolCall.function.arguments)\n"
                                }
                            }
                        }
                    }
                } else {
                    logContent += "\(key): \(String(describing: value))\n"
                }
            } else {
                logContent += "\(key): \(String(describing: value))\n"
            }
        }
        
        logContent += "\n==============================="
        
        do {
            try logContent.write(to: logFile, atomically: true, encoding: .utf8)
            os_log("✅ Complete agent state written to file: %@", log: log, type: .info, logFile.path)
        } catch {
            os_log("❌ Failed to write complete agent state to file: %@", log: log, type: .error, error.localizedDescription)
        }
    }
}

// MARK: - Logging Extension
extension NudgeAgent {
    private func logAgentState(_ Action: NudgeAgentState, context: String = "") {
        let contextPrefix = context.isEmpty ? "" : "\(context): "
        os_log("=== AGENT STATE LOG: %@===", log: agent_log, type: .info, contextPrefix)
        os_log("Iteration: %d | Errors: %d", log: agent_log, type: .info, Action.no_of_iteration ?? 0, Action.no_of_errors ?? 0)
        os_log("User Query: %@", log: agent_log, type: .info, Action.user_query ?? "None")
        os_log("Current App State: %@", log: agent_log, type: .info, Action.current_application_state?.isEmpty == false ? "Present (\(Action.current_application_state?.count ?? 0) chars)" : "None")
        os_log("Knowledge Items: %d", log: agent_log, type: .info, Action.knowledge?.count ?? 0)
        os_log("Available Tools: %d", log: agent_log, type: .info, Action.available_tools?.count ?? 0)
        os_log("Chat History Items: %d", log: agent_log, type: .info, Action.chat_history?.count ?? 0)
        os_log("Tool Call Result: %@", log: agent_log, type: .info, Action.tool_call_result?.isEmpty == false ? "Present" : "None")
        os_log("==========================================", log: agent_log, type: .info)
    }
    
    private func logPrettyContext(_ context: String) {
        // Split context into sections and log them nicely
        let sections = context.components(separatedBy: "\n\n")
        
        for section in sections {
            if section.isEmpty { continue }
            
            let lines = section.components(separatedBy: "\n")
            if let firstLine = lines.first {
                if firstLine.hasPrefix("##") {
                    // This is a section header
                    os_log("%@", log: agent_log, type: .info, firstLine)
                    if lines.count > 1 {
                        let content = lines.dropFirst().joined(separator: "\n")
                        // Split long content into chunks for better readability
                        if content.count > 500 {
                            let chunks = content.chunked(into: 400)
                            for (index, chunk) in chunks.enumerated() {
                                os_log("  [Part %d]: %@", log: agent_log, type: .info, index + 1, chunk)
                            }
                        } else {
                            os_log("  %@", log: agent_log, type: .info, content)
                        }
                    }
                } else {
                    // Regular content
                    if section.count > 500 {
                        let chunks = section.chunked(into: 400)
                        for (index, chunk) in chunks.enumerated() {
                            os_log("[Part %d]: %@", log: agent_log, type: .info, index + 1, chunk)
                        }
                    } else {
                        os_log("%@", log: agent_log, type: .info, section)
                    }
                }
            }
        }
    }
    
    private func logCompleteAgentState(_ state: NudgeAgentState) {
        os_log("=== COMPLETE AGENT STATE DUMP ===", log: agent_log, type: .info)
        
        // Basic counters
        os_log("Iteration: %d", log: agent_log, type: .info, state.no_of_iteration ?? 0)
        os_log("Errors: %d", log: agent_log, type: .info, state.no_of_errors ?? 0)
        
        // User query
        os_log("User Query: %@", log: agent_log, type: .info, state.user_query ?? "None")
        
        // System instructions (truncated)
        if let instructions = state.system_instructions {
            let truncated = instructions.count > 100 ? String(instructions.prefix(100)) + "..." : instructions
            os_log("System Instructions: %@", log: agent_log, type: .info, truncated)
        } else {
            os_log("System Instructions: None", log: agent_log, type: .info)
        }
        
        // Rules (truncated)
        if let rules = state.rules {
            let truncated = rules.count > 100 ? String(rules.prefix(100)) + "..." : rules
            os_log("Rules: %@", log: agent_log, type: .info, truncated)
        } else {
            os_log("Rules: None", log: agent_log, type: .info)
        }
        
        // Knowledge
        if let knowledge = state.knowledge, !knowledge.isEmpty {
            os_log("Knowledge (%d items):", log: agent_log, type: .info, knowledge.count)
            for (index, item) in knowledge.enumerated() {
                let truncated = item.count > 80 ? String(item.prefix(80)) + "..." : item
                os_log("  %d: %@", log: agent_log, type: .info, index + 1, truncated)
            }
        } else {
            os_log("Knowledge: Empty", log: agent_log, type: .info)
        }
        
        // Current application state (truncated)
        if let appState = state.current_application_state {
            let truncated = appState.count > 200 ? String(appState.prefix(200)) + "..." : appState
            os_log("Current Application State (%d chars): %@", log: agent_log, type: .info, appState.count, truncated)
        } else {
            os_log("Current Application State: None", log: agent_log, type: .info)
        }
        
        // Agent outcome
        if let outcomes = state.agent_outcome, !outcomes.isEmpty {
            os_log("Agent Outcomes (%d):", log: agent_log, type: .info, outcomes.count)
            for (index, outcome) in outcomes.enumerated() {
                if let content = outcome.choices.first?.message.content {
                    let truncated = content.count > 100 ? String(content.prefix(100)) + "..." : content
                    os_log("  %d: %@", log: agent_log, type: .info, index + 1, truncated)
                }
                if let toolCalls = outcome.choices.first?.message.toolCalls {
                    os_log("  %d Tool Calls: %d", log: agent_log, type: .info, index + 1, toolCalls.count)
                }
            }
        } else {
            os_log("Agent Outcomes: None", log: agent_log, type: .info)
        }
        
        // Tool call result
        if let toolResult = state.tool_call_result {
            let truncated = toolResult.count > 150 ? String(toolResult.prefix(150)) + "..." : toolResult
            os_log("Tool Call Result: %@", log: agent_log, type: .info, truncated)
        } else {
            os_log("Tool Call Result: None", log: agent_log, type: .info)
        }
        
        // Chat history
        if let history = state.chat_history, !history.isEmpty {
            os_log("Chat History (%d items):", log: agent_log, type: .info, history.count)
            for (index, chat) in history.enumerated() {
                let truncated = chat.count > 80 ? String(chat.prefix(80)) + "..." : chat
                os_log("  %d: %@", log: agent_log, type: .info, index + 1, truncated)
            }
        } else {
            os_log("Chat History: Empty", log: agent_log, type: .info)
        }
       
        // Clipboard content
        if let clipContent = state.clip_content {
            let truncated = clipContent.message.count > 80 ? String(clipContent.message.prefix(80)) + "..." : clipContent.message
            os_log("Clipboard Content: %@ (Meta: %@)", log: agent_log, type: .info, truncated, clipContent.meta_data)
        } else {
            os_log("Clipboard Content: None", log: agent_log, type: .info)
        }
        
        // Temp user response
        os_log("Temp User Response: %@", log: agent_log, type: .info, state.temp_user_response ?? "None")
        
        os_log("================================", log: agent_log, type: .info)
    }
}

// MARK: - Nudge Agent delegate protocol
protocol NudgeAgentDelegate {
    func agentCalledTool(toolName: String)
    
    func agentAskedUserForInput(question: String)
    
    func agentRespondedWithThought(thought: String)
    
    func agentFacedError(error: String)
}
    
