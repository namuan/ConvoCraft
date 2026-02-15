import SwiftUI
import Speech
import AVFoundation

#if canImport(ScreenCaptureKit)
import ScreenCaptureKit
#endif

struct OnboardingView: View {
    @Binding var isOnboardingComplete: Bool
    @State private var currentStep = 0
    @State private var speechAuthStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @State private var microphoneGranted = false
    @State private var screenRecordingGranted = false
    @State private var siriDictationEnabled = false
    @State private var isCheckingPermissions = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Logo/Icon
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 70))
                .foregroundColor(.blue)
            
            Text("Welcome to ConvoCraft")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("AI-powered meeting transcription and insights")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Divider()
                .padding(.vertical, 10)
            
            // Permission steps
            VStack(alignment: .leading, spacing: 20) {
                PermissionRow(
                    icon: "waveform",
                    title: "Speech Recognition",
                    description: "Required for real-time transcription",
                    status: speechAuthStatus == .authorized,
                    action: requestSpeechRecognition
                )
                
                PermissionRow(
                    icon: "mic.fill",
                    title: "Microphone Access",
                    description: "Required to capture meeting audio",
                    status: microphoneGranted,
                    action: requestMicrophone
                )
                
                PermissionRow(
                    icon: "speaker.wave.2.fill",
                    title: "Siri & Dictation",
                    description: "Must be enabled in System Settings",
                    status: siriDictationEnabled,
                    action: openSiriDictationSettings
                )
                
                PermissionRow(
                    icon: "rectangle.on.rectangle",
                    title: "Screen Recording",
                    description: "Required to capture system audio from meetings",
                    status: screenRecordingGranted,
                    action: requestScreenRecording
                )
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            
            Spacer(minLength: 10)
            
            // Status message - fixed height to prevent layout shifts
            HStack {
                if isCheckingPermissions {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Checking permissions...")
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 20)
            
            // Continue button
            Button(action: {
                Task { @MainActor in
                    if allPermissionsGranted {
                        isOnboardingComplete = true
                    } else {
                        requestAllPermissions()
                    }
                }
            }) {
                Text(allPermissionsGranted ? "Get Started" : "Grant Permissions")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isCheckingPermissions)
            
            // Warning message - fixed height to prevent layout shifts
            Group {
                if !allPermissionsGranted && (speechAuthStatus != .notDetermined || microphoneGranted || screenRecordingGranted) {
                    Text("Some permissions are missing. Please grant all permissions to continue.")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(height: 32)
        }
        .padding(30)
        .padding(.bottom, 30)
        .frame(width: 600, height: 720)
        .task {
            await checkPermissions()
        }
    }
    
    private var allPermissionsGranted: Bool {
        speechAuthStatus == .authorized && microphoneGranted && siriDictationEnabled && screenRecordingGranted
    }
    
    private func checkPermissions() async {
        logInfo("🔍 OnboardingView: Checking permissions...")
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
    
    private func checkMicrophonePermission() async -> Bool {
        // This will return the current status without showing a dialog if already determined
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        return status == .authorized
    }
    
    private func requestAllPermissions() {
        Task { @MainActor in
            // Request permissions in sequence to avoid overwhelming the user
            await requestSpeechRecognition()
            await requestMicrophone()
            await openSiriDictationSettings()
            await requestScreenRecording()
        }
    }
    
    private func requestSpeechRecognition() async {
        logInfo("🎬 Requesting Speech Recognition permission...")
        await MainActor.run {
            isCheckingPermissions = true
        }
        
        let newStatus = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { @Sendable status in
                // This callback runs on a background queue, so we can safely resume
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
    
    private func requestMicrophone() async {
        logInfo("🎤 Requesting Microphone permission...")
        await MainActor.run {
            isCheckingPermissions = true
        }
        
        // AVCaptureDevice.requestAccess is already async and handles isolation properly
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
    
    private func requestScreenRecording() async {
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
        
        // ScreenCaptureKit permission is granted by user in System Settings
        // We need to trigger the permission dialog by attempting to access content
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
            // If error, permission was likely denied
            // Show alert to guide user to System Settings
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
    
    private func checkSiriDictationEnabled() async -> Bool {
        // Check if speech recognizer is available (indicates Siri & Dictation is enabled)
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) else {
            return false
        }
        return recognizer.isAvailable
    }
    
    private func openSiriDictationSettings() async {
        logInfo("📢 Opening Siri & Dictation settings...")
        
        // Check current status
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
                    // Open System Settings
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Siri-Settings.extension")!)
                } else if response == .alertSecondButtonReturn {
                    // Recheck status
                    Task {
                        await checkPermissions()
                    }
                }
            } else {
                logSuccess("✅ Siri & Dictation is already enabled")
            }
        }
    }
    
    private func checkScreenRecordingPermission() async -> Bool {
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
    private func showScreenRecordingAlert() {
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

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let status: Bool
    let action: () async -> Void
    
    @State private var isRequesting = false
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isRequesting {
                ProgressView()
                    .scaleEffect(0.7)
            } else {
                Image(systemName: status ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(status ? .green : .secondary)
                    .font(.title3)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}
