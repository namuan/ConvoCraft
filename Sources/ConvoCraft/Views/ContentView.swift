import SwiftUI

struct ContentView: View {
    @State private var controller = MeetingSessionController()
    @State private var selectedTab = 0
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    
    var body: some View {
        if !onboardingComplete {
            OnboardingView(isOnboardingComplete: $onboardingComplete)
        } else {
        TabView(selection: $selectedTab) {
            MeetingView(controller: controller)
                .tabItem {
                    Label("Meeting", systemImage: "mic.circle")
                }
                .tag(0)
            
            SummaryListView(controller: controller)
                .tabItem {
                    Label("Summaries", systemImage: "doc.text")
                }
                .tag(1)
        }
        .frame(minWidth: 800, minHeight: 600)
        }
    }
}

struct MeetingView: View {
    @Bindable var controller: MeetingSessionController
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with controls
            HStack {
                Text("ConvoCraft")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                if let error = controller.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Spacer()
                
                Button(action: {
                    Task {
                        if controller.isRecording {
                            await controller.stopMeeting()
                        } else {
                            await controller.startMeeting()
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: controller.isRecording ? "stop.circle.fill" : "record.circle")
                            .font(.title2)
                        Text(controller.isRecording ? "Stop Meeting" : "Start Meeting")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(controller.isRecording ? .red : .green)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Main content
            HSplitView {
                // Left: Live transcript
                LiveTranscriptView(
                    transcript: controller.currentTranscript,
                    partialTranscript: controller.partialTranscript
                )
                .frame(minWidth: 300)
                
                // Right: Insights
                InsightsView(insights: controller.insights)
                    .frame(minWidth: 300)
            }
        }
    }
}

struct LiveTranscriptView: View {
    let transcript: [TranscriptSegment]
    let partialTranscript: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("🎙 Live Transcript")
                .font(.headline)
                .padding()
            
            Divider()
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(transcript) { segment in
                            TranscriptSegmentView(segment: segment)
                                .id(segment.id)
                        }
                        
                        if !partialTranscript.isEmpty {
                            Text(partialTranscript)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                                .id("partial")
                        }
                    }
                    .padding()
                }
                .onChange(of: transcript.count) { _, _ in
                    if let last = transcript.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: partialTranscript) { _, _ in
                    if !partialTranscript.isEmpty {
                        withAnimation {
                            proxy.scrollTo("partial", anchor: .bottom)
                        }
                    }
                }
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }
}

struct TranscriptSegmentView: View {
    let segment: TranscriptSegment
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(formatTime(segment.timestamp))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            Text(segment.text)
                .textSelection(.enabled)
        }
        .padding(.horizontal)
    }
    
    private func formatTime(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

struct InsightsView: View {
    let insights: [IntelligenceInsight]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("💡 AI Insights")
                .font(.headline)
                .padding()
            
            Divider()
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(insights) { insight in
                        InsightCardView(insight: insight)
                    }
                    
                    if insights.isEmpty {
                        Text("Insights will appear here as the meeting progresses...")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                .padding()
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct InsightCardView: View {
    let insight: IntelligenceInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: iconForType(insight.type))
                    .foregroundColor(colorForType(insight.type))
                Text(insight.type.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(colorForType(insight.type))
            }
            
            Text(insight.content)
                .font(.body)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
    }
    
    private func iconForType(_ type: InsightType) -> String {
        switch type {
        case .question: return "questionmark.circle.fill"
        case .idea: return "lightbulb.fill"
        case .risk: return "exclamationmark.triangle.fill"
        }
    }
    
    private func colorForType(_ type: InsightType) -> Color {
        switch type {
        case .question: return .blue
        case .idea: return .green
        case .risk: return .orange
        }
    }
}

struct SummaryListView: View {
    @Bindable var controller: MeetingSessionController
    @State private var summaries: [MeetingSummary] = []
    @State private var selectedSummary: MeetingSummary?
    
    var body: some View {
        NavigationSplitView {
            List(summaries, id: \.date, selection: $selectedSummary) { summary in
                VStack(alignment: .leading) {
                    Text(summary.title)
                        .font(.headline)
                    Text(formatDate(summary.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .tag(summary)
            }
            .navigationTitle("Meeting Summaries")
            .task {
                summaries = await controller.loadPreviousSummaries()
            }
        } detail: {
            if let summary = selectedSummary {
                SummaryDetailView(summary: summary)
            } else {
                Text("Select a summary to view details")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct SummaryDetailView: View {
    let summary: MeetingSummary
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(summary.title)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Duration: \(formatDuration(summary.duration))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Divider()
                
                SectionView(title: "Summary", content: summary.summary)
                
                if !summary.actionItems.isEmpty {
                    SectionView(title: "Action Items", items: summary.actionItems)
                }
                
                if !summary.keyDecisions.isEmpty {
                    SectionView(title: "Key Decisions", items: summary.keyDecisions)
                }
                
                if !summary.insights.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Insights")
                            .font(.headline)
                        
                        ForEach(summary.insights) { insight in
                            InsightCardView(insight: insight)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct SectionView: View {
    let title: String
    var content: String? = nil
    var items: [String]? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            if let content = content {
                Text(content)
                    .textSelection(.enabled)
            }
            
            if let items = items {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top) {
                        Text("•")
                        Text(item)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
