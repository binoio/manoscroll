import XCTest

/// UI Tests for menu visibility consistency
/// These tests verify that File, Edit, and Control menus are restored after window operations
final class MenuConsistencyUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        
        // Give the app time to fully launch
        sleep(1)
    }
    
    override func tearDownWithError() throws {
        app.terminate()
    }
    
    /// Get the current list of menu bar items
    private func getMenuBarItems() -> [String] {
        let menuBar = app.menuBars.firstMatch
        let menuBarItems = menuBar.menuBarItems
        
        var titles: [String] = []
        for i in 0..<menuBarItems.count {
            let item = menuBarItems.element(boundBy: i)
            if item.exists {
                titles.append(item.title)
            }
        }
        return titles
    }
    
    /// Verify essential menus are present
    private func assertEssentialMenusPresent(_ menuTitles: [String], context: String) {
        XCTAssertTrue(menuTitles.contains("File"), 
            "File menu should be present \(context)")
        XCTAssertTrue(menuTitles.contains("Edit"), 
            "Edit menu should be present \(context)")
        XCTAssertTrue(menuTitles.contains("Control"), 
            "Control menu should be present \(context)")
    }
    
    /// Test that menus are present at app launch
    func testMenusPresentAtLaunch() throws {
        let menuTitles = getMenuBarItems()
        assertEssentialMenusPresent(menuTitles, context: "at app launch")
    }

    /// Test that "Close" menu item is disabled when there are no open windows
    func testCloseMenuDisabledWhenNoWindows() throws {
        // Close any existing windows
        for i in 0..<app.windows.count {
            let w = app.windows.element(boundBy: i)
            if w.exists {
                let closeButton = w.buttons[XCUIIdentifierCloseWindow]
                if closeButton.exists {
                    closeButton.click()
                    sleep(1)
                }
            }
        }
        // Wait for menus to update
        sleep(1)

        let fileMenu = app.menuBars.menuBarItems["File"]
        XCTAssertTrue(fileMenu.exists, "File menu should exist")
        fileMenu.click()
        let closeItem = app.menuItems["Close"]
        XCTAssertTrue(closeItem.exists, "Close menu item should exist")
        XCTAssertFalse(closeItem.isEnabled, "Close should be disabled when no windows are open")
    }
    
    /// Test that menus are restored after Settings window is opened and closed
    /// This is the core regression test for the menu disappearance bug
    func testMenusRestoredAfterSettingsWindowClose() throws {
        // Step 1: Get initial menu state
        let initialMenus = getMenuBarItems()
        assertEssentialMenusPresent(initialMenus, context: "before opening Settings")
        
        // Step 2: Open Settings window via ManoScroll menu
        let appMenu = app.menuBars.menuBarItems["ManoScroll"]
        if appMenu.exists {
            appMenu.click()
            let settingsItem = app.menuItems["Settings..."]
            if settingsItem.waitForExistence(timeout: 2) {
                settingsItem.click()
            }
        }
        
        // Wait for Settings window to appear
        sleep(1)
        
        // Step 3: Get menu state while Settings is open
        let menusWhileSettingsOpen = getMenuBarItems()
        // Note: menus may be different while Settings is open - this is acceptable
        
        // Step 4: Close Settings window
        if app.windows["ManoScroll Settings"].exists {
            app.windows["ManoScroll Settings"].buttons[XCUIIdentifierCloseWindow].click()
        }
        
        // Wait for menu restoration
        sleep(2) // Give time for any restoration timers to fire
        
        // Step 5: Get final menu state
        let finalMenus = getMenuBarItems()
        
        // Step 6: Verify menus are restored
        // The final menu state should match the initial state
        XCTAssertEqual(initialMenus, finalMenus,
            "Menus should be restored after Settings window is closed. Initial: \(initialMenus), Final: \(finalMenus)")
    }
    
    /// Test that menus are restored after Hand Tracking Preview window is opened and closed
    func testMenusRestoredAfterPreviewWindowClose() throws {
        // Step 1: Get initial menu state
        let initialMenus = getMenuBarItems()
        assertEssentialMenusPresent(initialMenus, context: "before opening Preview")
        
        // Step 2: Open New Hand Tracking Preview via File menu
        let fileMenu = app.menuBars.menuBarItems["File"]
        if fileMenu.exists {
            fileMenu.click()
            let newPreviewItem = app.menuItems["New Hand Tracking Preview"]
            if newPreviewItem.waitForExistence(timeout: 2) {
                newPreviewItem.click()
            }
        }
        
        // Wait for Preview window to appear
        sleep(1)
        
        // Step 3: Close Preview window
        if app.windows["Hand Tracking Preview"].exists {
            app.windows["Hand Tracking Preview"].buttons[XCUIIdentifierCloseWindow].click()
        }
        
        // Wait for menu restoration
        sleep(2)
        
        // Step 4: Get final menu state
        let finalMenus = getMenuBarItems()
        
        // Step 5: Verify menus are restored
        XCTAssertEqual(initialMenus, finalMenus,
            "Menus should be restored after Preview window is closed. Initial: \(initialMenus), Final: \(finalMenus)")
    }
    
    /// Test that menus are restored after Help window is opened and closed
    func testMenusRestoredAfterHelpWindowClose() throws {
        // Step 1: Get initial menu state
        let initialMenus = getMenuBarItems()
        assertEssentialMenusPresent(initialMenus, context: "before opening Help")
        
        // Step 2: Open Help window via Help menu
        let helpMenu = app.menuBars.menuBarItems["Help"]
        if helpMenu.exists {
            helpMenu.click()
            let helpItem = app.menuItems["ManoScroll Help"]
            if helpItem.waitForExistence(timeout: 2) {
                helpItem.click()
            }
        }
        
        // Wait for Help window to appear
        sleep(1)
        
        // Step 3: Close Help window
        if app.windows["ManoScroll Help"].exists {
            app.windows["ManoScroll Help"].buttons[XCUIIdentifierCloseWindow].click()
        }
        
        // Wait for menu restoration
        sleep(2)
        
        // Step 4: Get final menu state
        let finalMenus = getMenuBarItems()
        
        // Step 5: Verify menus are restored
        XCTAssertEqual(initialMenus, finalMenus,
            "Menus should be restored after Help window is closed. Initial: \(initialMenus), Final: \(finalMenus)")
    }
    
    /// Test multiple window open/close cycles maintain menu consistency
    func testMenusConsistentAfterMultipleWindowCycles() throws {
        let initialMenus = getMenuBarItems()
        assertEssentialMenusPresent(initialMenus, context: "at start")
        
        // Cycle 1: Open and close Settings
        let appMenu = app.menuBars.menuBarItems["ManoScroll"]
        if appMenu.exists {
            appMenu.click()
            app.menuItems["Settings..."].click()
            sleep(1)
            if app.windows["ManoScroll Settings"].exists {
                app.windows["ManoScroll Settings"].buttons[XCUIIdentifierCloseWindow].click()
            }
            sleep(1)
        }
        
        // Cycle 2: Open and close Preview
        let fileMenu = app.menuBars.menuBarItems["File"]
        if fileMenu.exists {
            fileMenu.click()
            app.menuItems["New Hand Tracking Preview"].click()
            sleep(1)
            if app.windows["Hand Tracking Preview"].exists {
                app.windows["Hand Tracking Preview"].buttons[XCUIIdentifierCloseWindow].click()
            }
            sleep(1)
        }
        
        // Wait for final restoration
        sleep(2)
        
        let finalMenus = getMenuBarItems()
        XCTAssertEqual(initialMenus, finalMenus,
            "Menus should be consistent after multiple window cycles")
    }
}
