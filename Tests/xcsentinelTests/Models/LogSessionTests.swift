import Testing
import Foundation
@testable import xcsentinel

@Suite("LogSession Tests", .tags(.fast))
struct LogSessionTests {
    
    @Test("LogSession stores all properties correctly")
    func propertyStorage() {
        let startTime = Date()
        let session = LogSession(
            pid: 99999,
            name: "test-session",
            targetUDID: "UNIQUE-ID",
            bundleID: "com.steipete.test",
            logPath: "/Users/test/logs/test.log",
            startTime: startTime
        )
        
        #expect(session.pid == 99999)
        #expect(session.name == "test-session")
        #expect(session.targetUDID == "UNIQUE-ID")
        #expect(session.bundleID == "com.steipete.test")
        #expect(session.logPath == "/Users/test/logs/test.log")
        #expect(session.startTime == startTime)
    }
    
    @Test("LogSession encodes with correct JSON keys")
    func jsonEncodingKeys() throws {
        let session = LogSession(
            pid: 12345,
            name: "session-1",
            targetUDID: "ABC123",
            bundleID: "com.example.app",
            logPath: "/tmp/log.txt",
            startTime: Date(timeIntervalSince1970: 0)
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(session)
        let json = try #require(String(data: data, encoding: .utf8))
        
        // Check for snake_case keys
        #expect(json.contains("\"bundle_id\":"))
        #expect(json.contains("\"log_path\":"))
        #expect(json.contains("\"target_udid\":"))
        #expect(json.contains("\"start_time\":"))
        
        // Should not contain camelCase
        #expect(!json.contains("\"bundleID\":"))
        #expect(!json.contains("\"logPath\":"))
        #expect(!json.contains("\"targetUDID\":"))
    }
    
    @Test("LogSession decodes from JSON correctly")
    func jsonDecoding() throws {
        let json = """
        {
          "pid": 54321,
          "name": "decoded-session",
          "target_udid": "DEF456",
          "bundle_id": "com.decoded.app",
          "log_path": "/var/logs/decoded.log",
          "start_time": "2024-06-26T12:00:00Z"
        }
        """
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let session = try decoder.decode(LogSession.self, from: Data(json.utf8))
        
        #expect(session.pid == 54321)
        #expect(session.name == "decoded-session")
        #expect(session.targetUDID == "DEF456")
        #expect(session.bundleID == "com.decoded.app")
        #expect(session.logPath == "/var/logs/decoded.log")
        
        // Check the date was parsed correctly
        let expectedDate = ISO8601DateFormatter().date(from: "2024-06-26T12:00:00Z")
        #expect(session.startTime == expectedDate)
    }
    
    @Test("LogSession roundtrip encoding/decoding preserves data")
    func roundtripEncodingDecoding() throws {
        let original = LogSession(
            pid: 98765,
            name: "roundtrip-test",
            targetUDID: "ROUNDTRIP-ID",
            bundleID: "com.roundtrip.test",
            logPath: "/path/to/roundtrip.log",
            startTime: Date()
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(LogSession.self, from: data)
        
        #expect(decoded.pid == original.pid)
        #expect(decoded.name == original.name)
        #expect(decoded.targetUDID == original.targetUDID)
        #expect(decoded.bundleID == original.bundleID)
        #expect(decoded.logPath == original.logPath)
        
        // Date comparison with tolerance for ISO8601 encoding precision
        let timeDifference = abs(decoded.startTime.timeIntervalSince(original.startTime))
        #expect(timeDifference < 1.0) // ISO8601 typically has second precision
    }
}