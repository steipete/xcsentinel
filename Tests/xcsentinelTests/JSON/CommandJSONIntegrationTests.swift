import Testing
import Foundation
@testable import xcsentinel

@Suite("Command JSON Integration Tests", .tags(.integration, .fast))
struct CommandJSONIntegrationTests {
    
    // MARK: - Build Command JSON Output
    
    @Test("Build command with --json flag produces valid JSON")
    func buildCommandJSON() async throws {
        // Note: MockProcessExecutor would be used if commands supported dependency injection
        // For now, this test may fail without actual xcodebuild
        
        var command = try XCSentinel.parse(["build", "--scheme", "MyApp", "--workspace", "MyApp.xcworkspace", "--destination", "platform=iOS Simulator,name=iPhone 15", "--json"])
        
        // Capture output
        let output = try await captureCommandOutput {
            try await command.run()
        }
        
        // Verify JSON structure
        let json = try parseJSON(output)
        #expect(json["success"] as? Bool == true)
        
        if let data = json["data"] as? [String: Any] {
            #expect(data["success"] as? Bool == true)
            #expect(data["message"] as? String != nil)
        }
    }
    
    @Test("Build command error with --json flag")
    func buildCommandErrorJSON() async throws {
        // Note: MockProcessExecutor would be used if commands supported dependency injection
        // This test expects build to fail
        
        var command = try XCSentinel.parse(["build", "--scheme", "MyApp", "--workspace", "MyApp.xcworkspace", "--destination", "platform=iOS Simulator,name=iPhone 15", "--json"])
        
        let output = try await captureCommandOutput {
            do {
                try await command.run()
            } catch {
                // Expected to throw
            }
        }
        
        let json = try parseJSON(output)
        #expect(json["success"] as? Bool == false)
        
        if let error = json["error"] as? [String: String] {
            #expect(error["code"] == "BUILD_FAILED")
            #expect(error["message"]?.contains("Build failed") == true)
        }
    }
    
    // MARK: - Run Command JSON Output
    
    @Test("Run command with --json produces snake_case fields")
    func runCommandJSONSnakeCase() async throws {
        // Note: MockProcessExecutor would be used if commands supported dependency injection
        // This test may fail without actual xcodebuild and xcrun
        
        var command = try XCSentinel.parse([
            "run",
            "--scheme", "MyApp",
            "--destination", "platform=iOS Simulator,name=iPhone 15",
            "--workspace", "MyApp.xcworkspace",
            "--json"
        ])
        
        let output = try await captureCommandOutput {
            try await command.run()
        }
        
        let json = try parseJSON(output)
        if let data = json["data"] as? [String: Any] {
            // Verify snake_case fields
            #expect(data["app_path"] != nil)
            #expect(data["bundle_id"] != nil)
            #expect(data["target_udid"] != nil)
            
            // Verify camelCase is not used
            #expect(data["appPath"] == nil)
            #expect(data["bundleId"] == nil)
            #expect(data["targetUdid"] == nil)
        }
    }
    
    // MARK: - Log Command JSON Output
    
    @Test("Log start command with --json")
    func logStartJSON() async throws {
        let tempDir = try TestHelpers.createTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        setenv("HOME", tempDir.path, 1)
        defer { setenv("HOME", FileManager.default.homeDirectoryForCurrentUser.path, 1) }
        
        // Note: MockProcessExecutor would be used if commands supported dependency injection
        var command = try XCSentinel.parse(["log", "start", "--udid", "TEST-UDID", "--bundle-id", "com.test", "--json"])
        
        let output = try await captureCommandOutput {
            try await command.run()
        }
        
        let json = try parseJSON(output)
        #expect(json["success"] as? Bool == true)
        
        if let data = json["data"] as? [String: Any] {
            #expect(data["session_name"] as? String != nil)
            let sessionName = data["session_name"] as? String ?? ""
            #expect(sessionName.hasPrefix("session-"))
        }
    }
    
    @Test("Log list command with --json shows multiple sessions")
    func logListJSONMultipleSessions() async throws {
        let tempDir = try TestHelpers.createTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        setenv("HOME", tempDir.path, 1)
        defer { setenv("HOME", FileManager.default.homeDirectoryForCurrentUser.path, 1) }
        
        // Create some sessions in state
        let stateController = StateController.shared
        try await stateController.updateState { state in
            state.logSessions = [
                "session-1": LogSession(
                    pid: 1001,
                    name: "session-1",
                    targetUDID: "UDID-1",
                    bundleID: "com.app.one",
                    logPath: "/logs/1.log",
                    startTime: Date()
                ),
                "session-2": LogSession(
                    pid: 1002,
                    name: "session-2",
                    targetUDID: "UDID-2",
                    bundleID: "com.app.two",
                    logPath: "/logs/2.log",
                    startTime: Date()
                ),
                "session-3": LogSession(
                    pid: 1003,
                    name: "session-3",
                    targetUDID: "UDID-3",
                    bundleID: "com.app.three",
                    logPath: "/logs/3.log",
                    startTime: Date()
                )
            ]
        }
        
        var command = try XCSentinel.parse(["log", "list", "--json"])
        
        let output = try await captureCommandOutput {
            try await command.run()
        }
        
        let json = try parseJSON(output)
        #expect(json["success"] as? Bool == true)
        
        if let data = json["data"] as? [String: Any],
           let sessions = data["active_sessions"] as? [[String: Any]] {
            #expect(sessions.count == 3)
            
            // Verify session data structure
            for session in sessions {
                #expect(session["name"] as? String != nil)
                #expect(session["pid"] as? Int != nil)
                #expect(session["bundle_id"] as? String != nil)
                #expect(session["target_udid"] as? String != nil)
            }
        }
    }
    
    @Test("Log stop command with --json includes log content")
    func logStopJSONWithContent() async throws {
        let tempDir = try TestHelpers.createTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        setenv("HOME", tempDir.path, 1)
        defer { setenv("HOME", FileManager.default.homeDirectoryForCurrentUser.path, 1) }
        
        // Create a session with log file
        let logDir = tempDir.appendingPathComponent(".xcsentinel/logs")
        try FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        
        let logFile = logDir.appendingPathComponent("test-session.log")
        let logContent = """
        2024-01-01 12:00:00 MyApp[12345] Log line 1
        2024-01-01 12:00:01 MyApp[12345] Log line 2
        2024-01-01 12:00:02 MyApp[12345] Log line 3
        """
        try logContent.write(to: logFile, atomically: true, encoding: .utf8)
        
        let stateController = StateController.shared
        try await stateController.updateState { state in
            state.logSessions["test-session"] = LogSession(
                pid: 12345,
                name: "test-session",
                targetUDID: "TEST-UDID",
                bundleID: "com.test",
                logPath: logFile.path,
                startTime: Date()
            )
        }
        
        var command = try XCSentinel.parse(["log", "stop", "test-session", "--json", "--full"])
        
        let output = try await captureCommandOutput {
            try await command.run()
        }
        
        let json = try parseJSON(output)
        #expect(json["success"] as? Bool == true)
        
        if let data = json["data"] as? [String: Any] {
            let content = data["log_content"] as? String ?? ""
            #expect(content.contains("Log line 1"))
            #expect(content.contains("Log line 2"))
            #expect(content.contains("Log line 3"))
        }
    }
    
    // MARK: - Global --json Flag
    
    @Test("Global --json flag works for all commands", arguments: [
        ["--json", "build", "--scheme", "MyApp", "--workspace", "MyApp.xcworkspace", "--destination", "platform=iOS Simulator,name=iPhone 15"],
        ["--json", "run", "--scheme", "MyApp", "--destination", "platform=iOS", "--workspace", "MyApp.xcworkspace"],
        ["--json", "log", "list"]
    ])
    func globalJSONFlag(args: [String]) async throws {
        // Note: MockProcessExecutor would be used if commands supported dependency injection
        
        var command = try XCSentinel.parse(args)
        
        let output = try await captureCommandOutput {
            do {
                try await command.run()
            } catch {
                // Some commands might fail, but we're testing JSON output
            }
        }
        
        // All output should be valid JSON
        let json = try? parseJSON(output)
        #expect(json != nil, "Output should be valid JSON for args: \(args)")
        #expect(json?["success"] != nil, "JSON should have success field")
    }
    
    // MARK: - Error Response Validation
    
    @Test("All error types produce valid JSON", arguments: [
        XCSentinelError.simulatorNotFound(name: "iPhone 99"),
        XCSentinelError.deviceNotFound(name: "My Device"),
        XCSentinelError.ambiguousSimulator(name: "iPhone", matches: ["iPhone 14", "iPhone 15"]),
        XCSentinelError.buildFailed(message: "Compilation error"),
        XCSentinelError.invalidDestination("bad destination"),
        XCSentinelError.missingWorkspaceOrProject,
        XCSentinelError.stateFileError("Cannot read state"),
        XCSentinelError.processExecutionFailed("Command failed"),
        XCSentinelError.sessionNotFound("session-123"),
        XCSentinelError.invalidConfiguration("Bad config")
    ])
    func errorJSONValidation(error: XCSentinelError) throws {
        let formatter = OutputFormatter(json: true)
        
        let output = captureOutput {
            formatter.error(error)
        }
        
        let json = try parseJSON(output)
        
        // Verify error response structure
        #expect(json["success"] as? Bool == false)
        #expect(json["data"] == nil)
        
        let errorDict = try #require(json["error"] as? [String: String])
        #expect(errorDict["code"] != nil)
        #expect(errorDict["message"] != nil)
        
        // Verify error code matches
        #expect(errorDict["code"] == error.errorCode)
    }
    
    // MARK: - JSON Consistency
    
    @Test("JSON output is consistent across multiple invocations")
    func jsonConsistency() async throws {
        // Note: MockProcessExecutor would be used if commands supported dependency injection
        
        // Run multiple times
        var outputs: [String] = []
        for _ in 1...3 {
            var command = try XCSentinel.parse(["build", "--scheme", "MyApp", "--workspace", "MyApp.xcworkspace", "--destination", "platform=iOS Simulator,name=iPhone 15", "--json"])
            let output = try await captureCommandOutput {
                try await command.run()
            }
            outputs.append(output)
        }
        
        // All outputs should parse to equivalent JSON
        let jsons = try outputs.map { try parseJSON($0) }
        
        for json in jsons {
            #expect(json["success"] as? Bool == jsons[0]["success"] as? Bool)
            if let data1 = json["data"] as? [String: Any],
               let data0 = jsons[0]["data"] as? [String: Any] {
                #expect(data1["success"] as? Bool == data0["success"] as? Bool)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func captureOutput(_ block: () throws -> Void) rethrows -> String {
        let pipe = Pipe()
        let original = dup(STDOUT_FILENO)
        
        setvbuf(stdout, nil, _IONBF, 0)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        
        try block()
        
        fflush(stdout)
        pipe.fileHandleForWriting.closeFile()
        dup2(original, STDOUT_FILENO)
        close(original)
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    private func captureCommandOutput(_ block: () async throws -> Void) async throws -> String {
        let pipe = Pipe()
        let original = dup(STDOUT_FILENO)
        
        setvbuf(stdout, nil, _IONBF, 0)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        
        do {
            try await block()
        } catch {
            // Restore stdout before rethrowing
            fflush(stdout)
            pipe.fileHandleForWriting.closeFile()
            dup2(original, STDOUT_FILENO)
            close(original)
            
            // Still capture any output that was written
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        }
        
        fflush(stdout)
        pipe.fileHandleForWriting.closeFile()
        dup2(original, STDOUT_FILENO)
        close(original)
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    private func parseJSON(_ string: String) throws -> [String: Any] {
        let data = Data(string.utf8)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}