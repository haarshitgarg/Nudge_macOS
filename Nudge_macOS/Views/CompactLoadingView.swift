//
//  CompactLoadingView.swift
//  Nudge_macOS
//
//  Created by Harshit on 09/07/25.
//

import SwiftUI

struct CompactLoadingView: View {
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Loading animation (blue circles)
            LoadingView()
            
            Spacer()
        }
        .frame(height: 48)
    }
}

#Preview {
    CompactLoadingView()
        .frame(width: 500)
        .padding()
        .background(Color(red: 0.2, green: 0.25, blue: 0.2))
}