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
    
    private var containerWidth: CGFloat {
        switch uiState {
        case .input:
            return 500
        case .shrinking:
            // Smoothly shrink from 500 to 100 over the shrinking phase
            return 500 - (400 * min(1.0, progress * 3))
        case .sparkles, .transitioning, .thinking, .responding, .expanding:
            return 0 // Hidden
        }
    }
    
    private var isVisible: Bool {
        switch uiState {
        case .input, .shrinking:
            return true
        case .sparkles, .transitioning, .thinking, .responding, .expanding:
            return false
        }
    }
    
    func body(content: Content) -> some View {
        // Debug logging
        let _ = print("InputViewTransition: uiState=\(uiState), width=\(containerWidth), isVisible=\(isVisible)")
        
        return content
            .opacity(isVisible ? 1.0 : 0.0)
            .scaleEffect(isVisible ? 1.0 : 0.8, anchor: .leading)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .frame(width: containerWidth)
            .clipped()
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: containerWidth)
            .animation(.easeInOut(duration: 0.3), value: isVisible)
    }
}

struct ThinkingViewTransition: ViewModifier {
    let uiState: UITransitionState
    let progress: Double
    
    private var containerWidth: CGFloat {
        switch uiState {
        case .input, .shrinking, .sparkles:
            return 0 // Hidden
        case .transitioning:
            return 100 // Start with compact width
        case .thinking, .responding:
            return 500 // Full width
        case .expanding:
            return 500 * (1.0 - progress * 0.8) // Shrink back to compact
        }
    }
    
    private var isVisible: Bool {
        switch uiState {
        case .input, .shrinking, .sparkles:
            return false
        case .transitioning, .thinking, .responding, .expanding:
            return true
        }
    }
    
    func body(content: Content) -> some View {
        // Debug logging
        let _ = print("ThinkingViewTransition: uiState=\(uiState), width=\(containerWidth), isVisible=\(isVisible)")
        
        return content
            .frame(width: containerWidth)
            .opacity(isVisible ? 1.0 : 0.0)
            .scaleEffect(isVisible ? 1.0 : 0.8, anchor: .leading)
            .clipped()
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: containerWidth)
            .animation(.easeInOut(duration: 0.3), value: isVisible)
    }
}

struct LoadingViewTransition: ViewModifier {
    let uiState: UITransitionState
    let progress: Double
    
    private var isVisible: Bool {
        switch uiState {
        case .input, .shrinking:
            return false
        case .sparkles, .transitioning, .thinking, .responding, .expanding:
            return true
        }
    }
    
    func body(content: Content) -> some View {
        // Debug logging
        let _ = print("LoadingViewTransition: uiState=\(uiState), isVisible=\(isVisible)")
        
        return content
            .opacity(isVisible ? 1.0 : 0.0)
            .scaleEffect(isVisible ? 1.0 : 0.8, anchor: .leading)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isVisible)
    }
}

struct ContentViewTransition: ViewModifier {
    let uiState: UITransitionState
    let progress: Double
    
    private var isVisible: Bool {
        switch uiState {
        case .input, .shrinking, .sparkles, .transitioning:
            return false
        case .thinking, .responding, .expanding:
            return true
        }
    }
    
    func body(content: Content) -> some View {
        // Debug logging
        let _ = print("ContentViewTransition: uiState=\(uiState), isVisible=\(isVisible)")
        
        return content
            .opacity(isVisible ? 1.0 : 0.0)
            .offset(x: isVisible ? 0 : 50)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
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
    
    func loadingTransition(uiState: UITransitionState, progress: Double) -> some View {
        self.modifier(LoadingViewTransition(uiState: uiState, progress: progress))
    }
    
    func contentTransition(uiState: UITransitionState, progress: Double) -> some View {
        self.modifier(ContentViewTransition(uiState: uiState, progress: progress))
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
            
            // Test Loading View
            CompactLoadingView()
                .loadingTransition(uiState: uiState, progress: progress)
            
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
                    Button("Responding") { uiState = .responding }
                }
                
                Button("Input → Thinking") {
                    uiState = .transitioning
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        uiState = .thinking
                    }
                }
                
                Button("Thinking → Input") {
                    uiState = .transitioning
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        uiState = .input
                    }
                }
            }
            .padding()
        }
        .frame(width: 600, height: 700)
        .padding()
    }
}

#Preview {
    TransitionPreview()
}


