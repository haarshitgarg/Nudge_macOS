//
//  SeamlessTransitionView.swift
//  Nudge_macOS
//
//  Created by Harshit on 09/07/25.
//

import SwiftUI

struct SeamlessTransitionView: View {
    let uiState: UITransitionState
    
    var body: some View {
        ZStack {
            // Sparkles icon (only in input state)
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundColor(.accentColor)
                .opacity(uiState == .input ? 1.0 : 0.0)
            
            // Loading circles (in all non-input states) - instant transition
            LoadingView()
                .opacity(uiState != .input ? 1.0 : 0.0)
        }
    }
}

#Preview {
    SeamlessTransitionView(uiState: .input)
        .frame(width: 100, height: 100)
        .padding()
        .background(Color(red: 0.2, green: 0.25, blue: 0.2))
}
