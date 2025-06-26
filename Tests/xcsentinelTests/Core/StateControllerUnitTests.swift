import Testing
import Foundation
@testable import xcsentinel

@Suite("StateController Unit Tests", .tags(.unit, .fast, .stateManagement))
struct StateControllerUnitTests {
    
    @Test("StateController has shared instance")
    func sharedInstance() {
        let controller1 = StateController.shared
        let controller2 = StateController.shared
        
        // Verify it's a singleton
        #expect(controller1 === controller2)
    }
    
    // Note: stateDirectory and stateFileURL are private/internal
    // so we can't test them directly. We test functionality instead
    // in the StateControllerTests.swift file with integration tests.
}