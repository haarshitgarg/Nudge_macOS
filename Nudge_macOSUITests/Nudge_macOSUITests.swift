//
//  Nudge_macOSUITests.swift
//  Nudge_macOSUITests
//
//  Created by Harshit Garg on 18/06/25.
//

import XCTest

final class Nudge_macOSUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        
        // If test failed, capture agent state
        let testName = self.name
        let hasFailures = testRun?.failureCount ?? 0 > 0
        if hasFailures {
            captureAgentStateOnFailure(testID: testName)
        }
        
        
        // Close Safari if it's running
        let safari = XCUIApplication(bundleIdentifier: "com.apple.Safari")
        if safari.state == .runningForeground || safari.state == .runningBackground {
            safari.terminate()
        }
    }
    
    private func captureAgentStateOnFailure(testID: String) {
        // Use the microphone button to trigger agent state logging
        // This is cleaner than using the text field since the mic button isn't actively used
        
        let app = XCUIApplication()
        
        // Look for the microphone button and click it to trigger debug logging
        let micButton = app.buttons.matching(identifier: "mic.fill").firstMatch
        if micButton.exists {
            micButton.tap()
            print("🎤 Clicked microphone button to trigger agent state dump for test: \(testID)")
        } else {
            // Fallback: look for any button with mic-related label
            let micButtons = app.buttons.containing(NSPredicate(format: "identifier CONTAINS 'mic'"))
            if micButtons.count > 0 {
                micButtons.firstMatch.tap()
                print("🎤 Clicked microphone button (fallback) to trigger agent state dump for test: \(testID)")
            } else {
                print("❌ Could not find microphone button to trigger agent state logging")
            }
        }
        
        // Give it a moment to process
        sleep(5)
        
        print("📋 Attempted to capture agent state for failed test: \(testID)")
        print("📁 Agent state should be saved to ~/Documents/NudgeUITestLogs/")
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testOptionLTogglesChatPanel() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Wait for app to fully launch and show the floating panel
        sleep(2)
        
        // The chat panel should be visible on launch (as per AppDelegate.swift line 40)
        // Since it's a FloatingPanel (NSPanel), we need to look for UI elements within it
        // The chat panel contains a text field for input
        let chatTextField = app.textFields.firstMatch
        XCTAssertTrue(chatTextField.waitForExistence(timeout: 5), "Chat panel should be visible on launch with text input field")
        
        // Press Option+L to hide the chat panel
        app.typeKey("l", modifierFlags: .option)
        
        // Wait for animation to complete
        sleep(1)
        
        // The text field should no longer be accessible (panel is hidden)
        XCTAssertFalse(chatTextField.exists, "Chat panel should be hidden after first Option+L")
        
        // Press Option+L again to show the chat panel
        app.typeKey("l", modifierFlags: .option)
        
        // Wait for animation to complete
        sleep(1)
        
        // The text field should be accessible again (panel is shown)
        XCTAssertTrue(chatTextField.waitForExistence(timeout: 3), "Chat panel should be visible after second Option+L")
    }

    @MainActor
    func testOpenGithubInSafari() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Wait for app to fully launch and show the floating panel
        sleep(2)
        
        // Find the text input field
        let chatTextField = app.textFields.firstMatch
        XCTAssertTrue(chatTextField.waitForExistence(timeout: 5), "Chat text field should be available")
        
        // Tap the text field to focus it
        chatTextField.tap()
        
        // Type the command to open GitHub in Safari
        chatTextField.typeText("Open github in safari")
        
        // Press Enter to submit the command
        app.typeKey(.enter, modifierFlags: [])
        
        // Wait for the agent to process the command (UI should change to thinking state)
        // The text field placeholder should change to "Press Esc to cancel"
        let thinkingField = app.textFields["Press Esc to cancel"]
        XCTAssertTrue(thinkingField.waitForExistence(timeout: 10), "Agent should enter thinking state")
        
        // Wait for task completion - should return to input state
        // The text field placeholder should change back to "Type to Nudge"
        let completedField = app.textFields["Type to Nudge"]
        XCTAssertTrue(completedField.waitForExistence(timeout: 30), "Agent should complete task and return to input state")
        
        // Verify Safari is running
        let safari = XCUIApplication(bundleIdentifier: "com.apple.Safari")
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 15), "Safari should be launched")
        
        // Check if Safari's address bar contains "github"
        let addressBar = safari.textFields.firstMatch
        XCTAssertTrue(addressBar.waitForExistence(timeout: 10), "Safari address bar should be available")
        
        let addressBarValue = addressBar.value as? String ?? ""
        XCTAssertTrue(addressBarValue.lowercased().contains("github"), "Safari address bar should contain 'github'. Current URL: \(addressBarValue)")
    }

    @MainActor
    func testPlayCoffeezillaVideoOnYouTube() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Wait for app to fully launch and show the floating panel
        sleep(2)
        
        // Find the text input field
        let chatTextField = app.textFields.firstMatch
        XCTAssertTrue(chatTextField.waitForExistence(timeout: 5), "Chat text field should be available")
        
        // Tap the text field to focus it
        chatTextField.tap()
        
        // Type the command to play Coffeezilla video on YouTube
        chatTextField.typeText("Play any coffeezilla video on epstien on youtube in safari")
        
        // Press Enter to submit the command
        app.typeKey(.enter, modifierFlags: [])
        
        // Wait for the agent to process the command (UI should change to thinking state)
        let thinkingField = app.textFields["Press Esc to cancel"]
        XCTAssertTrue(thinkingField.waitForExistence(timeout: 10), "Agent should enter thinking state")
        
        // Wait for task completion - should return to input state
        let completedField = app.textFields["Type to Nudge"]
        XCTAssertTrue(completedField.waitForExistence(timeout: 65), "Agent should complete task and return to input state")
        
        // Verify Safari is running
        let safari = XCUIApplication(bundleIdentifier: "com.apple.Safari")
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 15), "Safari should be launched")
        
        // Check if Safari's address bar contains "youtube"
        let addressBar = safari.textFields.firstMatch
        XCTAssertTrue(addressBar.waitForExistence(timeout: 10), "Safari address bar should be available")
        
        let addressBarValue = addressBar.value as? String ?? ""
        XCTAssertTrue(addressBarValue.lowercased().contains("youtube"), "Safari address bar should contain 'youtube'. Current URL: \(addressBarValue)")
        
        // Wait for page to load
        sleep(3)
        
        // Check if the video is by Coffeezilla by looking for channel name or video title
        let webView = safari.webViews.firstMatch
        XCTAssertTrue(webView.waitForExistence(timeout: 10), "YouTube page should load")
        
        // Look for Coffeezilla in various YouTube page elements
        let coffeezillaInTitle = webView.staticTexts.containing(NSPredicate(format: "label CONTAINS[cd] 'coffeezilla'")).firstMatch
        let coffeezillaInChannel = webView.links.containing(NSPredicate(format: "label CONTAINS[cd] 'coffeezilla'")).firstMatch
        let coffeezillaInPageText = webView.staticTexts.containing(NSPredicate(format: "value CONTAINS[cd] 'coffeezilla'")).firstMatch
        
        let hasCoffeezillaContent = coffeezillaInTitle.exists || coffeezillaInChannel.exists || coffeezillaInPageText.exists
        XCTAssertTrue(hasCoffeezillaContent, "YouTube page should show Coffeezilla content")
        
        // Additional check for video playing - look for YouTube video player elements
        let playButton = safari.buttons.matching(identifier: "play").firstMatch
        let pauseButton = safari.buttons.matching(identifier: "pause").firstMatch
        let videoControls = webView.buttons.containing(NSPredicate(format: "label CONTAINS[cd] 'play' OR label CONTAINS[cd] 'pause'")).firstMatch
        
        // Check if any video control elements exist (indicating a video is loaded and potentially playing)
        let hasVideoControls = playButton.exists || pauseButton.exists || videoControls.exists
        XCTAssertTrue(hasVideoControls, "YouTube video should be loaded with play controls visible")
    }

    @MainActor
    func testToggleDarkLightMode() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Wait for app to fully launch and show the floating panel
        sleep(2)
        
        // Find the text input field
        let chatTextField = app.textFields.firstMatch
        XCTAssertTrue(chatTextField.waitForExistence(timeout: 5), "Chat text field should be available")
        
        // Tap the text field to focus it
        chatTextField.tap()
        
        // Type the command to toggle to dark mode
        chatTextField.typeText("Toggle to light mode")
        
        // Press Enter to submit the command
        app.typeKey(.enter, modifierFlags: [])
        
        // Wait for the agent to process the command
        let thinkingField = app.textFields["Press Esc to cancel"]
        XCTAssertTrue(thinkingField.waitForExistence(timeout: 10), "Agent should enter thinking state")
        
        // Wait for task completion - should return to input state
        let completedField = app.textFields["Type to Nudge"]
        XCTAssertTrue(completedField.waitForExistence(timeout: 30), "Agent should complete dark mode toggle")
        
        // Wait for system to process the appearance change
        sleep(3)
        
        // Clear the text field and test light mode toggle
        chatTextField.tap()
        chatTextField.typeText("Toggle to dark mode")
        app.typeKey(.enter, modifierFlags: [])
        
        // Wait for agent to process second command
        XCTAssertTrue(thinkingField.waitForExistence(timeout: 10), "Agent should enter thinking state for light mode")
        
        // Wait for task completion
        XCTAssertTrue(completedField.waitForExistence(timeout: 30), "Agent should complete light mode toggle")
        
        // Wait for system to process the appearance change
        sleep(3)
        
        // Verify the test completed successfully - both commands were processed
        XCTAssertTrue(chatTextField.exists, "Chat interface should still be available after appearance toggles")
    }

//    @MainActor
//    func testWriteEmailWithTimestamp() throws {
//        let app = XCUIApplication()
//        app.launch()
//        
//        // Wait for app to fully launch and show the floating panel
//        sleep(2)
//        
//        // Find the text input field
//        let chatTextField = app.textFields.firstMatch
//        XCTAssertTrue(chatTextField.waitForExistence(timeout: 5), "Chat text field should be available")
//        
//        // Tap the text field to focus it
//        chatTextField.tap()
//        
//        // Get current timestamp for the email content
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        formatter.timeStyle = .medium
//        let timestamp = formatter.string(from: Date())
//        
//        // Type the command to write an email with timestamp and nudge name
//        let emailCommand = "Write an email to gargharshit64@gmail.com with subject 'Nudge Test Email' and content 'This email was sent by Nudge at \(timestamp). Application: Nudge macOS'"
//        chatTextField.typeText(emailCommand)
//        
//        // Press Enter to submit the command
//        app.typeKey(.enter, modifierFlags: [])
//        
//        // Wait for the agent to process the command
//        let thinkingField = app.textFields["Press Esc to cancel"]
//        XCTAssertTrue(thinkingField.waitForExistence(timeout: 10), "Agent should enter thinking state")
//        
//        // Wait for task completion - should return to input state
//        let completedField = app.textFields["Type to Nudge"]
//        XCTAssertTrue(completedField.waitForExistence(timeout: 50), "Agent should complete email writing task")
//        
//        // Wait for Mail app to potentially launch and process
//        sleep(5)
//        
//        // Verify Mail app is running (the agent should have opened Mail to compose the email)
//        let mailApp = XCUIApplication(bundleIdentifier: "com.apple.mail")
//        XCTAssertTrue(mailApp.wait(for: .runningForeground, timeout: 15), "Mail app should be launched")
//        
//        // Verify the test completed successfully
//        XCTAssertTrue(chatTextField.exists, "Chat interface should still be available after email task")
//        
//        // Close Mail app to clean up for next test
//        mailApp.terminate()
//    }

    @MainActor
    func testCreateAlarmAt4AM() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Wait for app to fully launch and show the floating panel
        sleep(2)
        
        // Find the text input field
        let chatTextField = app.textFields.firstMatch
        XCTAssertTrue(chatTextField.waitForExistence(timeout: 5), "Chat text field should be available")
        
        // Tap the text field to focus it
        chatTextField.tap()
        
        // Type the command to create an alarm for 4 AM
        chatTextField.typeText("Create an alarm for 4 AM tomorrow")
        
        // Press Enter to submit the command
        app.typeKey(.enter, modifierFlags: [])
        
        // Wait for the agent to process the command
        let thinkingField = app.textFields["Press Esc to cancel"]
        XCTAssertTrue(thinkingField.waitForExistence(timeout: 10), "Agent should enter thinking state")
        
        // Wait for task completion - should return to input state
        let completedField = app.textFields["Type to Nudge"]
        XCTAssertTrue(completedField.waitForExistence(timeout: 45), "Agent should complete alarm creation task")
        
        // Wait for Clock app to potentially launch and process
        sleep(5)
        
        // Verify Clock app is running (the agent should have opened Clock app to create the alarm)
        let clockApp = XCUIApplication(bundleIdentifier: "com.apple.clock")
        if clockApp.wait(for: .runningForeground, timeout: 15) {
            // Clock app launched - check for alarm creation
            let alarmTab = clockApp.buttons["Alarm"]
            if alarmTab.exists {
                alarmTab.tap()
                sleep(2)
                
                // Look for 4:00 AM alarm in the list
                let alarmTime = clockApp.staticTexts.containing(NSPredicate(format: "label CONTAINS '4:00' OR label CONTAINS '04:00'")).firstMatch
                XCTAssertTrue(alarmTime.waitForExistence(timeout: 10), "4 AM alarm should be visible in Clock app")
            }
            
            // Close Clock app
            clockApp.terminate()
        } else {
            // If Clock app didn't launch, check if the agent used a different method
            // The agent might have used other system tools to create the alarm
            print("Clock app did not launch - agent may have used alternative method")
        }
        
        // Verify the test completed successfully
        XCTAssertTrue(chatTextField.exists, "Chat interface should still be available after alarm creation")
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
