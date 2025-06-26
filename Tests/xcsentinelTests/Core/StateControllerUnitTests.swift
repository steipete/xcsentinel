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
    
    @Test("State directory URL is correct")
    func stateDirectoryURL() {
        let controller = StateController.shared
        let expectedPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".xcsentinel")
        
        #expect(controller.stateDirectory == expectedPath)
    }
    
    @Test("State file URL is correct")
    func stateFileURL() {
        let controller = StateController.shared
        let expectedPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".xcsentinel")
            .appendingPathComponent("state.json")
        
        #expect(controller.stateFileURL == expectedPath)
    }
}