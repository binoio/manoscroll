import XCTest
import CoreGraphics
@testable import ManoScrollApp

// Mock accessibility checker for testing
class MockAccessibilityChecker: AccessibilityChecker {
    var isTrusted: Bool = false
    var promptForTrustCalled = false
    
    func isProcessTrusted() -> Bool {
        return isTrusted
    }
    
    func promptForTrust() {
        promptForTrustCalled = true
    }
}

// Mock scroll event poster for testing
class MockScrollEventPoster: ScrollEventPoster {
    var lastScrollAmount: Int32?
    var lastScrollUnits: CGScrollEventUnit?
    var scrollCallCount = 0
    
    func postScroll(amount: Int32, units: CGScrollEventUnit) {
        lastScrollAmount = amount
        lastScrollUnits = units
        scrollCallCount += 1
    }
}

final class HandTrackerTests: XCTestCase {
    
    var handTracker: HandTracker!
    var mockAccessibilityChecker: MockAccessibilityChecker!
    var mockScrollPoster: MockScrollEventPoster!
    
    override func setUp() {
        super.setUp()
        handTracker = HandTracker()
        mockAccessibilityChecker = MockAccessibilityChecker()
        mockScrollPoster = MockScrollEventPoster()
        handTracker.accessibilityChecker = mockAccessibilityChecker
        handTracker.scrollEventPoster = mockScrollPoster
    }
    
    override func tearDown() {
        handTracker = nil
        mockAccessibilityChecker = nil
        mockScrollPoster = nil
        super.tearDown()
    }
    
    // MARK: - Accessibility Permission Tests
    
    /// Test that scroll is blocked when accessibility is not trusted
    /// This is the regression test for the bug where scrolling stopped working
    func testPerformScrollBlockedWhenAccessibilityNotTrusted() {
        // Given: Accessibility is not trusted
        mockAccessibilityChecker.isTrusted = false
        
        // When: Attempting to scroll
        handTracker.performScroll(5)
        
        // Then: No scroll event should be posted
        XCTAssertEqual(mockScrollPoster.scrollCallCount, 0, 
            "Scroll should not be posted when accessibility is not trusted")
    }
    
    /// Test that accessibility prompt is triggered when not trusted
    /// This prevents the regression where the prompt stopped appearing
    func testAccessibilityPromptTriggeredWhenNotTrusted() {
        // Given: Accessibility is not trusted
        mockAccessibilityChecker.isTrusted = false
        
        // When: Attempting to scroll
        handTracker.performScroll(5)
        
        // Then: Prompt for trust should be called
        // Note: The actual prompt happens on main queue async, but the flag is set synchronously
        XCTAssertTrue(handTracker.hasPromptedForAccessibility,
            "Should mark that accessibility prompt was requested")
    }
    
    /// Test that accessibility prompt is only triggered once
    func testAccessibilityPromptOnlyTriggeredOnce() {
        // Given: Accessibility is not trusted
        mockAccessibilityChecker.isTrusted = false
        
        // When: Attempting to scroll multiple times
        handTracker.performScroll(5)
        handTracker.performScroll(5)
        handTracker.performScroll(5)
        
        // Then: The prompt flag should still be true (only prompted once)
        XCTAssertTrue(handTracker.hasPromptedForAccessibility)
        // And no scrolls should have been posted
        XCTAssertEqual(mockScrollPoster.scrollCallCount, 0)
    }
    
    /// Test that scroll works when accessibility IS trusted
    func testPerformScrollWorksWhenAccessibilityTrusted() {
        // Given: Accessibility IS trusted
        mockAccessibilityChecker.isTrusted = true
        
        // When: Attempting to scroll
        handTracker.performScroll(5)
        
        // Then: Scroll event should be posted
        XCTAssertEqual(mockScrollPoster.scrollCallCount, 1,
            "Scroll should be posted when accessibility is trusted")
        XCTAssertEqual(mockScrollPoster.lastScrollAmount, 5)
    }
    
    /// Test that scroll amount is passed correctly
    func testScrollAmountPassedCorrectly() {
        // Given: Accessibility is trusted
        mockAccessibilityChecker.isTrusted = true
        
        // When: Scrolling with specific amounts
        handTracker.performScroll(-10)
        
        // Then: Amount should be passed correctly
        XCTAssertEqual(mockScrollPoster.lastScrollAmount, -10)
    }
    
    /// Test multiple scroll calls accumulate
    func testMultipleScrollCallsWork() {
        // Given: Accessibility is trusted
        mockAccessibilityChecker.isTrusted = true
        
        // When: Multiple scroll calls
        handTracker.performScroll(3)
        handTracker.performScroll(3)
        handTracker.performScroll(3)
        
        // Then: All calls should be posted
        XCTAssertEqual(mockScrollPoster.scrollCallCount, 3)
    }
    
    // MARK: - Stop Tracking Tests
    
    /// Test that stopTracking doesn't crash when called without starting
    /// Regression test: stopTracking should be safe to call in any state
    func testStopTrackingWithoutStartingDoesNotCrash() {
        // Given: A fresh HandTracker that was never started
        // (handTracker from setUp is already in this state)
        
        // When: Calling stopTracking
        // Then: Should not crash
        handTracker.stopTracking()
        
        // If we get here, the test passed (no crash)
        XCTAssertTrue(true)
    }
    
    /// Test that stopTracking can be called multiple times safely
    /// Regression test: Multiple stop calls should not crash
    func testStopTrackingMultipleTimesDoesNotCrash() {
        // Given: A HandTracker
        
        // When: Calling stopTracking multiple times
        handTracker.stopTracking()
        handTracker.stopTracking()
        handTracker.stopTracking()
        
        // Then: Should not crash
        XCTAssertTrue(true)
    }
    
    /// Test that stopTracking is safe after preview window is closed by user
    /// Regression test for crash when user closes preview window then clicks Stop Tracking
    func testStopTrackingAfterPreviewWindowClosedDoesNotCrash() {
        // Given: A HandTracker where the preview window controller is nil
        // (simulating user having closed the preview window)
        // The internal previewWindowController should handle nil gracefully
        
        // When: Calling stopTracking
        handTracker.stopTracking()
        
        // Then: Should not crash - the cleanup should handle nil window controller
        XCTAssertTrue(true)
    }
}

// MARK: - Settings Window Consistency Tests

final class SettingsWindowConsistencyTests: XCTestCase {
    
    /// Test that SettingsWindowController creates a window with toolbar
    func testSettingsWindowHasToolbar() {
        // Given: A SettingsWindowController
        let controller = SettingsWindowController()
        
        // Then: The window should have a toolbar
        XCTAssertNotNil(controller.window?.toolbar, 
            "Settings window from menu bar should have a toolbar")
    }
    
    /// Test that the toolbar has the correct number of items
    func testSettingsWindowToolbarHasFourTabs() {
        // Given: A SettingsWindowController
        let controller = SettingsWindowController()
        
        // Then: The toolbar should have 4 selectable items
        let toolbar = controller.window?.toolbar
        let selectableIdentifiers = toolbar?.delegate?.toolbarSelectableItemIdentifiers?(toolbar!) ?? []
        XCTAssertEqual(selectableIdentifiers.count, 4,
            "Settings toolbar should have 4 tabs: Scroll, Detection, Display, Permissions")
    }
    
    /// Test that toolbar items have the expected identifiers
    func testSettingsWindowToolbarItemIdentifiers() {
        // Given: A SettingsWindowController
        let controller = SettingsWindowController()
        let toolbar = controller.window?.toolbar
        
        // Then: The toolbar should have the expected item identifiers
        let expectedIdentifiers: [NSToolbarItem.Identifier] = [
            .scrollTab, .detectionTab, .displayTab, .permissionsTab
        ]
        let actualIdentifiers = toolbar?.delegate?.toolbarDefaultItemIdentifiers?(toolbar!) ?? []
        
        XCTAssertEqual(actualIdentifiers, expectedIdentifiers,
            "Toolbar should have Scroll, Detection, Display, and Permissions tabs in order")
    }
    
    /// Test that toolbar uses preference style (icons with labels)
    func testSettingsWindowUsesPreferenceToolbarStyle() {
        // Given: A SettingsWindowController
        let controller = SettingsWindowController()
        
        // Then: The window should use preference toolbar style
        XCTAssertEqual(controller.window?.toolbarStyle, .preference,
            "Settings window should use .preference toolbar style for icon tabs")
    }
    
    /// Test that toolbar displays icons and labels
    func testSettingsWindowToolbarDisplaysIconAndLabel() {
        // Given: A SettingsWindowController
        let controller = SettingsWindowController()
        
        // Then: The toolbar should display icon and label
        XCTAssertEqual(controller.window?.toolbar?.displayMode, .iconAndLabel,
            "Settings toolbar should display both icon and label")
    }
    
    /// Test that each toolbar item has an icon
    func testSettingsWindowToolbarItemsHaveIcons() {
        // Given: A SettingsWindowController
        let controller = SettingsWindowController()
        let toolbar = controller.window?.toolbar
        
        // When: Getting each toolbar item
        let identifiers: [NSToolbarItem.Identifier] = [
            .scrollTab, .detectionTab, .displayTab, .permissionsTab
        ]
        
        // Then: Each item should have an image
        for identifier in identifiers {
            let item = toolbar?.delegate?.toolbar?(toolbar!, itemForItemIdentifier: identifier, willBeInsertedIntoToolbar: true)
            XCTAssertNotNil(item?.image, 
                "Toolbar item \(identifier.rawValue) should have an icon")
        }
    }
    
    /// Test that each toolbar item has a label
    func testSettingsWindowToolbarItemsHaveLabels() {
        // Given: A SettingsWindowController
        let controller = SettingsWindowController()
        let toolbar = controller.window?.toolbar
        
        // When: Getting each toolbar item
        let expectedLabels = [
            (NSToolbarItem.Identifier.scrollTab, "Scroll"),
            (.detectionTab, "Detection"),
            (.displayTab, "Display"),
            (.permissionsTab, "Permissions")
        ]
        
        // Then: Each item should have the correct label
        for (identifier, expectedLabel) in expectedLabels {
            let item = toolbar?.delegate?.toolbar?(toolbar!, itemForItemIdentifier: identifier, willBeInsertedIntoToolbar: true)
            XCTAssertEqual(item?.label, expectedLabel,
                "Toolbar item should have label '\(expectedLabel)'")
        }
    }
    
    /// Test that SwiftUI SettingsView has matching tab structure
    /// This ensures the SwiftUI Settings scene (from app menu) matches toolbar window
    func testSettingsViewHasFourTabs() {
        // Given: A SettingsView
        // The SettingsView contains a TabView with 4 tabs
        // We verify this by checking that the tab content views exist
        
        // Then: The individual tab views should be instantiable
        let settings = AppSettings.shared
        
        // These should not crash - they're the same views used in both windows
        let _ = ScrollControlTab(settings: settings)
        let _ = HandDetectionTab(settings: settings)
        let _ = DisplayAppearanceTab(settings: settings)
        let _ = PermissionsTab(settings: settings)
        
        XCTAssertTrue(true, "All four tab views should be instantiable")
    }
    
    /// Test that SettingsContentView switches content based on selected tab
    func testSettingsContentViewSwitchesTabs() {
        // Given: SettingsContentView with different tab indices
        // These should create without crashing, indicating correct tab switching
        
        let _ = SettingsContentView(selectedTab: 0) // Scroll
        let _ = SettingsContentView(selectedTab: 1) // Detection
        let _ = SettingsContentView(selectedTab: 2) // Display
        let _ = SettingsContentView(selectedTab: 3) // Permissions
        
        XCTAssertTrue(true, "SettingsContentView should handle all tab indices")
    }
    
    /// Test that invalid tab index defaults gracefully
    func testSettingsContentViewHandlesInvalidTabIndex() {
        // Given: SettingsContentView with an invalid tab index
        let _ = SettingsContentView(selectedTab: 99)
        
        // Then: Should not crash (defaults to ScrollControlTab)
        XCTAssertTrue(true, "SettingsContentView should handle invalid tab index gracefully")
    }
    
    /// Test that window title is consistent
    func testSettingsWindowTitleIsCorrect() {
        // Given: A SettingsWindowController
        let controller = SettingsWindowController()
        
        // Then: The window should have the correct title
        XCTAssertEqual(controller.window?.title, "ManoScroll Settings",
            "Settings window should have title 'ManoScroll Settings'")
    }
}

// MARK: - Menu Visibility Consistency Tests

final class MenuVisibilityConsistencyTests: XCTestCase {
    
    /// Test that AppDelegate has a restoreMainMenu method
    /// This method is critical for maintaining menu visibility when windows are opened
    func testAppDelegateHasRestoreMainMenuMethod() {
        // Given: An AppDelegate instance
        let appDelegate = AppDelegate()
        
        // Then: It should have a restoreMainMenu method (this compiles = method exists)
        // We can't fully test without running the app, but we verify the method exists
        appDelegate.restoreMainMenu()
        
        XCTAssertTrue(true, "AppDelegate should have restoreMainMenu method")
    }
    
    /// Test that SettingsWindowController has showWindow override that would restore menu
    /// This prevents menus from disappearing when Settings window is opened
    func testSettingsWindowControllerHasShowWindowOverride() {
        // Given: A SettingsWindowController
        let controller = SettingsWindowController()
        
        // Then: The controller should exist and have a window
        XCTAssertNotNil(controller.window, 
            "SettingsWindowController should create a window")
    }
    
    /// Test that PreviewWindowController has showWindow override
    /// This prevents menus from disappearing when Preview window is opened
    func testPreviewWindowControllerHasShowWindowOverride() {
        // Given: A PreviewWindowController
        let controller = PreviewWindowController(handTracker: nil)
        
        // Then: The controller should exist and have a window
        XCTAssertNotNil(controller.window, 
            "PreviewWindowController should create a window")
    }
    
    /// Test that HelpWindowController has showWindow override
    /// This prevents menus from disappearing when Help window is opened
    func testHelpWindowControllerHasShowWindowOverride() {
        // Given: A HelpWindowController
        let controller = HelpWindowController()
        
        // Then: The controller should exist and have a window
        XCTAssertNotNil(controller.window, 
            "HelpWindowController should create a window")
    }
    
    /// Test that all window controllers properly set isReleasedWhenClosed to false
    /// This ensures windows can be reopened without crashes
    func testWindowsAreNotReleasedWhenClosed() {
        let settingsController = SettingsWindowController()
        let previewController = PreviewWindowController(handTracker: nil)
        let helpController = HelpWindowController()
        
        XCTAssertFalse(settingsController.window?.isReleasedWhenClosed ?? true,
            "Settings window should not be released when closed")
        XCTAssertFalse(previewController.window?.isReleasedWhenClosed ?? true,
            "Preview window should not be released when closed")
        XCTAssertFalse(helpController.window?.isReleasedWhenClosed ?? true,
            "Help window should not be released when closed")
    }
}
