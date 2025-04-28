//
//  jumperApp.swift
//  jumper
//
//  Created by aliymnx on 28.04.2025..
//

import SwiftUI
import AppKit
import Cocoa
import Carbon

@main
struct jumperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .windowRestorationClass(nil)
    }
}

public class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var statusItem: NSStatusItem!
    private var statusBarMenu: NSMenu!
    public var screens: [NSScreen] = []
    @Published public var soundEffectEnabled = true
    @Published public var visualEffectEnabled = true

    // Store hotkey references to prevent deallocation
    private var hotkeyRefs: [EventHotKeyRef?] = []

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
    }

    private func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if !accessEnabled {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Required"
            alert.informativeText = "Jumper needs accessibility permissions to detect keyboard shortcuts. Please enable in System Settings > Privacy & Security > Accessibility."
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
        // Unregister existing hotkeys
        unregisterHotkeys()

        // Update screens array
        screens = NSScreen.screens

        // Update menu
        updateMenuItems()

        // Register new hotkeys
        registerHotkeys()
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

            // Get custom shortcut from ShortcutManager
            let shortcut = ShortcutManager.shared.getShortcut(for: index)

            let menuItem = NSMenuItem(
                title: "\(screenName) (\(resolution)) - \(shortcut.description)",
                action: #selector(jumpToScreen(_:)),
                keyEquivalent: shortcut.keyEquivalent
            )

            menuItem.keyEquivalentModifierMask = shortcut.modifierMask
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
        let screenNumber = screens.firstIndex(of: screen) ?? 0
        return "Screen \(screenNumber + 1)"
    }

    private func getScreenResolution(_ screen: NSScreen) -> String {
        let width = Int(screen.frame.width)
        let height = Int(screen.frame.height)
        return "\(width)×\(height)"
    }

    public func getScreenIconName(for index: Int) -> String {
        if index < screens.count {
            let screen = screens[index]
            let width = screen.frame.width
            let height = screen.frame.height
            let aspectRatio = width / height

            // Logic based on TODO list
            if screen.localizedName.lowercased().contains("built-in") {
                return "laptopcomputer"
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

    private func getScreenIcon(_ screen: NSScreen) -> NSImage? {
        let screenIndex = screens.firstIndex(of: screen) ?? 0
        let iconName = getScreenIconName(for: screenIndex)
        return NSImage(systemSymbolName: iconName, accessibilityDescription: "Display")
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

        // Move cursor
        CGWarpMouseCursorPosition(CGPoint(x: centerX, y: centerY))

        // Play sound if enabled
        if soundEffectEnabled {
            NSSound.beep()
        }

        // Show visual effect if enabled
        if visualEffectEnabled {
            showVisualEffect(at: CGPoint(x: centerX, y: centerY))
        }
    }

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

        window.orderFront(nil)

        // Animate the effect
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            circleView.layer?.opacity = 0
            circleView.layer?.setAffineTransform(CGAffineTransform(scaleX: 1.5, y: 1.5))
        }, completionHandler: {
            window.close()
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

    // MARK: - Global Hotkeys
    
    // Create a global event handler for hotkeys
    private var eventHandlerRef: EventHandlerRef? = nil
    
    private func registerHotkeys() {
        // First unregister any existing hotkeys
        unregisterHotkeys()
        
        // Install a single event handler for all hotkeys
        var eventType = EventTypeSpec()
        eventType.eventClass = UInt32(kEventClassKeyboard)
        eventType.eventKind = UInt32(kEventHotKeyPressed)
        
        // Install the event handler once
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, theEvent, userData) -> OSStatus in
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    theEvent,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                
                if status == noErr && hotKeyID.signature == 0x4A554D50 { // 'JUMP' in hex
                    let screenIndex = Int(hotKeyID.id)
                    
                    // Post a notification that will be handled on the main thread
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: Notification.Name("JumperScreenJump"),
                            object: nil,
                            userInfo: ["screenIndex": screenIndex]
                        )
                    }
                }
                
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
        
        if status != noErr {
            print("Failed to install event handler")
            return
        }
        
        // Register individual hotkeys
        for (index, _) in screens.enumerated() {
            registerHotkey(for: index)
        }
        
        // Add observer for the jump notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenJump(_:)),
            name: Notification.Name("JumperScreenJump"),
            object: nil
        )
    }
    
    @objc private func handleScreenJump(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let screenIndex = userInfo["screenIndex"] as? Int,
              screenIndex < screens.count else {
            return
        }
        
        jumpCursorToScreen(screens[screenIndex])
    }
    
    private func registerHotkey(for screenIndex: Int) {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = 0x4A554D50 // 'JUMP' in hex
        hotKeyID.id = UInt32(screenIndex)

        var hotKeyRef: EventHotKeyRef?

        // Get custom shortcut from ShortcutManager
        let shortcut = ShortcutManager.shared.getShortcut(for: screenIndex)

        // Use custom modifiers and keycode
        let modifiers: UInt32 = shortcut.modifiers
        let keyCode = UInt32(shortcut.keyCode)

        // Register the hotkey
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr {
            hotkeyRefs.append(hotKeyRef)
        } else {
            print("Failed to register hotkey for screen \(screenIndex)")
        }
    }

    private func unregisterHotkeys() {
        // Remove notification observer
        NotificationCenter.default.removeObserver(self, name: Notification.Name("JumperScreenJump"), object: nil)
        
        // Unregister all hotkeys
        for hotKeyRef in hotkeyRefs {
            if let hotKeyRef = hotKeyRef {
                UnregisterEventHotKey(hotKeyRef)
            }
        }
        hotkeyRefs.removeAll()
        
        // Remove event handler
        if let eventHandlerRef = eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
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
