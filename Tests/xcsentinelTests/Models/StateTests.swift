import Testing
import Foundation
@testable import xcsentinel

@Suite("State Model Tests", .tags(.fast))
struct StateTests {
    
    @Test("State initializes with default values")
    func defaultInitialization() {
        let state = State()
        #expect(state.globalSessionCounter == 0)
        #expect(state.logSessions.isEmpty)
    }
    
    @Test("State encodes to JSON correctly")
    func jsonEncoding() throws {
        var state = State()
        state.globalSessionCounter = 5
        
        let session = LogSession(
            pid: 12345,
            name: "session-5",
            targetUDID: "ABC123",
            bundleID: "com.example.app",
            logPath: "/tmp/session-5.log",
            startTime: Date(timeIntervalSince1970: 1000000)
        )
        state.logSessions["session-5"] = session
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(state)
        let json = try #require(String(data: data, encoding: .utf8))
        
        #expect(json.contains("\"global_session_counter\" : 5"))
        #expect(json.contains("\"session-5\""))
        #expect(json.contains("\"pid\" : 12345"))
        #expect(json.contains("\"target_udid\" : \"ABC123\""))
        #expect(json.contains("\"bundle_id\" : \"com.example.app\""))
    }
    
    @Test("State decodes from JSON correctly")
    func jsonDecoding() throws {
        let json = """
        {
          "global_session_counter": 3,
          "log_sessions": {
            "session-1": {
              "pid": 50123,
              "name": "session-1",
              "target_udid": "XYZ789",
              "bundle_id": "com.test.app",
              "log_path": "/var/log/test.log",
              "start_time": "2024-01-01T00:00:00Z"
            }
          }
        }
        """
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let state = try decoder.decode(State.self, from: Data(json.utf8))
        
        #expect(state.globalSessionCounter == 3)
        #expect(state.logSessions.count == 1)
        
        let session = try #require(state.logSessions["session-1"])
        #expect(session.pid == 50123)
        #expect(session.name == "session-1")
        #expect(session.targetUDID == "XYZ789")
        #expect(session.bundleID == "com.test.app")
        #expect(session.logPath == "/var/log/test.log")
    }
    
    @Test("State handles empty log sessions")
    func emptyLogSessions() throws {
        let json = """
        {
          "global_session_counter": 10,
          "log_sessions": {}
        }
        """
        
        let decoder = JSONDecoder()
        let state = try decoder.decode(State.self, from: Data(json.utf8))
        
        #expect(state.globalSessionCounter == 10)
        #expect(state.logSessions.isEmpty)
    }
}