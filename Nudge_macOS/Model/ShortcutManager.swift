import Cocoa
import Carbon
import Foundation
import os.log

@MainActor
protocol ShortcutManagerDelegate: AnyObject {
    func shortcutManagerDidNotHaveAccessibilityPermissions()
    func shortcutManagerDidReceiveChatShortcut()
}

class ShortcutManager: NSObject {
    weak var delegate: ShortcutManagerDelegate?
    
    private var eventHotKey: EventHotKeyRef?
    private let log = OSLog(subsystem: "com.harshit.nudge", category: "shortcuts")
    
    // Option + L shortcut
    private let kChatShortcutID: UInt32 = 1
    private let kChatShortcutKeyCode: UInt32 = 37 // L key
    private let kChatShortcutModifiers: UInt32 = UInt32(optionKey)
    
    override init() {
        super.init()
        registerGlobalShortcuts()
    }
    
    deinit {
        unregisterGlobalShortcuts()
    }
    
    private func registerGlobalShortcuts() {
        // Check if we need accessibility permissions first
        guard AXIsProcessTrusted() else {
            os_log("Accessibility permissions required for global shortcuts", log: log, type: .error)
            DispatchQueue.main.async {
                self.delegate?.shortcutManagerDidNotHaveAccessibilityPermissions()
            }
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
    
    private func unregisterGlobalShortcuts() {
        if let hotKey = eventHotKey {
            UnregisterEventHotKey(hotKey)
            eventHotKey = nil
            os_log("Global shortcuts unregistered", log: log, type: .info)
        }
    }
    
    // Carbon event handler
    static func handleHotKeyEvent(_ nextHandler: EventHandlerCallRef?, _ theEvent: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
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
                shortcutManager.delegate?.shortcutManagerDidReceiveChatShortcut()
            }
            return noErr
        }
        
        return OSStatus(eventNotHandledErr)
    }
    
    // Re-register shortcuts after permissions are granted
    func refreshShortcuts() {
        unregisterGlobalShortcuts()
        registerGlobalShortcuts()
    }
} 
