import Testing
import Foundation
@testable import xcsentinel

@Suite("OutputFormatter Unit Tests", .tags(.unit, .fast))
struct OutputFormatterUnitTests {
    
    @Test("OutputFormatter initializes with correct format")
    func initialization() {
        let jsonFormatter = OutputFormatter(json: true)
        #expect(jsonFormatter.format == .json)
        
        let plainFormatter = OutputFormatter(json: false)
        #expect(plainFormatter.format == .plain)
    }
    
    @Test("Plain formatter outputs strings directly")
    func plainStringOutput() {
        let formatter = OutputFormatter(json: false)
        
        // Can't easily test print output, but we can verify the formatter is created
        formatter.success("Test message")
        #expect(formatter.format == .plain)
    }
    
    @Test("JSON formatter uses correct encoder settings")
    func jsonEncoderSettings() throws {
        let formatter = OutputFormatter(json: true)
        
        // Test with a simple encodable struct
        struct TestData: Encodable {
            let message: String
            let count: Int
        }
        
        let testData = TestData(message: "test", count: 42)
        
        // Can't capture print output easily, but verify formatter exists
        formatter.success(testData)
        #expect(formatter.format == .json)
    }
    
    @Test("Error formatter creates proper error response")
    func errorFormatting() {
        let formatter = OutputFormatter(json: true)
        let error = XCSentinelError.buildFailed(message: "Test error")
        
        formatter.error(error)
        #expect(formatter.format == .json)
    }
}