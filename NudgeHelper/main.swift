//
//  main.swift
//  NudgeHelper
//
//  Created by Harshit Garg on 18/06/25.
//

import Foundation
import os
let log = OSLog(subsystem: "Harshit.Nudge", category: "main_helper")

class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    
    /// This method is where the NSXPCListener configures, accepts, and resumes a new incoming NSXPCConnection.
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        let interface = NSXPCInterface(with: NudgeHelperProtocol.self)
        
        // Configure the connection.
        // First, set the interface that the exported object implements.
        interface.setInterface(
            NSXPCInterface(with: NudgeClientProtocol.self),
            for: #selector(NudgeHelperProtocol.setClient(_:)),
            argumentIndex: 0,
            ofReply: false
        )
        
        newConnection.exportedInterface = interface
        
        // Next, set the object that the connection exports. All messages sent on the connection to this service will be sent to the exported object to handle. The connection retains the exported object.
        let exportedObject = NudgeHelper()
        newConnection.exportedObject = exportedObject
        
        // Resuming the connection allows the system to deliver more incoming messages.
        newConnection.resume()
        
        // Returning true from this method tells the system that you have accepted this connection. If you want to reject the connection for some reason, call invalidate() on the connection and return false.
        return true
    }
    
}

// Create the delegate for the service.
let delegate = ServiceDelegate()

// Set up the one NSXPCListener for this service. It will handle all incoming connections.
let listener = NSXPCListener.service()
listener.delegate = delegate

// Resuming the serviceListener starts this service. This method does not return.
listener.resume()

