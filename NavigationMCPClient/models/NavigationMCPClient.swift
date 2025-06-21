//
//  NavigationMCPClient.swift
//  NavigationMCPClient
//
//  Created by Harshit Garg on 21/06/25.
//

import Foundation
import os
import MCP



/// This object implements the protocol which we have defined. It provides the actual behavior for the service. It is 'exported' by the service to make it available to the process hosting the service over an NSXPCConnection.
class NavigationMCPClient: NSObject, NavigationMCPClientProtocol {
    private let log = OSLog(subsystem: "Harshit.Nudge", category: "NavigationMCPClient")
    
    // MCP client variables
    private var client: Client?
    // ____________________
    
    override init() {
        super.init()
        setupMCPClient()
        os_log("NavigationMCPClient initialized", log: log, type: .debug)
    }
    
    @objc func sendUserMessage(_ message: String) {
        os_log("Received user message: %@", log: log, type: .debug, message)
    }
    
    // MARK: - Start the MCP client settings from here
    private func setupMCPClient() {
        os_log("Setting up MCP Client...", log: log, type: .debug)
        // Load server configuration
        loadServerConfig()
        self.client = Client(name: "NudgeClient", version: "1.0")
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
                       serverConfig.host, 
                       serverConfig.port, 
                       serverConfig.transport,
                       serverConfig.requiresAccessibility ? "true" : "false")
                
                // Here you can add logic to process each server configuration
                // For example, you might want to:
                // - Validate the configuration
                // - Set up connections to each server
                // - Store them for later use
            }
            
        } catch {
            os_log("Error loading server configuration: %@", log: log, type: .error, error.localizedDescription)
        }
    }
        
}

