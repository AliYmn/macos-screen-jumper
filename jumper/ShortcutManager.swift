//
//  ShortcutManager.swift
//  jumper
//
//  Created for Screen Jumper app
//  Manages keyboard shortcuts for screen jumping functionality
//

import Foundation
import AppKit

/// Represents a keyboard shortcut with key code and modifier flags
public struct KeyboardShortcut: Codable, Equatable {
    /// The key code of the shortcut key
    public var keyCode: Int
    
    /// Bit flags representing modifier keys (Control, Shift, Option, Command)
    public var modifiers: UInt32
    
    /// Creates a new keyboard shortcut
    /// - Parameters:
    ///   - keyCode: The key code of the shortcut key
    ///   - modifiers: Bit flags for modifier keys
    public init(keyCode: Int, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
    
    /// Default modifier combination: Control (1) + Shift (2) = 3
    public static let defaultModifiers: UInt32 = 3

    /// Creates a default shortcut for the given screen index
    /// - Parameter screenIndex: The index of the screen (0-based)
    /// - Returns: A keyboard shortcut using Control+Shift+Number (1-9)
    public static func defaultShortcut(for screenIndex: Int) -> KeyboardShortcut {
        // Default to Control+Shift+Number (1-9)
        // 0x12 is kVK_ANSI_1, so we add the screen index to get keys 1-9
        let keyCode = 0x12 + min(screenIndex, 8) // Limit to 9 screens (1-9)
        return KeyboardShortcut(keyCode: keyCode, modifiers: defaultModifiers)
    }

    public var keyEquivalent: String {
        // Convert keyCode to character
        if keyCode >= 0x12 && keyCode <= 0x1B {  // 1-0 keys
            let number = keyCode - 0x12 + 1
            return number == 10 ? "0" : "\(number)"
        } else {
            // For other keys, use a simpler approach
            // This is a simplified implementation that works for common keys
            switch keyCode {
            case 0x00: return "a"
            case 0x01: return "s"
            case 0x02: return "d"
            case 0x03: return "f"
            case 0x04: return "h"
            case 0x05: return "g"
            case 0x06: return "z"
            case 0x07: return "x"
            case 0x08: return "c"
            case 0x09: return "v"
            case 0x0B: return "b"
            case 0x0C: return "q"
            case 0x0D: return "w"
            case 0x0E: return "e"
            case 0x0F: return "r"
            case 0x10: return "y"
            case 0x11: return "t"
            case 0x1C: return "k"
            case 0x1D: return "i"
            case 0x1E: return "o"
            case 0x1F: return "p"
            case 0x20: return "l"
            case 0x21: return "j"
            case 0x22: return "'"
            case 0x23: return ";"
            case 0x25: return ","
            case 0x26: return "."
            case 0x2A: return "\\"
            case 0x2B: return "/"
            case 0x2C: return "n"
            case 0x2D: return "m"
            case 0x2F: return "."
            case 0x32: return "`"
            default: return ""
            }
        }
    }

    public var modifierMask: NSEvent.ModifierFlags {
        var mask: NSEvent.ModifierFlags = []

        if modifiers & 1 != 0 { // Control
            mask.insert(.control)
        }
        if modifiers & 2 != 0 { // Shift
            mask.insert(.shift)
        }
        if modifiers & 4 != 0 { // Option
            mask.insert(.option)
        }
        if modifiers & 8 != 0 { // Command
            mask.insert(.command)
        }

        return mask
    }

    public var description: String {
        var desc = ""

        if modifiers & 1 != 0 { // Control
            desc += "⌃"
        }
        if modifiers & 2 != 0 { // Shift
            desc += "⇧"
        }
        if modifiers & 4 != 0 { // Option
            desc += "⌥"
        }
        if modifiers & 8 != 0 { // Command
            desc += "⌘"
        }

        desc += keyEquivalent

        return desc
    }
}

/// Notification sent when shortcuts are changed
public let shortcutsChangedNotification = Notification.Name("ScreenJumperShortcutsChanged")

/// Manages keyboard shortcuts for screen jumping functionality
public final class ShortcutManager {
    /// Shared singleton instance
    public static let shared = ShortcutManager()
    
    /// UserDefaults key for storing shortcuts
    private let userDefaultsKey = "ScreenJumperKeyboardShortcuts"
    
    /// Dictionary mapping screen indices to their keyboard shortcuts
    private var shortcuts: [Int: KeyboardShortcut] = [:]
    
    /// Cache for frequently accessed shortcuts to improve performance
    private var shortcutCache: [Int: KeyboardShortcut] = [:]
    
    /// Private initializer to enforce singleton pattern
    private init() {
        loadShortcuts()
    }

    /// Gets the keyboard shortcut for a specific screen index
    /// - Parameter screenIndex: The index of the screen
    /// - Returns: The keyboard shortcut for the specified screen
    public func getShortcut(for screenIndex: Int) -> KeyboardShortcut {
        // First check the cache for better performance
        if let cachedShortcut = shortcutCache[screenIndex] {
            return cachedShortcut
        }
        
        // If not in cache, check the main shortcuts dictionary
        if let shortcut = shortcuts[screenIndex] {
            // Store in cache for future access
            shortcutCache[screenIndex] = shortcut
            return shortcut
        } 
        
        // Create default shortcut if none exists
        let defaultShortcut = KeyboardShortcut.defaultShortcut(for: screenIndex)
        shortcuts[screenIndex] = defaultShortcut
        shortcutCache[screenIndex] = defaultShortcut
        saveShortcuts()
        return defaultShortcut
    }

    public func setShortcut(_ shortcut: KeyboardShortcut, for screenIndex: Int) {
        shortcuts[screenIndex] = shortcut
        // Update cache
        shortcutCache[screenIndex] = shortcut
        saveShortcuts()

        // Notify about shortcut change
        notifyShortcutChange()
    }

    public func resetToDefault(for screenIndex: Int) {
        let defaultShortcut = KeyboardShortcut.defaultShortcut(for: screenIndex)
        shortcuts[screenIndex] = defaultShortcut
        // Update cache
        shortcutCache[screenIndex] = defaultShortcut
        saveShortcuts()

        // Notify about shortcut change
        notifyShortcutChange()
    }

    public func resetAllShortcuts() {
        // Clear all shortcuts
        shortcuts.removeAll()
        // Clear the cache
        shortcutCache.removeAll()

        // Set default shortcuts based on current screen count
        let screenCount = NSScreen.screens.count
        for i in 0..<screenCount {
            let defaultShortcut = KeyboardShortcut.defaultShortcut(for: i)
            shortcuts[i] = defaultShortcut
            shortcutCache[i] = defaultShortcut
        }

        saveShortcuts()

        // Notify about shortcut change
        notifyShortcutChange()
    }

    // Helper method to notify about shortcut changes
    private func notifyShortcutChange() {
        NotificationCenter.default.post(name: shortcutsChangedNotification, object: nil)
    }

    /// Loads saved shortcuts from UserDefaults
    private func loadShortcuts() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }
        
        do {
            shortcuts = try JSONDecoder().decode([Int: KeyboardShortcut].self, from: data)
            // Pre-populate cache with loaded shortcuts for better performance
            shortcutCache = shortcuts
        } catch {
            print("Error loading shortcuts: \(error)")
        }
    }
    
    /// Saves shortcuts to UserDefaults
    private func saveShortcuts() {
        do {
            let data = try JSONEncoder().encode(shortcuts)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("Error saving shortcuts: \(error)")
        }
    }
}
