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
        uiState == .input || (uiState == .transitioning && transitionProgress < 0.5)
    }
    
    func body(content: Content) -> some View {
        // TODO: Modify the animation. This spring animation is shit
        content
            .opacity(isVisible ? 1.0 : 0.0)
            .scaleEffect(isVisible ? 1.0 : 0.85)
            .offset(y: isVisible ? 0 : -10)
            .animation(.easeOut(duration: 0.5), value: isVisible)
    }
}

struct ThinkingViewTransition: ViewModifier {
    let uiState: UITransitionState
    let transitionProgress: Double
    
    private var isVisible: Bool {
        uiState == .thinking || uiState == .responding || (uiState == .transitioning && transitionProgress >= 0.5)
    }
    
    func body(content: Content) -> some View {
        // TODO: Modify the animation. This spring animation is shit
        content
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
        uiState == .thinking || uiState == .responding || (uiState == .transitioning && transitionProgress >= 0.5)
    }
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1.0 : 0.0)
            .scaleEffect(isVisible ? 1.0 : 0.95)
            .offset(y: isVisible ? 0 : 10)
            .animation(.easeOut, value: isVisible)
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

