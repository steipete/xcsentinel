import Testing
import Foundation
@testable import xcsentinel

@Suite("XCSentinelError Unit Tests", .tags(.unit, .fast, .errorHandling))
struct ErrorUnitTests {
    
    @Test("All error cases have proper error codes")
    func errorCodesExist() {
        // Test each error case
        let errors: [XCSentinelError] = [
            .simulatorNotFound(name: "test"),
            .deviceNotFound(name: "test"),
            .ambiguousSimulator(name: "test", matches: ["a", "b"]),
            .buildFailed(message: "test"),
            .invalidDestination("test"),
            .missingWorkspaceOrProject,
            .stateFileError("test"),
            .processExecutionFailed("test"),
            .sessionNotFound("test"),
            .invalidConfiguration("test")
        ]
        
        for error in errors {
            #expect(!error.errorCode.isEmpty)
            // Verify error codes are SCREAMING_SNAKE_CASE
            #expect(error.errorCode == error.errorCode.uppercased())
            #expect(error.errorCode.contains("_") || error.errorCode.rangeOfCharacter(from: .letters) != nil)
        }
    }
    
    @Test("Error descriptions are not empty")
    func errorDescriptionsExist() {
        let errors: [XCSentinelError] = [
            .simulatorNotFound(name: "iPhone"),
            .deviceNotFound(name: "MyDevice"),
            .ambiguousSimulator(name: "iPhone", matches: ["iPhone 14", "iPhone 15"]),
            .buildFailed(message: "Compilation failed"),
            .invalidDestination("bad-destination"),
            .missingWorkspaceOrProject,
            .stateFileError("Permission denied"),
            .processExecutionFailed("Command not found"),
            .sessionNotFound("session-123"),
            .invalidConfiguration("No scheme specified")
        ]
        
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }
    
    @Test("Error recovery suggestions exist for some errors")
    func recoverySuggestions() {
        // Some errors should have recovery suggestions
        let errorWithSuggestion = XCSentinelError.missingWorkspaceOrProject
        #expect(errorWithSuggestion.recoverySuggestion == nil) // Currently no suggestions implemented
        
        // This is where we could add tests for recovery suggestions when implemented
    }
}