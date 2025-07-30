# Nudge for macOS

A sophisticated AI-powered navigation assistant that guides users through macOS interfaces using natural language. Nudge lives in your menu bar and provides an intelligent floating chat panel to help you navigate and interact with any macOS application.

[![Watch the demo](https://img.youtube.com/vi/F6bio6s9JWs/0.jpg)](https://youtu.be/F6bio6s9JWs)

## Features

### 🤖 AI-Powered Navigation
- **Natural Language Interface**: Describe what you want to do in plain English
- **UI Element Detection**: Automatically finds and interacts with interface elements

### 🎯 Smart Interface
- **MenuBar Integration**: Unobtrusive menu bar application
- **Floating Chat Panel**: Beautiful, always-on-top chat interface
- **Global Shortcuts**: Quick access via `Option+L` keyboard shortcut
- **Modern SwiftUI Design**: Material effects and smooth animations


### 🔧 System Integration
- **Accessibility Framework**: Deep macOS integration for UI automation
- **Model Context Protocol (MCP)**: Extensible tool integration system
- **Cross-Application Support**: Works with any macOS application

![Chat Interface](screenshots/chat-interface.png)

## Installation

### Prerequisites
- macOS 15.5 or later
- Xcode 16.4+ (for development)
- OpenAI API key

### Setup
1. Clone the repository:
   ```bash
   git clone https://github.com/haarshitgarg/Nudge_macOS.git
   cd Nudge_macOS
   ```

2. Open in Xcode:
   ```bash
   open Nudge_macOS.xcodeproj
   ```

3. Configure your OpenAI API key in `NavigationMCPClient/ServerConfigs/Secrets.swift`

4. Build and run the project in Xcode

### Permissions
The app requires accessibility permissions to interact with macOS interfaces:
1. Go to **System Preferences** → **Security & Privacy** → **Privacy**
2. Select **Accessibility** from the left sidebar
3. Add Nudge to the list of allowed applications

## Usage

### Basic Navigation
1. Click the Nudge icon in your menu bar or press `Option+L`
2. Type your request in natural language:
   - "Open Safari and navigate to GitHub"
   - "Find the network settings in System Preferences"
   - "Create a new document in Pages"
3. Watch as Nudge guides you through the interface

## Architecture

### Core Components

```
Nudge_macOS/
├── Main App (Nudge_macOS)           # MenuBar app with chat interface
└── NavigationMCPClient (XPC Service) # AI navigation engine
```

### Technology Stack
- **SwiftUI**: Modern declarative UI framework
- **XPC Services**: Secure inter-process communication
- **Accessibility Framework**: macOS UI automation
- **OpenAI GPT**: Large language model integration
- **Model Context Protocol**: Extensible tool system

## Development

### Build Commands
```bash
# Build the project
xcodebuild -scheme Nudge_macOS build

# Run tests
xcodebuild test -scheme Nudge_macOS

# Run UI tests
xcodebuild test -scheme Nudge_macOSUITests
```

### Dependencies
The project uses Swift Package Manager for dependency management:
- **MCP Swift SDK** (v0.9.0) - Model Context Protocol implementation
- **OpenAI** (v0.4.3) - AI model integration
- **NudgeLibrary** (v2.0.0) - Custom navigation tools

## Contributing

1. Create a feature branch (`git checkout -b feature/amazing-feature`)
2. Commit your changes (`git commit -m 'Add amazing feature'`)
3. Push to the branch (`git push origin feature/amazing-feature`)
4. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

**Note**: This application requires accessibility permissions and an OpenAI API key to function properly. Please ensure you have configured both before using the application.
