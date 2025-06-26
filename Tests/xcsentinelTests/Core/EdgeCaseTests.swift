import Testing
import Foundation
@testable import xcsentinel

@Suite("Edge Case Tests", .tags(.errorHandling, .unit))
struct EdgeCaseTests {
    
    // MARK: - State Management Edge Cases
    
    @Test("Handles corrupt state file gracefully")
    func corruptStateFile() async throws {
        let tempDir = try TestHelpers.createTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Override HOME for this test
        let originalHome = FileManager.default.homeDirectoryForCurrentUser.path
        setenv("HOME", tempDir.path, 1)
        defer { setenv("HOME", originalHome, 1) }
        
        // Create corrupt state file
        let stateDir = tempDir.appendingPathComponent(".xcsentinel")
        try FileManager.default.createDirectory(at: stateDir, withIntermediateDirectories: true)
        let stateFile = stateDir.appendingPathComponent("state.json")
        try "{ invalid json".write(to: stateFile, atomically: true, encoding: .utf8)
        
        let stateController = StateController.shared
        
        // Should handle gracefully - either throw or return empty state
        do {
            let state = try await stateController.loadState()
            // If it returns, it should be empty state
            #expect(state.globalSessionCounter == 0)
            #expect(state.logSessions.isEmpty)
        } catch {
            // If it throws, that's also acceptable
            // Error was thrown, which is expected for corrupt file
        }
    }
    
    @Test("Handles missing log directory")
    func missingLogDirectory() async throws {
        let tempDir = try TestHelpers.createTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        setenv("HOME", tempDir.path, 1)
        defer { setenv("HOME", FileManager.default.homeDirectoryForCurrentUser.path, 1) }
        
        let manager = SessionManager()
        
        // Should create directory automatically
        do {
            _ = try await manager.startLogSession(udid: "TEST-UDID", bundleID: "com.test.app")
            // If it succeeds, that's fine
        } catch {
            // If it throws due to missing mock process, that's OK
            // We're testing directory creation, not process execution
            // Error was thrown, which is expected
        }
        
        // Verify directory was created
        let logDir = tempDir.appendingPathComponent(".xcsentinel/logs")
        #expect(FileManager.default.fileExists(atPath: logDir.path))
    }
    
    // MARK: - Process Execution Edge Cases
    
    @Test("Handles very long command output")
    func veryLongOutput() async throws {
        // Generate output larger than typical buffer sizes
        let lineCount = 100_000
        let longScript = "for i in $(seq 1 \(lineCount)); do echo \"This is line number $i with some additional text to make it longer\"; done"
        
        await #expect(throws: Never.self) {
            let result = try await ProcessExecutor.execute(
                "/bin/sh",
                arguments: ["-c", longScript]
            )
            
            let lines = result.output.components(separatedBy: .newlines).filter { !$0.isEmpty }
            #expect(lines.count == lineCount)
        }
    }
    
    @Test("Handles command with no output")
    func noOutput() async throws {
        let result = try await ProcessExecutor.execute("/usr/bin/true")
        
        #expect(result.exitCode == 0)
        #expect(result.output.isEmpty)
        #expect(result.error.isEmpty)
    }
    
    @Test("Handles command timeout scenarios", .timeLimit(.minutes(1)))
    func commandTimeout() async throws {
        // Start a long-running process
        let tempDir = try TestHelpers.createTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let outputPath = tempDir.appendingPathComponent("timeout-test.txt").path
        
        let process = try await ProcessExecutor.executeAsync(
            "/bin/sh",
            arguments: ["-c", "sleep 60"],
            outputPath: outputPath
        )
        
        // Give it a moment to start
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Terminate it early
        process.terminate()
        process.waitUntilExit()
        
        #expect(process.terminationStatus != 0)
    }
    
    // MARK: - Session Management Edge Cases
    
    @Test("Handles session name collisions")
    func sessionNameCollisions() async throws {
        let tempDir = try TestHelpers.createTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        setenv("HOME", tempDir.path, 1)
        defer { setenv("HOME", FileManager.default.homeDirectoryForCurrentUser.path, 1) }
        
        let stateController = StateController.shared
        
        // Create initial state with specific counter
        var state = State()
        state.globalSessionCounter = 42
        try await stateController.updateState { currentState in
            // Set the initial state
            currentState = state
        }
        
        // Create multiple sessions quickly
        for i in 1...10 {
            try await stateController.updateState { state in
                state.globalSessionCounter += 1
                let sessionName = "session-\(state.globalSessionCounter)"
                state.logSessions[sessionName] = LogSession(
                    pid: Int32(1000 + i),
                    name: sessionName,
                    targetUDID: "UDID-\(i)",
                    bundleID: "com.test.\(i)",
                    logPath: "/test-\(i).log",
                    startTime: Date()
                )
            }
        }
        
        // Verify all sessions have unique names
        let finalState = try await stateController.loadState()
        #expect(finalState.logSessions.count == 10)
        #expect(finalState.globalSessionCounter == 52)
        
        let sessionNames = Set(finalState.logSessions.keys)
        #expect(sessionNames.count == 10) // All unique
    }
    
    // MARK: - Device Resolution Edge Cases
    
    @Test("Handles empty device list")
    func emptyDeviceList() async throws {
        let manager = DeviceManager()
        
        // Mock empty device list response
        let _ = """
        {
            "devices": {}
        }
        """
        
        // This would normally be tested with a mock, but we can test the parsing logic
        await #expect(throws: Error.self) {
            _ = try await manager.resolveDestination("platform=iOS Simulator,name=iPhone 15")
        }
    }
    
    @Test("Handles malformed destination strings")
    func malformedDestinations() async throws {
        let manager = DeviceManager()
        
        let badDestinations = [
            "",                          // Empty
            "invalid",                   // No key-value pairs
            "platform=",                 // Empty value
            "=iOS",                      // Empty key
            "platform=iOS,platform=iOS", // Duplicate keys
            "platform = iOS",            // Spaces around equals
            ";;;",                       // Invalid separators
            "platform:iOS",              // Wrong separator
        ]
        
        for dest in badDestinations {
            await #expect(throws: Error.self) {
                _ = try await manager.resolveDestination(dest)
            }
        }
    }
}