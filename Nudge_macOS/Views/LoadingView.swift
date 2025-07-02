//
//  LoadingView.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 02/07/25.
//

import SwiftUI

struct CircularThread: Shape {
    var baseRadius: Double
    var maxAmplitude: Double
    var phase: Double
    var centerAngle: Double // The angle where amplitude is maximum
    var taperedRange: Double = 100 * .pi / 180 // 30 degrees in radians
    
    var animatableData: Double {
        get { centerAngle }
        set { self.centerAngle = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseR = min(rect.width, rect.height) / 3 // Base radius
        
        let angleStep = 0.02 // Small step for smooth curve
        var points: [CGPoint] = []
        
        // Create outer path
        for angle in stride(from: 0, to: 2 * .pi, by: angleStep) {
            let amplitude = calculateAmplitude(for: angle)
            let oscillation = amplitude/2 * sin(angle * 5 + phase)
            let radius = baseR + oscillation
            
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            points.append(CGPoint(x: x, y: y))
        }
        
        // Create the path
        if !points.isEmpty {
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.closeSubpath()
        }
        
        return path
    }
    
    private func calculateAmplitude(for angle: Double) -> Double {
        let normalizedAngle = angle.truncatingRemainder(dividingBy: 2 * .pi)
        let angleDiff = abs(normalizedAngle - centerAngle)
        let minDiff = min(angleDiff, 2 * .pi - angleDiff)
        
        if minDiff <= taperedRange {
            // Cosine taper for smooth transition
            let factor = cos(minDiff / taperedRange * .pi / 2)
            return maxAmplitude * factor
        } else {
            return 0
        }
    }
}

struct LoadingView: View {
    @State private var phase: Double = 0.0
    @State private var centerAngle: Double = 0.0
    
    var body: some View {
        ZStack {
            // Background circle
            //Circle()
            //    .fill(Color.black.opacity(0.1))
            //    .frame(width: 150, height: 150)
            
            // Animated circular thread
            CircularThread(
                baseRadius: 45,
                maxAmplitude: 6,
                phase: phase,
                centerAngle: centerAngle
            )
            .stroke(
                LinearGradient(
                    colors: [.cyan.opacity(0.8), .blue.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 2
            )
            .frame(width: 60, height: 60)
            
            
            CircularThread(
                baseRadius: 45,
                maxAmplitude: 6,
                phase: phase,
                centerAngle: centerAngle + 0.3
            )
            .stroke(
                LinearGradient(
                    colors: [.orange.opacity(0.8), .blue.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 2
            )
            .frame(width: 60, height: 60)
            
            CircularThread(
                baseRadius: 45,
                maxAmplitude: 6,
                phase: phase,
                centerAngle: centerAngle + 0.6
            )
            .stroke(
                LinearGradient(
                    colors: [.orange.opacity(0.8), .blue.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 2
            )
            .frame(width: 60, height: 60)
            
            CircularThread(
                baseRadius: 45,
                maxAmplitude: 6,
                phase: phase,
                centerAngle: centerAngle + 0.9
            )
            .stroke(
                LinearGradient(
                    colors: [.orange.opacity(0.8), .blue.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 2
            )
            .frame(width: 60, height: 60)
            
        }
        .onAppear {
            // Animate the wave pattern
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                phase = 2 * .pi
            }
            
            // Animate the center angle to move the amplitude bulge around
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                centerAngle = 2 * .pi
            }
        }
    }
}

#Preview {
    LoadingView()
}
