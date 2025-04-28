//
//  jumperApp.swift
//  jumper
//
//  Created by aliymnx on 28.04.2025..
//

import SwiftUI
import AppKit
import UserNotifications

@main
struct jumperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

public class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var statusItem: NSStatusItem!
    private var statusBarMenu: NSMenu!
    public var screens: [NSScreen] = []
    @Published public var soundEffectEnabled = true
    @Published public var visualEffectEnabled = true

    // Pre-created sound object for sound effect
    private var popSound: NSSound?

    // Settings window controller
    private var settingsWindowController: SettingsWindowController?

    // User defaults keys
    private let launchAtLoginPromptShownKey = "LaunchAtLoginPromptShown"

    // Store monitors for key events
    private var localMonitor: Any?
    private var globalMonitor: Any?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock
        NSApp.setActivationPolicy(.accessory)

        // Request accessibility permissions
        requestAccessibilityPermissions()

        // Setup menu bar item
        setupMenuBar()

        // Initial screen setup
        updateScreens()

        // Pre-create sound object
        popSound = NSSound(named: "Pop")

        // Register for screen change notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        // Listen for shortcut changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(shortcutsDidChange),
            name: shortcutsChangedNotification,
            object: nil
        )

        // Listen for launch at login status changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(launchAtLoginStatusDidChange),
            name: LaunchAtLogin.statusChangedNotification,
            object: nil
        )

        // Register app to receive background events
        NSApplication.shared.setActivationPolicy(.accessory)

        // Register keyboard shortcuts
        registerKeyboardShortcuts()

        // Ensure menu bar item is visible
        DispatchQueue.main.async {
            self.setupMenuBar()
        }

        // Ask for Launch at Login permission once
        askForLaunchAtLoginPermission()
    }

    private func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if !accessEnabled {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Required"
            alert.informativeText = "Jumper needs accessibility permissions to move the cursor and respond to global keyboard shortcuts. Please enable in System Settings > Privacy & Security > Accessibility."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Later")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        }
    }

    private func setupMenuBar() {
        // Create an item in the menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // Mouse and jump themed icon
            button.image = NSImage(systemSymbolName: "cursorarrow.rays", accessibilityDescription: "Jumper")
            button.imagePosition = .imageLeft
        }

        statusBarMenu = NSMenu()
        updateMenuItems()
        statusItem.menu = statusBarMenu
    }

    @objc private func screensDidChange() {
        updateScreens()
    }

    @objc private func shortcutsDidChange(_ notification: Notification) {
        // Apply shortcut changes
        updateMenuItems() // Update menu
        unregisterKeyboardShortcuts()
        registerKeyboardShortcuts() // Re-register keyboard shortcuts
    }

    // Handle launch at login status changes
    @objc private func launchAtLoginStatusDidChange() {
        // Force UI update
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    @objc private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(appDelegate: self)
        }

        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func refreshScreens() {
        updateScreens()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // Ask for Launch at Login permission once when app is first launched
    private func askForLaunchAtLoginPermission() {
        let defaults = UserDefaults.standard

        // Check if we've already shown the prompt
        if !defaults.bool(forKey: launchAtLoginPromptShownKey) {
            let alert = NSAlert()
            alert.messageText = "Launch Jumper at Login?"
            alert.informativeText = "Would you like Jumper to automatically start when you log in to your Mac?"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Yes")
            alert.addButton(withTitle: "No")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // User chose Yes
                LaunchAtLogin.shared.setEnabled(true)
            }

            // Mark that we've shown the prompt
            defaults.set(true, forKey: launchAtLoginPromptShownKey)
        }
    }

    public func updateScreens() {
        // Update screens array
        screens = NSScreen.screens

        // Update menu
        updateMenuItems()

        // Re-register keyboard shortcuts
        registerKeyboardShortcuts()
    }

    private func updateMenuItems() {
        statusBarMenu.removeAllItems()

        // Add header
        let headerItem = NSMenuItem(title: "Jumper - Screen Selector", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        statusBarMenu.addItem(headerItem)
        statusBarMenu.addItem(NSMenuItem.separator())

        // Add screens
        for (index, screen) in screens.enumerated() {
            // Get screen information
            let resolution = getScreenResolution(screen)
            let icon = getScreenIcon(screen)
            let screenType = getScreenType(screen)

            // Get custom shortcut from ShortcutManager
            let shortcut = ShortcutManager.shared.getShortcut(for: index)

            // Format menu item with right-aligned shortcut
            let menuItem = NSMenuItem(
                title: "\(screenType) (\(resolution))",
                action: #selector(jumpToScreen(_:)),
                keyEquivalent: shortcut.keyEquivalent
            )

            // Set the actual shortcut modifiers
            menuItem.keyEquivalentModifierMask = shortcut.modifierMask
            menuItem.tag = index
            menuItem.image = icon
            statusBarMenu.addItem(menuItem)
        }

        statusBarMenu.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: "")
        statusBarMenu.addItem(settingsItem)

        // Refresh screens
        let refreshItem = NSMenuItem(title: "Refresh Screens", action: #selector(refreshScreens), keyEquivalent: "")
        statusBarMenu.addItem(refreshItem)

        statusBarMenu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit Jumper", action: #selector(quitApp), keyEquivalent: "")
        statusBarMenu.addItem(quitItem)
    }

    public func getScreenName(_ screen: NSScreen) -> String {
        // Try to get a meaningful name
        let name = screen.localizedName
        if name.isEmpty {
            let index = screens.firstIndex(of: screen) ?? 0
            return "Screen \(index + 1)"
        }
        return name
    }

    private func getScreenType(_ screen: NSScreen) -> String {
        // Use screen name directly
        return screen.localizedName
    }

    private func getScreenEmoji(_ screen: NSScreen) -> String {
        let name = screen.localizedName.lowercased()
        let width = screen.frame.width
        let height = screen.frame.height
        let aspectRatio = width / height

        // Return appropriate emoji based on screen type
        if name.contains("macbook") || name.contains("built-in") {
            return "💻"
        } else if aspectRatio < 0.8 {
            return "🖥️"
        } else if aspectRatio > 2.0 {
            return "📺"
        } else if min(width, height) < 900 && aspectRatio.rounded(to: 1) == 1.3 {
            return "📱"
        } else {
            return "🖥️"
        }
    }

    private func getScreenResolution(_ screen: NSScreen) -> String {
        let width = Int(screen.frame.width)
        let height = Int(screen.frame.height)
        return "\(width)×\(height)"
    }

    private func getScreenIcon(_ screen: NSScreen) -> NSImage? {
        let screenIndex = screens.firstIndex(of: screen) ?? 0
        let iconName = getScreenIconName(for: screenIndex)
        return NSImage(systemSymbolName: iconName, accessibilityDescription: "Display")
    }

    public func getScreenIconName(for index: Int) -> String {
        if index < screens.count {
            let screen = screens[index]
            let width = screen.frame.width
            let height = screen.frame.height
            let aspectRatio = width / height
            let name = screen.localizedName.lowercased()

            // Enhanced logic for screen type detection
            if name.contains("macbook") || name.contains("built-in") {
                return "laptopcomputer"
            } else if name.contains("lg") && name.contains("ultrafine") {
                return "display.trianglebadge.exclamationmark"
            } else if name.contains("dell") {
                if aspectRatio < 0.8 {
                    return "rectangle.portrait"
                } else {
                    return "display"
                }
            } else if aspectRatio < 0.8 {
                return "rectangle.portrait"
            } else if aspectRatio > 2.0 {
                return "display.2"
            } else if min(width, height) < 900 && aspectRatio.rounded(to: 1) == 1.3 {
                return "ipad.landscape"
            } else {
                return "display"
            }
        }
        return "display"
    }


    @objc private func jumpToScreen(_ sender: NSMenuItem) {
        let screenIndex = sender.tag
        if screenIndex < screens.count {
            jumpCursorToScreen(screens[screenIndex])
        }
    }

    private func jumpCursorToScreen(_ screen: NSScreen) {
        // Calculate center point of screen
        let centerX = screen.frame.origin.x + screen.frame.width / 2
        let centerY = screen.frame.origin.y + screen.frame.height / 2

        // Move cursor directly
        CGWarpMouseCursorPosition(CGPoint(x: centerX, y: centerY))

        // Show visual effect if enabled
        if visualEffectEnabled {
            showLightVisualEffect(at: CGPoint(x: centerX, y: centerY))
        }

        // Play sound if enabled
        if soundEffectEnabled {
            // Create sound object if needed or use existing one
            if popSound == nil {
                popSound = NSSound(named: "Pop")
            }

            // If sound is playing, stop it and restart
            if let sound = popSound {
                if sound.isPlaying {
                    sound.stop()
                }
                sound.play()
            }
        }
    }

    // Show a quick jump effect at the cursor position with high contrast colors
    private func showLightVisualEffect(at point: CGPoint) {
        // Create a simple circular highlight
        let highlightSize: CGFloat = 70 // Slightly larger for better visibility
        let highlightPanel = NSPanel(
            contentRect: NSRect(x: point.x - highlightSize/2, y: point.y - highlightSize/2, width: highlightSize, height: highlightSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Configure the panel - make sure it doesn't block mouse events
        highlightPanel.backgroundColor = .clear
        highlightPanel.isOpaque = false
        highlightPanel.hasShadow = false
        highlightPanel.level = .popUpMenu
        highlightPanel.ignoresMouseEvents = true // This is important - panel should not intercept mouse events
        highlightPanel.alphaValue = 0.0

        // Create a custom view for the highlight
        let highlightView = NSView(frame: NSRect(x: 0, y: 0, width: highlightSize, height: highlightSize))
        highlightView.wantsLayer = true

        // Create a background glow effect that will be visible on any background
        let glowLayer = CAShapeLayer()
        let glowPath = NSBezierPath(ovalIn: NSRect(x: 5, y: 5, width: highlightSize-10, height: highlightSize-10))
        glowLayer.path = glowPath.cgPath
        glowLayer.fillColor = NSColor.clear.cgColor
        glowLayer.strokeColor = NSColor.white.cgColor // White outline for contrast
        glowLayer.lineWidth = 8.0 // Thicker line for the glow
        glowLayer.opacity = 0.3
        glowLayer.shadowColor = NSColor.white.cgColor
        glowLayer.shadowOffset = CGSize.zero
        glowLayer.shadowRadius = 5.0
        glowLayer.shadowOpacity = 0.8

        // Create the outer ring with a bright, noticeable color
        let ringLayer = CAShapeLayer()
        let ringPath = NSBezierPath(ovalIn: NSRect(x: 2, y: 2, width: highlightSize-4, height: highlightSize-4))
        ringLayer.path = ringPath.cgPath
        ringLayer.fillColor = NSColor.clear.cgColor

        // Use a bright, high-contrast color that stands out on most backgrounds
        // Neon colors are very visible
        let neonGreen = NSColor(calibratedRed: 0.0, green: 1.0, blue: 0.5, alpha: 1.0)
        ringLayer.strokeColor = neonGreen.cgColor
        ringLayer.lineWidth = 3.0
        ringLayer.opacity = 0.9

        // Add a secondary ring with a complementary color for better visibility
        let innerRingLayer = CAShapeLayer()
        let innerRingPath = NSBezierPath(ovalIn: NSRect(x: 15, y: 15, width: highlightSize-30, height: highlightSize-30))
        innerRingLayer.path = innerRingPath.cgPath
        innerRingLayer.fillColor = NSColor.clear.cgColor

        // Use a contrasting color
        let neonPink = NSColor(calibratedRed: 1.0, green: 0.0, blue: 0.8, alpha: 1.0)
        innerRingLayer.strokeColor = neonPink.cgColor
        innerRingLayer.lineWidth = 2.0
        innerRingLayer.opacity = 0.9

        // Create the center dot with a bright color
        let dotLayer = CAShapeLayer()
        let dotSize: CGFloat = 15 // Slightly larger dot for better visibility
        let dotPath = NSBezierPath(ovalIn: NSRect(x: (highlightSize-dotSize)/2, y: (highlightSize-dotSize)/2, width: dotSize, height: dotSize))
        dotLayer.path = dotPath.cgPath
        dotLayer.fillColor = NSColor.white.cgColor // White is highly visible
        dotLayer.opacity = 1.0

        // Add a shadow to the dot for better contrast against any background
        dotLayer.shadowColor = NSColor.black.cgColor
        dotLayer.shadowOffset = CGSize.zero
        dotLayer.shadowRadius = 3.0
        dotLayer.shadowOpacity = 0.8

        // Add the layers in order (background to foreground)
        highlightView.layer?.addSublayer(glowLayer)
        highlightView.layer?.addSublayer(ringLayer)
        highlightView.layer?.addSublayer(innerRingLayer)
        highlightView.layer?.addSublayer(dotLayer)
        highlightPanel.contentView = highlightView

        // Show the panel
        highlightPanel.orderFront(nil)

        // Pulse animation for the outer ring - longer but still smooth
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.duration = 0.4 // Longer duration
        pulseAnimation.fromValue = 0.9
        pulseAnimation.toValue = 1.1
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = 1
        ringLayer.add(pulseAnimation, forKey: "pulse")

        // Inner ring animation with rotation - longer but still smooth
        let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotateAnimation.duration = 0.5 // Longer duration
        rotateAnimation.fromValue = 0
        rotateAnimation.toValue = CGFloat.pi * 0.1 // Slightly larger rotation
        rotateAnimation.autoreverses = true
        rotateAnimation.repeatCount = 1
        innerRingLayer.add(rotateAnimation, forKey: "rotate")

        // Dot animation (pulse) - longer but still smooth
        let dotPulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        dotPulseAnimation.duration = 0.3 // Longer duration
        dotPulseAnimation.fromValue = 1.3
        dotPulseAnimation.toValue = 0.9
        dotPulseAnimation.autoreverses = true
        dotPulseAnimation.repeatCount = 1
        dotLayer.add(dotPulseAnimation, forKey: "dotPulse")

        // Fade-in and fade-out animation with moderate speed
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2 // Moderate fade-in
            highlightPanel.animator().alphaValue = 1.0
        }) {
            // Add a slight delay to keep the effect visible a bit longer
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Moderate fade-out
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.3 // Moderate fade-out
                    highlightPanel.animator().alphaValue = 0.0
                }) {
                    // Close panel
                    highlightPanel.close()
                }
            }
        }
    }

    private func unregisterKeyboardShortcuts() {
        // Remove the local monitor
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }

        // Remove the global monitor
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
    }

    private func registerKeyboardShortcuts() {
        // Remove any existing monitors
        unregisterKeyboardShortcuts()

        // Register app to receive keyboard events in the background
        // Only check permissions, don't show alerts (already shown in requestAccessibilityPermissions)
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] // Don't show prompt automatically
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)

        // Just print debug information
        if !accessEnabled {
            print("Accessibility permissions not granted. Global shortcuts may not work.")
        }

        // Create a global monitor for key events that works even when app isn't active
        // Use flags to ensure we capture all key combinations
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self = self else { return }

            // Only process keyDown events
            if event.type == .keyDown {
                print("Global key event detected: \(event.keyCode) with modifiers: \(event.modifierFlags.rawValue)")
                _ = self.handleKeyEvent(event)
            }
        }

        // Create a local monitor for key events (when app is active)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self = self else { return event }

            // Only process keyDown events
            if event.type == .keyDown {
                print("Local key event detected: \(event.keyCode) with modifiers: \(event.modifierFlags.rawValue)")
                if self.handleKeyEvent(event) {
                    return nil // Consume the event
                }
            }

            return event // Pass the event through
        }

        print("Keyboard shortcuts registered. Global monitor: \(String(describing: globalMonitor)), Local monitor: \(String(describing: localMonitor))")
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        // Check if we have screens to jump to
        guard !screens.isEmpty else { return false }

        // Debug info
        print("Handling key event: keyCode=\(event.keyCode), modifiers=\(event.modifierFlags.rawValue)")

        // Check all screens
        for (index, screen) in screens.enumerated() {
            // Get the shortcut defined for this screen
            let shortcut = ShortcutManager.shared.getShortcut(for: index)

            // Debug info for this shortcut
            print("Checking shortcut for screen \(index): keyCode=\(shortcut.keyCode), modifiers=\(shortcut.modifiers)")

            // Check if the shortcut keys match
            if event.keyCode == shortcut.keyCode {
                // Check if the modifiers match (more lenient matching)
                let requiredModifiers = shortcut.modifierMask
                let eventModifiers = event.modifierFlags.intersection([.shift, .control, .option, .command])

                print("Required modifiers: \(requiredModifiers), Event modifiers: \(eventModifiers)")

                // Check if all required modifiers are present
                if eventModifiers == requiredModifiers {
                    print("Shortcut matched! Moving cursor to screen \(index)")
                    // Match found, move cursor to this screen
                    jumpCursorToScreen(screen)
                    return true
                }
            }
        }

        return false // Event was not handled
    }
}

extension FloatingPoint {
    func rounded(to places: Int) -> Self {
        guard places >= 0 else { return self }
        let multiplier = Self(Int(pow(10.0, Double(places))))
        return (self * multiplier).rounded() / multiplier
    }
}
