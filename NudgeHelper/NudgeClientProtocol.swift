//
//  NudgeClientProtocol.swift
//  Nudge_macOS
//
//  Created by Harshit Garg on 20/06/25.
//

import Foundation
import os

@objc public protocol NudgeClientProtocol {
    func notifyShortcutPressed()
    func askForAccessibilityPermission()
}
