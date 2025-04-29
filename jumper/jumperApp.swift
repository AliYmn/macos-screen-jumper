//
//  jumperApp.swift
//  jumper
//
//  Created by aliymnx on 28.04.2025
//  A utility app for quickly jumping between multiple monitors
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

        // Setup menu bar item
        setupMenuBar()

        // Initial screen setup
        updateScreens()

        // Pre-create sound object
        popSound = NSSound(named: "Pop")

        // Register for screen configuration changes
        NotificationCenter.default.addObserver(self, selector: #selector(screensDidChange), name: NSApplication.didChangeScreenParametersNotification, object: nil)

        // Register for shortcut changes notification
        NotificationCenter.default.addObserver(self, selector: #selector(shortcutsDidChange), name: shortcutsChangedNotification, object: nil)

        // Register for Launch at Login status changes
        NotificationCenter.default.addObserver(self, selector: #selector(launchAtLoginStatusDidChange), name: LaunchAtLogin.statusChangedNotification, object: nil)

        // Request accessibility permissions immediately
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if !accessEnabled {
            requestAccessibilityPermissions()
        }

        // Register keyboard shortcuts
        registerKeyboardShortcuts()

        // Ensure menu bar item is visible
        DispatchQueue.main.async {
            self.setupMenuBar()
        }

        // Register keyboard shortcuts again after a delay to ensure they work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.registerKeyboardShortcuts()
        }

        // And one more time after a longer delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.registerKeyboardShortcuts()
        }

        // Ask for Launch at Login permission once
        askForLaunchAtLoginPermission()
    }

    private func requestAccessibilityPermissions() {
        // Store a flag to prevent showing this alert multiple times per session
        let defaults = UserDefaults.standard
        let permissionAlertShownKey = "accessibilityPermissionAlertShown"

        if !defaults.bool(forKey: permissionAlertShownKey) {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Required"
            alert.informativeText = "Display Jumper needs accessibility permissions to move the cursor and respond to global keyboard shortcuts when other apps are active. This permission is only requested once.\n\nPlease enable in System Settings > Privacy & Security > Accessibility."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Later")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }

            // Mark that we've shown the alert this session
            defaults.set(true, forKey: permissionAlertShownKey)
        }
    }

    private func setupMenuBar() {
        // Create an item in the menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // Use a more visible icon for menu bar with standard dimensions
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            let menuIcon = NSImage(systemSymbolName: "cursorarrow.click.2", accessibilityDescription: "Jumper")?
                .withSymbolConfiguration(config) ?? NSImage(systemSymbolName: "cursorarrow.rays", accessibilityDescription: "Jumper")!

            // Ensure the icon has a standard size
            menuIcon.size = NSSize(width: 18, height: 18)

            // Set the icon
            button.image = menuIcon

            // Set proper spacing and alignment
            button.imagePosition = .imageLeft
            button.imageHugsTitle = true
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

    /**
     Sets up all notification observers needed by the application.

     This includes observers for screen changes, shortcut changes, and launch at login status changes.
     */
    private func setupNotificationObservers() {
        // Create an array of notification observations for cleaner setup
        let observations: [(NSNotification.Name, Selector)] = [
            (NSApplication.didChangeScreenParametersNotification, #selector(screensDidChange)),
            (shortcutsChangedNotification, #selector(shortcutsDidChange)),
            (LaunchAtLogin.statusChangedNotification, #selector(launchAtLoginStatusDidChange))
        ]

        // Register all observers
        for (name, selector) in observations {
            NotificationCenter.default.addObserver(
                self,
                selector: selector,
                name: name,
                object: nil
            )
        }
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

    /**
     Updates the list of available screens and refreshes related components.

     This method is called whenever screen configuration changes, such as when
     monitors are connected or disconnected.
     */
    public func updateScreens() {
        // Update screens array - automatically detect all available monitors
        screens = NSScreen.screens

        // Update menu to reflect the current screen configuration
        updateMenuItems()

        // Re-register keyboard shortcuts to ensure they work with the new screen configuration
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

        // Create a properly sized icon with standard menu item dimensions
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let icon = NSImage(systemSymbolName: iconName, accessibilityDescription: "Display")?.withSymbolConfiguration(config)

        // Ensure the icon has a standard size for menu items
        if let icon = icon {
            icon.size = NSSize(width: 18, height: 18)
        }

        return icon
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

    /**
     Jumps the cursor to the center of the specified screen.

     This method handles the coordinate conversion between Cocoa's coordinate system (origin at bottom-left)
     and Quartz's coordinate system (origin at top-left) to ensure accurate cursor positioning.

     - Parameter screen: The NSScreen to jump the cursor to
     */
    private func jumpCursorToScreen(_ screen: NSScreen) {
        // Get the global screen coordinates
        let screenFrame = screen.frame

        // Calculate center point in global coordinates
        let centerX = screenFrame.origin.x + screenFrame.width / 2

        // Convert from Cocoa's coordinate system (origin at bottom-left) to
        // Quartz's coordinate system (origin at top-left) for CGWarpMouseCursorPosition
        let mainScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        let flippedY = mainScreenHeight - (screenFrame.origin.y + screenFrame.height / 2)

        // Create the center point in global coordinates
        let centerPoint = CGPoint(x: centerX, y: flippedY)

        // Move cursor to the center of the screen
        CGWarpMouseCursorPosition(centerPoint)

        // Show visual effect at the exact cursor position if enabled
        if visualEffectEnabled {
            // Small delay to ensure cursor has moved before showing effect
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
                guard let self = self else { return }
                let currentMouseLocation = NSEvent.mouseLocation
                self.showLightVisualEffect(at: currentMouseLocation)
            }
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

    /**
     Shows a visual effect at the specified point when the cursor jumps.

     Creates a non-interactive panel with animated layers to provide visual feedback
     at the exact location where the cursor has jumped to.

     - Parameter point: The point where the visual effect should be displayed
     */
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

        // Add layers in the correct order for proper rendering
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
        static let debugMode = false // Set to false for production
    }

    /**
     Registers keyboard shortcuts for screen jumping functionality.

     Sets up both local and global event monitors to capture keyboard shortcuts
     regardless of which application is active.
     */
    private func registerKeyboardShortcuts() {
        // Remove any existing monitors first to prevent duplicates
        unregisterKeyboardShortcuts()

        // Check accessibility permissions without showing system dialog
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if !accessEnabled {
            // Show our custom permission dialog only once after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.requestAccessibilityPermissions()
            }
        }

        // Set up local event monitor for keyboard shortcuts when app is active
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self else { return event }

            if self.handleKeyEvent(event) {
                return nil // Event was handled, don't propagate
            }
            return event // Event wasn't handled, propagate normally
        }

        // Set up global event monitor for keyboard shortcuts when app is in background
        // Note: Global monitor only works properly when accessibility permissions are granted
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self else { return }
            _ = self.handleKeyEvent(event) // Just handle the event
        }

        // Force accessibility permissions dialog if needed
        if !accessEnabled {
            // This will show the system dialog
            let forceOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            _ = AXIsProcessTrustedWithOptions(forceOptions as CFDictionary)
        }
    }

    /**
     Handles keyboard events and determines if they match any registered shortcuts.

     - Parameter event: The NSEvent to process
     - Returns: Boolean indicating whether the event was handled
     */
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        // Check if we have screens to jump to
        guard !screens.isEmpty else { return false }

        // Extract key information from the event
        let keyCode = event.keyCode

        // IMPORTANT: For global shortcuts, we need to handle modifiers differently
        // The raw value includes additional flags that we need to filter out
        let rawModifiers = event.modifierFlags.rawValue
        let deviceIndependentMask = NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue
        let modifiers = rawModifiers & deviceIndependentMask

        // Additional mask to handle common modifier flag variations
        let baseMask: UInt = 0xFFFF0000
        let baseModifiers = rawModifiers & ~baseMask

        // Debug info is disabled in production

        // Check if the event matches any screen's shortcut
        for (index, screen) in screens.enumerated() {
            let shortcut = ShortcutManager.shared.getShortcut(for: index)

            // Try multiple matching strategies for better compatibility
            let exactMatch = (keyCode == shortcut.keyCode && modifiers == shortcut.modifiers)
            // Simplify the match to avoid type conversion issues
            let baseMatch = (keyCode == shortcut.keyCode)

            // For Control+Shift+Number shortcuts (common case)
            let isControlShiftNumber =
                (keyCode >= 18 && keyCode <= 29) && // Number keys 1-0
                ((rawModifiers & UInt(NSEvent.ModifierFlags.control.rawValue)) != 0) &&
                ((rawModifiers & UInt(NSEvent.ModifierFlags.shift.rawValue)) != 0)

            // Check if this is a match
            if exactMatch || baseMatch || (index < 10 && isControlShiftNumber && (keyCode - 18) == index) {
                // Shortcut match found for this screen

                // Found a match, jump to this screen on the main thread
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.jumpCursorToScreen(screen)
                }
                return true // Event was handled
            }
        }

        return false // No matching shortcut found
    }
}

extension FloatingPoint {
    func rounded(to places: Int) -> Self {
        guard places >= 0 else { return self }
        let multiplier = Self(Int(pow(10.0, Double(places))))
        return (self * multiplier).rounded() / multiplier
    }
}
