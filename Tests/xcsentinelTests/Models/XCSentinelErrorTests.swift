import Testing
import Foundation
@testable import xcsentinel

@Suite("XCSentinelError Tests", .tags(.fast))
struct XCSentinelErrorTests {
    
    @Test("Error descriptions are properly formatted", arguments: [
        (XCSentinelError.simulatorNotFound(name: "iPhone 99"), "Simulator with name 'iPhone 99' not found."),
        (XCSentinelError.ambiguousSimulator(name: "iPhone 15", matches: ["iPhone 15 (17.2)", "iPhone 15 (17.5)"]), 
         "Ambiguous simulator name 'iPhone 15'. Matches: iPhone 15 (17.2), iPhone 15 (17.5)"),
        (XCSentinelError.buildFailed(message: "Compilation error"), "Build failed: Compilation error"),
        (XCSentinelError.invalidDestination("bad-dest"), "Invalid destination: bad-dest"),
        (XCSentinelError.missingWorkspaceOrProject, "Either --workspace or --project must be specified"),
        (XCSentinelError.stateFileError("Cannot write"), "State file error: Cannot write"),
        (XCSentinelError.processExecutionFailed("Exit code 1"), "Process execution failed: Exit code 1"),
        (XCSentinelError.sessionNotFound("session-5"), "Session 'session-5' not found"),
        (XCSentinelError.invalidConfiguration("Missing scheme"), "Invalid configuration: Missing scheme")
    ])
    func errorDescriptions(error: XCSentinelError, expectedDescription: String) {
        #expect(error.errorDescription == expectedDescription)
    }
    
    @Test("Error codes are consistent", arguments: [
        (XCSentinelError.simulatorNotFound(name: "test"), "SIMULATOR_NOT_FOUND"),
        (XCSentinelError.ambiguousSimulator(name: "test", matches: []), "AMBIGUOUS_SIMULATOR"),
        (XCSentinelError.buildFailed(message: "test"), "BUILD_FAILED"),
        (XCSentinelError.invalidDestination("test"), "INVALID_DESTINATION"),
        (XCSentinelError.missingWorkspaceOrProject, "MISSING_WORKSPACE_OR_PROJECT"),
        (XCSentinelError.stateFileError("test"), "STATE_FILE_ERROR"),
        (XCSentinelError.processExecutionFailed("test"), "PROCESS_EXECUTION_FAILED"),
        (XCSentinelError.sessionNotFound("test"), "SESSION_NOT_FOUND"),
        (XCSentinelError.invalidConfiguration("test"), "INVALID_CONFIGURATION")
    ])
    func errorCodes(error: XCSentinelError, expectedCode: String) {
        #expect(error.errorCode == expectedCode)
    }
    
    @Test("Errors conform to LocalizedError")
    func localizedErrorConformance() {
        let error: LocalizedError = XCSentinelError.buildFailed(message: "Test")
        #expect(error.errorDescription != nil)
    }
}