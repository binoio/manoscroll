import SwiftUI
import AVFoundation
import AppKit

// MARK: - App State

/// Centralized state management for the app, replacing AppDelegate state
@MainActor
class AppState: ObservableObject {
    @Published var handTracker: HandTracker
    @Published var isTracking: Bool = false
    @Published var alwaysOnTopEnabled: Bool = false

    let settings = AppSettings.shared

    // Keep a strong reference to the preview window so it stays open
    private(set) var previewWindow: NSWindow?

    init() {
        self.handTracker = HandTracker()
        checkCameraPermission()

        // Create and show the hand tracking preview window on launch
        DispatchQueue.main.async {
            let previewView = PreviewWindowView(appState: self)
            let hosting = NSHostingController(rootView: previewView)
            let window = NSWindow(contentViewController: hosting)
            window.title = "Hand Tracking Preview"
            window.setContentSize(NSSize(width: 480, height: 360))
            window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
            window.center()
            window.makeKeyAndOrderFront(nil)
            self.previewWindow = window
        }
    }

    func startTracking() {
        handTracker.startTracking()
        isTracking = true
    }

    func stopTracking() {
        handTracker.stopTracking()
        isTracking = false
    }

    func toggleAlwaysOnTop() {
        alwaysOnTopEnabled.toggle()
    }

    private func checkCameraPermission() {
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
        @unknown default:
            break
        }
    }
}

// MARK: - Main App

@main
struct ManoScrollApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // Menu bar icon
        MenuBarExtra {
            MenuBarContentView(appState: appState, openWindow: openWindow)
        } label: {
            Image(systemName: appState.isTracking ? "hand.raised.fingers.spread" : "hand.raised.fill")
        }
        .menuBarExtraStyle(.menu)

        // Settings window
        Settings {
            SettingsWindowView()
        }

        // Preview window - opens automatically on launch (WindowGroup opens by default)
        WindowGroup("Hand Tracking Preview", id: "preview") {
            PreviewWindowView(appState: appState)
        }
        .defaultSize(width: 480, height: 360)
        .windowResizability(.contentMinSize)
        .handlesExternalEvents(matching: Set(arrayLiteral: "preview"))

        // Help window
        Window("ManoScroll Help", id: "help") {
            HelpContentView()
        }
        .defaultSize(width: 550, height: 500)
        .windowResizability(.contentMinSize)
    }
}

// MARK: - Menu Bar Content

struct MenuBarContentView: View {
    @ObservedObject var appState: AppState
    let openWindow: OpenWindowAction

    var body: some View {
        Button("Start Hand Tracking") {
            appState.startTracking()
        }
        .keyboardShortcut("s", modifiers: [])
        .disabled(appState.isTracking)

        Button("Stop Hand Tracking") {
            appState.stopTracking()
        }
        .keyboardShortcut(".", modifiers: [])
        .disabled(!appState.isTracking)

        Divider()

        Button("Show Preview Window") {
            openWindow(id: "preview")
        }
        .keyboardShortcut("p", modifiers: [])

        Divider()

        SettingsLink {
            Text("Settings...")
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button("Quit ManoScroll") {
            appState.stopTracking()
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

// MARK: - Settings Window View

struct SettingsWindowView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ScrollControlTab(settings: settings)
                .tabItem {
                    Label("Scroll", systemImage: "arrow.up.arrow.down")
                }
                .tag(0)

            HandDetectionTab(settings: settings)
                .tabItem {
                    Label("Detection", systemImage: "hand.raised")
                }
                .tag(1)

            DisplayAppearanceTab(settings: settings)
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
                .tag(2)

            CameraTab(settings: settings)
                .tabItem {
                    Label("Camera", systemImage: "camera")
                }
                .tag(3)

            PermissionsTab(settings: settings)
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }
                .tag(4)
        }
        .frame(width: 550, height: 550)
        .padding()
    }
}

// MARK: - Preview Window View

struct PreviewWindowView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Group {
            if appState.isTracking, let session = appState.handTracker.captureSession {
                ZStack {
                    CameraPreviewView(session: session)
                    ScrollIndicatorOverlay(tracker: appState.handTracker)
                }
            } else {
                PreviewContentView(onStartTracking: {
                    appState.startTracking()
                })
            }
        }
        .frame(minWidth: 240, minHeight: 180)
    }
}

// MARK: - Camera Preview (NSViewRepresentable)

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.wantsLayer = true

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer = previewLayer
        view.layerContentsRedrawPolicy = .onSetNeedsDisplay

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let layer = nsView.layer as? AVCaptureVideoPreviewLayer {
            layer.session = session
        }
    }
}

// MARK: - Preview Content View (Placeholder)

struct PreviewContentView: View {
    let onStartTracking: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("\u{1F44B}")
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

// MARK: - Help Content View

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
                        HelpStep(number: 2, text: "Go to Privacy & Security > Camera")
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
                        HelpStep(number: 2, text: "Go to Privacy & Security > Accessibility")
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
        .frame(minWidth: 450, minHeight: 400)
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
