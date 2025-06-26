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
            appPath: "/path/to/app",
            bundleId: "com.example.app",
            targetUdid: "12345"
        )
        
        #expect(response.success == true)
        #expect(response.appPath == "/path/to/app")
        #expect(response.bundleId == "com.example.app")
        #expect(response.targetUdid == "12345")
    }
    
    @Test("LogStartResponse has proper session info")
    func logStartResponse() {
        let response = LogStartResponse(
            success: true,
            sessionName: "session-123",
            pid: 12345
        )
        
        #expect(response.success == true)
        #expect(response.sessionName == "session-123")
        #expect(response.pid == 12345)
    }
    
    @Test("LogListResponse handles empty sessions")
    func emptyLogListResponse() {
        let response = LogListResponse(
            success: true,
            activeSessions: []
        )
        
        #expect(response.success == true)
        #expect(response.activeSessions.isEmpty)
    }
    
    @Test("LogSessionInfo contains session details")
    func logSessionInfo() {
        let sessionInfo = LogSessionInfo(
            name: "test-session",
            pid: 9876,
            bundleId: "com.example.app",
            targetUdid: "DEVICE-123"
        )
        
        #expect(sessionInfo.name == "test-session")
        #expect(sessionInfo.pid == 9876)
        #expect(sessionInfo.bundleId == "com.example.app")
        #expect(sessionInfo.targetUdid == "DEVICE-123")
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