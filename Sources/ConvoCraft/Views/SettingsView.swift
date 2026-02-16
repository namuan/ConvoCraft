import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var permissionsManager = PermissionsManager()
    @State private var selectedTab = 0
    
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
            
            // Tab View
            TabView(selection: $selectedTab) {
                // Permissions Tab
                permissionsContent
                    .tabItem {
                        Label("Permissions", systemImage: "lock.shield")
                    }
                    .tag(0)
                
                // AI Insights Tab
                aiInsightsContent
                    .tabItem {
                        Label("AI Insights", systemImage: "brain")
                    }
                    .tag(1)
            }
            .frame(minHeight: 450, maxHeight: .infinity)
            
            Spacer()
            
            // Status message
            HStack {
                if selectedTab == 0 && permissionsManager.isCheckingPermissions {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Checking permissions...")
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 20)
        }
        .padding(30)
        .frame(minWidth: 700, idealWidth: 800, maxWidth: .infinity, minHeight: 600, idealHeight: 700, maxHeight: .infinity)
        .task {
            await permissionsManager.checkPermissions()
        }
    }
    
    private var permissionsContent: some View {
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
    }
    
    private var aiInsightsContent: some View {
        if #available(macOS 26.0, *) {
            return AnyView(AIPromptConfigurationView())
        } else {
            return AnyView(
                VStack(spacing: 20) {
                    Text("AI Insights Configuration")
                        .font(.headline)
                    Text("This feature is available on macOS 26.0 or newer.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            )
        }
    }
}

@available(macOS 26.0, *)
struct AIPromptConfigurationView: View {
    @State private var customPrompt: String = FoundationModelsService.defaultInsightPrompt
    @State private var isResetting = false
    @State private var showResetConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Prompt Editor
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("AI Insight Generation Prompt")
                        .font(.headline)
                    
                    TextEditor(text: $customPrompt)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 250)
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                        .border(Color.gray.opacity(0.3), width: 1)
                    
                    // Validation Status
                    HStack {
                        if customPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Prompt cannot be empty")
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else if customPrompt.contains("json") == false {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Prompt should include JSON response format instructions")
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Prompt is valid")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
            }
            
            // Action Buttons
            HStack(spacing: 15) {
                Button(action: {
                    showResetConfirmation = true
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset to Default")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
                }
                .buttonStyle(.borderless)
                .disabled(isResetting)
                
                Spacer()
                
                Button(action: {
                    savePrompt()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                .buttonStyle(.borderless)
                .disabled(customPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            // Instructions
            Text("This prompt guides the AI in analyzing meeting discussions and generating insights. The response format should include a JSON array of insights with 'type' and 'content' fields.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .task {
            loadCurrentPrompt()
        }
        .alert("Reset to Default", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                Task {
                    await resetToDefault()
                }
            }
        } message: {
            Text("Are you sure you want to reset the prompt to the original default? Your current custom prompt will be lost.")
        }
    }
    
    private func loadCurrentPrompt() {
        customPrompt = FoundationModelsService().insightPrompt
    }
    
    private func savePrompt() {
        FoundationModelsService().insightPrompt = customPrompt
    }
    
    @MainActor
    private func resetToDefault() async {
        isResetting = true
        FoundationModelsService().resetInsightPromptToDefault()
        customPrompt = FoundationModelsService.defaultInsightPrompt
        isResetting = false
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

#if DEBUG
#Preview {
    SettingsView()
}
#endif