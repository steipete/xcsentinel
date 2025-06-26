import ArgumentParser
import Foundation

@main
struct XCSentinel: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "xcsentinel",
        abstract: "A native macOS CLI tool to augment Xcode development workflow",
        version: Version.fullVersion,
        subcommands: [BuildCommand.self, RunCommand.self, LogCommand.self, CompletionCommand.self]
    )
}