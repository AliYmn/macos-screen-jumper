//
//  LaunchAtLogin.swift
//  jumper
//
//  Created for Jumper app
//

import Foundation
import ServiceManagement

public class LaunchAtLogin {
    public static let shared = LaunchAtLogin()
    
    // Notification name for launch at login status change
    public static let statusChangedNotification = Notification.Name("LaunchAtLoginStatusChanged")
    
    private let launcherAppIdentifier = "com.jumper.LauncherApp"
    private let userDefaults = UserDefaults.standard
    private let statusKey = "LaunchAtLoginStatus"
    
    private init() {
        // Initialize the cached status
        if userDefaults.object(forKey: statusKey) == nil {
            userDefaults.set(checkActualStatus(), forKey: statusKey)
        }
    }
    
    // Check the actual system status
    private func checkActualStatus() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            // For older macOS versions
            let jobs = SMCopyAllJobDictionaries(kSMDomainUserLaunchd).takeRetainedValue() as? [[String: AnyObject]] ?? []
            return jobs.contains { ($0["Label"] as? String) == launcherAppIdentifier }
        }
    }
    
    public func isEnabled() -> Bool {
        return userDefaults.bool(forKey: statusKey)
    }
    
    public func setEnabled(_ enabled: Bool) {
        // Update the system setting
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            if #available(macOS 13.0, *) {
                do {
                    if enabled {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                    
                    // Update the cached value on success
                    DispatchQueue.main.async { [self] in
                        userDefaults.set(enabled, forKey: statusKey)
                        NotificationCenter.default.post(name: LaunchAtLogin.statusChangedNotification, object: nil)
                    }
                } catch {
                    print("Error setting launch at login: \(error)")
                }
            } else {
                // For older macOS versions
                SMLoginItemSetEnabled(launcherAppIdentifier as CFString, enabled)
                
                // Update the cached value
                DispatchQueue.main.async { [self] in
                    userDefaults.set(enabled, forKey: statusKey)
                    NotificationCenter.default.post(name: LaunchAtLogin.statusChangedNotification, object: nil)
                }
            }
        }
    }
    
    // Force refresh the status from system
    public func refreshStatus() {
        let status = checkActualStatus()
        userDefaults.set(status, forKey: statusKey)
        NotificationCenter.default.post(name: LaunchAtLogin.statusChangedNotification, object: nil)
    }
}
