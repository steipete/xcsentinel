import Testing
import Foundation
@testable import xcsentinel

@Suite("Basic JSON Tests", .tags(.unit, .fast))
struct BasicJSONTests {
    
    @Test("JSON responses encode with snake_case")
    func jsonSnakeCase() throws {
        // Test BuildSuccessResponse
        let buildResponse = BuildSuccessResponse(success: true, message: "Test")
        let buildData = try JSONEncoder().encode(buildResponse)
        let buildJSON = String(data: buildData, encoding: .utf8)!
        #expect(buildJSON.contains("\"success\":true"))
        #expect(buildJSON.contains("\"message\":\"Test\""))
        
        // Test RunSuccessResponse
        let runResponse = RunSuccessResponse(
            success: true,
            appPath: "/path/to/app",
            bundleId: "com.test",
            targetUdid: "UDID-123"
        )
        let runData = try JSONEncoder().encode(runResponse)
        let runJSON = String(data: runData, encoding: .utf8)!
        #expect(runJSON.contains("\"app_path\""))
        #expect(runJSON.contains("\"bundle_id\""))
        #expect(runJSON.contains("\"target_udid\""))
        #expect(!runJSON.contains("\"appPath\""))
        #expect(!runJSON.contains("\"bundleId\""))
        #expect(!runJSON.contains("\"targetUdid\""))
    }
    
    @Test("Error codes are SCREAMING_SNAKE_CASE")
    func errorCodes() {
        let errors: [XCSentinelError] = [
            .simulatorNotFound(name: "test"),
            .deviceNotFound(name: "test"),
            .buildFailed(message: "test"),
            .invalidDestination("test"),
            .missingWorkspaceOrProject,
            .stateFileError("test"),
            .processExecutionFailed("test"),
            .sessionNotFound("test"),
            .invalidConfiguration("test")
        ]
        
        let expectedCodes = [
            "SIMULATOR_NOT_FOUND",
            "DEVICE_NOT_FOUND", 
            "BUILD_FAILED",
            "INVALID_DESTINATION",
            "MISSING_WORKSPACE_OR_PROJECT",
            "STATE_FILE_ERROR",
            "PROCESS_EXECUTION_FAILED",
            "SESSION_NOT_FOUND",
            "INVALID_CONFIGURATION"
        ]
        
        for (error, expectedCode) in zip(errors, expectedCodes) {
            #expect(error.errorCode == expectedCode)
            #expect(error.errorCode == error.errorCode.uppercased())
        }
    }
    
    @Test("Log session info encodes correctly")
    func logSessionInfo() throws {
        let info = LogSessionInfo(
            name: "test-session",
            pid: 12345,
            bundleId: "com.example.app",
            targetUdid: "TEST-UDID"
        )
        
        let data = try JSONEncoder().encode(info)
        let json = String(data: data, encoding: .utf8)!
        
        #expect(json.contains("\"name\":\"test-session\""))
        #expect(json.contains("\"pid\":12345"))
        #expect(json.contains("\"bundle_id\":\"com.example.app\""))
        #expect(json.contains("\"target_udid\":\"TEST-UDID\""))
    }
    
    @Test("State encodes with snake_case")
    func stateEncoding() throws {
        var state = State()
        state.globalSessionCounter = 10
        state.logSessions["test"] = LogSession(
            pid: 123,
            name: "test",
            targetUDID: "UDID",
            bundleID: "com.test",
            logPath: "/test.log",
            startTime: Date(timeIntervalSince1970: 1700000000)
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        let json = String(data: data, encoding: .utf8)!
        
        #expect(json.contains("\"global_session_counter\":10"))
        #expect(json.contains("\"log_sessions\""))
        #expect(json.contains("\"target_udid\":\"UDID\""))
        #expect(json.contains("\"bundle_id\":\"com.test\""))
        #expect(json.contains("\"log_path\":\"/test.log\""))
        #expect(json.contains("\"start_time\":\"2023-11"))
    }
    
    @Test("JSON formatter encodes responses correctly") 
    func jsonFormatterEncoder() throws {
        // Test that responses encode correctly
        let response = BuildSuccessResponse(success: true, message: "Test message")
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(response)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        #expect(json?["success"] as? Bool == true)
        #expect(json?["message"] as? String == "Test message")
    }
    
    @Test("Error response format")
    func errorResponseFormat() throws {
        let error = XCSentinelError.buildFailed(message: "Test error")
        
        let errorResponse = ErrorResponse(
            success: false,
            error: ErrorInfo(
                code: error.errorCode,
                message: error.errorDescription ?? "Unknown error"
            )
        )
        
        let data = try JSONEncoder().encode(errorResponse)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        #expect(json?["success"] as? Bool == false)
        #expect(json?["error"] != nil)
        
        if let errorDict = json?["error"] as? [String: String] {
            #expect(errorDict["code"] == "BUILD_FAILED")
            #expect(errorDict["message"]?.contains("Test error") == true)
        }
    }
}