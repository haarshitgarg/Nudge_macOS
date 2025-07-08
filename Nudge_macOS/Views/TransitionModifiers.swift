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
    let transitionProgress: Double
    
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
        let _ = print("InputViewTransition: uiState=\(uiState), progress=\(transitionProgress), isVisible=\(isVisible)")
        
        return content
            .opacity(isVisible ? 1.0 : 0.0)
            .scaleEffect(isVisible ? 1.0 : 0.85)
            .offset(y: isVisible ? 0 : -10)
            .animation(.bouncy(duration: 0.5), value: isVisible)
    }
}

struct ThinkingViewTransition: ViewModifier {
    let uiState: UITransitionState
    let transitionProgress: Double
    
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
        let _ = print("ThinkingViewTransition: uiState=\(uiState), progress=\(transitionProgress), isVisible=\(isVisible)")
        
        return content
            .opacity(isVisible ? 1.0 : 0.0)
            .scaleEffect(isVisible ? 1.0 : 0.95)
            .offset(y: isVisible ? 0 : 10)
            .animation(.easeOut(duration: 0.5), value: isVisible)
    }
}

struct TextViewTransition: ViewModifier {
    let uiState: UITransitionState
    let transitionProgress: Double
    
    private var isVisible: Bool {
        switch uiState {
        case .input, .transitioning:
            return false
        case .thinking, .responding:
            return true
        }
    }
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1.0 : 0.0)
            .scaleEffect(isVisible ? 1.0 : 0.95)
            .offset(y: isVisible ? 0 : 10)
            .animation(.easeOut(duration: 0.5), value: isVisible)
    }
}


// MARK: - View Extensions
extension View {
    func inputTransition(uiState: UITransitionState, progress: Double) -> some View {
        self.modifier(InputViewTransition(uiState: uiState, transitionProgress: progress))
    }
    
    func thinkingTransition(uiState: UITransitionState, progress: Double) -> some View {
        self.modifier(ThinkingViewTransition(uiState: uiState, transitionProgress: progress))
    }
    
    func textTransition(uiState: UITransitionState, progress: Double) -> some View {
        self.modifier(TextViewTransition(uiState: uiState, transitionProgress: progress))
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

