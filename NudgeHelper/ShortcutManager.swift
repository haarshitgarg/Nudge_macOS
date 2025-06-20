//
//  ShortcutManager.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 20/06/25.
//

import Foundation
import ApplicationServices
import os

class ShortcutManager {
    private let log = OSLog(subsystem: "com.harshitgarg.NudgeHelper", category: "ShortcutManager")
    static let shared = ShortcutManager()
    
    private init() {}
    
    public func isTrusted() -> Bool {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            os_log("Process is not trusted for accessibility.", log: OSLog.default, type: .error)
            DispatchQueue.main.async {
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                let _ = AXIsProcessTrustedWithOptions(options)
            }
        }
        else{
            os_log("Process is trusted for accessibility.", log: OSLog.default, type: .info)
        }
        return trusted
    }
        
}


