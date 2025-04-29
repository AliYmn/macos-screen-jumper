//
//  LaunchAtLogin.swift
//  jumper
//
//  Created for Jumper app
//  Manages launch at login functionality for the application
//

import Foundation
import ServiceManagement

/// Manages launch at login functionality for the application
public final class LaunchAtLogin {
    /// Shared singleton instance
    public static let shared = LaunchAtLogin()

    /// Notification sent when launch at login status changes
    public static let statusChangedNotification = Notification.Name("LaunchAtLoginStatusChanged")

    /// Bundle identifier for the launcher application
    private let launcherAppIdentifier = "com.jumper.LauncherApp"

    /// UserDefaults instance for storing settings
    private let userDefaults = UserDefaults.standard

    /// Key for storing launch at login status in UserDefaults
    private let statusKey = "LaunchAtLoginStatus"

    /// Private initializer to enforce singleton pattern
    private init() {
        // Initialize the cached status if it doesn't exist
        if userDefaults.object(forKey: statusKey) == nil {
            userDefaults.set(checkActualStatus(), forKey: statusKey)
        }
    }

    /// Checks the actual system launch at login status
    /// - Returns: Boolean indicating if launch at login is enabled
    private func checkActualStatus() -> Bool {
        if #available(macOS 13.0, *) {
            // Use the modern API on macOS 13 and later
            return SMAppService.mainApp.status == .enabled
        } else {
            // Fallback for older macOS versions
            let jobs = SMCopyAllJobDictionaries(kSMDomainUserLaunchd).takeRetainedValue() as? [[String: AnyObject]] ?? []
            return jobs.contains { ($0["Label"] as? String) == launcherAppIdentifier }
        }
    }

    /// Checks if launch at login is enabled
    /// - Returns: Boolean indicating if launch at login is enabled
    public func isEnabled() -> Bool {
        return userDefaults.bool(forKey: statusKey)
    }

    /// Enables or disables launch at login
    /// - Parameter enabled: Boolean indicating whether to enable or disable launch at login
    public func setEnabled(_ enabled: Bool) {
        // Update the system setting on a background thread to avoid blocking the UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            if #available(macOS 13.0, *) {
                // Use the modern API on macOS 13 and later
                do {
                    if enabled {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }

                    // Update the cached value on success
                    self.updateCachedStatus(enabled)
                } catch {
                    print("Error setting launch at login: \(error)")
                }
            } else {
                // Fallback for older macOS versions
                SMLoginItemSetEnabled(self.launcherAppIdentifier as CFString, enabled)

                // Update the cached value
                self.updateCachedStatus(enabled)
            }
        }
    }

    /// Updates the cached status and notifies observers
    /// - Parameter enabled: The new status to cache
    private func updateCachedStatus(_ enabled: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.userDefaults.set(enabled, forKey: self.statusKey)
            NotificationCenter.default.post(name: LaunchAtLogin.statusChangedNotification, object: nil)
        }
    }

    /// Forces a refresh of the launch at login status from the system
    public func refreshStatus() {
        // Check the actual system status
        let status = checkActualStatus()

        // Update the cached value and notify observers
        updateCachedStatus(status)
    }
}
