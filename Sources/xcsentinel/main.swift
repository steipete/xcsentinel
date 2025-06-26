import ArgumentParser
import Foundation

// Shared global options
struct GlobalOptions: ParsableArguments {
    @Flag(name: .long, help: "Output in JSON format")
    var json = false
}

@main
struct XCSentinel: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "xcsentinel",
        abstract: "A native macOS CLI tool to augment Xcode development workflow",
        discussion: """
            xcsentinel enhances your Xcode development experience with advanced features:
            
            • Accelerated Builds: Intelligent incremental build system using xcodemake
            • Workflow Automation: Build, install, and launch apps with a single command
            • Log Management: Session-based log streaming with automatic cleanup
            • JSON Support: Machine-readable output for automation and AI agents
            
            Examples:
              Build a project:
                xcsentinel build --scheme MyApp --destination "platform=iOS Simulator,name=iPhone 15"
              
              Build and run:
                xcsentinel run --scheme MyApp --destination "platform=iOS Simulator,name=iPhone 15 Pro"
              
              Start logging:
                xcsentinel log start --udid ABC123 --bundle-id com.example.MyApp
              
              View logs:
                xcsentinel log stop session-1
              
            Use --json flag globally or per-command for JSON output.
            """,
        version: Version.fullVersion,
        subcommands: [BuildCommand.self, RunCommand.self, LogCommand.self, CompletionCommand.self]
    )
    
    @OptionGroup var options: GlobalOptions
    
    mutating func run() async throws {
        // This should never be called as we have subcommands
        throw CleanExit.helpRequest(self)
    }
}

