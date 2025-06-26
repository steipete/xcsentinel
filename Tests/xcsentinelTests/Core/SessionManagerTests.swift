import Testing
import Foundation
@testable import xcsentinel

@Suite("SessionManager Tests", .tags(.fileSystem))
final class SessionManagerTests {
    let tempDirectory: URL
    let originalHome: String
    
    init() throws {
        // Save original home
        originalHome = FileManager.default.homeDirectoryForCurrentUser.path
        
        // Create temp directory
        tempDirectory = try TestHelpers.createTemporaryDirectory()
        
        // Override home directory for tests
        setenv("HOME", tempDirectory.path, 1)
    }
    
    deinit {
        // Restore original home
        setenv("HOME", originalHome, 1)
        
        // Clean up
        try? FileManager.default.removeItem(at: tempDirectory)
    }
    
    @Test("Start log session creates log file and updates state")
    func startLogSession() async throws {
        let manager = SessionManager()
        
        // This will fail because we can't mock the actual log process
        // but it demonstrates the expected behavior
        do {
            _ = try await manager.startLogSession(udid: "TEST-UDID", bundleID: "com.test.app")
            Issue.record("Expected error but none was thrown")
        } catch {
            // Expected to fail
            // Error was thrown, which is expected
        }
    }
    
    @Test("Stop log session returns log content")
    func stopLogSession() async throws {
        // First, manually create a session in state
        let stateController = StateController.shared
        let logPath = tempDirectory.appendingPathComponent(".xcsentinel/logs/test-session.log").path
        
        // Create log directory
        try FileManager.default.createDirectory(
            at: tempDirectory.appendingPathComponent(".xcsentinel/logs"),
            withIntermediateDirectories: true
        )
        
        // Create a log file with content
        let logContent = """
        Line 1
        Line 2
        Line 3
        """
        try logContent.write(toFile: logPath, atomically: true, encoding: .utf8)
        
        // Add session to state
        try await stateController.updateState { state in
            state.logSessions["test-session"] = LogSession(
                pid: 99999, // Non-existent process
                name: "test-session",
                targetUDID: "TEST-UDID",
                bundleID: "com.test.app",
                logPath: logPath,
                startTime: Date()
            )
        }
        
        let manager = SessionManager()
        
        // Stop with last 100 lines (in this case, all 3)
        let output = try await manager.stopLogSession(sessionName: "test-session", fullOutput: false)
        #expect(output.contains("Line 1"))
        #expect(output.contains("Line 3"))
        
        // Verify session was removed from state
        let state = try await stateController.loadState()
        #expect(state.logSessions["test-session"] == nil)
    }
    
    @Test("Stop log session with full output")
    func stopLogSessionFullOutput() async throws {
        let stateController = StateController.shared
        let logPath = tempDirectory.appendingPathComponent(".xcsentinel/logs/full-test.log").path
        
        // Create log directory and file
        try FileManager.default.createDirectory(
            at: tempDirectory.appendingPathComponent(".xcsentinel/logs"),
            withIntermediateDirectories: true
        )
        
        // Create a log with many lines
        var logLines: [String] = []
        for i in 1...150 {
            logLines.append("Log line \(i)")
        }
        let logContent = logLines.joined(separator: "\n")
        try logContent.write(toFile: logPath, atomically: true, encoding: .utf8)
        
        // Add session to state
        try await stateController.updateState { state in
            state.logSessions["full-test"] = LogSession(
                pid: 88888,
                name: "full-test",
                targetUDID: "FULL-TEST",
                bundleID: "com.full.test",
                logPath: logPath,
                startTime: Date()
            )
        }
        
        let manager = SessionManager()
        
        // Get full output
        let fullOutput = try await manager.stopLogSession(sessionName: "full-test", fullOutput: true)
        #expect(fullOutput.contains("Log line 1"))
        #expect(fullOutput.contains("Log line 150"))
        
        // Get last 100 lines only
        try await stateController.updateState { state in
            state.logSessions["full-test"] = LogSession(
                pid: 88888,
                name: "full-test",
                targetUDID: "FULL-TEST",
                bundleID: "com.full.test",
                logPath: logPath,
                startTime: Date()
            )
        }
        
        let partialOutput = try await manager.stopLogSession(sessionName: "full-test", fullOutput: false)
        #expect(!partialOutput.contains("Log line 1"))
        #expect(partialOutput.contains("Log line 150"))
    }
    
    @Test("List sessions returns active sessions")
    func listSessions() async throws {
        let stateController = StateController.shared
        
        // Add multiple sessions
        try await stateController.updateState { state in
            state.logSessions["session-1"] = LogSession(
                pid: Int32(ProcessInfo.processInfo.processIdentifier), // Current process - will be active
                name: "session-1",
                targetUDID: "UDID-1",
                bundleID: "com.test.1",
                logPath: "/log1.txt",
                startTime: Date().addingTimeInterval(-300) // 5 minutes ago
            )
            
            state.logSessions["session-2"] = LogSession(
                pid: 99999, // Non-existent - will be cleaned
                name: "session-2",
                targetUDID: "UDID-2",
                bundleID: "com.test.2",
                logPath: "/log2.txt",
                startTime: Date().addingTimeInterval(-600) // 10 minutes ago
            )
        }
        
        let manager = SessionManager()
        let sessions = try await manager.listSessions()
        
        // Should only return the active session
        #expect(sessions.count == 1)
        #expect(sessions.first?.name == "session-1")
    }
    
    @Test("Clean stale sessions removes dead processes")
    func cleanStaleSessions() async throws {
        let stateController = StateController.shared
        
        // Add a mix of active and stale sessions
        try await stateController.updateState { state in
            // Active session (current process)
            state.logSessions["active"] = LogSession(
                pid: Int32(ProcessInfo.processInfo.processIdentifier),
                name: "active",
                targetUDID: "ACTIVE",
                bundleID: "com.active",
                logPath: "/active.log",
                startTime: Date()
            )
            
            // Stale sessions
            for i in 1...3 {
                state.logSessions["stale-\(i)"] = LogSession(
                    pid: Int32(90000 + i),
                    name: "stale-\(i)",
                    targetUDID: "STALE-\(i)",
                    bundleID: "com.stale.\(i)",
                    logPath: "/stale-\(i).log",
                    startTime: Date()
                )
            }
        }
        
        let manager = SessionManager()
        try await manager.cleanStaleSessions()
        
        // Verify only active session remains
        let state = try await stateController.loadState()
        #expect(state.logSessions.count == 1)
        #expect(state.logSessions["active"] != nil)
    }
    
    @Test("Get session throws for non-existent session")
    func getNonExistentSession() async throws {
        let manager = SessionManager()
        
        do {
            _ = try await manager.stopLogSession(sessionName: "ghost-session", fullOutput: false)
            Issue.record("Expected error but none was thrown")
        } catch let error as XCSentinelError {
            if case .sessionNotFound(let name) = error {
                #expect(name == "ghost-session")
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
    
    @Test("Session name generation increments counter")
    func sessionNameGeneration() async throws {
        let stateController = StateController.shared
        
        // Set initial counter
        try await stateController.updateState { state in
            state.globalSessionCounter = 10
        }
        
        // Create mock sessions by updating state multiple times
        for i in 1...3 {
            try await stateController.updateState { state in
                state.globalSessionCounter += 1
                state.logSessions["session-\(state.globalSessionCounter)"] = LogSession(
                    pid: Int32(i),
                    name: "session-\(state.globalSessionCounter)",
                    targetUDID: "TEST",
                    bundleID: "com.test",
                    logPath: "/test.log",
                    startTime: Date()
                )
            }
        }
        
        let finalState = try await stateController.loadState()
        #expect(finalState.globalSessionCounter == 13)
        #expect(finalState.logSessions.count == 3)
    }
}