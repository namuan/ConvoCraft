import Foundation
import os.log
import AppKit

/// File-based logger for ConvoCraft
/// Logs to ~/Library/Logs/ConvoCraft/
final class Logger: @unchecked Sendable {
    static let shared = Logger()
    
    private let logDirectory: URL
    private let logFileURL: URL
    private let fileHandle: FileHandle?
    private let osLog = OSLog(subsystem: "com.convocraft.app", category: "general")
    
    private init() {
        // Create log directory
        let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        logDirectory = libraryURL.appendingPathComponent("Logs/ConvoCraft", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        
        // Create log file with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        logFileURL = logDirectory.appendingPathComponent("ConvoCraft_\(timestamp).log")
        
        // Create file and get handle
        FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        fileHandle = try? FileHandle(forWritingTo: logFileURL)
        
        log("🚀 ConvoCraft Started", level: .info)
        log("📁 Log file: \(logFileURL.path)", level: .info)
        log("📱 System: macOS \(ProcessInfo.processInfo.operatingSystemVersionString)", level: .info)
    }
    
    deinit {
        try? fileHandle?.close()
    }
    
    enum LogLevel: String {
        case debug = "🔍 DEBUG"
        case info = "ℹ️ INFO"
        case warning = "⚠️ WARNING"
        case error = "❌ ERROR"
        case success = "✅ SUCCESS"
    }
    
    func log(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        let timestamp = Date()
        let fileName = (file as NSString).lastPathComponent
        let location = "\(fileName):\(line) \(function)"
        
        let logMessage = "[\(formatTimestamp(timestamp))] \(level.rawValue) [\(location)] \(message)\n"
        
        // Write to file
        if let data = logMessage.data(using: .utf8) {
            fileHandle?.write(data)
        }
        
        // Also log to console in debug builds
        #if DEBUG
        print(logMessage, terminator: "")
        #endif
        
        // Log to unified logging system
        os_log("%{public}@", log: osLog, type: logTypeFromLevel(level), logMessage)
    }
    
    func logError(_ error: Error, context: String, file: String = #file, function: String = #function, line: Int = #line) {
        log("\(context): \(error.localizedDescription)", level: .error, file: file, function: function, line: line)
    }
    
    func logSeparator() {
        log("═══════════════════════════════════════════════════════════════", level: .info)
    }
    
    func getLogFilePath() -> String {
        return logFileURL.path
    }
    
    func openLogDirectory() {
        NSWorkspace.shared.open(logDirectory)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
    
    private func logTypeFromLevel(_ level: LogLevel) -> OSLogType {
        switch level {
        case .debug:
            return .debug
        case .info, .success:
            return .info
        case .warning:
            return .default
        case .error:
            return .error
        }
    }
}

// Convenience functions
func logDebug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.log(message, level: .debug, file: file, function: function, line: line)
}

func logInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.log(message, level: .info, file: file, function: function, line: line)
}

func logWarning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.log(message, level: .warning, file: file, function: function, line: line)
}

func logError(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.log(message, level: .error, file: file, function: function, line: line)
}

func logSuccess(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.log(message, level: .success, file: file, function: function, line: line)
}
