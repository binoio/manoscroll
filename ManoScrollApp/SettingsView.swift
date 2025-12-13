import SwiftUI

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    @Published var scrollSpeed: Double {
        didSet { UserDefaults.standard.set(scrollSpeed, forKey: "scrollSpeed") }
    }
    @Published var smoothingFactor: Double {
        didSet { UserDefaults.standard.set(smoothingFactor, forKey: "smoothingFactor") }
    }
    @Published var detectionConfidence: Double {
        didSet { UserDefaults.standard.set(detectionConfidence, forKey: "detectionConfidence") }
    }
    @Published var scrollThreshold: Double {
        didSet { UserDefaults.standard.set(scrollThreshold, forKey: "scrollThreshold") }
    }
    @Published var invertScroll: Bool {
        didSet { UserDefaults.standard.set(invertScroll, forKey: "invertScroll") }
    }
    @Published var showPreviewWindow: Bool {
        didSet { UserDefaults.standard.set(showPreviewWindow, forKey: "showPreviewWindow") }
    }
    @Published var decayRate: Double {
        didSet { UserDefaults.standard.set(decayRate, forKey: "decayRate") }
    }
    @Published var openPalmThreshold: Int {
        didSet { UserDefaults.standard.set(openPalmThreshold, forKey: "openPalmThreshold") }
    }
    @Published var fistThreshold: Int {
        didSet { UserDefaults.standard.set(fistThreshold, forKey: "fistThreshold") }
    }
    @Published var leftHandMode: Bool {
        didSet { UserDefaults.standard.set(leftHandMode, forKey: "leftHandMode") }
    }
    @Published var scrollMode: ScrollMode {
        didSet { UserDefaults.standard.set(scrollMode.rawValue, forKey: "scrollMode") }
    }
    @Published var deadZone: Double {
        didSet { UserDefaults.standard.set(deadZone, forKey: "deadZone") }
    }
    @Published var accelerationEnabled: Bool {
        didSet { UserDefaults.standard.set(accelerationEnabled, forKey: "accelerationEnabled") }
    }
    @Published var accelerationFactor: Double {
        didSet { UserDefaults.standard.set(accelerationFactor, forKey: "accelerationFactor") }
    }
    @Published var showInDock: Bool {
        didSet { 
            UserDefaults.standard.set(showInDock, forKey: "showInDock")
            if isInitialized {
                updateAppPresentation()
            }
        }
    }
    @Published var showInMenuBar: Bool {
        didSet { 
            UserDefaults.standard.set(showInMenuBar, forKey: "showInMenuBar")
            if isInitialized {
                updateAppPresentation()
            }
        }
    }
    
    // Overlay settings
    @Published var showOverlay: Bool {
        didSet { UserDefaults.standard.set(showOverlay, forKey: "showOverlay") }
    }
    @Published var showHandDetectionStatus: Bool {
        didSet { UserDefaults.standard.set(showHandDetectionStatus, forKey: "showHandDetectionStatus") }
    }
    @Published var showFingerCount: Bool {
        didSet { UserDefaults.standard.set(showFingerCount, forKey: "showFingerCount") }
    }
    @Published var showScrollDirection: Bool {
        didSet { UserDefaults.standard.set(showScrollDirection, forKey: "showScrollDirection") }
    }
    
    private var isInitialized = false
    
    enum ScrollMode: String, CaseIterable {
        case pixel = "pixel"
        case line = "line"
        
        var displayName: String {
            switch self {
            case .pixel: return "Pixel (Smooth)"
            case .line: return "Line (Stepped)"
            }
        }
    }
    
    fileprivate init() {
        // Load saved settings or use defaults
        self.scrollSpeed = UserDefaults.standard.object(forKey: "scrollSpeed") as? Double ?? 3.0
        self.smoothingFactor = UserDefaults.standard.object(forKey: "smoothingFactor") as? Double ?? 0.3
        self.detectionConfidence = UserDefaults.standard.object(forKey: "detectionConfidence") as? Double ?? 0.5
        self.scrollThreshold = UserDefaults.standard.object(forKey: "scrollThreshold") as? Double ?? 0.3
        self.invertScroll = UserDefaults.standard.object(forKey: "invertScroll") as? Bool ?? false
        self.showPreviewWindow = UserDefaults.standard.object(forKey: "showPreviewWindow") as? Bool ?? true
        self.decayRate = UserDefaults.standard.object(forKey: "decayRate") as? Double ?? 0.8
        self.openPalmThreshold = UserDefaults.standard.object(forKey: "openPalmThreshold") as? Int ?? 4
        self.fistThreshold = UserDefaults.standard.object(forKey: "fistThreshold") as? Int ?? 1
        self.leftHandMode = UserDefaults.standard.object(forKey: "leftHandMode") as? Bool ?? false
        let modeRaw = UserDefaults.standard.string(forKey: "scrollMode") ?? "pixel"
        self.scrollMode = ScrollMode(rawValue: modeRaw) ?? .pixel
        self.deadZone = UserDefaults.standard.object(forKey: "deadZone") as? Double ?? 0.0
        self.accelerationEnabled = UserDefaults.standard.object(forKey: "accelerationEnabled") as? Bool ?? false
        self.accelerationFactor = UserDefaults.standard.object(forKey: "accelerationFactor") as? Double ?? 1.5
        self.showInDock = UserDefaults.standard.object(forKey: "showInDock") as? Bool ?? true
        self.showInMenuBar = UserDefaults.standard.object(forKey: "showInMenuBar") as? Bool ?? true
        
        // Overlay settings
        self.showOverlay = UserDefaults.standard.object(forKey: "showOverlay") as? Bool ?? true
        self.showHandDetectionStatus = UserDefaults.standard.object(forKey: "showHandDetectionStatus") as? Bool ?? true
        self.showFingerCount = UserDefaults.standard.object(forKey: "showFingerCount") as? Bool ?? true
        self.showScrollDirection = UserDefaults.standard.object(forKey: "showScrollDirection") as? Bool ?? true
        
        self.isInitialized = true
    }
    
    func updateAppPresentation() {
        // Ensure at least one is enabled
        if !showInDock && !showInMenuBar {
            showInMenuBar = true
            return
        }
        
        // Update dock visibility
        if showInDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
        
        // Notify observers to update menu bar
        NotificationCenter.default.post(name: NSNotification.Name("UpdateMenuBarVisibility"), object: nil)
    }
}

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    
    var body: some View {
        TabView {
            ScrollControlTab(settings: settings)
                .tabItem {
                    Label("Scroll", systemImage: "arrow.up.arrow.down")
                }
            
            HandDetectionTab(settings: settings)
                .tabItem {
                    Label("Detection", systemImage: "hand.raised")
                }
            
            DisplayAppearanceTab(settings: settings)
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
            
            PermissionsTab(settings: settings)
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }
        }
        .frame(width: 550, height: 550)
        .padding()
    }
}

struct ScrollControlTab: View {
    @ObservedObject var settings: AppSettings
    
    var body: some View {
        ScrollView {
            Form {
                Section {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Scroll Speed")
                            Spacer()
                            Text(String(format: "%.1f", settings.scrollSpeed))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $settings.scrollSpeed, in: 1...20, step: 0.5)
                        Text("Higher values = faster scrolling")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Smoothing Factor")
                            Spacer()
                            Text(String(format: "%.2f", settings.smoothingFactor))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $settings.smoothingFactor, in: 0.1...0.9, step: 0.05)
                        Text("Lower = smoother, Higher = more responsive")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Scroll Threshold")
                            Spacer()
                            Text(String(format: "%.2f", settings.scrollThreshold))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $settings.scrollThreshold, in: 0.1...2.0, step: 0.1)
                        Text("Minimum gesture intensity to trigger scroll")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Decay Rate")
                            Spacer()
                            Text(String(format: "%.2f", settings.decayRate))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $settings.decayRate, in: 0.5...0.99, step: 0.01)
                        Text("How quickly scroll slows when hand not detected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Dead Zone")
                            Spacer()
                            Text(String(format: "%.2f", settings.deadZone))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $settings.deadZone, in: 0...1.0, step: 0.05)
                        Text("Neutral zone where no scroll occurs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Picker("Scroll Mode", selection: $settings.scrollMode) {
                        ForEach(AppSettings.ScrollMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    
                    Toggle("Invert Scroll Direction", isOn: $settings.invertScroll)
                    
                    Toggle("Enable Acceleration", isOn: $settings.accelerationEnabled)
                    
                    if settings.accelerationEnabled {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Acceleration Factor")
                                Spacer()
                                Text(String(format: "%.1f×", settings.accelerationFactor))
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $settings.accelerationFactor, in: 1.0...3.0, step: 0.1)
                            Text("Multiplier for faster gestures")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
    }
}

struct HandDetectionTab: View {
    @ObservedObject var settings: AppSettings
    
    var body: some View {
        ScrollView {
            Form {
                Section {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Detection Confidence")
                            Spacer()
                            Text(String(format: "%.0f%%", settings.detectionConfidence * 100))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $settings.detectionConfidence, in: 0.3...0.9, step: 0.05)
                        Text("Higher = more accurate but may miss some gestures")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Open Palm Threshold")
                            Spacer()
                            Text("\(settings.openPalmThreshold) fingers")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: Binding(
                            get: { Double(settings.openPalmThreshold) },
                            set: { settings.openPalmThreshold = Int($0) }
                        ), in: 3...5, step: 1)
                        Text("Minimum fingers extended to trigger scroll up")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Fist Threshold")
                            Spacer()
                            Text("\(settings.fistThreshold) fingers")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: Binding(
                            get: { Double(settings.fistThreshold) },
                            set: { settings.fistThreshold = Int($0) }
                        ), in: 0...2, step: 1)
                        Text("Maximum fingers extended to trigger scroll down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Toggle("Left Hand Mode", isOn: $settings.leftHandMode)
                    Text("Adjusts thumb detection for left-handed users")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)
        }
    }
}

struct DisplayAppearanceTab: View {
    @ObservedObject var settings: AppSettings
    
    var body: some View {
        Form {
            Section(header: Text("Camera Preview")) {
                Toggle("Show Camera Preview Window", isOn: $settings.showPreviewWindow)
                Text("Display live camera feed when tracking")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("Overlay")) {
                Toggle("Show Overlay", isOn: $settings.showOverlay)
                Text("Display status information on the preview window")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if settings.showOverlay {
                    Toggle("Hand Detection Status", isOn: $settings.showHandDetectionStatus)
                    Toggle("Finger Count", isOn: $settings.showFingerCount)
                    Toggle("Scroll Direction Indicator", isOn: $settings.showScrollDirection)
                }
            }
            
            Section(header: Text("App Visibility")) {
                Toggle("Show in Dock", isOn: $settings.showInDock)
                Toggle("Show in Menu Bar", isOn: $settings.showInMenuBar)
                Text("At least one must be enabled")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct PermissionsTab: View {
    @ObservedObject var settings: AppSettings
    
    var body: some View {
        Form {
            Section(header: Text("Required Permissions")) {
                VStack(alignment: .leading, spacing: 8) {
                    Button("Open Accessibility Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    Text("Required for scroll injection. Add ManoScroll to allowed apps.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Button("Open Camera Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    Text("Required for hand tracking via webcam.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Reset")) {
                Button("Reset All Settings to Defaults") {
                    settings.scrollSpeed = 3.0
                    settings.smoothingFactor = 0.3
                    settings.detectionConfidence = 0.5
                    settings.scrollThreshold = 0.3
                    settings.invertScroll = false
                    settings.showPreviewWindow = true
                    settings.decayRate = 0.8
                    settings.openPalmThreshold = 4
                    settings.fistThreshold = 1
                    settings.leftHandMode = false
                    settings.scrollMode = .pixel
                    settings.deadZone = 0.0
                    settings.accelerationEnabled = false
                    settings.accelerationFactor = 1.5
                    settings.showInDock = true
                    settings.showInMenuBar = true
                    settings.showOverlay = true
                    settings.showHandDetectionStatus = true
                    settings.showFingerCount = true
                    settings.showScrollDirection = true
                }
                .foregroundColor(.red)
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    SettingsView()
}
