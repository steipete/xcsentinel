import Testing
import Foundation
@testable import xcsentinel

@Suite("RunCommand Tests", .tags(.commandParsing, .deviceHandling, .unit))
struct RunCommandTests {
    
    @Test("RunCommand inherits BuildCommand properties")
    func inheritsFromBuildCommand() {
        let command = RunCommand()
        
        // Verify it has all BuildCommand properties
        #expect(command.workspace == nil)
        #expect(command.project == nil)
        #expect(command.scheme == "")
        #expect(command.destination == "")
        #expect(!command.options.json)
    }
    
    @Test("RunCommand validates required fields")
    func validateRequiredFields() throws {
        var command = RunCommand()
        
        // Should fail without required fields
        #expect(throws: Error.self) {
            try command.validate()
        }
        
        // Add required fields one by one
        command.scheme = "MyApp"
        #expect(throws: Error.self) {
            try command.validate()
        }
        
        command.destination = "platform=iOS Simulator,name=iPhone 15"
        #expect(throws: Error.self) {
            try command.validate()
        }
        
        command.workspace = "MyApp.xcworkspace"
        #expect(throws: Never.self) {
            try command.validate()
        }
    }
    
    @Test("RunCommand handles different destination formats")
    func destinationFormats() {
        var command = RunCommand()
        command.scheme = "MyApp"
        command.workspace = "MyApp.xcworkspace"
        
        // Test various destination formats
        let destinations = [
            "platform=iOS Simulator,name=iPhone 15",
            "platform=iOS,id=00008110-001234567890ABCD",
            "id=12345678-1234-1234-1234-123456789012",
            "platform=macOS",
            "platform=iOS Simulator,name=iPhone 15 Pro Max,OS=17.5"
        ]
        
        for dest in destinations {
            command.destination = dest
            #expect(throws: Never.self) {
                try command.validate()
            }
        }
    }
}