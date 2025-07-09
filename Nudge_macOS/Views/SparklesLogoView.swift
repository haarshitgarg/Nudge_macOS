//
//  SparklesLogoView.swift
//  Nudge_macOS
//
//  Created by Harshit on 09/07/25.
//

import SwiftUI

struct SparklesLogoView: View {
    @State private var animationPhase: Double = 0
    
    var body: some View {
        HStack {
            Image(systemName: "sparkles")
                .font(.title)
                .foregroundColor(.accentColor)
                .scaleEffect(1.0 + sin(animationPhase) * 0.1)
                .rotationEffect(.degrees(sin(animationPhase * 1.5) * 5))
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: animationPhase)
                .padding()
            
            Spacer()
        }
        .frame(height: 48)
        .background(
            ZStack {
                LinearGradient(
                    colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Color.clear.background(.regularMaterial)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.purple.opacity(0.6), .pink.opacity(0.6), .orange.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .blur(radius: 2)
        )
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        .onAppear {
            animationPhase = 1.0
        }
    }
}

#Preview {
    SparklesLogoView()
        .frame(width: 500)
        .padding()
        .background(Color(red: 0.2, green: 0.25, blue: 0.2))
}
