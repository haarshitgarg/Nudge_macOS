//
//  TransitionModifiers.swift
//  Nudge_macOS
//
//  Created by Harshit on 08/07/25.
//

import SwiftUI

// Adding View modifiers to the view
// We have here input view modifier that handles input view. Thinking view modifier that handles thinking view

// MARK: - Custom Transition Modifiers
struct InputViewTransition: ViewModifier {
    let uiState: UITransitionState
    let progress: Double
    
    private var isVisible: Bool {
        switch uiState {
        case .input:
            return true
        case .transitioning, .thinking, .responding:
            return false
        }
    }
    
    func body(content: Content) -> some View {
        // Debug logging
        let _ = print("InputViewTransition: uiState=\(uiState), isVisible=\(isVisible)")
        
        return content
            .opacity(isVisible ? 1.0 : 0.0)
            .offset(x: isVisible ? 0 : -500)
            .animation(.smooth(duration: 0.5), value: isVisible)
    }
}

struct ThinkingViewTransition: ViewModifier {
    let uiState: UITransitionState
    let progress: Double
    
    private var isVisible: Bool {
        switch uiState {
        case .input, .transitioning:
            return false
        case .thinking, .responding:
            return true
        }
    }
    
    func body(content: Content) -> some View {
        // Debug logging
        let _ = print("ThinkingViewTransition: uiState=\(uiState), isVisible=\(isVisible)")
        
        return content
            .opacity(isVisible ? 1.0 : 0.0)
            .offset(x: isVisible ? 0 : -500)
            .animation(.smooth(duration: 0.5), value: isVisible)
    }
}



// MARK: - View Extensions
extension View {
    func inputTransition(uiState: UITransitionState, progress: Double) -> some View {
        self.modifier(InputViewTransition(uiState: uiState, progress: progress))
    }
    
    func thinkingTransition(uiState: UITransitionState, progress: Double) -> some View {
        self.modifier(ThinkingViewTransition(uiState: uiState, progress: progress))
    }
}

// MARK: - Preview for Testing Transitions
struct TransitionPreview: View {
    @State private var uiState: UITransitionState = .input
    @State private var progress: Double = 0.0
    
    var body: some View {
        VStack(spacing: 20) {
            // Test Input View
            VStack {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Input View")
                    Spacer()
                }
                .padding()
                .background(Color.blue.opacity(0.3))
                .cornerRadius(12)
            }
            .inputTransition(uiState: uiState, progress: progress)
            
            // Test Thinking View  
            VStack {
                HStack {
                    Image(systemName: "brain")
                    Text("Thinking View")
                    Spacer()
                }
                .padding()
                .background(Color.green.opacity(0.3))
                .cornerRadius(12)
            }
            .thinkingTransition(uiState: uiState, progress: progress)
            
            // Controls
            VStack {
                Text("Current State: \(uiState.rawValue)")
                
                HStack {
                    Button("Input") { uiState = .input }
                    Button("Transitioning") { uiState = .transitioning }
                    Button("Thinking") { uiState = .thinking }
                }
                
                Button("Animate Input → Thinking") {
                    uiState = .transitioning
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        uiState = .thinking
                    }
                }
                
                Button("Animate Thinking → Input") {
                    uiState = .transitioning
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        uiState = .input
                    }
                }
            }
            .padding()
        }
        .frame(width: 400, height: 600)
        .padding()
    }
}

#Preview {
    TransitionPreview()
}


