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

    var body: some View {
        TabView(selection: $selectedTab) {
            // General Settings Tab
            VStack(spacing: 16) {
                Toggle("Enable Sound Effect", isOn: $appDelegate.soundEffectEnabled)
                    .padding(.horizontal)

                Toggle("Enable Visual Effect", isOn: $appDelegate.visualEffectEnabled)
                    .padding(.horizontal)

                Toggle("Launch at Login", isOn: Binding(
                    get: { LaunchAtLogin.shared.isEnabled() },
                    set: { LaunchAtLogin.shared.setEnabled($0) }
                ))
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 20)
            .tabItem {
                Label("General", systemImage: "gear")
            }
            .tag(0)

            // Shortcuts Tab
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

                            Button(action: {
                                ShortcutManager.shared.resetToDefault(for: index)
                                appDelegate.updateScreens() // Refresh shortcuts
                            }) {
                                Text("Reset")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Button("Reset All to Default") {
                    ShortcutManager.shared.resetAllToDefault()
                    appDelegate.updateScreens() // Refresh shortcuts
                }
                .padding()
            }
            .tabItem {
                Label("Shortcuts", systemImage: "keyboard")
            }
            .tag(1)

            // About Tab
            VStack(spacing: 20) {
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)

                Text("Jumper")
                    .font(.largeTitle)
                    .bold()

                Text("Version 1.0")
                    .font(.subheadline)

                Text("A lightweight utility to jump your cursor between screens.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()

                Text("© 2025 Jumper App")
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
        .frame(width: 500, height: 400)
        .onAppear {
            setupKeyboardMonitoring()
        }
        .onDisappear {
            recordingScreenIndex = -1
            NSEvent.removeMonitor(keyboardMonitor)
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

// Helper to convert NSHostingView to NSView for use in AppKit
class SettingsWindowController: NSWindowController {
    convenience init(appDelegate: AppDelegate) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
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
