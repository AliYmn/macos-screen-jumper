//
//  jumperApp.swift
//  jumper
//
//  Created by aliymnx on 28.04.2025..
//

import SwiftUI
import AppKit

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

    // Store monitors for key events
    private var localMonitor: Any?
    private var globalMonitor: Any?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Request accessibility permissions
        requestAccessibilityPermissions()

        // Setup menu bar item
        setupMenuBar()

        // Register for screen change notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        // Initial screen setup
        updateScreens()

        // Register keyboard shortcuts
        registerKeyboardShortcuts()
    }

    private func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if !accessEnabled {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Required"
            alert.informativeText = "Jumper needs accessibility permissions to move the cursor. Please enable in System Settings > Privacy & Security > Accessibility."
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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "arrow.up.and.down.and.arrow.left.and.right", accessibilityDescription: "Jumper")
        }

        statusBarMenu = NSMenu()
        updateMenuItems()
        statusItem.menu = statusBarMenu
    }

    @objc private func screensDidChange() {
        updateScreens()
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
            let screenName = getScreenName(screen)
            let resolution = getScreenResolution(screen)
            let icon = getScreenIcon(screen)
            let screenType = getScreenType(screen)

            // Get custom shortcut from ShortcutManager
            let shortcut = ShortcutManager.shared.getShortcut(for: index)

            // Format menu item with right-aligned shortcut
            let menuItem = NSMenuItem(
                title: "\(screenType) (\(resolution))",
                action: #selector(jumpToScreen(_:)),
                keyEquivalent: index < 9 ? "\(index + 1)" : ""
            )

            // Set Command as the modifier
            menuItem.keyEquivalentModifierMask = .command
            menuItem.tag = index
            menuItem.image = icon
            statusBarMenu.addItem(menuItem)
        }

        statusBarMenu.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        statusBarMenu.addItem(settingsItem)

        // Refresh screens
        let refreshItem = NSMenuItem(title: "Refresh Screens", action: #selector(refreshScreens), keyEquivalent: "r")
        statusBarMenu.addItem(refreshItem)

        statusBarMenu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit Jumper", action: #selector(quitApp), keyEquivalent: "q")
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
        let name = screen.localizedName.lowercased()
        let width = screen.frame.width
        let height = screen.frame.height
        let aspectRatio = width / height

        // Detect screen type based on name and dimensions
        if name.contains("macbook") || name.contains("built-in") {
            return "MacBook"
        } else if name.contains("lg") && name.contains("ultrafine") {
            return "LG UltraFine"
        } else if name.contains("dell") {
            if aspectRatio < 0.8 {
                return "Dell Portrait"
            } else {
                return "Dell Monitor"
            }
        } else if aspectRatio < 0.8 {
            return "Portrait Monitor"
        } else if aspectRatio > 2.0 {
            return "Ultrawide Monitor"
        } else if min(width, height) < 900 && aspectRatio.rounded(to: 1) == 1.3 {
            return "Tablet"
        } else {
            return "Monitor"
        }
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

        // Move cursor directly (without visual effect)
        CGWarpMouseCursorPosition(CGPoint(x: centerX, y: centerY))

        // Play sound if enabled
        if soundEffectEnabled {
            // Use a softer system sound instead of beep
            NSSound(named: "Pop")?.play()
        }

        // Visual effect disabled to prevent memory issues
    }

    // Store a reference to the effect window to prevent it from being deallocated
    private var effectWindow: NSWindow?

    private func showVisualEffect(at point: CGPoint) {
        // Create a window for the visual effect
        let window = NSWindow(
            contentRect: NSRect(x: point.x - 50, y: point.y - 50, width: 100, height: 100),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        window.backgroundColor = .clear
        window.isOpaque = false
        window.level = .floating
        window.ignoresMouseEvents = true

        // Create the visual effect view
        let visualEffectView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        visualEffectView.material = .hudWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 50

        // Add a circle shape
        let circleView = NSView(frame: NSRect(x: 10, y: 10, width: 80, height: 80))
        circleView.wantsLayer = true
        circleView.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.5).cgColor
        circleView.layer?.cornerRadius = 40

        visualEffectView.addSubview(circleView)
        window.contentView = visualEffectView

        // Store a reference to the window
        self.effectWindow = window

        window.orderFront(nil)

        // Animate the effect
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            circleView.layer?.opacity = 0
            circleView.layer?.setAffineTransform(CGAffineTransform(scaleX: 1.5, y: 1.5))
        }, completionHandler: { [weak self] in
            // Close the window and release the reference
            window.close()
            self?.effectWindow = nil
        })
    }

    private var settingsWindowController: SettingsWindowController?

    @objc private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(appDelegate: self)
        }

        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleSound(_ sender: NSButton) {
        soundEffectEnabled = sender.state == .on
    }

    @objc private func toggleVisual(_ sender: NSButton) {
        visualEffectEnabled = sender.state == .on
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        setLaunchAtLogin(enabled: sender.state == .on)
    }

    private func isLaunchAtLoginEnabled() -> Bool {
        return LaunchAtLogin.shared.isEnabled()
    }

    private func setLaunchAtLogin(enabled: Bool) {
        LaunchAtLogin.shared.setEnabled(enabled)
    }

    @objc private func refreshScreens() {
        updateScreens()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Keyboard Shortcuts

    private func registerKeyboardShortcuts() {
        // Remove any existing monitors
        unregisterKeyboardShortcuts()

        // Create a global monitor for key events
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            _ = self?.handleKeyEvent(event)
        }

        // Create a local monitor for key events (when app is active)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self else { return event }

            if self.handleKeyEvent(event) {
                return nil // Consume the event
            }

            return event // Pass the event through
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        // Check if we have screens to jump to
        guard !screens.isEmpty else { return false }

        // Check if the event has Control+Shift modifiers
        if event.modifierFlags.contains(.control) && event.modifierFlags.contains(.shift) {
            // Check for number keys 1-9
            let keyCode = event.keyCode
            if keyCode >= 0x12 && keyCode <= 0x1B { // 1-9 keys
                let screenIndex = Int(keyCode) - 0x12 // Convert to 0-based index

                // Check if we have this screen
                if screenIndex < screens.count {
                    // Jump to screen directly
                    jumpCursorToScreen(screens[screenIndex])
                    return true
                }
            }
        }

        return false // Event was not handled
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
}

extension FloatingPoint {
    func rounded(to places: Int) -> Self {
        guard places >= 0 else { return self }
        let multiplier = Self(Int(pow(10.0, Double(places))))
        return (self * multiplier).rounded() / multiplier
    }
}
