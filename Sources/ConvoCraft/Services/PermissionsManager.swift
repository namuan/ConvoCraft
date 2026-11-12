import AVFoundation
import Speech
import SwiftUI

@MainActor
@Observable
class PermissionsManager {
    var speechAuthStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    var microphoneGranted = false
    var systemAudioGranted = false
    var siriDictationEnabled = false
    var isCheckingPermissions = false

    var allPermissionsGranted: Bool {
        speechAuthStatus == .authorized && microphoneGranted && siriDictationEnabled && systemAudioGranted
    }

    func checkPermissions() async {
        isCheckingPermissions = true
        speechAuthStatus = SFSpeechRecognizer.authorizationStatus()
        microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        siriDictationEnabled = await checkSiriDictationEnabled()
        systemAudioGranted = UserDefaults.standard.bool(forKey: "systemAudioPermissionGranted")
        isCheckingPermissions = false
    }

    func checkMicrophonePermission() async -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    func requestAllPermissions() async {
        await requestSpeechRecognition()
        await requestMicrophone()
        await openSiriDictationSettings()
        await requestSystemAudio()
    }

    func requestSpeechRecognition() async {
        isCheckingPermissions = true
        speechAuthStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        isCheckingPermissions = false
    }

    func requestMicrophone() async {
        isCheckingPermissions = true
        microphoneGranted = await AVCaptureDevice.requestAccess(for: .audio)
        isCheckingPermissions = false
    }

    func requestSystemAudio() async {
        isCheckingPermissions = true
        do {
            try AudioCaptureManager.checkSystemAudioPermission()
            systemAudioGranted = true
            UserDefaults.standard.set(true, forKey: "systemAudioPermissionGranted")
        } catch {
            systemAudioGranted = false
            UserDefaults.standard.set(false, forKey: "systemAudioPermissionGranted")
            logError("System audio permission or capture failed: \(error.localizedDescription)")
            let alert = NSAlert()
            alert.messageText = "System Audio Recording Unavailable"
            alert.informativeText = "Allow ConvoCraft under System Settings > Privacy & Security > Screen & System Audio Recording, then try again. \(error.localizedDescription)"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
        isCheckingPermissions = false
    }

    func checkSiriDictationEnabled() async -> Bool {
        SFSpeechRecognizer(locale: Locale(identifier: "en-US"))?.isAvailable == true
    }

    func openSiriDictationSettings() async {
        siriDictationEnabled = await checkSiriDictationEnabled()
        guard !siriDictationEnabled else { return }
        let alert = NSAlert()
        alert.messageText = "Siri & Dictation Required"
        alert.informativeText = "ConvoCraft requires Siri & Dictation to be enabled for speech recognition to work. Please enable Dictation in System Settings, then check again."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Check Again")
        alert.addButton(withTitle: "Later")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Siri-Settings.extension")!)
        } else if response == .alertSecondButtonReturn {
            siriDictationEnabled = await checkSiriDictationEnabled()
        }
    }
}
