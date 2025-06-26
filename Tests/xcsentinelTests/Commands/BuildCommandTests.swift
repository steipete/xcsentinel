import Testing
import Foundation
import ArgumentParser
@testable import xcsentinel

@Suite("BuildCommand Tests", .tags(.commandParsing, .buildSystem, .unit))
struct BuildCommandTests {
    
    @Test("BuildCommand has correct configuration")
    func commandConfiguration() {
        let config = BuildCommand.configuration
        #expect(config.commandName == "build")
        #expect(config.abstract == "Build an Xcode project or workspace")
        #expect(config.discussion != nil)
    }
    
    @Test("BuildCommand initializes with correct defaults")
    func defaultValues() throws {
        // We can't directly instantiate the command without parsing,
        // so we test the configuration instead
        let helpText = BuildCommand.helpMessage()
        #expect(helpText.contains("--scheme"))
        #expect(helpText.contains("--destination"))
        #expect(helpText.contains("--workspace"))
        #expect(helpText.contains("--project"))
        #expect(helpText.contains("--no-incremental"))
        #expect(helpText.contains("--json"))
    }
    
    @Test("BuildCommand help includes examples")
    func helpExamples() {
        let helpText = BuildCommand.helpMessage()
        #expect(helpText.contains("Examples:"))
        #expect(helpText.contains("Build with workspace:"))
        #expect(helpText.contains("Build with project:"))
        #expect(helpText.contains("Force clean build"))
    }
    
    @Test("BuildCommand async execution")
    func asyncExecution() async throws {
        // Test that BuildCommand conforms to AsyncParsableCommand
        // This is a compile-time test - if it compiles, it passes
        let _: AsyncParsableCommand.Type = BuildCommand.self
        #expect(true) // Compilation success means the test passes
    }
}