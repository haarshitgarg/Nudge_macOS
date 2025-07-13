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

// The nudge agent to do everything required
struct NudgeAgent {
    let log = OSLog(subsystem: "Harshit.Nudge", category: "Agent")
    // Define nodes here
    var workflow: StateGraph<NudgeAgentState>
    var state: NudgeAgentState
    let edge_mappings: [String: String] = [
        "tool_call": "tool_node",
        "ask_user": "user_node",
        "finish": END
    ]
    
    struct agentResponse: Codable {
        let ask_user: String?
        let finished: String?
        let agent_thought: String?
    }
    
    // Tools
    var chat_gpt_tools: [ChatQuery.ChatCompletionToolParam] = []
    private let jsonEncoder: JSONEncoder = JSONEncoder()
    private let jsonDecoder: JSONDecoder = JSONDecoder()

    // LLM Information
    var openAIClient: OpenAI
    
    var agent: StateGraph<NudgeAgentState>.CompiledGraph?
    
    init() throws {
        // TODO: Decide how the Nudge agent is initialised.
        // Need to decinde how initial state for the agent will be decided, where it will be decided
        // Been thinking about a .md file for how the agent should behave or something like this
        
        // TODO: As I don't have any custom channels I have this basic workflow
        os_log("Initializing Nudge Agent", log: log, type: .debug)
        self.workflow = StateGraph(channels: NudgeAgentState.schema) { state in
            return NudgeAgentState(state)
        }
        // Initialise open AI
        os_log("Initializing OpenAI client with API key", log: log, type: .debug)
        self.openAIClient = OpenAI(apiToken: Secrets.open_ai_key)

        // Initialise State
        self.state = NudgeAgentState([:])
        try self.initialiseAgentState()
        os_log("Initialization Success", log: log, type: .debug)
    }
    
    mutating func defineWorkFlow() throws {
        os_log("Defining the workflow of the agent", log: log, type: .debug)
        try self.workflow.addNode("llm_node", action: contact_llm)
        try self.workflow.addNode("tool_node", action: tool_call)
        try self.workflow.addNode("user_node", action: user_input)
        
        // START to the first node
        try self.workflow.addEdge(sourceId: START, targetId: "llm_node")
        
        // Add a conditional edge to tool call
        try self.workflow.addConditionalEdge(sourceId: "llm_node", condition: edgeConditionForLLM, edgeMapping: self.edge_mappings)
        
        // Add an edge to go to the llm node right after tool call. No conditions asked
        try self.workflow.addEdge(sourceId: "tool_node", targetId: "llm_node")
        
        // Add an edge to go to the llm node right after user call. No conditions asked
        try self.workflow.addEdge(sourceId: "user_node", targetId: "llm_node")
        
        do {
            self.agent = try self.workflow.compile()
            os_log("✅ Workflow compiled successfully", log: log, type: .info)
        } catch {
            os_log("❌ Workflow compilation failed: %@", log: log, type: .error, error.localizedDescription)
            os_log("Compile error details - Domain: %@, Code: %d", log: log, type: .error, (error as NSError).domain, (error as NSError).code)
            throw error
        }
    }
    
    func contact_llm(Action: NudgeAgentState) async throws -> PartialAgentState {
        // Call LLM here.
        // Fill the agent outcome
        // Update anyother thing that is required
        os_log("contact_llm function called", log: log, type: .debug)
        os_log("Current thought process", log: log, type: .debug)
        if let thought = Action.agent_outcome?.choices.first?.message.content?.data(using: .utf8) {
            let agent_response = try jsonDecoder.decode(agentResponse.self, from: thought)
            let agent_thought = agent_response.agent_thought
            os_log("Agent thought process atm: %@", log: log, type: .debug, agent_thought ?? "Nothing")
        }
        
        
        let user_query: String = Action.user_query ?? "Testing 123"
        let system_instructions: String = Action.system_instructions ?? "NO INSTRUCTIONS"
        let context = try buildContextFromState(Action)

        guard let system_message_to_llm: ChatQuery.ChatCompletionMessageParam = ChatQuery.ChatCompletionMessageParam(
            role: .system, content: system_instructions
        ) else {
            throw NudgeError.cannotCreateMessageForOpenAI
        }
        
        guard let developer_message_to_llm: ChatQuery.ChatCompletionMessageParam = ChatQuery.ChatCompletionMessageParam(
            role: .developer, content: context
        ) else {
            throw NudgeError.cannotCreateMessageForOpenAI
        }
        
        guard let user_message_to_llm: ChatQuery.ChatCompletionMessageParam = ChatQuery.ChatCompletionMessageParam(
            role: .user, content: user_query
        ) else {
            throw NudgeError.cannotCreateMessageForOpenAI
        }
        
        let messages = [system_message_to_llm, developer_message_to_llm, user_message_to_llm]
        
        // Get tools from the current state
        let availableTools = Action.available_tools ?? []
        os_log("No of tools available for the agent: %d", log: log, type: .debug, availableTools.count)
        let llm_query = ChatQuery(
            messages: messages,
            model: "gpt-4.1",
            tools: availableTools
            )
        
        guard let iteration: Int = Action.no_of_iteration else {
            os_log("No of iterations variable doesn't exist", log: log, type: .error)
            throw NudgeError.agentStateVarMissing(description: "The no_of_iteration doesn't exist")
        }
        
        return try await performOpenAIRequestWithRetry(query: llm_query, iteration: iteration, maxRetries: 3)
    }
    
    func tool_call(Action: NudgeAgentState) async throws -> PartialAgentState {
        // Based on agent outcome call a tool that is required
        os_log("tool_call function called", log: log, type: .debug)
        
        guard let errors = Action.no_of_errors else {
            os_log("The errors variable not found in the state", log: log, type: .debug)
            throw NudgeError.agentStateVarMissing(description: "no_of_errors var missing")
        }
        guard let iterations = Action.no_of_iteration else {
            os_log("The iterations variable not found in the state", log: log, type: .debug)
            throw NudgeError.agentStateVarMissing(description: "no_of_iteration var missing")
        }

        
        guard let tool_calls = Action.agent_outcome?.choices.first?.message.toolCalls else {
            os_log("Tool call list is empty", log: log, type: .error)
            return [
                "no_of_iteration": iterations + 1,
                "no_of_errors": errors + 1
            ]
        }
        
        guard let curr_tool = tool_calls.first else {
            os_log("Tool call list is empty", log: log, type: .error)
            throw NudgeError.toolcalllistempty
        }
        
        let function_name = curr_tool.function.name
        os_log("Tool call function name: %@", log: log, type: .debug, function_name)
        guard let argumentsData = curr_tool.function.arguments.data(using: .utf8) else {
            os_log("Failed to convert arguments to Data", log: log, type: .error)
            throw NudgeError.cannotParseToolArguments
        }
        let arguemnt_dict: [String: Value]  = try jsonDecoder.decode([String: Value].self, from: argumentsData)
        os_log("Decoded arguments: %@", log: log, type: .debug, String(describing: arguemnt_dict))
        
        do {
            switch (curr_tool.function.name) {
            case "get_ui_elements":
                os_log("Calling get_ui_elemets", log: log, type: .debug)
                let ui_element_tree: [UIElementInfo] = try await NudgeLibrary.shared.getUIElements(arguments: arguemnt_dict)
                let server_response = formatUIElementsToString(ui_element_tree)
                return [
                    "current_application_state": server_response,
                    "no_of_iteration": iterations + 1
                ]
            case "click_element_by_id":
                os_log("Calling click_element_by_id", log: log, type: .debug)
                try await NudgeLibrary.shared.clickElement(arguments: arguemnt_dict)
                return [
                    "current_application_state": "Successfully clicked the element. The state of application might have changed because of that",
                    "no_of_iteration": iterations + 1
                ]
            case "update_ui_element_tree":
                os_log("Calling update_ui_element_tree", log: log, type: .debug)
                let ui_element_tree: [UIElementInfo] = try await NudgeLibrary.shared.updateUIElementTree(arguments: arguemnt_dict)
                let server_response = formatUIElementsToString(ui_element_tree)
                return [
                    "current_application_state": server_response,
                    "no_of_iteration": iterations + 1
                ]
            default:
                return [
                    "tool_call_result": "The tool with name \(function_name) is not implemented or not supported by the server. Please look into the available tools or ask user for more help",
                    "no_of_errors": errors + 1,
                    "no_of_iteration": iterations + 1
                ]
            }
        } catch {
            return [
                "current_application_state": "The following error occured while performing the toolcall: \(error.localizedDescription)",
                "no_of_errors": errors + 1,
                "no_of_iteration": iterations + 1
            ]
            
        }
    }
    
    func user_input(Action: NudgeAgentState) async throws -> PartialAgentState {
        // ASK user for its input
        guard let agent_outcome = Action.agent_outcome else {
            os_log("The agent_outcome variable not found in the state", log: log, type: .debug)
            throw NudgeError.agentStateVarMissing(description: "agent_outcome variable is missing")
        }
        
        guard let message = agent_outcome.choices.first?.message.content?.data(using: .utf8) else {
            os_log("The content from llm is missing")
            throw NudgeError.agentStateVarMissing(description: "agent_outcome has no content")
        }
        
        let response: agentResponse = try self.jsonDecoder.decode(agentResponse.self, from: message)
        if response.ask_user != nil {
            os_log("Asking user for information", log: log, type: .debug)
        }
        
        return [
            "chat_history":
                    [
                        "agent: \(response.ask_user ?? "Agent asked user")",
                        "user: Do what you think is best. You have complete freedom to choose"
                    ]
        ]
    }
    
    // Checks if we need to end the loop or call some other tool
    func edgeConditionForLLM(Action: NudgeAgentState) async throws -> String {
        os_log("Edge conditon is checked", log: log, type: .debug)
        guard let errors = Action.no_of_errors else {
            os_log("The errors variable not found in the state", log: log, type: .debug)
            return "finish"
        }
        guard let iterations = Action.no_of_iteration else {
            os_log("The iterations variable not found in the state", log: log, type: .debug)
            return "finish"
        }
        
        if (errors > 5 || iterations > 10) {
            os_log("Reached the limit of iterations and errors, stopping")
            return "finish"
        }
        // Based on the agent outcome decide if we need to go to the tool_call or end it
        if (Action.agent_outcome?.choices.first?.message.toolCalls?.count ?? 0 > 0) {
            os_log("Deciding to go to the node tool_call as tools are available", log: log, type: .debug)
            return "tool_call"
        }
        
        guard let response = Action.agent_outcome?.choices.first?.message.content?.data(using: .utf8) else {
            os_log("The agent outcome variable has no content to decide if we need to ask user or finish", log: log, type: .debug)
            throw NudgeError.agentStateVarMissing(description: "The agent_outcome has no content")
        }
        os_log("Response received will decide if we need to ask user or finish")
        let message: agentResponse = try JSONDecoder().decode(agentResponse.self, from: response)
        if message.ask_user != nil {
            return "ask_user"
        }
        if message.finished != nil {
            os_log("Finishing because agent says: %@", log: log, type: .debug, message.finished!)
            return "finish"
        }
        os_log("Why am i here", log: log, type: .debug)
        os_log("%@", log: log, type: .debug, String(data: response, encoding: .utf8) ?? "NO DATA")

        return "finish"
    }
    
    // MARK: Private functions
    
    private mutating func initialiseAgentState() throws {
        os_log("Initializing agent state with .md files", log: log, type: .debug)
        
        // Load system instructions from SystemInstructions.md
        if let systemInstructionsPath = Bundle.main.path(forResource: "SystemInstructions", ofType: "md") {
            let systemInstructions = try String(contentsOfFile: systemInstructionsPath, encoding: .utf8)
            self.state.data["system_instructions"] = systemInstructions
            os_log("Loaded system instructions successfully", log: log, type: .debug)
        } else {
            os_log("SystemInstructions.md not found in bundle", log: log, type: .error)
            throw NudgeError.agentNotInitialized(description: "SystemInstrcutions.md not found in bundle")
        }
        
        // Load rules from Nudge.md
        if let rulesPath = Bundle.main.path(forResource: "Nudge", ofType: "md") {
            let rules = try String(contentsOfFile: rulesPath, encoding: .utf8)
            self.state.data["rules"] = rules
            os_log("Loaded rules successfully", log: log, type: .debug)
        } else {
            os_log("Nudge.md not found in bundle", log: log, type: .error)
            throw NudgeError.agentNotInitialized(description: "Nudge.md not found in bundle")
        }
        
        // Initialize other state properties
        self.state.data["todo_list"] = [String]()
        self.state.data["knowledge"] = [String]()
        self.state.data["no_of_iteration"] = 0
        self.state.data["no_of_errors"] = 0

        os_log("Agent state initialization completed", log: log, type: .debug)
    }
    
    
    private func performOpenAIRequestWithRetry(query: ChatQuery, iteration: Int, maxRetries: Int) async throws -> PartialAgentState {
        var retryCount = 0
        
        while retryCount <= maxRetries {
            do {
                os_log("Attempting OpenAI request (attempt %d/%d)", log: log, type: .debug, retryCount + 1, maxRetries + 1)
                
                let response = try await self.openAIClient.chats(query: query)
                os_log("OpenAI request successful", log: log, type: .info)
                
                return [
                    "no_of_iteration": iteration + 1,
                    "agent_outcome": response
                ]
                
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
                throw NudgeError.failedToSendMessageToOpenAI(descripiton: "\(detailedError) [\(errorContext)]")
            }
        }
        
        throw NudgeError.failedToSendMessageToOpenAI(descripiton: "Max retries exceeded. Model: \(query.model), Messages: \(query.messages.count)")
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
        
        // Add user query
        if let user_query = state.user_query {
            contextComponents.append("## user_query\n\(user_query)")
        }
        
        // Add current application UI state if available
        if let currentAppState = state.current_application_state {
            contextComponents.append("## current_application_state\n\(currentAppState)")
        }
        
        // Add todo list if available
        if let todoList = state.todo_list, !todoList.isEmpty {
            let todoString = todoList.enumerated().map { index, todo in
                "\(index + 1). \(todo)"
            }.joined(separator: "\n")
            contextComponents.append("## Pending Tasks\n\(todoString)")
        }
        
        // Add previous agent outcome if available
        if let message = state.agent_outcome?.choices.first?.message.content?.data(using: .utf8) {
            let agent_message = try self.jsonDecoder.decode(agentResponse.self, from: message)
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
    
    // MARK: Public functions

    public func invoke() async throws -> NudgeAgentState? {
        os_log("Running the Nudge Agent...", log: log, type: .debug)
        os_log("Current Context: %@", log: log, type: .debug, try self.buildContextFromState(self.state))
        return try await self.agent?.invoke(inputs: self.state.data, verbose: true)
    }
    
    public mutating func updateTools(_ tools: [ChatQuery.ChatCompletionToolParam]) {
        self.chat_gpt_tools = tools
        self.state.data["available_tools"] = tools
        os_log("NudgeAgent: Tools updated, now have %d tools", log: log, type: .debug, self.chat_gpt_tools.count)
    }
}
