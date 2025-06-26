import Testing
import Foundation
@testable import xcsentinel

@Suite("Simple JSON Tests", .tags(.unit, .fast))
struct SimpleJSONTests {
    
    @Test("Verify JSON encoding works")
    func basicJSONTest() throws {
        // Test that basic response types encode correctly
        let response = BuildSuccessResponse(success: true, message: "Build completed")
        let data = try JSONEncoder().encode(response)
        #expect(data.count > 0)
        
        // Verify it's valid JSON
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json != nil)
    }
    
    @Test("Error codes are uppercase with underscores")
    func errorCodesTest() {
        let error1 = XCSentinelError.simulatorNotFound(name: "test")
        #expect(error1.errorCode == "SIMULATOR_NOT_FOUND")
        
        let error2 = XCSentinelError.buildFailed(message: "test")
        #expect(error2.errorCode == "BUILD_FAILED")
    }
}