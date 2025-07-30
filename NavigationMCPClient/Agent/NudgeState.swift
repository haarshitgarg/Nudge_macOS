//
//  NudgeState.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 11/07/25.
//

import LangGraph
import OpenAI
import NudgeLibrary

// More information is good as I can pick and chose what goes into the LLM, so any useful information about the current state is good
struct NudgeAgentState: AgentState {
    
    var data: [String : Any]
    
    static var schema: Channels = {
        [
            "chat_history": AppenderChannel<String>(),
            "agent_outcome": AppenderChannel<ChatResult>()
        ]
    }()
    
    init(_ initState: [String : Any]) {
        self.data = initState
    }
    
    var todo_list: [String]? {
        value("todo_list")
    }
    
    // TODO: I don't want to let anyone edit the user_query once it is set. Need to define a way to do that
    var user_query: String? {
        value("user_query")
    }
    
    // TODO: I don't want anyone to change system instructions at any point in the Agent lifecycle. Need to find a way
    var system_instructions: String? {
        value("system_instructions")
    }
    
    // TODO: Get this from a text file or like an .md file (same as how gemini or claude does it)
    var rules: String? {
        value("rules")
    }
    
    // Knowledge about the system. Like what apps or how accessibility architecture works etc
    // I was debating whether to put it as String or a list of string. I am thinking if I add a comprehensive RAG pipeline for this knowledge, it is better
    // to have a list of string. Might be wrong. We'll see
    var knowledge: [String]? {
        value("knowledge")
    }
    
    // To capture the current ui state of application agent is interacting with
    var current_application_state: String? {
        value("current_application_state")
    }
    
    // Whatever the agent has blurted out.
    var agent_outcome: [ChatResult]? {
        value("agent_outcome")
    }
    
    // Available tools for the agent
    var available_tools: [ChatQuery.ChatCompletionToolParam]? {
        value("available_tools")
    }
    
    var no_of_iteration: Int? {
        value("no_of_iteration")
    }
    
    var no_of_errors: Int? {
        value("no_of_errors")
    }
    
    var tool_call_result: String? {
        value("tool_call_result")
    }
    
    var chat_history: [String]? {
        value("chat_history")
    }
    
    var temp_user_response: String? {
        value("temp_user_response")
    }
    
}
