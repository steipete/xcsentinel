import Testing
import Foundation
@testable import xcsentinel

@Suite("Responses Tests", .tags(.unit, .fast))
struct ResponsesTests {
    
    @Test("BuildSuccessResponse encodes correctly to JSON")
    func buildSuccessResponseJSON() throws {
        let response = BuildSuccessResponse(success: true, message: "Build completed successfully")
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(response)
        let json = String(data: data, encoding: .utf8)!
        
        #expect(json.contains("\"success\":true"))
        #expect(json.contains("\"message\":\"Build completed successfully\""))
    }
    
    @Test("RunSuccessResponse uses snake_case in JSON")
    func runSuccessResponseSnakeCase() throws {
        let response = RunSuccessResponse(
            success: true,
            appPath: "/path/to/MyApp.app",
            bundleId: "com.example.MyApp",
            targetUdid: "12345678-1234-1234-1234-123456789012"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(response)
        let json = String(data: data, encoding: .utf8)!
        
        // Verify snake_case keys
        #expect(json.contains("\"app_path\""))
        #expect(json.contains("\"bundle_id\""))
        #expect(json.contains("\"target_udid\""))
        
        // Verify camelCase is NOT used
        #expect(!json.contains("\"appPath\""))
        #expect(!json.contains("\"bundleId\""))
        #expect(!json.contains("\"targetUdid\""))
    }
    
    @Test("LogSessionInfo encodes with all fields")
    func logSessionInfoEncoding() throws {
        let info = LogSessionInfo(
            name: "session-42",
            pid: 12345,
            bundleId: "com.test.app",
            targetUdid: "TEST-UDID"
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(info)
        let json = String(data: data, encoding: .utf8)!
        
        #expect(json.contains("\"name\":\"session-42\""))
        #expect(json.contains("\"pid\":12345"))
        #expect(json.contains("\"bundle_id\":\"com.test.app\""))
        #expect(json.contains("\"target_udid\":\"TEST-UDID\""))
    }
    
    @Test("LogListResponse handles empty and populated lists")
    func logListResponseVariations() throws {
        // Empty list
        let emptyResponse = LogListResponse(success: true, activeSessions: [])
        let emptyData = try JSONEncoder().encode(emptyResponse)
        let emptyJson = String(data: emptyData, encoding: .utf8)!
        #expect(emptyJson.contains("\"active_sessions\":[]"))
        
        // Populated list
        let sessions = [
            LogSessionInfo(name: "session-1", pid: 100, bundleId: "com.app1", targetUdid: "UDID1"),
            LogSessionInfo(name: "session-2", pid: 200, bundleId: "com.app2", targetUdid: "UDID2")
        ]
        let populatedResponse = LogListResponse(success: true, activeSessions: sessions)
        let populatedData = try JSONEncoder().encode(populatedResponse)
        let populatedJson = String(data: populatedData, encoding: .utf8)!
        
        #expect(populatedJson.contains("\"active_sessions\":["))
        #expect(populatedJson.contains("session-1"))
        #expect(populatedJson.contains("session-2"))
    }
    
    @Test("All response types are Sendable")
    func responsesSendable() {
        // This test verifies at compile time that all response types conform to Sendable
        func requireSendable<T: Sendable>(_ value: T) {
            // If this compiles, the type is Sendable
            _ = value
        }
        
        requireSendable(BuildSuccessResponse(success: true, message: "test"))
        requireSendable(RunSuccessResponse(success: true, appPath: "", bundleId: "", targetUdid: ""))
        requireSendable(LogStartResponse(success: true, sessionName: "test", pid: 123))
        requireSendable(LogStopResponse(success: true, logContent: "test"))
        requireSendable(LogSessionInfo(name: "", pid: 0, bundleId: "", targetUdid: ""))
        requireSendable(LogListResponse(success: true, activeSessions: []))
        requireSendable(CleanResponse(success: true, message: "test"))
        
        #expect(true) // If we get here, all types are Sendable
    }
}