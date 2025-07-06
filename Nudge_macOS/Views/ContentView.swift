//
//  ContentView.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 18/06/25.
//

import SwiftUI
import os

struct ContentView: View {
    @EnvironmentObject var floatingChatManager: FloatingChatManager
    
    private let log = OSLog(subsystem: "Harshit.Nudge", category: "ContentView")
    
    var body: some View {
        VStack {
            Button("Toggle Chat Window") {
                floatingChatManager.toggleChat()
            }
        }
        .padding()
        .frame(width: 200, height: 100)
        
    }

}

#Preview {
    ContentView()
}
