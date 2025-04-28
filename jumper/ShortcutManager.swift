//
//  ShortcutManager.swift
//  jumper
//
//  Created for Jumper app
//

import Foundation
import AppKit
import Carbon

public struct KeyboardShortcut: Codable, Equatable {
    public var keyCode: Int
    public var modifiers: UInt32

    public init(keyCode: Int, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public static let defaultModifiers: UInt32 = UInt32(1 << 0) | UInt32(1 << 1) // controlKey | shiftKey

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

        if modifiers & UInt32(1 << 0) != 0 { // controlKey
            mask.insert(.control)
        }
        if modifiers & UInt32(1 << 1) != 0 { // shiftKey
            mask.insert(.shift)
        }
        if modifiers & UInt32(1 << 2) != 0 { // optionKey
            mask.insert(.option)
        }
        if modifiers & UInt32(1 << 3) != 0 { // cmdKey
            mask.insert(.command)
        }

        return mask
    }

    public var description: String {
        var desc = ""

        if modifiers & UInt32(1 << 0) != 0 { // controlKey
            desc += "⌃"
        }
        if modifiers & UInt32(1 << 2) != 0 { // optionKey
            desc += "⌥"
        }
        if modifiers & UInt32(1 << 1) != 0 { // shiftKey
            desc += "⇧"
        }
        if modifiers & UInt32(1 << 3) != 0 { // cmdKey
            desc += "⌘"
        }

        desc += keyEquivalent

        return desc
    }
}

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
    }

    public func resetToDefault(for screenIndex: Int) {
        shortcuts[screenIndex] = KeyboardShortcut.defaultShortcut(for: screenIndex)
        saveShortcuts()
    }

    public func resetAllToDefault() {
        shortcuts.removeAll()
        saveShortcuts()
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
