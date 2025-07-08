//
//  XPCMessage.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 18/06/25.
//

import Foundation

struct XPCMessage {
    public let id: UUID
    public let content: String
    
    init(content: String) {
        self.id = UUID()
        self.content = content
    }
}
