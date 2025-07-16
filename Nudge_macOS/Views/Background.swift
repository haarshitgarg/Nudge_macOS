//
//  Background.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 15/07/25.
//

import SwiftUI

struct Background: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.purple.opacity(0.4), .blue.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Color.clear.background(.regularMaterial.opacity(0.95))
        }
    }
}

#Preview {
    Background()
}

