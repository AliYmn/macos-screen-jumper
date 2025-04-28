//
//  ContentView.swift
//  jumper
//
//  Created by aliymnx on 28.04.2025..
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Jumper Settings")
                .font(.title)
                .padding(.top)
            
            Toggle("Enable Sound Effect", isOn: $appDelegate.soundEffectEnabled)
                .padding(.horizontal)
            
            Toggle("Enable Visual Effect", isOn: $appDelegate.visualEffectEnabled)
                .padding(.horizontal)
            
            Spacer()
            
            Text("Jumper v1.0")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 300, height: 200)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppDelegate())
}
