import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var permissionsManager = PermissionsManager()
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
            
            Divider()
            
            // Permissions Section
            Section {
                VStack(alignment: .leading, spacing: 20) {
                    PermissionRow(
                        icon: "waveform",
                        title: "Speech Recognition",
                        description: "Required for real-time transcription",
                        status: permissionsManager.speechAuthStatus == .authorized,
                        action: permissionsManager.requestSpeechRecognition
                    )
                    
                    PermissionRow(
                        icon: "mic.fill",
                        title: "Microphone Access",
                        description: "Required to capture meeting audio",
                        status: permissionsManager.microphoneGranted,
                        action: permissionsManager.requestMicrophone
                    )
                    
                    PermissionRow(
                        icon: "speaker.wave.2.fill",
                        title: "Siri & Dictation",
                        description: "Must be enabled in System Settings",
                        status: permissionsManager.siriDictationEnabled,
                        action: permissionsManager.openSiriDictationSettings
                    )
                    
                    PermissionRow(
                        icon: "rectangle.on.rectangle",
                        title: "Screen Recording",
                        description: "Required to capture system audio from meetings",
                        status: permissionsManager.screenRecordingGranted,
                        action: permissionsManager.requestScreenRecording
                    )
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
            } header: {
                Text("Permissions")
                    .font(.headline)
            }
            
            Spacer()
            
            // Status message
            HStack {
                if permissionsManager.isCheckingPermissions {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Checking permissions...")
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 20)
        }
        .padding(30)
        .frame(width: 600, height: 500)
        .task {
            await permissionsManager.checkPermissions()
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
                HStack(spacing: 8) {
                    Image(systemName: status ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(status ? .green : .orange)
                        .font(.title3)
                    
                    if !status {
                        Button(action: {
                            Task {
                                isRequesting = true
                                await action()
                                isRequesting = false
                            }
                        }) {
                            Text("Request")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    SettingsView()
}