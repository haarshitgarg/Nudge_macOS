//
//  main.swift
//  NavigationMCPClient
//
//  Created by Harshit Garg on 21/06/25.
//

import Foundation

class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    
    /// This method is where the NSXPCListener configures, accepts, and resumes a new incoming NSXPCConnection.
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        
        // Configure the connection.
        // First, set the interface that the exported object implements.
        let serviceInterface = NSXPCInterface(with: (any NavigationMCPClientProtocol).self)
        let callbackInterface = NSXPCInterface(with: (any NavigationMCPClientCallbackProtocol).self)
        
        // Configure the service interface to accept callback client parameter
        serviceInterface.setInterface(callbackInterface, for: #selector(NavigationMCPClientProtocol.setCallbackClient(_:)), argumentIndex: 0, ofReply: false)
        
        newConnection.exportedInterface = serviceInterface
        newConnection.remoteObjectInterface = callbackInterface
        
        // Next, set the object that the connection exports. All messages sent on the connection to this service will be sent to the exported object to handle. The connection retains the exported object.
        let exportedObject = NavigationMCPClient()
        Task {
            await exportedObject.setupMCPClient()
        }
        newConnection.exportedObject = exportedObject
        
        // Resuming the connection allows the system to deliver more incoming messages.
        newConnection.resume()
        
        // Returning true from this method tells the system that you have accepted this connection. If you want to reject the connection for some reason, call invalidate() on the connection and return false.
        return true
    }
    
}

// Running the stdio server
//NudgeServerRun()

// Create the delegate for the service.
let delegate = ServiceDelegate()

// Set up the one NSXPCListener for this service. It will handle all incoming connections.
let listener = NSXPCListener.service()
listener.delegate = delegate

// Resuming the serviceListener starts this service. This method does not return.
listener.resume()
