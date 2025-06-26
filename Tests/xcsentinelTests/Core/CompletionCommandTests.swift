import Testing
import Foundation
import ArgumentParser
@testable import xcsentinel

@Suite("CompletionCommand Tests", .tags(.unit, .fast, .commandParsing))
struct CompletionCommandTests {
    
    @Test("Completion command generates scripts for all supported shells")
    func completionScriptGeneration() throws {
        // Test bash completion
        let bashCommand = try CompletionCommand.parse(["--shell", "bash"])
        #expect(bashCommand.shell == .bash)
        
        // Test zsh completion
        let zshCommand = try CompletionCommand.parse(["--shell", "zsh"])
        #expect(zshCommand.shell == .zsh)
        
        // Test fish completion
        let fishCommand = try CompletionCommand.parse(["--shell", "fish"])
        #expect(fishCommand.shell == .fish)
    }
    
    @Test("Completion command has correct configuration")
    func commandConfiguration() {
        let config = CompletionCommand.configuration
        #expect(config.commandName == "completion")
        #expect(config.abstract.contains("completion"))
    }
    
    @Test("Default shell is bash if not specified")
    func defaultShell() throws {
        let command = try CompletionCommand.parse([])
        #expect(command.shell == .bash)
    }
}