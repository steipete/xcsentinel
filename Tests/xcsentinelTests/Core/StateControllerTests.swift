import Testing
import Foundation
@testable import xcsentinel

@Suite("StateController Tests", .tags(.fileSystem))
final class StateControllerTests {
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
    
    @Test("StateController creates state directory if missing")
    func createsStateDirectory() throws {
        let stateController = StateController.shared
        try stateController.ensureStateDirectory()
        
        let expectedPath = tempDirectory.appendingPathComponent(".xcsentinel")
        #expect(FileManager.default.fileExists(atPath: expectedPath.path))
    }
    
    @Test("StateController loads empty state when file doesn't exist")
    func loadsEmptyState() throws {
        let stateController = StateController.shared
        let state = try stateController.loadState()
        
        #expect(state.globalSessionCounter == 0)
        #expect(state.logSessions.isEmpty)
    }
    
    @Test("StateController saves and loads state correctly")
    func savesAndLoadsState() throws {
        let stateController = StateController.shared
        
        // Create a state with data
        var state = State()
        state.globalSessionCounter = 42
        state.logSessions["test-session"] = LogSession(
            pid: 12345,
            name: "test-session",
            targetUDID: "TEST-UDID",
            bundleID: "com.test.app",
            logPath: "/test/log.txt",
            startTime: Date()
        )
        
        // Save it
        try stateController.saveState(state)
        
        // Load it back
        let loadedState = try stateController.loadState()
        
        #expect(loadedState.globalSessionCounter == 42)
        #expect(loadedState.logSessions.count == 1)
        #expect(loadedState.logSessions["test-session"] != nil)
    }
    
    @Test("StateController updateState modifies state atomically")
    func updateStateAtomic() throws {
        let stateController = StateController.shared
        
        // Initialize with a counter
        try stateController.saveState(State())
        
        // Update the counter
        try stateController.updateState { state in
            state.globalSessionCounter = 10
        }
        
        // Verify the update
        let state = try stateController.loadState()
        #expect(state.globalSessionCounter == 10)
        
        // Update again
        try stateController.updateState { state in
            state.globalSessionCounter += 5
        }
        
        // Verify the second update
        let finalState = try stateController.loadState()
        #expect(finalState.globalSessionCounter == 15)
    }
    
    @Test("StateController cleanStaleSessions removes dead processes")
    func cleansStaleSessions() throws {
        let stateController = StateController.shared
        
        // Create state with both valid and stale sessions
        var state = State()
        
        // Add a session with current process (should stay)
        let currentPid = ProcessInfo.processInfo.processIdentifier
        state.logSessions["current"] = LogSession(
            pid: Int32(currentPid),
            name: "current",
            targetUDID: "CURRENT",
            bundleID: "com.current",
            logPath: "/current.log",
            startTime: Date()
        )
        
        // Add a session with invalid PID (should be removed)
        state.logSessions["stale"] = LogSession(
            pid: 99999,  // Very unlikely to exist
            name: "stale",
            targetUDID: "STALE",
            bundleID: "com.stale",
            logPath: "/stale.log",
            startTime: Date()
        )
        
        try stateController.saveState(state)
        
        // Clean stale sessions
        try stateController.cleanStaleSessions()
        
        // Verify results
        let cleanedState = try stateController.loadState()
        #expect(cleanedState.logSessions.count == 1)
        #expect(cleanedState.logSessions["current"] != nil)
        #expect(cleanedState.logSessions["stale"] == nil)
    }
    
    @Test("StateController handles concurrent updates correctly")
    func concurrentUpdates() async throws {
        let stateController = StateController.shared
        
        // Initialize
        try stateController.saveState(State())
        
        // Perform concurrent updates
        await withTaskGroup(of: Void.self) { group in
            for i in 1...10 {
                group.addTask {
                    try? stateController.updateState { state in
                        state.globalSessionCounter += 1
                        state.logSessions["session-\(i)"] = LogSession(
                            pid: Int32(i),
                            name: "session-\(i)",
                            targetUDID: "UDID-\(i)",
                            bundleID: "com.test.\(i)",
                            logPath: "/log-\(i).txt",
                            startTime: Date()
                        )
                    }
                }
            }
        }
        
        // Verify all updates were applied
        let finalState = try stateController.loadState()
        #expect(finalState.globalSessionCounter == 10)
        #expect(finalState.logSessions.count == 10)
    }
}