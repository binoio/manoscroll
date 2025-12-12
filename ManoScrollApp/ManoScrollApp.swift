import SwiftUI
import AVFoundation

@main
struct ManoScrollApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Minimal WindowGroup that stays hidden - required for SwiftUI app lifecycle
        // but we manage all windows via AppDelegate to maintain menu control
        WindowGroup {
            Color.clear
                .frame(width: 0, height: 0)
                .hidden()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .commandsRemoved()  // Remove all SwiftUI-managed commands
    }
}

// Empty view placeholder - all UI is managed by AppDelegate
private struct EmptyView: View {
    var body: some View {
        Color.clear
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem?
    var handTracker: HandTracker?
    var settingsWindowController: SettingsWindowController?
    var helpWindowController: HelpWindowController?
    var previewWindows: [PreviewWindowController] = []
    private let settings = AppSettings.shared
    private var mainMenu: NSMenu?
    private var menuRestoreTimer: Timer?
    private var hiddenWindow: NSWindow?  // Hidden window to keep menu active
    private var alwaysOnTopEnabled = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create a hidden window to maintain menu bar presence
        createHiddenWindow()
        
        // Set up main menu first
        setupMainMenu()
        
        // Set up menu bar if enabled
        updateMenuBarVisibility()
        
        // Set up dock visibility
        updateDockVisibility()
        
        // Initialize hand tracker
        handTracker = HandTracker()
        
        // Check camera permission
        checkCameraPermission()
        
        // Listen for visibility changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVisibilityChange),
            name: NSNotification.Name("UpdateMenuBarVisibility"),
            object: nil
        )
        
        // Listen for window changes to restore menu
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeMain),
            name: NSWindow.didBecomeMainNotification,
            object: nil
        )
        
        // Listen for window close to restore menu
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose),
            name: NSWindow.willCloseNotification,
            object: nil
        )
        
        // Listen for when windows resign key status (important for when last window closes)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignKey),
            name: NSWindow.didResignKeyNotification,
            object: nil
        )
        
        // Re-apply menu after a delay to override any SwiftUI menu changes at launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.restoreMainMenu()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.restoreMainMenu()
        }
        
        // Also listen for app activation
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppBecameActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func handleAppBecameActive(_ notification: Notification) {
        restoreMainMenuWithDelay()
    }
    
    @objc private func windowDidBecomeKey(_ notification: Notification) {
        // Restore main menu when any window becomes key
        restoreMainMenuWithDelay()
    }
    
    @objc private func windowDidBecomeMain(_ notification: Notification) {
        // Restore main menu when any window becomes main
        restoreMainMenuWithDelay()
    }
    
    @objc private func windowDidResignKey(_ notification: Notification) {
        // When a window resigns key status, schedule a menu restore
        // This helps when the last window closes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.restoreMainMenu()
        }
    }
    
    @objc private func windowWillClose(_ notification: Notification) {
        // Start a timer to persistently restore the menu after window close
        // This combats SwiftUI's tendency to reset the menu after a window closes
        startMenuRestoreTimer()
        
        // Also schedule a check to ensure we have the menu after all windows close
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            // If no windows are key, we still need to restore the menu
            if NSApp.keyWindow == nil {
                self?.restoreMainMenu()
            }
        }
    }
    
    private func startMenuRestoreTimer() {
        // Cancel any existing timer
        menuRestoreTimer?.invalidate()
        
        // Create a timer that restores the menu repeatedly for 3 seconds
        var restoreCount = 0
        menuRestoreTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            self?.restoreMainMenu()
            restoreCount += 1
            if restoreCount >= 30 { // 3 seconds worth of restores
                timer.invalidate()
                self?.menuRestoreTimer = nil
            }
        }
    }
    
    private func restoreMainMenuWithDelay() {
        // Restore immediately
        restoreMainMenu()
        // Also restore after a short delay to override SwiftUI's menu changes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.restoreMainMenu()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.restoreMainMenu()
        }
    }
    
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        
        // Application menu (ManoScroll)
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "About ManoScroll", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit ManoScroll", action: #selector(quit), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        // File menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.autoenablesItems = true
        let newPreviewItem = NSMenuItem(title: "New Hand Tracking Preview", action: #selector(newPreviewWindow), keyEquivalent: "n")
        newPreviewItem.target = self
        fileMenu.addItem(newPreviewItem)
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)
        
        // Edit menu
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.autoenablesItems = true
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        
        // View menu
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenu.autoenablesItems = false  // We manage enabled state manually
        let alwaysOnTopItem = NSMenuItem(title: "Always on Top", action: #selector(toggleAlwaysOnTop(_:)), keyEquivalent: "t")
        alwaysOnTopItem.keyEquivalentModifierMask = [.command, .shift]
        alwaysOnTopItem.target = self
        viewMenu.addItem(alwaysOnTopItem)
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(NSMenuItem(title: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f"))
        viewMenu.delegate = self  // Set delegate to update checkmark state
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)
        
        // Control menu
        let controlMenuItem = NSMenuItem()
        let controlMenu = NSMenu(title: "Control")
        controlMenu.autoenablesItems = true
        let startItem = NSMenuItem(title: "Start Hand Tracking", action: #selector(startTracking), keyEquivalent: "s")
        startItem.target = self
        let stopItem = NSMenuItem(title: "Stop Hand Tracking", action: #selector(stopTracking), keyEquivalent: ".")
        stopItem.target = self
        controlMenu.addItem(startItem)
        controlMenu.addItem(stopItem)
        controlMenuItem.submenu = controlMenu
        mainMenu.addItem(controlMenuItem)
        
        // Window menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.autoenablesItems = true
        windowMenu.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: ""))
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        NSApp.windowsMenu = windowMenu
        
        // Help menu
        let helpMenuItem = NSMenuItem()
        let helpMenu = NSMenu(title: "Help")
        let helpItem = NSMenuItem(title: "ManoScroll Help", action: #selector(showHelp), keyEquivalent: "?")
        helpItem.target = self
        helpMenu.addItem(helpItem)
        helpMenuItem.submenu = helpMenu
        mainMenu.addItem(helpMenuItem)
        NSApp.helpMenu = helpMenu
        
        self.mainMenu = mainMenu
        NSApp.mainMenu = mainMenu
    }
    
    func restoreMainMenu() {
        if let menu = mainMenu {
            NSApp.mainMenu = menu
        }
    }
    
    private func createHiddenWindow() {
        // Create a tiny, invisible window that never appears on screen
        // This keeps the menu bar active even when no visible windows are open
        hiddenWindow = NSWindow(
            contentRect: NSRect(x: -10000, y: -10000, width: 1, height: 1),
            styleMask: [],
            backing: .buffered,
            defer: true
        )
        hiddenWindow?.isReleasedWhenClosed = false
        hiddenWindow?.orderOut(nil)  // Keep it hidden but loaded
        hiddenWindow?.setIsVisible(false)
    }
    
    @objc private func handleVisibilityChange() {
        updateMenuBarVisibility()
        updateDockVisibility()
    }
    
    private func updateDockVisibility() {
        if settings.showInDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    private func updateMenuBarVisibility() {
        if settings.showInMenuBar {
            if statusItem == nil {
                statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                
                if let button = statusItem?.button {
                    button.image = NSImage(systemSymbolName: "hand.raised.fill", accessibilityDescription: "ManoScroll")
                }
                
                let menu = NSMenu()
                menu.addItem(NSMenuItem(title: "Start Hand Tracking", action: #selector(startTracking), keyEquivalent: ""))
                menu.addItem(NSMenuItem(title: "Stop Hand Tracking", action: #selector(stopTracking), keyEquivalent: ""))
                menu.addItem(NSMenuItem.separator())
                menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ""))
                menu.addItem(NSMenuItem.separator())
                menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: ""))
                
                statusItem?.menu = menu
            }
        } else {
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
        }
    }
    
    func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            print("Camera access authorized")
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    print("Camera access granted")
                } else {
                    print("Camera access denied")
                }
            }
        case .denied, .restricted:
            print("Camera access denied or restricted")
            showCameraPermissionAlert()
        @unknown default:
            break
        }
    }
    
    func showCameraPermissionAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Camera Access Required"
            alert.informativeText = "ManoScroll needs camera access to track hand gestures. Please enable it in System Preferences > Privacy & Security > Camera."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Preferences")
            alert.addButton(withTitle: "Cancel")
            
            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
    
    @objc func startTracking() {
        handTracker?.startTracking()
        updateMenuIcon(tracking: true)
    }
    
    @objc func stopTracking() {
        handTracker?.stopTracking()
        updateMenuIcon(tracking: false)
    }
    
    func updateMenuIcon(tracking: Bool) {
        if let button = statusItem?.button {
            // Use distinct icons: spread fingers when tracking, regular hand when idle
            let iconName = tracking ? "hand.raised.fingers.spread" : "hand.raised.fill"
            button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "ManoScroll")
        }
    }
    
    @objc func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func newPreviewWindow() {
        let previewController = PreviewWindowController(handTracker: handTracker)
        previewWindows.append(previewController)
        previewController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func showHelp() {
        if helpWindowController == nil {
            helpWindowController = HelpWindowController()
        }
        helpWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func quit() {
        handTracker?.stopTracking()
        NSApplication.shared.terminate(nil)
    }
    
    @objc func toggleAlwaysOnTop(_ sender: NSMenuItem) {
        alwaysOnTopEnabled.toggle()
        sender.state = alwaysOnTopEnabled ? .on : .off
        
        // Apply to all preview windows
        for controller in previewWindows {
            if let window = controller.window, window.isVisible {
                window.level = alwaysOnTopEnabled ? .floating : .normal
            }
        }
        
        // Also apply to HandTracker's preview window if it exists
        if let previewWindow = handTracker?.previewWindow {
            previewWindow.level = alwaysOnTopEnabled ? .floating : .normal
        }
    }
    
    // NSMenuDelegate - update menu item states before display
    func menuNeedsUpdate(_ menu: NSMenu) {
        // Update Always on Top checkmark
        if let viewMenu = mainMenu?.item(withTitle: "View")?.submenu,
           let alwaysOnTopItem = viewMenu.item(withTitle: "Always on Top") {
            alwaysOnTopItem.state = alwaysOnTopEnabled ? .on : .off
        }
    }
}

// MARK: - Custom Window that preserves main menu

class MenuPreservingWindow: NSWindow {
    override func becomeKey() {
        super.becomeKey()
        // Restore the main menu whenever this window becomes key
        DispatchQueue.main.async {
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.restoreMainMenu()
            }
        }
    }
    
    override func becomeMain() {
        super.becomeMain()
        // Restore the main menu whenever this window becomes main
        DispatchQueue.main.async {
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.restoreMainMenu()
            }
        }
    }
}

// MARK: - Preview Window Controller

class PreviewWindowController: NSWindowController, NSWindowDelegate {
    private var hostingView: NSHostingView<PreviewContentView>?
    private var previewView: NSView?
    private var overlayHostingView: NSHostingView<ScrollIndicatorOverlay>?
    private weak var handTracker: HandTracker?
    
    convenience init(handTracker: HandTracker?) {
        let window = MenuPreservingWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Hand Tracking Preview"
        window.minSize = NSSize(width: 240, height: 180)
        window.center()
        window.isReleasedWhenClosed = false
        
        self.init(window: window)
        self.handTracker = handTracker
        window.delegate = self
        
        // Check if tracking is already active
        if let tracker = handTracker, tracker.isCurrentlyTracking, let session = tracker.captureSession {
            // Show live camera preview immediately
            showCameraPreview(session: session, tracker: tracker)
        } else {
            // Show placeholder with start button
            let contentView = PreviewContentView(onStartTracking: { [weak self] in
                self?.startTracking()
            })
            hostingView = NSHostingView(rootView: contentView)
            window.contentView = hostingView
        }
    }
    
    private func showCameraPreview(session: AVCaptureSession, tracker: HandTracker) {
        guard let window = self.window else { return }
        
        // Create container view
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 360))
        containerView.wantsLayer = true
        containerView.autoresizesSubviews = true
        
        // Camera preview layer
        let cameraView = NSView(frame: containerView.bounds)
        cameraView.wantsLayer = true
        cameraView.autoresizingMask = [.width, .height]
        
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.frame = cameraView.bounds
        layer.videoGravity = .resizeAspectFill
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        cameraView.layer = layer
        cameraView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        
        containerView.addSubview(cameraView)
        
        // Overlay for scroll direction indicator
        let overlayView = NSHostingView(rootView: ScrollIndicatorOverlay(tracker: tracker))
        overlayView.frame = containerView.bounds
        overlayView.autoresizingMask = [.width, .height]
        // Make overlay background transparent
        overlayView.layer?.backgroundColor = .clear
        
        containerView.addSubview(overlayView)
        overlayHostingView = overlayView
        
        window.contentView = containerView
        previewView = containerView
        hostingView = nil
    }
    
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        // Ensure main menu is preserved
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.restoreMainMenu()
        }
    }
    
    // NSWindowDelegate - restore menu when window closes
    func windowWillClose(_ notification: Notification) {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.restoreMainMenu()
        }
    }
    
    private func startTracking() {
        handTracker?.startTracking()
        // Update app delegate menu icon
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.updateMenuIcon(tracking: true)
        }
        // Close this preview window since HandTracker has its own preview
        window?.close()
    }
}

struct PreviewContentView: View {
    let onStartTracking: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("👋")
                .font(.system(size: 80))
            
            Text("Hand Tracking Preview")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("Click the button below to start tracking your hand movements and control scrolling.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Button(action: onStartTracking) {
                HStack {
                    Image(systemName: "hand.raised.fill")
                    Text("Start Hand Tracking")
                }
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }
}

// MARK: - Scroll Indicator Overlay

struct ScrollIndicatorOverlay: View {
    @ObservedObject var tracker: HandTracker
    @ObservedObject private var settings = AppSettings.shared
    
    var body: some View {
        Group {
            if settings.showOverlay {
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        // Scroll direction indicator
                        VStack(spacing: 4) {
                            // Detection status
                            if settings.showHandDetectionStatus {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(tracker.isHandDetected ? Color.green : Color.red)
                                        .frame(width: 10, height: 10)
                                    
                                    Text(tracker.isHandDetected ? "Hand Detected" : "No Hand")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                            }
                            
                            // Fingers count
                            if settings.showFingerCount && tracker.isHandDetected {
                                Text("\(tracker.fingersExtendedCount) fingers")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Scroll direction arrow
                            if settings.showScrollDirection {
                                Group {
                                    switch tracker.currentScrollDirection {
                                    case .up:
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.up.circle.fill")
                                                .font(.title2)
                                                .foregroundColor(.blue)
                                            Text("Scroll Up")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                        }
                                    case .down:
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.down.circle.fill")
                                                .font(.title2)
                                                .foregroundColor(.orange)
                                            Text("Scroll Down")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                        }
                                    case .none:
                                        HStack(spacing: 4) {
                                            Image(systemName: "minus.circle")
                                                .font(.title2)
                                                .foregroundColor(.gray)
                                            Text("Idle")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        .padding(12)
                    }
                }
            }
        }
    }
}

class SettingsWindowController: NSWindowController, NSToolbarDelegate {
    private var selectedTabIndex = 0
    private var hostingView: NSHostingView<SettingsContentView>?
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "ManoScroll Settings"
        window.center()
        window.isReleasedWhenClosed = false
        
        self.init(window: window)
        
        // Set up toolbar
        let toolbar = NSToolbar(identifier: "SettingsToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.allowsUserCustomization = false
        window.toolbar = toolbar
        window.toolbarStyle = .preference
        
        // Set initial selected tab to Scroll
        toolbar.selectedItemIdentifier = .scrollTab
        
        // Set initial content
        updateContent()
    }
    
    private func updateContent() {
        let contentView = SettingsContentView(selectedTab: selectedTabIndex)
        if hostingView == nil {
            hostingView = NSHostingView(rootView: contentView)
            window?.contentView = hostingView
        } else {
            hostingView?.rootView = contentView
        }
    }
    
    override func showWindow(_ sender: Any?) {
        // Reset to Scroll tab when showing window
        selectedTabIndex = 0
        updateContent()
        window?.toolbar?.selectedItemIdentifier = .scrollTab
        window?.center()
        window?.makeKeyAndOrderFront(sender)
        
        // Ensure main menu is preserved
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.restoreMainMenu()
        }
    }
    
    // MARK: - NSToolbarDelegate
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.scrollTab, .detectionTab, .displayTab, .permissionsTab]
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.scrollTab, .detectionTab, .displayTab, .permissionsTab]
    }
    
    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.scrollTab, .detectionTab, .displayTab, .permissionsTab]
    }
    
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        
        switch itemIdentifier {
        case .scrollTab:
            item.label = "Scroll"
            item.image = NSImage(systemSymbolName: "arrow.up.arrow.down", accessibilityDescription: "Scroll")
            item.target = self
            item.action = #selector(selectScrollTab)
        case .detectionTab:
            item.label = "Detection"
            item.image = NSImage(systemSymbolName: "hand.raised", accessibilityDescription: "Detection")
            item.target = self
            item.action = #selector(selectDetectionTab)
        case .displayTab:
            item.label = "Display"
            item.image = NSImage(systemSymbolName: "display", accessibilityDescription: "Display")
            item.target = self
            item.action = #selector(selectDisplayTab)
        case .permissionsTab:
            item.label = "Permissions"
            item.image = NSImage(systemSymbolName: "lock.shield", accessibilityDescription: "Permissions")
            item.target = self
            item.action = #selector(selectPermissionsTab)
        default:
            return nil
        }
        
        return item
    }
    
    @objc private func selectScrollTab() {
        selectedTabIndex = 0
        updateContent()
        window?.toolbar?.selectedItemIdentifier = .scrollTab
    }
    
    @objc private func selectDetectionTab() {
        selectedTabIndex = 1
        updateContent()
        window?.toolbar?.selectedItemIdentifier = .detectionTab
    }
    
    @objc private func selectDisplayTab() {
        selectedTabIndex = 2
        updateContent()
        window?.toolbar?.selectedItemIdentifier = .displayTab
    }
    
    @objc private func selectPermissionsTab() {
        selectedTabIndex = 3
        updateContent()
        window?.toolbar?.selectedItemIdentifier = .permissionsTab
    }
}

extension NSToolbarItem.Identifier {
    static let scrollTab = NSToolbarItem.Identifier("ScrollTab")
    static let detectionTab = NSToolbarItem.Identifier("DetectionTab")
    static let displayTab = NSToolbarItem.Identifier("DisplayTab")
    static let permissionsTab = NSToolbarItem.Identifier("PermissionsTab")
}

struct SettingsContentView: View {
    let selectedTab: Int
    @ObservedObject private var settings = AppSettings.shared
    
    var body: some View {
        Group {
            switch selectedTab {
            case 0:
                ScrollControlTab(settings: settings)
            case 1:
                HandDetectionTab(settings: settings)
            case 2:
                DisplayAppearanceTab(settings: settings)
            case 3:
                PermissionsTab(settings: settings)
            default:
                ScrollControlTab(settings: settings)
            }
        }
        .frame(width: 520, height: 450)
        .padding()
    }
}

// MARK: - Help Window Controller

class HelpWindowController: NSWindowController, NSWindowDelegate {
    convenience init() {
        let window = MenuPreservingWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ManoScroll Help"
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 450, height: 400)
        
        self.init(window: window)
        window.delegate = self
        
        let hostingView = NSHostingView(rootView: HelpContentView())
        window.contentView = hostingView
    }
    
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        // Ensure main menu is preserved
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.restoreMainMenu()
        }
    }
    
    // NSWindowDelegate - restore menu when window closes
    func windowWillClose(_ notification: Notification) {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.restoreMainMenu()
        }
    }
}

struct HelpContentView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    Image(systemName: "hand.raised.fill")
                        .font(.largeTitle)
                        .foregroundColor(.accentColor)
                    Text("ManoScroll Help")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                .padding(.bottom, 8)
                
                Text("ManoScroll lets you control scrolling using hand gestures detected through your camera.")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Divider()
                
                // Troubleshooting Camera
                VStack(alignment: .leading, spacing: 12) {
                    Label("Troubleshooting Camera Permissions", systemImage: "camera.fill")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("ManoScroll requires camera access to detect your hand movements.")
                        .font(.body)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("If the camera isn't working:")
                            .fontWeight(.medium)
                        
                        HelpStep(number: 1, text: "Open System Settings (or System Preferences on older macOS)")
                        HelpStep(number: 2, text: "Go to Privacy & Security → Camera")
                        HelpStep(number: 3, text: "Find ManoScroll in the list and enable the toggle")
                        HelpStep(number: 4, text: "Restart ManoScroll if prompted")
                    }
                    .padding(.leading, 8)
                    
                    Button("Open Camera Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Divider()
                
                // Troubleshooting Accessibility
                VStack(alignment: .leading, spacing: 12) {
                    Label("Troubleshooting Accessibility Permissions", systemImage: "accessibility")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("ManoScroll requires Accessibility access to send scroll events to other applications.")
                        .font(.body)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("If scrolling isn't working in other apps:")
                            .fontWeight(.medium)
                        
                        HelpStep(number: 1, text: "Open System Settings (or System Preferences on older macOS)")
                        HelpStep(number: 2, text: "Go to Privacy & Security → Accessibility")
                        HelpStep(number: 3, text: "Click the + button and add ManoScroll")
                        HelpStep(number: 4, text: "Enable the toggle next to ManoScroll")
                        HelpStep(number: 5, text: "If ManoScroll is already listed, try removing and re-adding it")
                    }
                    .padding(.leading, 8)
                    
                    Button("Open Accessibility Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Divider()
                
                // Tips
                VStack(alignment: .leading, spacing: 12) {
                    Label("Tips for Best Results", systemImage: "lightbulb.fill")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        TipRow(icon: "sun.max", text: "Ensure good lighting so the camera can clearly see your hand")
                        TipRow(icon: "hand.raised", text: "Keep your hand clearly visible in the camera frame")
                        TipRow(icon: "arrow.up.arrow.down", text: "Move your hand up or down smoothly to scroll")
                        TipRow(icon: "gearshape", text: "Adjust sensitivity in Settings if scrolling is too fast or slow")
                        TipRow(icon: "rectangle.on.rectangle", text: "The preview window shows what the camera sees")
                    }
                }
                
                Spacer()
            }
            .padding(24)
        }
    }
}

struct HelpStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .fontWeight(.medium)
                .foregroundColor(.accentColor)
                .frame(width: 20, alignment: .trailing)
            Text(text)
        }
    }
}

struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            Text(text)
        }
    }
}
