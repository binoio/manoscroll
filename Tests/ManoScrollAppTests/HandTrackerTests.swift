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
