import Testing
import Foundation
@testable import xcsentinel

@Suite("StateController Tests", .tags(.stateManagement, .fileSystem, .unit))
final class StateControllerTests {
    let tempDirectory: URL
    let originalHome: String
    let stateController: StateController
    
    init() throws {
        // Save original home to restore in deinit
        originalHome = FileManager.default.homeDirectoryForCurrentUser.path
        
        // Create isolated temp directory for each test
        tempDirectory = try TestHelpers.createTemporaryDirectory()
        
        // Override HOME to ensure complete isolation
        setenv("HOME", tempDirectory.path, 1)
        
        // Create a fresh StateController instance
        stateController = StateController.shared
    }
    
    deinit {
        // Restore original HOME environment
        setenv("HOME", originalHome, 1)
        
        // Clean up temp directory
        try? FileManager.default.removeItem(at: tempDirectory)
    }
    
    // MARK: - Basic State Operations
    
    @Test("Creates state directory on first access")
    func createsStateDirectory() async throws {
        // Call loadState which will ensure directory exists
        _ = try await stateController.loadState()
        
        let expectedPath = tempDirectory.appendingPathComponent(".xcsentinel")
        #expect(FileManager.default.fileExists(atPath: expectedPath.path))
    }
    
    @Test("Loads empty state when no file exists")
    func loadsEmptyState() async throws {
        let state = try await stateController.loadState()
        
        // Multiple expectations for comprehensive validation
        #expect(state.globalSessionCounter == 0)
        #expect(state.logSessions.isEmpty)
        #expect(state.logSessions.count == 0)
    }
    
    @Test("Persists and retrieves state correctly")
    func persistsState() async throws {
        // Arrange: Create test data
        let testSession = LogSession(
            pid: 12345,
            name: "test-session",
            targetUDID: "TEST-UDID",
            bundleID: "com.test.app",
            logPath: "/test/log.txt",
            startTime: Date()
        )
        
        var state = State()
        state.globalSessionCounter = 42
        state.logSessions["test-session"] = testSession
        
        // Act: Save and reload
        try await stateController.updateState { currentState in
            // Replace entire state
            currentState = state
        }
        let loadedState = try await stateController.loadState()
        
        // Assert: Validate all properties independently
        #expect(loadedState.globalSessionCounter == 42)
        #expect(loadedState.logSessions.count == 1)
        
        let loadedSession = try #require(loadedState.logSessions["test-session"])
        #expect(loadedSession.pid == testSession.pid)
        #expect(loadedSession.name == testSession.name)
        #expect(loadedSession.targetUDID == testSession.targetUDID)
        #expect(loadedSession.bundleID == testSession.bundleID)
        #expect(loadedSession.logPath == testSession.logPath)
    }
    
    // MARK: - Atomic Update Operations
    
    @Test("Updates state atomically with closure")
    func atomicUpdates() async throws {
        // Start with empty state
        try await stateController.updateState { state in
            // Initialize with empty state
            state = State()
        }
        
        // First update: Set initial value
        try await stateController.updateState { state in
            state.globalSessionCounter = 10
        }
        
        let afterFirst = try await stateController.loadState()
        #expect(afterFirst.globalSessionCounter == 10)
        
        // Second update: Increment value
        try await stateController.updateState { state in
            state.globalSessionCounter += 5
        }
        
        let afterSecond = try await stateController.loadState()
        #expect(afterSecond.globalSessionCounter == 15)
        
        // Third update: Add session
        try await stateController.updateState { state in
            state.logSessions["new-session"] = LogSession(
                pid: 999,
                name: "new-session",
                targetUDID: "NEW-UDID",
                bundleID: "com.new.app",
                logPath: "/new.log",
                startTime: Date()
            )
        }
        
        let finalState = try await stateController.loadState()
        #expect(finalState.globalSessionCounter == 15)
        #expect(finalState.logSessions.count == 1)
        #expect(finalState.logSessions["new-session"] != nil)
    }
    
    // MARK: - Stale Session Management
    
    @Test("Removes only stale sessions, preserving active ones")
    func cleansStaleSessions() async throws {
        // Arrange: Create sessions with different PIDs
        let currentPid = Int32(ProcessInfo.processInfo.processIdentifier)
        let sessions = [
            ("active-current", currentPid, true),      // Current process - should remain
            ("stale-1", Int32(99999), false),         // Non-existent PID - should be removed
            ("stale-2", Int32(88888), false),         // Another non-existent - should be removed
            ("active-init", Int32(1), true)           // Init process (always exists) - should remain
        ]
        
        var state = State()
        for (name, pid, _) in sessions {
            state.logSessions[name] = LogSession(
                pid: pid,
                name: name,
                targetUDID: "UDID-\(name)",
                bundleID: "com.test.\(name)",
                logPath: "/\(name).log",
                startTime: Date()
            )
        }
        
        try await stateController.updateState { currentState in
            // Replace entire state
            currentState = state
        }
        
        // Act: Clean stale sessions
        try await stateController.cleanStaleSessions()
        
        // Assert: Verify only active sessions remain
        let cleanedState = try await stateController.loadState()
        
        for (name, _, shouldRemain) in sessions {
            if shouldRemain {
                #expect(cleanedState.logSessions[name] != nil, "Active session '\(name)' should remain")
            } else {
                #expect(cleanedState.logSessions[name] == nil, "Stale session '\(name)' should be removed")
            }
        }
    }
    
    // MARK: - Concurrency Tests
    
    @Test("Handles concurrent updates safely", .timeLimit(.minutes(1)))
    func concurrentUpdates() async throws {
        // Initialize with empty state
        try await stateController.updateState { state in
            // Initialize with empty state
            state = State()
        }
        
        let updateCount = 20
        let controller = stateController
        let results = await withTaskGroup(of: Result<Void, Error>.self) { group in
            // Launch concurrent update tasks
            for i in 1...updateCount {
                group.addTask {
                    do {
                        try await controller.updateState { state in
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
                        return .success(())
                    } catch {
                        return .failure(error)
                    }
                }
            }
            
            // Collect results
            var results: [Result<Void, Error>] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
        
        // Verify all updates succeeded
        for result in results {
            #expect(throws: Never.self) {
                try result.get()
            }
        }
        
        // Verify final state consistency
        let finalState = try await stateController.loadState()
        #expect(finalState.globalSessionCounter == updateCount)
        #expect(finalState.logSessions.count == updateCount)
        
        // Verify all sessions were created
        for i in 1...updateCount {
            #expect(finalState.logSessions["session-\(i)"] != nil)
        }
    }
    
    @Test("State file corruption recovery", .disabled("Requires manual file corruption"))
    func corruptionRecovery() throws {
        // This test would verify that StateController handles corrupted JSON gracefully
        // Disabled as it requires manual file manipulation
    }
}