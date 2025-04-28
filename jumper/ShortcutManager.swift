//
//  ShortcutManager.swift
//  jumper
//
//  Created for Jumper app
//

import Foundation
import AppKit

public struct KeyboardShortcut: Codable, Equatable {
    public var keyCode: Int
    public var modifiers: UInt32

    public init(keyCode: Int, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public static let defaultModifiers: UInt32 = 3 // Control (1) + Shift (2)

    public static func defaultShortcut(for screenIndex: Int) -> KeyboardShortcut {
        // Default to Control+Shift+Number (1-9)
        let keyCode = 0x12 + screenIndex // 0x12 is kVK_ANSI_1
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

// Kısayol değişikliklerini bildirmek için bildirim adı
public let shortcutsChangedNotification = Notification.Name("JumperShortcutsChanged")

public class ShortcutManager {
    public static let shared = ShortcutManager()

    private let userDefaultsKey = "JumperKeyboardShortcuts"
    private var shortcuts: [Int: KeyboardShortcut] = [:]

    private init() {
        loadShortcuts()
    }

    public func getShortcut(for screenIndex: Int) -> KeyboardShortcut {
        if let shortcut = shortcuts[screenIndex] {
            return shortcut
        } else {
            let defaultShortcut = KeyboardShortcut.defaultShortcut(for: screenIndex)
            shortcuts[screenIndex] = defaultShortcut
            saveShortcuts()
            return defaultShortcut
        }
    }

    public func setShortcut(_ shortcut: KeyboardShortcut, for screenIndex: Int) {
        shortcuts[screenIndex] = shortcut
        saveShortcuts()
        
        // Kısayol değişikliğini bildir
        NotificationCenter.default.post(name: shortcutsChangedNotification, object: nil)
    }

    public func resetToDefault(for screenIndex: Int) {
        shortcuts[screenIndex] = KeyboardShortcut.defaultShortcut(for: screenIndex)
        saveShortcuts()
        
        // Kısayol değişikliğini bildir
        NotificationCenter.default.post(name: shortcutsChangedNotification, object: nil)
    }

    public func resetAllShortcuts() {
        // Tüm kısayolları temizle
        shortcuts.removeAll()
        
        // Mevcut ekran sayısına göre varsayılan kısayolları ayarla
        let screenCount = NSScreen.screens.count
        for i in 0..<screenCount {
            shortcuts[i] = KeyboardShortcut.defaultShortcut(for: i)
        }
        
        saveShortcuts()
        
        // Kısayol değişikliğini bildir
        NotificationCenter.default.post(name: shortcutsChangedNotification, object: nil)
    }

    private func loadShortcuts() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let savedShortcuts = try? JSONDecoder().decode([Int: KeyboardShortcut].self, from: data) {
            shortcuts = savedShortcuts
        }
    }

    private func saveShortcuts() {
        if let data = try? JSONEncoder().encode(shortcuts) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}
