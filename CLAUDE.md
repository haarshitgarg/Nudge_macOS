# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Nudge is a macOS application that guides users through various tasks or locations on their macOS system. It's built using SwiftUI and provides a chat interface accessible through a floating panel.

## Build Commands

- **Build the project**: Open in Xcode or use `xcodebuild`
- **Run tests**: `xcodebuild test -scheme Nudge_macOS`
- **Run UI tests**: `xcodebuild test -scheme Nudge_macOSUITests`

## Architecture

The application follows a multi-component architecture:

### Main App (Nudge_macOS)
- **Entry point**: `Nudge_macOSApp.swift` - MenuBar app with floating panel
- **Main view model**: `ChatViewModel` - Singleton that manages the entire app state
- **UI**: SwiftUI-based floating panel with chat interface
- **XPC communication**: Communicates with helper services via NSXPCConnection

### XPC Services
1. **NudgeHelper**: Handles keyboard shortcuts and system-level operations
2. **NavigationMCPClient**: MCP (Model Context Protocol) client for AI navigation features

### Key Components

#### ChatViewModel (`Nudge_macOS/ViewModels/ChatViewModel.swift`)
- Singleton pattern with `shared` instance
- Manages XPC clients: `NudgeClient` and `NudgeNavClient`
- Handles floating panel lifecycle and chat messages
- Manages keyboard shortcuts via `ShortcutManager`

#### XPC Architecture
- **NudgeClient**: Connects to `NudgeHelper` XPC service
- **NudgeNavClient**: Connects to `NavigationMCPClient` XPC service
- Uses protocols for bidirectional communication

#### Dependencies
- **MCP Swift SDK**: For Model Context Protocol integration
- **OpenAI**: For AI functionality in NavigationMCPClient
- **SwiftUI**: For the user interface

## Development Notes

### XPC Services
- Both XPC services are embedded in the main app bundle
- Services use shared protocols for communication
- Error handling uses `NudgeError` custom error types

### UI Pattern
- MenuBar extra application (no dock icon)
- Floating panel shows/hides on demand
- Chat interface with loading animations
- Accessibility permissions handling for keyboard shortcuts

### Logging
- Uses `os.log` throughout with consistent subsystem: "Harshit.Nudge"
- Different categories for different components

### Bundle Identifiers
- Main app: `Harshit.Nudge-macOS`
- NudgeHelper: `Harshit.NudgeHelper` 
- NavigationMCPClient: `Harshit.NavigationMCPClient`