import Foundation

class SessionManager {
    private let stateController = StateController.shared
    private let fileManager = FileManager.default
    
    private var logDirectory: URL {
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        return homeDirectory.appendingPathComponent(".xcsentinel/logs")
    }
    
    func startLogSession(udid: String, bundleID: String) throws -> String {
        // Ensure log directory exists
        try fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        
        // Generate session name
        var sessionName = ""
        try stateController.updateState { state in
            state.globalSessionCounter += 1
            sessionName = "session-\(state.globalSessionCounter)"
        }
        
        // Create log file path
        let logPath = logDirectory.appendingPathComponent("\(sessionName).log").path
        
        // Determine if this is a simulator or device
        let isSimulator = try isSimulatorUDID(udid)
        
        // Start appropriate log process
        let process: Process
        
        if isSimulator {
            // Per spec: using simctl log stream with predicate
            // Note: This will stream from the currently booted simulator, not a specific UDID
            process = try ProcessExecutor.executeAsync(
                "/usr/bin/xcrun",
                arguments: [
                    "simctl", "log", "stream",
                    "--predicate", "subsystem == \"\(bundleID)\""
                ],
                outputPath: logPath
            )
        } else {
            process = try ProcessExecutor.executeAsync(
                "/usr/bin/xcrun",
                arguments: [
                    "devicectl", "device", "console",
                    "--device", udid,
                    bundleID
                ],
                outputPath: logPath
            )
        }
        
        // Save session info
        let session = LogSession(
            pid: process.processIdentifier,
            name: sessionName,
            targetUDID: udid,
            bundleID: bundleID,
            logPath: logPath,
            startTime: Date()
        )
        
        try stateController.updateState { state in
            state.logSessions[sessionName] = session
        }
        
        return sessionName
    }
    
    func stopLogSession(sessionName: String, fullOutput: Bool) throws -> String {
        let session = try getSession(sessionName)
        
        // Terminate the process
        let killResult = try ProcessExecutor.execute(
            "/bin/kill",
            arguments: ["-TERM", "\(session.pid)"]
        )
        
        if killResult.exitCode != 0 && killResult.exitCode != 1 {
            // Exit code 1 means process already terminated
            throw XCSentinelError.processExecutionFailed("Failed to stop log session: \(killResult.error)")
        }
        
        // Wait a moment for the process to finish writing
        Thread.sleep(forTimeInterval: 0.5)
        
        // Read log content
        let logContent = try String(contentsOfFile: session.logPath, encoding: .utf8)
        
        // Remove session from state
        try stateController.updateState { state in
            state.logSessions.removeValue(forKey: sessionName)
        }
        
        // Return requested output
        if fullOutput {
            return logContent
        } else {
            // Return last 100 lines
            let lines = logContent.components(separatedBy: .newlines)
            let lastLines = lines.suffix(100)
            return lastLines.joined(separator: "\n")
        }
    }
    
    func tailLogSession(sessionName: String) throws {
        let session = try getSession(sessionName)
        
        // Use tail -f to follow the log file
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tail")
        process.arguments = ["-f", session.logPath]
        
        try process.run()
        process.waitUntilExit()
    }
    
    func listSessions() throws -> [LogSession] {
        // Clean stale sessions first
        try stateController.cleanStaleSessions()
        
        // Return active sessions
        let state = try stateController.loadState()
        return Array(state.logSessions.values).sorted { $0.startTime < $1.startTime }
    }
    
    func cleanStaleSessions() throws {
        try stateController.cleanStaleSessions()
    }
    
    private func getSession(_ name: String) throws -> LogSession {
        let state = try stateController.loadState()
        guard let session = state.logSessions[name] else {
            throw XCSentinelError.sessionNotFound(name)
        }
        return session
    }
    
    private func isSimulatorUDID(_ udid: String) throws -> Bool {
        // Check if this UDID exists in simulator list
        let result = try ProcessExecutor.execute(
            "/usr/bin/xcrun",
            arguments: ["simctl", "list", "devices", "-j"]
        )
        
        if result.exitCode != 0 {
            throw XCSentinelError.processExecutionFailed("Failed to list devices: \(result.error)")
        }
        
        // Simple check: if the UDID appears in simctl output, it's a simulator
        return result.output.contains(udid)
    }
}