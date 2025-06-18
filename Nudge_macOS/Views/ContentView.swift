//
//  ContentView.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 18/06/25.
//

import SwiftUI
import os

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    
    private let log = OSLog(subsystem: "com.harshitgarg.Nudge_macOS", category: "ContentView")
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            List {
                ForEach(viewModel.xcpMessage, id: \.id) { message in
                    Text("\(message.content) at \(message.timestamp, formatter: DateFormatter())")
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            Button("Send Message") {
                os_log("Button tapped to send message", log: log, type: .info)
                Task {
                    do {
                        try await viewModel.fetchMessages()
                    } catch {
                        os_log("Failed to send message: %@", log: log, type: .error, error.localizedDescription)
                    }
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
