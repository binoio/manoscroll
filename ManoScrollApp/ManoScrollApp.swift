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
    var settingsWindow: NSWindow?
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
            button.image = NSImage(systemSymbolName: tracking ? "hand.raised.fill" : "hand.raised", accessibilityDescription: "ManoScroll")
        }
    }
    
    @objc func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 600),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.title = "ManoScroll Settings"
            settingsWindow?.contentView = NSHostingView(rootView: settingsView)
            settingsWindow?.center()
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func quit() {
        handTracker?.stopTracking()
        NSApplication.shared.terminate(nil)
    }
}
