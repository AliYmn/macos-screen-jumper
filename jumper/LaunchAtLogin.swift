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
    
    private let launcherAppIdentifier = "com.jumper.LauncherApp"
    
    private init() {}
    
    public func isEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            // For older macOS versions
            let jobs = SMCopyAllJobDictionaries(kSMDomainUserLaunchd).takeRetainedValue() as? [[String: AnyObject]] ?? []
            return jobs.contains { ($0["Label"] as? String) == launcherAppIdentifier }
        }
    }
    
    public func setEnabled(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Error setting launch at login: \(error)")
            }
        } else {
            // For older macOS versions
            // Directly use the SMLoginItemSetEnabled API
            if enabled {
                SMLoginItemSetEnabled(launcherAppIdentifier as CFString, true)
            } else {
                SMLoginItemSetEnabled(launcherAppIdentifier as CFString, false)
            }
        }
    }
}
