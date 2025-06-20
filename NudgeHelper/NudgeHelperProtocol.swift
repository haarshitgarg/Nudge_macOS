//
//  NudgeHelperProtocol.swift
//  NudgeHelper
//
//  Created by Harshit Garg on 18/06/25.
//

import Foundation

/// The protocol that this service will vend as its API. This protocol will also need to be visible to the process hosting the service.
@objc protocol NudgeHelperProtocol {
    
    // Function to send the chat message by user to NudgeHelper
    func sendChatMessage(message: String, with reply: @escaping (String) -> Void)
    
    // Function to set the client that will be used by the service
    func setClient(_ nudgeClient: NudgeClientProtocol)

    // Function to clean up the service
    func terminate()
}

/*
 To use the service from an application or other process, use NSXPCConnection to establish a connection to the service by doing something like this:

     connectionToService = NSXPCConnection(serviceName: "Harshit.NudgeHelper")
     connectionToService.remoteObjectInterface = NSXPCInterface(with: (any NudgeHelperProtocol).self)
     connectionToService.resume()

 Once you have a connection to the service, you can use it like this:

     if let proxy = connectionToService.remoteObjectProxy as? NudgeHelperProtocol {
         proxy.performCalculation(firstNumber: 23, secondNumber: 19) { result in
             NSLog("Result of calculation is: \(result)")
         }
     }

 And, when you are finished with the service, clean up the connection like this:

     connectionToService.invalidate()
*/
