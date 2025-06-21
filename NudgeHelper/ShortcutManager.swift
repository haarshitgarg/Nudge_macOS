//
//  ShortcutManager.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 20/06/25.
//

import Foundation
import ApplicationServices
import Carbon
import os

class ShortcutManager {
    private let log = OSLog(subsystem: "com.harshitgarg.NudgeHelper", category: "ShortcutManager")
    static let shared = ShortcutManager()
    
    // Option + L shortcut
    private let kChatShortcutID: UInt32 = 1
    private let kChatShortcutKeyCode: UInt32 = 37 // L key
    private let kChatShortcutModifiers: UInt32 = UInt32(optionKey)
    private var eventHotKey: EventHotKeyRef?
    
    private init() {
        registerForGlobalEvent()
    }
    
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
    
    private func registerForGlobalEvent() {
        if !self.isTrusted() {
            os_log("Cannot register global shortcut without accessibility permissions.", log: log, type: .error)
            return
        }
        
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(kChatShortcutID)
        hotKeyID.id = kChatShortcutID
        
        let status = RegisterEventHotKey(
            kChatShortcutKeyCode,
            kChatShortcutModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &eventHotKey
        )
        
        if status == noErr {
            os_log("Global shortcut registered: Option+L", log: log, type: .info)
            
            // Install event handler
            var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
            var handlerRef: EventHandlerRef?
            let _ = InstallEventHandler(
                GetApplicationEventTarget(),
                { (nextHandler, theEvent, userData) -> OSStatus in
                    return ShortcutManager.handleHotKeyEvent(nextHandler, theEvent, userData)
                },
                1,
                &eventSpec,
                Unmanaged.passUnretained(self).toOpaque(),
                &handlerRef
            )
        } else {
            os_log("Failed to register global shortcut. Status: %d", log: log, type: .error, status)
        }
    }
    
    static func handleHotKeyEvent(_ nextHandler: EventHandlerCallRef?, _ theEvent: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
        os_log("Handling hotkey event", log: OSLog.default, type: .debug)
        guard let userData = userData else { return OSStatus(eventNotHandledErr) }
        
        let shortcutManager = Unmanaged<ShortcutManager>.fromOpaque(userData).takeUnretainedValue()
        
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
        
        if status == noErr && hotKeyID.id == shortcutManager.kChatShortcutID {
            DispatchQueue.main.async {
                os_log("Chat shortcut pressed", log: shortcutManager.log, type: .debug)
            }
            return noErr
        }
        
        return OSStatus(eventNotHandledErr)
    }
        
    private func unregisterGlobalShortcuts() {
        os_log("Unregistering global shortcuts", log: log, type: .debug)
        if let hotKey = eventHotKey {
            UnregisterEventHotKey(hotKey)
            eventHotKey = nil
            os_log("Global shortcuts unregistered", log: log, type: .info)
        }
    }
    
    deinit {
        unregisterGlobalShortcuts()
    }
}


