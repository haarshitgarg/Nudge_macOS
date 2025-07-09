//
//  SeamlessTransitionView.swift
//  Nudge_macOS
//
//  Created by Harshit on 09/07/25.
//

import SwiftUI

struct SeamlessTransitionView: View {
    let uiState: UITransitionState
    let animationPhase: Int
    
    var body: some View {
        ZStack {
            // Sparkles icon (only in input state)
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundColor(.accentColor)
                .scaleEffect(animationPhase == 1 ? 1.2 : 1.0)
                .rotationEffect(.degrees(animationPhase == 1 ? 10 : 0))
                .opacity(uiState == .input ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 1), value: animationPhase)
            
            // Loading circles (in all non-input states) - instant transition
            LoadingView()
                .opacity(uiState != .input ? 1.0 : 0.0)
                .scaleEffect(uiState != .input ? 1.0 : 0.8)
        }
    }
}

#Preview {
    SeamlessTransitionView(uiState: .input, animationPhase: 0)
        .frame(width: 100, height: 100)
        .padding()
        .background(Color(red: 0.2, green: 0.25, blue: 0.2))
}
