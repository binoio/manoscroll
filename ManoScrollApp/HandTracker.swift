import Foundation
import Vision
import AVFoundation
import AppKit
import CoreGraphics
import ApplicationServices
import SwiftUI

// Protocol for accessibility checking - allows mocking in tests
protocol AccessibilityChecker {
    func isProcessTrusted() -> Bool
    func promptForTrust()
}

// Default implementation using system APIs
class SystemAccessibilityChecker: AccessibilityChecker {
    func isProcessTrusted() -> Bool {
        return AXIsProcessTrusted()
    }
    
    func promptForTrust() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}

// Protocol for scroll event posting - allows mocking in tests
protocol ScrollEventPoster {
    func postScroll(amount: Int32, units: CGScrollEventUnit)
}

// Default implementation using CGEvent
class SystemScrollEventPoster: ScrollEventPoster {
    func postScroll(amount: Int32, units: CGScrollEventUnit) {
        if let scrollEvent = CGEvent(scrollWheelEvent2Source: nil,
                                      units: units,
                                      wheelCount: 1,
                                      wheel1: amount,
                                      wheel2: 0,
                                      wheel3: 0) {
            scrollEvent.post(tap: .cghidEventTap)
        }
    }
}

// Scroll direction for visual indicator
enum ScrollDirection {
    case none
    case up
    case down
}

class HandTracker: NSObject, ObservableObject {
    private(set) var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var handPoseRequest: VNDetectHumanHandPoseRequest?
    private var previewWindowController: NSWindowController?
    
    // Public accessor for preview window
    var previewWindow: NSWindow? {
        return previewWindowController?.window
    }
    
    private var smoothedScroll: Double = 0.0
    private var isTracking = false
    
    // Published properties for UI updates
    @Published var isHandDetected: Bool = false
    @Published var currentScrollDirection: ScrollDirection = .none
    @Published var fingersExtendedCount: Int = 0
    
    // Public accessor for tracking state
    var isCurrentlyTracking: Bool {
        return isTracking
    }
    private var gestureStartTime: Date?
    private(set) var hasPromptedForAccessibility = false
    
    private let settings = AppSettings.shared
    
    // Injectable dependencies for testing
    var accessibilityChecker: AccessibilityChecker = SystemAccessibilityChecker()
    var scrollEventPoster: ScrollEventPoster = SystemScrollEventPoster()
    
    override init() {
        super.init()
        setupHandPoseRequest()
    }
    
    private func setupHandPoseRequest() {
        handPoseRequest = VNDetectHumanHandPoseRequest()
        handPoseRequest?.maximumHandCount = 2
    }
    
    func startTracking() {
        guard !isTracking else { return }
        isTracking = true
        
        setupCaptureSession()
        
        DispatchQueue.main.async {
            if self.settings.showPreviewWindow {
                self.showPreviewWindow()
            }
        }
        
        captureSession?.startRunning()
        print("Hand tracking started")
    }
    
    func stopTracking() {
        guard isTracking else { return }
        isTracking = false
        
        // Hide preview window first, before stopping capture session
        // Do this synchronously on main thread to avoid race conditions
        if Thread.isMainThread {
            cleanupPreviewWindow()
        } else {
            DispatchQueue.main.sync {
                self.cleanupPreviewWindow()
            }
        }
        
        captureSession?.stopRunning()
        captureSession = nil
        videoOutput = nil
        
        print("Hand tracking stopped")
    }
    
    private func cleanupPreviewWindow() {
        // Close and release the window controller
        previewWindowController?.close()
        previewWindowController = nil
    }
    
    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .medium
        
        guard let device = AVCaptureDevice.default(for: .video) else {
            print("No video device available")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession?.canAddInput(input) == true {
                captureSession?.addInput(input)
            }
        } catch {
            print("Error setting up camera input: \(error)")
            return
        }
        
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput?.setSampleBufferDelegate(self, queue: DispatchQueue(label: "handTracking"))
        videoOutput?.alwaysDiscardsLateVideoFrames = true
        
        if captureSession?.canAddOutput(videoOutput!) == true {
            captureSession?.addOutput(videoOutput!)
        }
    }
    
    private func showPreviewWindow() {
        guard previewWindowController == nil, let session = captureSession else { return }
        
        // Keep a strong reference to the window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Hand Tracking Preview"
        window.minSize = NSSize(width: 240, height: 180)
        window.level = .normal  // Default to normal; Always on Top toggle controls this
        window.collectionBehavior = [.canJoinAllSpaces]
        window.isReleasedWhenClosed = false
        window.delegate = self
        
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
        let overlayView = NSHostingView(rootView: HandTrackerOverlay(tracker: self))
        overlayView.frame = containerView.bounds
        overlayView.autoresizingMask = [.width, .height]
        // Make overlay background transparent
        overlayView.layer?.backgroundColor = .clear
        
        containerView.addSubview(overlayView)
        
        window.contentView = containerView
        window.center()
        
        // Use NSWindowController to manage window lifecycle
        let controller = NSWindowController(window: window)
        controller.showWindow(nil)
        previewWindowController = controller
    }
    
    private func processHandPose(_ observation: VNHumanHandPoseObservation) {
        do {
            // Get all finger tip and MCP joint points
            let thumbTip = try observation.recognizedPoint(.thumbTip)
            let thumbCMC = try observation.recognizedPoint(.thumbCMC)
            let indexTip = try observation.recognizedPoint(.indexTip)
            let indexMCP = try observation.recognizedPoint(.indexMCP)
            let middleTip = try observation.recognizedPoint(.middleTip)
            let middleMCP = try observation.recognizedPoint(.middleMCP)
            let ringTip = try observation.recognizedPoint(.ringTip)
            let ringMCP = try observation.recognizedPoint(.ringMCP)
            let littleTip = try observation.recognizedPoint(.littleTip)
            let littleMCP = try observation.recognizedPoint(.littleMCP)
            
            // Count extended fingers
            var fingersExtended = 0
            let minConfidence = Float(settings.detectionConfidence)
            
            // Update hand detection state on main thread
            DispatchQueue.main.async {
                self.isHandDetected = true
            }
            
            // Check thumb (compare X position - direction depends on hand)
            if thumbTip.confidence > minConfidence &&
               thumbCMC.confidence > minConfidence {
                // Left hand mode inverts the thumb X comparison
                let thumbExtended = settings.leftHandMode ?
                    thumbTip.location.x > thumbCMC.location.x :
                    thumbTip.location.x < thumbCMC.location.x
                if thumbExtended {
                    fingersExtended += 1
                }
            }
            
            // Check other fingers (tip Y > MCP Y means extended, Vision coordinates are flipped)
            let fingerPairs = [
                (indexTip, indexMCP),
                (middleTip, middleMCP),
                (ringTip, ringMCP),
                (littleTip, littleMCP)
            ]
            
            for (tip, mcp) in fingerPairs {
                if tip.confidence > minConfidence &&
                   mcp.confidence > minConfidence {
                    if tip.location.y > mcp.location.y {
                        fingersExtended += 1
                    }
                }
            }
            
            // Determine scroll direction using configurable thresholds
            var targetScroll: Double = 0.0
            var scrollDir: ScrollDirection = .none
            
            if fingersExtended >= settings.openPalmThreshold {
                // Open palm - scroll up
                targetScroll = settings.scrollSpeed
                scrollDir = .up
            } else if fingersExtended <= settings.fistThreshold {
                // Closed fist - scroll down
                targetScroll = -settings.scrollSpeed
                scrollDir = .down
            }
            
            // Update published properties on main thread
            let finalFingersCount = fingersExtended
            DispatchQueue.main.async {
                self.fingersExtendedCount = finalFingersCount
                self.currentScrollDirection = scrollDir
            }
            
            // Apply dead zone
            if abs(targetScroll) < settings.deadZone {
                targetScroll = 0.0
            }
            
            // Apply acceleration if enabled
            if settings.accelerationEnabled && abs(targetScroll) > 0 {
                let holdTime = Date().timeIntervalSince(gestureStartTime ?? Date())
                if holdTime > 0.5 {
                    let accel = 1.0 + ((holdTime - 0.5) * (settings.accelerationFactor - 1.0) / 2.0)
                    targetScroll *= min(accel, settings.accelerationFactor)
                }
                if gestureStartTime == nil && targetScroll != 0 {
                    gestureStartTime = Date()
                }
            } else if targetScroll == 0 {
                gestureStartTime = nil
            }
            
            // Apply inversion if enabled
            if settings.invertScroll {
                targetScroll = -targetScroll
            }
            
            // Apply smoothing
            smoothedScroll = (settings.smoothingFactor * targetScroll) + 
                           ((1 - settings.smoothingFactor) * smoothedScroll)
            
            // Trigger scroll if above threshold
            if abs(smoothedScroll) > settings.scrollThreshold {
                performScroll(Int32(smoothedScroll))
            }
            
        } catch {
            // Hand pose points not available, decay scroll
            smoothedScroll *= settings.decayRate
            gestureStartTime = nil
            DispatchQueue.main.async {
                self.isHandDetected = false
                self.currentScrollDirection = .none
            }
        }
    }
    
    func performScroll(_ amount: Int32) {
        // Check accessibility permission first
        let trusted = accessibilityChecker.isProcessTrusted()
        if !trusted {
            if !hasPromptedForAccessibility {
                hasPromptedForAccessibility = true
                DispatchQueue.main.async {
                    self.accessibilityChecker.promptForTrust()
                }
            }
            return
        }
        
        // Create and post scroll event using configured scroll mode
        let units: CGScrollEventUnit = settings.scrollMode == .pixel ? .pixel : .line
        scrollEventPoster.postScroll(amount: amount, units: units)
    }
}

extension HandTracker: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isTracking,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let request = handPoseRequest else { return }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        do {
            try handler.perform([request])
            
            if let results = request.results, let firstHand = results.first {
                processHandPose(firstHand)
            } else {
                // No hand detected, decay scroll
                smoothedScroll *= settings.decayRate
                gestureStartTime = nil
                DispatchQueue.main.async {
                    self.isHandDetected = false
                    self.currentScrollDirection = .none
                }
            }
        } catch {
            print("Hand pose detection error: \(error)")
        }
    }
}

extension HandTracker: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // When user closes the preview window, clear our reference
        previewWindowController = nil
    }
}

// MARK: - Hand Tracker Overlay View

struct HandTrackerOverlay: View {
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
