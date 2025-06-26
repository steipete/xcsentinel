import Testing
import Foundation
@testable import xcsentinel

@Suite("RunCommand Tests", .tags(.commandParsing, .deviceHandling, .unit))
struct RunCommandTests {
    
    @Test("RunCommand inherits BuildCommand properties")
    func inheritsFromBuildCommand() throws {
        // Parse with minimum required arguments
        let command = try RunCommand.parse(["--scheme", "MyApp", "--destination", "platform=iOS", "--workspace", "MyApp.xcworkspace"])
        
        // Verify parsed properties
        #expect(command.workspace == "MyApp.xcworkspace")
        #expect(command.project == nil)
        #expect(command.scheme == "MyApp")
        #expect(command.destination == "platform=iOS")
        #expect(!command.options.json)
    }
    
    @Test("RunCommand validates required fields")
    func validateRequiredFields() throws {
        // Test missing scheme
        #expect(throws: Error.self) {
            _ = try RunCommand.parse(["--destination", "platform=iOS", "--workspace", "MyApp.xcworkspace"])
        }
        
        // Test missing destination
        #expect(throws: Error.self) {
            _ = try RunCommand.parse(["--scheme", "MyApp", "--workspace", "MyApp.xcworkspace"])
        }
        
        // Test missing workspace and project - ArgumentParser allows this, validation happens later
        let cmdNoWorkspace = try RunCommand.parse(["--scheme", "MyApp", "--destination", "platform=iOS"])
        #expect(cmdNoWorkspace.workspace == nil)
        #expect(cmdNoWorkspace.project == nil)
        
        // Should succeed with all required fields
        let command = try RunCommand.parse(["--scheme", "MyApp", "--destination", "platform=iOS", "--workspace", "MyApp.xcworkspace"])
        #expect(command.scheme == "MyApp")
        #expect(command.destination == "platform=iOS")
        #expect(command.workspace == "MyApp.xcworkspace")
    }
    
    @Test("RunCommand handles different destination formats")
    func destinationFormats() throws {
        // Test various destination formats
        let destinations = [
            "platform=iOS Simulator,name=iPhone 15",
            "platform=iOS,id=00008110-001234567890ABCD",
            "id=12345678-1234-1234-1234-123456789012",
            "platform=macOS",
            "platform=iOS Simulator,name=iPhone 15 Pro Max,OS=17.5"
        ]
        
        for dest in destinations {
            let command = try RunCommand.parse(["--scheme", "MyApp", "--destination", dest, "--workspace", "MyApp.xcworkspace"])
            #expect(command.destination == dest)
        }
    }
}