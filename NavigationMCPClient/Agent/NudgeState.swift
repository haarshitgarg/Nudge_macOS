//
//  NudgeState.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 11/07/25.
//

import LangGraph

struct NudgeAgentState: AgentState {
    
    var data: [String : Any]
    
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
        value("user_query")
    }
    
    // TODO: Get this from a text file or like an .md file (same as how gemini or claude does it)
    var rules: String? {
        value("rules")
    }
    
    // I was debating whether to put it as String or a list of string. I am thinking if I add a comprehensive RAG pipeline for this knowledge, it is better
    // to have a list of string. Might be wrong. We'll see
    var knowledge: [String]? {
        value("knowledge")
    }
    
    var current_application_state: [String: String]? {
        value("current_application_state")
    }
    
    var agent_outcome: AgentOutcome? {
        value("agent_outcome")
    }
    
}

