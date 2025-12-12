import Foundation
import Vision
import AVFoundation
import AppKit
import CoreGraphics
import ApplicationServices

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

class HandTracker: NSObject, ObservableObject {
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var handPoseRequest: VNDetectHumanHandPoseRequest?
    private var previewWindowController: NSWindowController?
    
    private var smoothedScroll: Double = 0.0
    private var isTracking = false
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
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Hand Tracking Preview"
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isReleasedWhenClosed = false
        window.delegate = self
        
        let previewView = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 240))
        previewView.wantsLayer = true
        
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.frame = previewView.bounds
        layer.videoGravity = .resizeAspectFill
        previewView.layer = layer
        
        window.contentView = previewView
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
            
            if fingersExtended >= settings.openPalmThreshold {
                // Open palm - scroll up
                targetScroll = settings.scrollSpeed
            } else if fingersExtended <= settings.fistThreshold {
                // Closed fist - scroll down
                targetScroll = -settings.scrollSpeed
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
