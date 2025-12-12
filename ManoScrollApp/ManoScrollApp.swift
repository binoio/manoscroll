import SwiftUI
import AVFoundation

@main
struct ManoScrollApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var handTracker: HandTracker?
    var settingsWindowController: SettingsWindowController?
    private let settings = AppSettings.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
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
                menu.addItem(NSMenuItem(title: "Start Tracking", action: #selector(startTracking), keyEquivalent: "s"))
                menu.addItem(NSMenuItem(title: "Stop Tracking", action: #selector(stopTracking), keyEquivalent: "x"))
                menu.addItem(NSMenuItem.separator())
                menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
                menu.addItem(NSMenuItem.separator())
                menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
                
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
    
    @objc func quit() {
        handTracker?.stopTracking()
        NSApplication.shared.terminate(nil)
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
        window?.center()
        window?.makeKeyAndOrderFront(sender)
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
