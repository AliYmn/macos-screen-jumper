//
//  ContentView.swift
//  jumper
//
//  Created by aliymnx on 28.04.2025
//  Main content view for the Jumper application
//

import SwiftUI

/// Main content view for the Jumper application settings
struct ContentView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Jumper Settings")
                .font(.title)
                .fontWeight(.semibold)
                .padding(.top)
            
            // Settings toggles
            settingsToggles
            
            Spacer()
            
            // Footer with version
            Text("Jumper v1.0")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 300, height: 200)
        .padding()
    }
    
    /// Settings toggle switches for sound and visual effects
    private var settingsToggles: some View {
        VStack(spacing: 12) {
            Toggle("Enable Sound Effect", isOn: $appDelegate.soundEffectEnabled)
                .padding(.horizontal)
            
            Toggle("Enable Visual Effect", isOn: $appDelegate.visualEffectEnabled)
                .padding(.horizontal)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppDelegate())
}
