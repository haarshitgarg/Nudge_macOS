//
//  ContentView.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 18/06/25.
//

import SwiftUI
import os

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel.shared
    
    private let log = OSLog(subsystem: "Harshit.Nudge", category: "ContentView")
    
    var body: some View {
        VStack {
            Button("Toggle Chat Window") {
                ChatViewModel.shared.togglePanel()
            }
        }
        .padding()
        .frame(width: 200, height: 100)
        
    }

}

#Preview {
    ContentView()
}
