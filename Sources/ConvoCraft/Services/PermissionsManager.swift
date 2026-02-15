import SwiftUI
import Speech
import AVFoundation

#if canImport(ScreenCaptureKit)
import ScreenCaptureKit
#endif

@MainActor
@Observable
class PermissionsManager {
    var speechAuthStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    var microphoneGranted = false
    var screenRecordingGranted = false
    var siriDictationEnabled = false
    var isCheckingPermissions = false
    
    var allPermissionsGranted: Bool {
        speechAuthStatus == .authorized && microphoneGranted && siriDictationEnabled && screenRecordingGranted
    }
    
    func checkPermissions() async {
        logInfo("🔍 PermissionsManager: Checking permissions...")
        isCheckingPermissions = true
        
        // Check speech recognition (don't request, just check status)
        await MainActor.run {
            speechAuthStatus = SFSpeechRecognizer.authorizationStatus()
            logInfo("Speech recognition status: \(speechAuthStatus.rawValue)")
        }
        
        // Check microphone (check current authorization status without requesting)
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        await MainActor.run {
            microphoneGranted = micStatus == .authorized
            logInfo("Microphone status: \(micStatus.rawValue), granted=\(microphoneGranted)")
        }
        
        // Check Siri & Dictation
        let siriStatus = await checkSiriDictationEnabled()
        await MainActor.run {
            siriDictationEnabled = siriStatus
            logInfo("Siri & Dictation enabled: \(siriStatus)")
        }
        
        // Check screen recording (ScreenCaptureKit permission)
        let screenStatus = await checkScreenRecordingPermission()
        await MainActor.run {
            screenRecordingGranted = screenStatus
            logInfo("Screen recording granted: \(screenStatus)")
            isCheckingPermissions = false
        }
        
        if speechAuthStatus == .authorized && microphoneGranted && siriDictationEnabled && screenRecordingGranted {
            logSuccess("✅ All permissions already granted!")
        } else {
            logWarning("⚠️ Some permissions missing")
        }
    }
    
    func checkMicrophonePermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        return status == .authorized
    }
    
    func requestAllPermissions() async {
        await requestSpeechRecognition()
        await requestMicrophone()
        await openSiriDictationSettings()
        await requestScreenRecording()
    }
    
    func requestSpeechRecognition() async {
        logInfo("🎬 Requesting Speech Recognition permission...")
        await MainActor.run {
            isCheckingPermissions = true
        }
        
        let newStatus = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { @Sendable status in
                continuation.resume(returning: status)
            }
        }
        
        await MainActor.run {
            speechAuthStatus = newStatus
            logInfo("Speech Recognition result: \(newStatus.rawValue)")
            if newStatus == .authorized {
                logSuccess("✅ Speech Recognition authorized!")
            } else {
                logError("❌ Speech Recognition denied or restricted")
            }
            isCheckingPermissions = false
        }
    }
    
    func requestMicrophone() async {
        logInfo("🎤 Requesting Microphone permission...")
        await MainActor.run {
            isCheckingPermissions = true
        }
        
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        
        await MainActor.run {
            microphoneGranted = granted
            logInfo("Microphone result: \(granted)")
            if granted {
                logSuccess("✅ Microphone authorized!")
            } else {
                logError("❌ Microphone denied")
            }
            isCheckingPermissions = false
        }
    }
    
    func requestScreenRecording() async {
        logInfo("📺 Requesting Screen Recording permission...")
        await MainActor.run {
            isCheckingPermissions = true
        }
        
        #if canImport(ScreenCaptureKit)
        guard #available(macOS 12.3, *) else {
            await MainActor.run {
                screenRecordingGranted = false
                isCheckingPermissions = false
            }
            return
        }
        
        do {
            let _ = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            await MainActor.run {
                screenRecordingGranted = true
                isCheckingPermissions = false
            }
        } catch {
            await MainActor.run {
                screenRecordingGranted = false
                isCheckingPermissions = false
                showScreenRecordingAlert()
            }
        }
        #else
        await MainActor.run {
            screenRecordingGranted = false
            isCheckingPermissions = false
        }
        #endif
    }
    
    func checkSiriDictationEnabled() async -> Bool {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) else {
            return false
        }
        return recognizer.isAvailable
    }
    
    func openSiriDictationSettings() async {
        logInfo("📢 Opening Siri & Dictation settings...")
        
        let isEnabled = await checkSiriDictationEnabled()
        
        await MainActor.run {
            siriDictationEnabled = isEnabled
            
            if !isEnabled {
                let alert = NSAlert()
                alert.messageText = "Siri & Dictation Required"
                alert.informativeText = "ConvoCraft requires Siri & Dictation to be enabled for speech recognition to work.\n\nPlease enable 'Dictation' in System Settings > Siri & Spotlight, then click 'Check Again' to verify."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "Check Again")
                alert.addButton(withTitle: "Later")
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Siri-Settings.extension")!)
                } else if response == .alertSecondButtonReturn {
                    Task {
                        await checkPermissions()
                    }
                }
            } else {
                logSuccess("✅ Siri & Dictation is already enabled")
            }
        }
    }
    
    func checkScreenRecordingPermission() async -> Bool {
        #if canImport(ScreenCaptureKit)
        guard #available(macOS 12.3, *) else {
            return false
        }
        
        do {
            let _ = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }
    
    @MainActor
    func showScreenRecordingAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "ConvoCraft needs Screen Recording permission to capture system audio. Please grant permission in System Settings > Privacy & Security > Screen Recording, then restart the app."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
        }
    }
}