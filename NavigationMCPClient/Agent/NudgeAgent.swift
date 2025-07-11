//
//  NudgeAgent.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 11/07/25.
//

import LangGraph
import OSLog

// The nudge agent to do everything required
struct NudgeAgent {
    let log = OSLog(subsystem: "Harshit.Nudge", category: "Agent")
    // Define nodes here
    var workflow: StateGraph<NudgeAgentState>
    var state: NudgeAgentState
    let edge_mappings: [String: String] = [
        "tool_call": "tool_node",
        "finish": END
    ]
    
    var agent: StateGraph<NudgeAgentState>.CompiledGraph?
    
    init() {
        // TODO: Decide how the Nudge agent is initialised.
        // Need to decinde how initial state for the agent will be decided, where it will be decided
        // Been thinking about a .md file for how the agent should behave or something like this
        
        // TODO: As I don't have any custom channels I have this basic workflow
        os_log("Initializing Nudge Agent", log: log, type: .debug)
        self.workflow = StateGraph { state in
            return NudgeAgentState(state)
        }
        
        self.state = NudgeAgentState([:])
        os_log("Initialization Success", log: log, type: .debug)
    }
    
    mutating func defineWorkFlow() throws {
        os_log("Defining the workflow of the agent", log: log, type: .debug)
        try self.workflow.addNode("llm_node", action: contact_llm)
        try self.workflow.addNode("tool_node", action: tool_call)
        
        // START to the first node
        try self.workflow.addEdge(sourceId: START, targetId: "llm_node")
        
        // Add a conditional edge to tool call
        try self.workflow.addConditionalEdge(sourceId: "llm_node", condition: edgeConditionForLLM, edgeMapping: self.edge_mappings)
        
        // Add an edge to go to the llm node right after tool call. No conditions asked
        try self.workflow.addEdge(sourceId: "tool_node", targetId: "llm_node")
        
        self.agent = try self.workflow.compile()
    }
    
    func contact_llm(Action: NudgeAgentState) async throws -> PartialAgentState {
        // Call LLM here.
        // Fill the agent outcome
        // Update anyother thing that is required
        os_log("contact_llm function called", log: log, type: .debug)
        
        return Action.data
    }
    
    func tool_call(Action: NudgeAgentState) async throws -> PartialAgentState {
        // Based on agent outcome call a tool that is required
        os_log("tool_call function called", log: log, type: .debug)
        return Action.data
    }
    
    // Checks if we need to end the loop or call some other tool
    func edgeConditionForLLM(Action: NudgeAgentState) async throws -> String {
        // Based on the agent outcome decide if we need to go to the tool_call or end it
        os_log("Edgne conditon is checked", log: log, type: .debug)
        
        return "finish"
    }
    
}
