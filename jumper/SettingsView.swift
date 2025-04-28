//
//  SettingsView.swift
//  jumper
//
//  Created for Jumper app
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var appDelegate: AppDelegate
    @State private var selectedTab = 0
    @State private var isRecordingShortcut = false
    @State private var recordingScreenIndex = -1
    @State private var keyboardMonitor: Any?
    @State private var autoLaunch = LaunchAtLogin.shared.isEnabled()

    var body: some View {
        TabView(selection: $selectedTab) {
            // General Settings Tab
            VStack(spacing: 0) {
                Spacer().frame(height: 10)

                // All Settings in One Box
                GroupBox {
                    VStack(alignment: .leading, spacing: 20) {
                        // VISUAL EFFECTS
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.blue)
                                    .frame(width: 20)
                                Text("Visual Effects")
                                    .font(.headline)
                            }
                            
                            Toggle("Enable visual effects when jumping", isOn: $appDelegate.visualEffectEnabled)
                                .toggleStyle(SwitchToggleStyle())
                                .padding(.leading, 5)
                            
                            Text("Effect Style:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.leading, 5)
                            
                            Picker("", selection: Binding<Int>(
                                get: { appDelegate.visualEffectStyle.rawValue },
                                set: { appDelegate.visualEffectStyle = AppDelegate.VisualEffectStyle(rawValue: $0) ?? .modern }
                            )) {
                                ForEach(AppDelegate.VisualEffectStyle.allCases, id: \.rawValue) { style in
                                    Text(style.name).tag(style.rawValue)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .disabled(!appDelegate.visualEffectEnabled)
                            .padding(.leading, 5)
                        }
                        
                        Divider()
                        
                        // SOUND EFFECTS
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Image(systemName: "speaker.wave.2")
                                    .foregroundColor(.blue)
                                    .frame(width: 20)
                                Text("Sound Effects")
                                    .font(.headline)
                            }
                            
                            Toggle("Enable sound effects when jumping", isOn: $appDelegate.soundEffectEnabled)
                                .toggleStyle(SwitchToggleStyle())
                                .padding(.leading, 5)
                            
                            Text("Sound Type:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.leading, 5)
                            
                            Picker("", selection: Binding<Int>(
                                get: { appDelegate.selectedSoundEffect.rawValue },
                                set: { appDelegate.selectedSoundEffect = AppDelegate.SoundEffectType(rawValue: $0) ?? .pop }
                            )) {
                                ForEach(AppDelegate.SoundEffectType.allCases, id: \.rawValue) { sound in
                                    Text(sound.name).tag(sound.rawValue)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .disabled(!appDelegate.soundEffectEnabled)
                            .padding(.leading, 5)
                            
                            HStack {
                                Text("Volume:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Slider(value: $appDelegate.soundVolume, in: 0...1)
                                    .disabled(!appDelegate.soundEffectEnabled)
                                
                                Text("\(Int(appDelegate.soundVolume * 100))%")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                    .frame(width: 40, alignment: .trailing)
                            }
                            .padding(.leading, 5)
                        }
                        
                        Divider()
                        
                        // SYSTEM SETTINGS
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Image(systemName: "gearshape")
                                    .foregroundColor(.blue)
                                    .frame(width: 20)
                                Text("System Settings")
                                    .font(.headline)
                            }
                            
                            // Startup Option
                            Toggle("Launch Jumper when you log in", isOn: $autoLaunch)
                                .toggleStyle(SwitchToggleStyle())
                                .onChange(of: autoLaunch) { oldValue, newValue in
                                    LaunchAtLogin.shared.setEnabled(newValue)
                                }
                                .padding(.leading, 5)
                            
                            // Permissions
                            HStack {
                                Text("Accessibility Permission:")
                                    .font(.subheadline)

                                Spacer()

                                HStack(spacing: 5) {
                                    if AXIsProcessTrusted() {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text("Granted")
                                            .foregroundColor(.green)
                                    } else {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.red)
                                        Text("Not Granted")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                            .padding(.leading, 5)

                            if !AXIsProcessTrusted() {
                                Button("Open Accessibility Settings") {
                                    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                                    AXIsProcessTrustedWithOptions(options as CFDictionary)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.leading, 5)
                            }
                        }
                    }
                    .padding(.vertical, 10)
                }
                .padding(.horizontal)

                Spacer().frame(height: 8)
            }
            .padding(.top, 20)
            .onAppear {
                NotificationCenter.default.addObserver(
                    forName: LaunchAtLogin.statusChangedNotification,
                    object: nil,
                    queue: .main) { _ in
                        self.autoLaunch = LaunchAtLogin.shared.isEnabled()
                    }

                // Force refresh the status when view appears
                LaunchAtLogin.shared.refreshStatus()
            }
            .tabItem {
                Label("General", systemImage: "gear")
            }
            .tag(0)

            // Screens Tab
            VStack {
                List {
                    ForEach(0..<appDelegate.screens.count, id: \.self) { index in
                        HStack {
                            Image(systemName: appDelegate.getScreenIconName(for: index))
                                .frame(width: 24, height: 24)

                            Text(appDelegate.getScreenName(appDelegate.screens[index]))
                                .frame(width: 100, alignment: .leading)

                            Spacer()

                            if recordingScreenIndex == index {
                                Text("Press New Shortcut...")
                                    .foregroundColor(.secondary)
                            } else {
                                Text(ShortcutManager.shared.getShortcut(for: index).description)
                                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.2))
                                    .cornerRadius(4)
                            }

                            Button(action: {
                                if recordingScreenIndex == index {
                                    recordingScreenIndex = -1
                                } else {
                                    recordingScreenIndex = index
                                    startRecordingShortcut()
                                }
                            }) {
                                Text(recordingScreenIndex == index ? "Cancel" : "Change")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Refresh Screens Button at the bottom right
                HStack {
                    Spacer()
                    Button(action: {
                        appDelegate.updateScreens()
                    }) {
                        Label("Refresh Screens", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
            .tabItem {
                Label("Screens", systemImage: "display.2")
            }
            .tag(1)

            // About Tab
            VStack(spacing: 20) {
                // App Name and Version
                VStack(spacing: 8) {
                    Text("Jumper")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("Version 1.0")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)

                // App Description
                Text("Quickly jump your cursor between screens with customizable keyboard shortcuts")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)

                // Features List
                VStack(alignment: .leading, spacing: 8) {
                    FeatureRow(icon: "keyboard", text: "Global keyboard shortcuts")
                    FeatureRow(icon: "display.2", text: "Multi-screen support")
                    FeatureRow(icon: "sparkles", text: "Visual effects")
                    FeatureRow(icon: "gearshape", text: "Customizable settings")
                }
                .padding(.top, 10)

                Spacer()

                // Links
                HStack(spacing: 20) {
                    Link("GitHub", destination: URL(string: "https://github.com/AliYmn/macos-jumper")!)
                    Link("Report Issue", destination: URL(string: "https://github.com/AliYmn/macos-jumper/issues")!)
                    Link("Website", destination: URL(string: "https://aliyaman.dev")!)
                }
                .padding(.bottom, 10)

                // Copyright
                Text("© \(Calendar.current.component(.year, from: Date())) Jumper App")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
            .tag(2)
        }
        .padding()
        .frame(width: 600, height: 550)
        .onAppear {
            setupKeyboardMonitoring()
        }
        .onDisappear {
            recordingScreenIndex = -1
            if let monitor = keyboardMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }

    private func setupKeyboardMonitoring() {
        DispatchQueue.main.async {
            self.keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
                if self.recordingScreenIndex >= 0 {
                    self.handleShortcutRecording(event)
                    return nil // Consume the event
                }
                return event
            }
        }
    }

    private func startRecordingShortcut() {
        isRecordingShortcut = true
    }

    private func handleShortcutRecording(_ event: NSEvent) {
        // Ignore standalone modifier keys
        if event.keyCode == 0x37 || // Command
           event.keyCode == 0x38 || // Shift
           event.keyCode == 0x3A || // Option
           event.keyCode == 0x3B {  // Control
            return
        }

        // Get modifiers
        var modifiers: UInt32 = 0

        if event.modifierFlags.contains(.control) {
            modifiers |= 1 // Control
        }
        if event.modifierFlags.contains(.shift) {
            modifiers |= 2 // Shift
        }
        if event.modifierFlags.contains(.option) {
            modifiers |= 4 // Option
        }
        if event.modifierFlags.contains(.command) {
            modifiers |= 8 // Command
        }

        // Create new shortcut
        let newShortcut = KeyboardShortcut(keyCode: Int(event.keyCode), modifiers: modifiers)

        // Save the shortcut
        ShortcutManager.shared.setShortcut(newShortcut, for: recordingScreenIndex)

        // Update UI and shortcuts
        isRecordingShortcut = false
        recordingScreenIndex = -1
        appDelegate.updateScreens() // This will re-register hotkeys
    }
}

// Feature row component for About tab
struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .frame(width: 24, height: 24)
                .foregroundColor(.blue)

            Text(text)
                .font(.system(size: 14))
        }
        .padding(.horizontal)
    }
}

// Helper to convert NSHostingView to NSView for use in AppKit
class SettingsWindowController: NSWindowController {
    convenience init(appDelegate: AppDelegate) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Jumper Settings"
        window.center()

        let hostingView = NSHostingView(rootView: SettingsView(appDelegate: appDelegate))
        hostingView.frame = window.contentView!.bounds
        hostingView.autoresizingMask = [NSView.AutoresizingMask.width, NSView.AutoresizingMask.height]
        window.contentView!.addSubview(hostingView)

        self.init(window: window)
    }
}
