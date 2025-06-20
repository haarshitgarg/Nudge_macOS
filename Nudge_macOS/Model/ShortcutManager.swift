//
//  ShortcutManager.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 20/06/25.
//

import Foundation
import os

public protocol ShortcutManagerDelegateProtocol {
    func userRequestedToggleChat()
}

class ShortcutManager: ObservableObject {
    public static let shared: ShortcutManager = ShortcutManager()
    private var delegates: [UUID: ShortcutManagerDelegateProtocol] = [:]
    
    private let log = OSLog(subsystem: "com.harshitgarg.nudge", category: "ShortcutManager")
    
    private init() {
    }
    
    public func addDelegate(_ delegate: ShortcutManagerDelegateProtocol) -> UUID {
        let delegateID = UUID()
        delegates[delegateID] = delegate
        os_log("Added delegate: %@", log: log, type: .info, String(describing: delegate))
        return delegateID
    }
    
    public func removeDelegate(_ delegateID: UUID) {
        if let removedDelegate = delegates.removeValue(forKey: delegateID) {
            os_log("Removed delegate: %@", log: log, type: .info, String(describing: removedDelegate))
        } else {
            os_log("No delegate found for ID: %@", log: log, type: .error, delegateID.uuidString)
        }
    }
}
