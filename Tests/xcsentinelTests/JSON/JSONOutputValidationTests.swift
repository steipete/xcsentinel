import Testing
import Foundation
@testable import xcsentinel

@Suite("JSON Output Validation Tests", .tags(.unit, .fast))
struct JSONOutputValidationTests {
    
    // MARK: - JSON Structure Validation
    
    @Test("JSON output follows correct envelope structure")
    func jsonEnvelopeStructure() throws {
        let formatter = OutputFormatter(json: true)
        
        // Test success response
        let successResponse = BuildSuccessResponse(success: true, message: "Test")
        var output = captureOutput { formatter.success(successResponse) }
        var json = try parseJSON(output)
        
        #expect(json["success"] as? Bool == true)
        #expect(json["message"] as? String == "Test")
        #expect(json["error"] == nil)
        
        // Test error envelope
        let error = XCSentinelError.buildFailed(message: "Test error")
        output = captureOutput { formatter.error(error) }
        json = try parseJSON(output)
        
        #expect(json["success"] as? Bool == false)
        #expect(json["error"] != nil)
    }
    
    @Test("Error JSON follows spec format")
    func errorJSONFormat() throws {
        let formatter = OutputFormatter(json: true)
        let error = XCSentinelError.simulatorNotFound(name: "iPhone 99")
        
        let output = captureOutput { formatter.error(error) }
        let json = try parseJSON(output)
        
        let errorDict = try #require(json["error"] as? [String: String])
        
        // Verify required fields
        #expect(errorDict["code"] != nil)
        #expect(errorDict["message"] != nil)
        
        // Verify error code is SCREAMING_SNAKE_CASE
        let code = try #require(errorDict["code"])
        #expect(code == code.uppercased())
        #expect(code.contains("_"))
        #expect(code == "SIMULATOR_NOT_FOUND")
    }
    
    @Test("All error codes are SCREAMING_SNAKE_CASE", arguments: [
        XCSentinelError.simulatorNotFound(name: "test"),
        XCSentinelError.deviceNotFound(name: "test"),
        XCSentinelError.ambiguousSimulator(name: "test", matches: ["a"]),
        XCSentinelError.buildFailed(message: "test"),
        XCSentinelError.invalidDestination("test"),
        XCSentinelError.missingWorkspaceOrProject,
        XCSentinelError.stateFileError("test"),
        XCSentinelError.processExecutionFailed("test"),
        XCSentinelError.sessionNotFound("test"),
        XCSentinelError.invalidConfiguration("test")
    ])
    func errorCodesScreamingSnakeCase(error: XCSentinelError) {
        let code = error.errorCode
        
        // Must be uppercase
        #expect(code == code.uppercased())
        
        // Must contain underscores (except single word codes)
        if code.count > 10 {
            #expect(code.contains("_"))
        }
        
        // Must not contain lowercase
        #expect(!code.contains { $0.isLowercase })
        
        // Must not contain special characters except underscore
        #expect(code.allSatisfy { $0.isUppercase || $0.isNumber || $0 == "_" })
    }
    
    // MARK: - Field Naming Validation
    
    @Test("All JSON fields use snake_case")
    func snakeCaseFieldNames() throws {
        let testCases: [(any Encodable, [String])] = [
            (RunSuccessResponse(success: true, appPath: "/path", bundleId: "com.test", targetUdid: "123"),
             ["app_path", "bundle_id", "target_udid"]),
            (LogSessionInfo(name: "test", pid: 123, bundleId: "com.test", targetUdid: "123"),
             ["bundle_id", "target_udid"]),
            (LogListResponse(success: true, activeSessions: []),
             ["success", "active_sessions"]),
            (LogStartResponse(success: true, sessionName: "test", pid: 123),
             ["success", "session_name", "pid"]),
            (LogStopResponse(success: true, logContent: "test"),
             ["success", "log_content"])
        ]
        
        for (response, expectedFields) in testCases {
            let data = try JSONEncoder().encode(response)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            
            // Check that expected snake_case fields exist
            for field in expectedFields {
                #expect(json[field] != nil, "Missing field: \(field)")
            }
            
            // Check that no camelCase fields exist
            for key in json.keys {
                #expect(!key.contains(where: { $0.isUppercase }), 
                       "Field '\(key)' contains uppercase letters")
            }
        }
    }
    
    // MARK: - Response Content Validation
    
    @Test("Build response JSON contains all required fields")
    func buildResponseFields() throws {
        let response = BuildSuccessResponse(success: true, message: "Build succeeded")
        let data = try JSONEncoder().encode(response)
        let json = try parseJSONData(data)
        
        #expect(json["success"] as? Bool == true)
        #expect(json["message"] as? String == "Build succeeded")
        #expect(json.count == 2) // Only success and message
    }
    
    @Test("Run response JSON contains all required fields")
    func runResponseFields() throws {
        let response = RunSuccessResponse(
            success: true,
            appPath: "/path/to/app",
            bundleId: "com.example.app",
            targetUdid: "UDID-123"
        )
        
        let data = try JSONEncoder().encode(response)
        let json = try parseJSONData(data)
        
        #expect(json["success"] as? Bool == true)
        #expect(json["app_path"] as? String == "/path/to/app")
        #expect(json["bundle_id"] as? String == "com.example.app")
        #expect(json["target_udid"] as? String == "UDID-123")
        #expect(json.count == 4) // Exactly 4 fields
    }
    
    @Test("Log session info JSON structure")
    func logSessionInfoStructure() throws {
        let info = LogSessionInfo(
            name: "session-123",
            pid: 54321,
            bundleId: "com.test.app",
            targetUdid: "TEST-UDID"
        )
        
        let data = try JSONEncoder().encode(info)
        let json = try parseJSONData(data)
        
        #expect(json["name"] as? String == "session-123")
        #expect(json["pid"] as? Int == 54321)
        #expect(json["bundle_id"] as? String == "com.test.app")
        #expect(json["target_udid"] as? String == "TEST-UDID")
        #expect(json.count == 4)
    }
    
    @Test("Log list response with multiple sessions")
    func logListMultipleSessions() throws {
        let sessions = [
            LogSessionInfo(name: "s1", pid: 100, bundleId: "com.app1", targetUdid: "U1"),
            LogSessionInfo(name: "s2", pid: 200, bundleId: "com.app2", targetUdid: "U2"),
            LogSessionInfo(name: "s3", pid: 300, bundleId: "com.app3", targetUdid: "U3")
        ]
        
        let response = LogListResponse(success: true, activeSessions: sessions)
        let data = try JSONEncoder().encode(response)
        let json = try parseJSONData(data)
        
        let sessionArray = try #require(json["active_sessions"] as? [[String: Any]])
        #expect(sessionArray.count == 3)
        
        for (index, sessionJSON) in sessionArray.enumerated() {
            let session = sessions[index]
            #expect(sessionJSON["name"] as? String == session.name)
            #expect(sessionJSON["pid"] as? Int == Int(session.pid))
            #expect(sessionJSON["bundle_id"] as? String == session.bundleId)
            #expect(sessionJSON["target_udid"] as? String == session.targetUdid)
        }
    }
    
    // MARK: - State File JSON Validation
    
    @Test("State file JSON follows spec schema")
    func stateFileSchema() throws {
        var state = State()
        state.globalSessionCounter = 42
        state.logSessions = [
            "session-1": LogSession(
                pid: 12345,
                name: "session-1",
                targetUDID: "UDID-1",
                bundleID: "com.app.one",
                logPath: "/logs/session-1.log",
                startTime: Date(timeIntervalSince1970: 1700000000)
            ),
            "session-2": LogSession(
                pid: 23456,
                name: "session-2",
                targetUDID: "UDID-2",
                bundleID: "com.app.two",
                logPath: "/logs/session-2.log",
                startTime: Date(timeIntervalSince1970: 1700001000)
            )
        ]
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        
        let data = try encoder.encode(state)
        let json = try parseJSONData(data)
        
        // Verify top-level structure
        #expect(json["global_session_counter"] as? Int == 42)
        
        let sessions = try #require(json["log_sessions"] as? [String: [String: Any]])
        #expect(sessions.count == 2)
        
        // Verify session structure
        for (sessionName, sessionData) in sessions {
            #expect(sessionData["pid"] as? Int != nil)
            #expect(sessionData["name"] as? String == sessionName)
            #expect(sessionData["target_udid"] as? String != nil)
            #expect(sessionData["bundle_id"] as? String != nil)
            #expect(sessionData["log_path"] as? String != nil)
            #expect(sessionData["start_time"] as? String != nil)
            
            // Verify ISO8601 date format
            let dateString = try #require(sessionData["start_time"] as? String)
            #expect(dateString.contains("T"))
            #expect(dateString.contains("Z"))
        }
    }
    
    // MARK: - JSON Encoding Options
    
    @Test("JSON output is pretty printed")
    func jsonPrettyPrinting() throws {
        let formatter = OutputFormatter(json: true)
        let response = BuildSuccessResponse(success: true, message: "Test")
        
        let output = captureOutput { formatter.success(response) }
        
        // Pretty printed JSON has newlines and indentation
        #expect(output.contains("\n"))
        #expect(output.contains("  ")) // 2-space indentation
        #expect(output.split(separator: "\n").count > 3) // Multiple lines
    }
    
    @Test("JSON keys are sorted alphabetically")
    func jsonSortedKeys() throws {
        let response = RunSuccessResponse(
            success: true,
            appPath: "/path",
            bundleId: "bundle",
            targetUdid: "udid"
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(response)
        let output = String(data: data, encoding: .utf8)!
        
        // Find positions of keys in output
        let appPathPos = output.range(of: "app_path")!.lowerBound
        let bundleIdPos = output.range(of: "bundle_id")!.lowerBound
        let successPos = output.range(of: "success")!.lowerBound
        let targetUdidPos = output.range(of: "target_udid")!.lowerBound
        
        // Verify alphabetical order
        #expect(appPathPos < bundleIdPos)
        #expect(bundleIdPos < successPos)
        #expect(successPos < targetUdidPos)
    }
    
    // MARK: - Edge Cases
    
    @Test("Empty arrays and objects encode correctly")
    func emptyCollections() throws {
        // Empty sessions array
        let emptyList = LogListResponse(success: true, activeSessions: [])
        let data = try JSONEncoder().encode(emptyList)
        let json = try parseJSONData(data)
        
        let sessions = try #require(json["active_sessions"] as? [Any])
        #expect(sessions.isEmpty)
        
        // Empty state
        let emptyState = State()
        let stateData = try JSONEncoder().encode(emptyState)
        let stateJson = try parseJSONData(stateData)
        
        #expect(stateJson["global_session_counter"] as? Int == 0)
        let logSessions = try #require(stateJson["log_sessions"] as? [String: Any])
        #expect(logSessions.isEmpty)
    }
    
    @Test("Special characters in strings are properly escaped")
    func specialCharacterEscaping() throws {
        let response = BuildSuccessResponse(
            success: true,
            message: "Build \"succeeded\" with\nnewline and\ttab"
        )
        
        let data = try JSONEncoder().encode(response)
        let jsonString = String(data: data, encoding: .utf8)!
        
        // Verify escaping
        #expect(jsonString.contains("\\\"succeeded\\\""))
        #expect(jsonString.contains("\\n"))
        #expect(jsonString.contains("\\t"))
        
        // Verify it parses back correctly
        let json = try parseJSONData(data)
        let message = try #require(json["message"] as? String)
        #expect(message.contains("\"succeeded\""))
        #expect(message.contains("\n"))
        #expect(message.contains("\t"))
    }
    
    @Test("Unicode characters are preserved")
    func unicodePreservation() throws {
        let response = BuildSuccessResponse(
            success: true,
            message: "Build succeeded 🎉 with émojis and ñon-ASCII"
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        let data = try encoder.encode(response)
        let json = try parseJSONData(data)
        
        let message = try #require(json["message"] as? String)
        #expect(message.contains("🎉"))
        #expect(message.contains("é"))
        #expect(message.contains("ñ"))
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
    
    private func parseJSON(_ string: String) throws -> [String: Any] {
        let data = Data(string.utf8)
        return try parseJSONData(data)
    }
    
    private func parseJSONData(_ data: Data) throws -> [String: Any] {
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}