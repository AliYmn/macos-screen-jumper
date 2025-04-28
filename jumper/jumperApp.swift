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

    // Sound effect settings
    @Published public var soundEffectEnabled = true
    @Published public var soundVolume: Double = 0.8
    @Published public var selectedSoundEffect: SoundEffectType = .pop

    // Sound effect types
    public enum SoundEffectType: Int, CaseIterable {
        case pop = 0
        case click = 1
        case swoosh = 2
        case beep = 3
        case tink = 4

        var name: String {
            switch self {
            case .pop: return "Pop"
            case .click: return "Click"
            case .swoosh: return "Swoosh"
            case .beep: return "Beep"
            case .tink: return "Tink"
            }
        }

        var soundName: String {
            switch self {
            case .pop: return "Pop"
            case .click: return "Tink"
            case .swoosh: return "Submarine"
            case .beep: return "Basso"
            case .tink: return "Funk"
            }
        }
    }

    // Visual effect settings
    @Published public var visualEffectEnabled = true
    @Published public var visualEffectStyle: VisualEffectStyle = .modern

    // Startup settings
    @Published public var showWelcomeScreen = false
    @Published public var checkForUpdatesAutomatically = true

    // Visual effect style enum
    public enum VisualEffectStyle: Int, CaseIterable {
        case modern = 0
        case classic = 1
        case minimal = 2

        var name: String {
            switch self {
            case .modern: return "Modern"
            case .classic: return "Classic"
            case .minimal: return "Minimal"
            }
        }
    }

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
        // Hide from Dock and register app to receive background events
        NSApp.setActivationPolicy(.accessory)

        // Request accessibility permissions
        requestAccessibilityPermissions()

        // Setup menu bar item
        setupMenuBar()

        // Initial screen setup
        updateScreens()

        // Pre-create sound object
        popSound = NSSound(named: "Pop")

        // Setup all notification observers
        setupNotificationObservers()

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
            // Use a more visible icon for menu bar
            let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
            let menuIcon = NSImage(systemSymbolName: "cursorarrow.click.2", accessibilityDescription: "Jumper")?.
                withSymbolConfiguration(config) ?? NSImage(systemSymbolName: "cursorarrow.rays", accessibilityDescription: "Jumper")!

            // Set the icon
            button.image = menuIcon

            // Increase the button size to accommodate the icon
            button.frame = NSRect(x: button.frame.origin.x, y: button.frame.origin.y,
                                 width: button.frame.width + 8, height: button.frame.height)
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
    // Setup all notification observers in one place for better organization
    private func setupNotificationObservers() {
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
    }

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
            // Get the sound name based on selected effect
            let soundName = selectedSoundEffect.soundName

            // Create or update sound object if needed
            if popSound == nil || popSound?.name != soundName {
                popSound = NSSound(named: soundName)
            }

            // If sound is playing, stop it and restart
            if let sound = popSound {
                if sound.isPlaying {
                    sound.stop()
                }
                // Set volume based on user preference
                sound.volume = Float(soundVolume)
                sound.play()
            }
        }
    }

    // Constants for visual effect
    private struct VisualEffectConstants {
        // Base constants
        static let highlightSize: CGFloat = 70
        static let glowInset: CGFloat = 5
        static let ringInset: CGFloat = 2
        static let innerRingInset: CGFloat = 15
        static let dotSize: CGFloat = 15

        // Modern style colors (default)
        static let modernOuterColor = NSColor(calibratedRed: 0.0, green: 1.0, blue: 0.5, alpha: 1.0) // Neon green
        static let modernInnerColor = NSColor(calibratedRed: 1.0, green: 0.0, blue: 0.8, alpha: 1.0) // Neon pink
        static let modernDotColor = NSColor.white

        // Classic style colors
        static let classicOuterColor = NSColor.systemBlue
        static let classicInnerColor = NSColor.systemBlue.withAlphaComponent(0.7)
        static let classicDotColor = NSColor.white

        // Minimal style colors
        static let minimalOuterColor = NSColor.white.withAlphaComponent(0.8)
        static let minimalInnerColor = NSColor.clear
        static let minimalDotColor = NSColor.white

        // Animation durations
        static let fadeInDuration: TimeInterval = 0.2
        static let visibleDuration: TimeInterval = 0.3
        static let fadeOutDuration: TimeInterval = 0.3
        static let ringPulseDuration: TimeInterval = 0.4
        static let ringRotationDuration: TimeInterval = 0.5
        static let dotPulseDuration: TimeInterval = 0.3

        // Get colors based on current style
        static func getOuterColor(for style: VisualEffectStyle) -> NSColor {
            switch style {
            case .modern: return modernOuterColor
            case .classic: return classicOuterColor
            case .minimal: return minimalOuterColor
            }
        }

        static func getInnerColor(for style: VisualEffectStyle) -> NSColor {
            switch style {
            case .modern: return modernInnerColor
            case .classic: return classicInnerColor
            case .minimal: return minimalInnerColor
            }
        }

        static func getDotColor(for style: VisualEffectStyle) -> NSColor {
            switch style {
            case .modern: return modernDotColor
            case .classic: return classicDotColor
            case .minimal: return minimalDotColor
            }
        }
    }

    // Show a quick jump effect at the cursor position with high contrast colors
    private func showLightVisualEffect(at point: CGPoint) {
        let constants = VisualEffectConstants.self
        let highlightSize = constants.highlightSize

        // Create and configure the panel
        let highlightPanel = createVisualEffectPanel(at: point, size: highlightSize)

        // Create a custom view for the highlight
        let highlightView = NSView(frame: NSRect(x: 0, y: 0, width: highlightSize, height: highlightSize))
        highlightView.wantsLayer = true

        // Create and add all layers
        let (glowLayer, ringLayer, innerRingLayer, dotLayer) = createVisualEffectLayers(size: highlightSize)

        highlightView.layer?.addSublayer(glowLayer)
        highlightView.layer?.addSublayer(ringLayer)
        highlightView.layer?.addSublayer(innerRingLayer)
        highlightView.layer?.addSublayer(dotLayer)
        highlightPanel.contentView = highlightView

        // Show the panel
        highlightPanel.orderFront(nil)

        // Add animations
        addAnimationsToLayers(ringLayer: ringLayer, innerRingLayer: innerRingLayer, dotLayer: dotLayer)

        // Handle panel fade-in/out and cleanup
        animatePanelVisibility(panel: highlightPanel)
    }

    // Create the panel for the visual effect
    private func createVisualEffectPanel(at point: CGPoint, size: CGFloat) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: point.x - size/2, y: point.y - size/2, width: size, height: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Configure the panel - make sure it doesn't block mouse events
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .popUpMenu
        panel.ignoresMouseEvents = true // This is important - panel should not intercept mouse events
        panel.alphaValue = 0.0

        return panel
    }

    // Create all the layers for the visual effect
    private func createVisualEffectLayers(size: CGFloat) -> (glow: CAShapeLayer, ring: CAShapeLayer, innerRing: CAShapeLayer, dot: CAShapeLayer) {
        let constants = VisualEffectConstants.self

        // Get colors based on the selected style
        let outerColor = constants.getOuterColor(for: visualEffectStyle)
        let innerColor = constants.getInnerColor(for: visualEffectStyle)
        let dotColor = constants.getDotColor(for: visualEffectStyle)

        // Create a background glow effect
        let glowLayer = CAShapeLayer()
        let glowInset = constants.glowInset
        let glowPath = NSBezierPath(ovalIn: NSRect(x: glowInset, y: glowInset, width: size-glowInset*2, height: size-glowInset*2))
        glowLayer.path = glowPath.cgPath
        glowLayer.fillColor = NSColor.clear.cgColor
        glowLayer.strokeColor = NSColor.white.cgColor
        glowLayer.lineWidth = 8.0
        glowLayer.opacity = 0.3
        glowLayer.shadowColor = NSColor.white.cgColor
        glowLayer.shadowOffset = CGSize.zero
        glowLayer.shadowRadius = 5.0
        glowLayer.shadowOpacity = 0.8

        // Create the outer ring
        let ringLayer = CAShapeLayer()
        let ringInset = constants.ringInset
        let ringPath = NSBezierPath(ovalIn: NSRect(x: ringInset, y: ringInset, width: size-ringInset*2, height: size-ringInset*2))
        ringLayer.path = ringPath.cgPath
        ringLayer.fillColor = NSColor.clear.cgColor
        ringLayer.strokeColor = outerColor.cgColor
        ringLayer.lineWidth = 3.0
        ringLayer.opacity = 0.9

        // Create the inner ring
        let innerRingLayer = CAShapeLayer()
        let innerRingInset = constants.innerRingInset
        let innerRingPath = NSBezierPath(ovalIn: NSRect(x: innerRingInset, y: innerRingInset, width: size-innerRingInset*2, height: size-innerRingInset*2))
        innerRingLayer.path = innerRingPath.cgPath
        innerRingLayer.fillColor = NSColor.clear.cgColor
        innerRingLayer.strokeColor = innerColor.cgColor
        innerRingLayer.lineWidth = 2.0
        innerRingLayer.opacity = 0.9

        // Create the center dot
        let dotLayer = CAShapeLayer()
        let dotSize = constants.dotSize
        let dotPath = NSBezierPath(ovalIn: NSRect(x: (size-dotSize)/2, y: (size-dotSize)/2, width: dotSize, height: dotSize))
        dotLayer.path = dotPath.cgPath
        dotLayer.fillColor = dotColor.cgColor
        dotLayer.opacity = 1.0
        dotLayer.shadowColor = NSColor.black.cgColor
        dotLayer.shadowOffset = CGSize.zero
        dotLayer.shadowRadius = 3.0
        dotLayer.shadowOpacity = 0.8

        return (glowLayer, ringLayer, innerRingLayer, dotLayer)
    }

    // Add animations to the visual effect layers
    private func addAnimationsToLayers(ringLayer: CAShapeLayer, innerRingLayer: CAShapeLayer, dotLayer: CAShapeLayer) {
        let constants = VisualEffectConstants.self

        // Pulse animation for the outer ring
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.duration = constants.ringPulseDuration
        pulseAnimation.fromValue = 0.9
        pulseAnimation.toValue = 1.1
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = 1
        ringLayer.add(pulseAnimation, forKey: "pulse")

        // Inner ring animation with rotation
        let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotateAnimation.duration = constants.ringRotationDuration
        rotateAnimation.fromValue = 0
        rotateAnimation.toValue = CGFloat.pi * 0.1
        rotateAnimation.autoreverses = true
        rotateAnimation.repeatCount = 1
        innerRingLayer.add(rotateAnimation, forKey: "rotate")

        // Dot animation (pulse)
        let dotPulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        dotPulseAnimation.duration = constants.dotPulseDuration
        dotPulseAnimation.fromValue = 1.3
        dotPulseAnimation.toValue = 0.9
        dotPulseAnimation.autoreverses = true
        dotPulseAnimation.repeatCount = 1
        dotLayer.add(dotPulseAnimation, forKey: "dotPulse")
    }

    // Handle panel visibility animations and cleanup
    private func animatePanelVisibility(panel: NSPanel) {
        let constants = VisualEffectConstants.self

        // Fade-in animation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = constants.fadeInDuration
            panel.animator().alphaValue = 1.0
        }) {
            // Add a slight delay to keep the effect visible
            DispatchQueue.main.asyncAfter(deadline: .now() + constants.visibleDuration) {
                // Fade-out animation
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = constants.fadeOutDuration
                    panel.animator().alphaValue = 0.0
                }) {
                    // Close panel
                    panel.close()
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

    // Constants for keyboard shortcut handling
    private struct KeyboardShortcutConstants {
        static let debugMode = false // Set to false in production to disable debug prints
    }

    private func registerKeyboardShortcuts() {
        // Remove any existing monitors
        unregisterKeyboardShortcuts()

        // Register app to receive keyboard events in the background
        // Only check permissions, don't show alerts (already shown in requestAccessibilityPermissions)
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] // Don't show prompt automatically
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)

        // Just print debug information
        if !accessEnabled && KeyboardShortcutConstants.debugMode {
            print("Accessibility permissions not granted. Global shortcuts may not work.")
        }

        // Create a global monitor for key events that works even when app isn't active
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self else { return }

            if KeyboardShortcutConstants.debugMode {
                print("Global key event detected: \(event.keyCode) with modifiers: \(event.modifierFlags.rawValue)")
            }
            _ = self.handleKeyEvent(event)
        }

        // Create a local monitor for key events (when app is active)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self else { return event }

            if KeyboardShortcutConstants.debugMode {
                print("Local key event detected: \(event.keyCode) with modifiers: \(event.modifierFlags.rawValue)")
            }

            if self.handleKeyEvent(event) {
                return nil // Consume the event
            }

            return event // Pass the event through
        }

        if KeyboardShortcutConstants.debugMode {
            print("Keyboard shortcuts registered. Global monitor: \(String(describing: globalMonitor)), Local monitor: \(String(describing: localMonitor))")
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        // Check if we have screens to jump to
        guard !screens.isEmpty else { return false }

        // Debug info
        if KeyboardShortcutConstants.debugMode {
            print("Handling key event: keyCode=\(event.keyCode), modifiers=\(event.modifierFlags.rawValue)")
        }

        // Get the event modifiers once for all comparisons
        let eventModifiers = event.modifierFlags.intersection([.shift, .control, .option, .command])

        // Create a cache of shortcuts for better performance
        // This avoids repeated calls to ShortcutManager.shared.getShortcut
        let shortcutsCache = screens.indices.map { ShortcutManager.shared.getShortcut(for: $0) }

        // Check all screens
        for (index, screen) in screens.enumerated() {
            // Get the shortcut from our cache
            let shortcut = shortcutsCache[index]

            // Debug info for this shortcut
            if KeyboardShortcutConstants.debugMode {
                print("Checking shortcut for screen \(index): keyCode=\(shortcut.keyCode), modifiers=\(shortcut.modifiers)")
            }

            // Check if the shortcut keys match
            if event.keyCode == shortcut.keyCode {
                // Check if the modifiers match
                let requiredModifiers = shortcut.modifierMask

                if KeyboardShortcutConstants.debugMode {
                    print("Required modifiers: \(requiredModifiers), Event modifiers: \(eventModifiers)")
                }

                // Check if all required modifiers are present
                if eventModifiers == requiredModifiers {
                    if KeyboardShortcutConstants.debugMode {
                        print("Shortcut matched! Moving cursor to screen \(index)")
                    }
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
