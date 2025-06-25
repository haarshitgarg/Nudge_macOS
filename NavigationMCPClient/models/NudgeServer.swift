//
//  NudgeServer.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 25/06/25.
//

// This file is to run the stdio MCP NudgeServer
import Foundation

public func NudgeServerRun() {
    if let executablePath = Bundle.main.path(forResource: "NudgeServer", ofType: nil) {
        print("Running the NudgeServer executable")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executablePath)
        // task.arguments = [...]
        try? task.run()
    } else {
        print("Couldn't find the NudgeServer Executable")
    }
}

