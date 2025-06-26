import Testing
import Foundation
@testable import xcsentinel

@Suite("Response Unit Tests", .tags(.unit, .fast))
struct ResponseUnitTests {
    
    @Test("BuildSuccessResponse initializes correctly")
    func buildSuccessResponse() {
        let response = BuildSuccessResponse(success: true, message: "Build completed")
        #expect(response.success == true)
        #expect(response.message == "Build completed")
    }
    
    @Test("RunSuccessResponse contains all required fields")
    func runSuccessResponse() {
        let response = RunSuccessResponse(
            success: true,
            message: "App launched",
            bundleId: "com.example.app",
            targetUdid: "12345",
            targetName: "iPhone 15",
            targetType: "simulator"
        )
        
        #expect(response.success == true)
        #expect(response.message == "App launched")
        #expect(response.bundleId == "com.example.app")
        #expect(response.targetUdid == "12345")
        #expect(response.targetName == "iPhone 15")
        #expect(response.targetType == "simulator")
    }
    
    @Test("LogStartResponse has proper session info")
    func logStartResponse() {
        let sessionInfo = LogSessionInfo(
            sessionId: "session-123",
            bundleId: "com.test",
            targetUdid: "UDID",
            targetName: "Test Device",
            targetType: "device",
            logPath: "/path/to/log"
        )
        
        let response = LogStartResponse(
            success: true,
            message: "Started",
            sessionInfo: sessionInfo
        )
        
        #expect(response.success == true)
        #expect(response.sessionInfo.sessionId == "session-123")
        #expect(response.sessionInfo.bundleId == "com.test")
    }
    
    @Test("LogListResponse handles empty sessions")
    func emptyLogListResponse() {
        let response = LogListResponse(
            success: true,
            message: "No sessions",
            sessions: []
        )
        
        #expect(response.success == true)
        #expect(response.sessions.isEmpty)
    }
    
    @Test("CleanResponse for cleanup operations")
    func cleanResponse() {
        let response = CleanResponse(success: true, message: "Cleaned 5 stale sessions")
        #expect(response.success == true)
        #expect(response.message.contains("5"))
    }
    
    @Test("ErrorInfo encodes properly")
    func errorInfo() {
        let info = ErrorInfo(code: "TEST_ERROR", message: "This is a test error")
        #expect(info.code == "TEST_ERROR")
        #expect(info.message == "This is a test error")
    }
    
    @Test("ErrorResponse structure")
    func errorResponse() {
        let errorInfo = ErrorInfo(code: "BUILD_FAILED", message: "Compilation error")
        let response = ErrorResponse(success: false, error: errorInfo)
        
        #expect(response.success == false)
        #expect(response.error.code == "BUILD_FAILED")
        #expect(response.error.message == "Compilation error")
    }
}