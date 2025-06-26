import ArgumentParser
import Foundation

struct CompletionCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "completion",
        abstract: "Generate shell completion scripts",
        subcommands: [BashCompletion.self, ZshCompletion.self, FishCompletion.self]
    )
}

struct BashCompletion: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bash",
        abstract: "Generate bash completion script"
    )
    
    func run() throws {
        let completions = XCSentinel.completionScript(for: .bash)
        print(completions)
    }
}

struct ZshCompletion: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "zsh",
        abstract: "Generate zsh completion script"
    )
    
    func run() throws {
        let completions = XCSentinel.completionScript(for: .zsh)
        print(completions)
    }
}

struct FishCompletion: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "fish",
        abstract: "Generate fish completion script"
    )
    
    func run() throws {
        let completions = XCSentinel.completionScript(for: .fish)
        print(completions)
    }
}