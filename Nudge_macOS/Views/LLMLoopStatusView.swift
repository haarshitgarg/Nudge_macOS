//
//  LLMLoopStatusView.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 06/07/25.
//

import SwiftUI

struct LLMLoopStatusView: View {
    let currentTool: String
    let llmMessages: [String]
    
    @State private var animationPhase: Double = 0
    
    var body: some View {
        VStack {
            HStack{
                LoadingView()
                Spacer()
                Text("LLM IS THINGKING...")
            }
            .frame(width: 500)
            .background(
                ZStack {
                    LinearGradient(
                        colors: [.purple.opacity(0.4), .blue.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Color.clear.background(.regularMaterial)
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous)))

            
        }
        
    }
}

#Preview {
    LLMLoopStatusView(
        currentTool: "get_ui_elements",
        llmMessages: [
            "Goal identified: open_safari",
            "Knowledge updated: Safari application is being located",
            "Tool called: get_ui_elements with arguments: {...}"
        ]
    )
    .frame(width: 400)
    .padding()
}
