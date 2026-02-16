import SwiftUI
import Speech
import AVFoundation

#if canImport(ScreenCaptureKit)
import ScreenCaptureKit
#endif

struct OnboardingView: View {
    @Binding var isOnboardingComplete: Bool
    @State private var currentStep = 0
    @State private var permissionsManager = PermissionsManager()
    
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
                    status: permissionsManager.speechAuthStatus == .authorized,
                    action: { await permissionsManager.requestSpeechRecognition() }
                )
                
                PermissionRow(
                    icon: "mic.fill",
                    title: "Microphone Access",
                    description: "Required to capture meeting audio",
                    status: permissionsManager.microphoneGranted,
                    action: { await permissionsManager.requestMicrophone() }
                )
                
                PermissionRow(
                    icon: "speaker.wave.2.fill",
                    title: "Siri & Dictation",
                    description: "Must be enabled in System Settings",
                    status: permissionsManager.siriDictationEnabled,
                    action: { await permissionsManager.openSiriDictationSettings() }
                )
                
                PermissionRow(
                    icon: "rectangle.on.rectangle",
                    title: "Screen Recording",
                    description: "Required to capture system audio from meetings",
                    status: permissionsManager.screenRecordingGranted,
                    action: { await permissionsManager.requestScreenRecording() }
                )
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            
            Spacer(minLength: 10)
            
            // Status message - fixed height to prevent layout shifts
            HStack {
                if permissionsManager.isCheckingPermissions {
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
                    if permissionsManager.allPermissionsGranted {
                        isOnboardingComplete = true
                    } else {
                        await permissionsManager.requestAllPermissions()
                    }
                }
            }) {
                Text(permissionsManager.allPermissionsGranted ? "Get Started" : "Grant Permissions")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(permissionsManager.isCheckingPermissions)
            
            // Warning message - fixed height to prevent layout shifts
            Group {
                if !permissionsManager.allPermissionsGranted && (permissionsManager.speechAuthStatus != .notDetermined || permissionsManager.microphoneGranted || permissionsManager.screenRecordingGranted) {
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
            await permissionsManager.checkPermissions()
        }
    }
    
}

#if DEBUG
#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}
#endif
