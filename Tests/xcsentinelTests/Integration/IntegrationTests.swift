import Testing
import Foundation
import ArgumentParser
@testable import xcsentinel

@Suite("Integration Tests", .tags(.integration, .slow))
final class IntegrationTests {
    let tempDirectory: URL
    let originalHome: String
    
    init() throws {
        // Save original home
        originalHome = FileManager.default.homeDirectoryForCurrentUser.path
        
        // Create temp directory
        tempDirectory = try TestHelpers.createTemporaryDirectory()
        
        // Override home directory for tests
        setenv("HOME", tempDirectory.path, 1)
    }
    
    deinit {
        // Restore original home
        setenv("HOME", originalHome, 1)
        
        // Clean up
        try? FileManager.default.removeItem(at: tempDirectory)
    }
    
    @Test("Full command parsing and validation")
    func commandParsing() throws {
        // Test build command parsing
        let buildArgs = ["build", "--scheme", "MyApp", "--destination", "platform=iOS", "--project", "MyApp.xcodeproj"]
        let buildCommand = try XCSentinel.parseAsRoot(buildArgs) as? BuildCommand
        #expect(buildCommand != nil)
        #expect(buildCommand?.scheme == "MyApp")
        #expect(buildCommand?.destination == "platform=iOS")
        #expect(buildCommand?.project == "MyApp.xcodeproj")
        
        // Test run command parsing
        let runArgs = ["run", "--scheme", "MyApp", "--destination", "id=ABC123", "--workspace", "MyApp.xcworkspace", "--json"]
        let runCommand = try XCSentinel.parseAsRoot(runArgs) as? RunCommand
        #expect(runCommand != nil)
        #expect(runCommand?.json == true)
        
        // Test log start command parsing
        let logArgs = ["log", "start", "--udid", "TEST-UDID", "--bundle-id", "com.test.app"]
        _ = try XCSentinel.parseAsRoot(logArgs)
    }
    
    @Test("Invalid command arguments are rejected")
    func invalidArguments() {
        // Missing required arguments
        #expect(throws: Error.self) {
            _ = try XCSentinel.parseAsRoot(["build"])
        }
        
        // Invalid subcommand
        #expect(throws: Error.self) {
            _ = try XCSentinel.parseAsRoot(["invalid-command"])
        }
        
        // Conflicting options
        #expect(throws: Error.self) {
            _ = try XCSentinel.parseAsRoot(["build", "--scheme", "App", "--destination", "iOS", "--workspace", "W.xcworkspace", "--project", "P.xcodeproj"])
        }
    }
    
    @Test("Version command outputs correctly")
    func versionCommand() throws {
        let output = captureOutput {
            _ = try? XCSentinel.parseAsRoot(["--version"])
        }
        
        #expect(output.contains("1.0.0"))
    }
    
    @Test("Help command provides usage information")
    func helpCommand() throws {
        let output = captureOutput {
            _ = try? XCSentinel.parseAsRoot(["--help"])
        }
        
        #expect(output.contains("xcsentinel"))
        #expect(output.contains("build"))
        #expect(output.contains("run"))
        #expect(output.contains("log"))
    }
    
    @Test("Completion generation works for all shells")
    func completionGeneration() throws {
        // Bash completion
        let bashCompletion = try XCSentinel.completionScript(for: .bash)
        #expect(bashCompletion.contains("_xcsentinel"))
        #expect(bashCompletion.contains("COMPREPLY"))
        
        // Zsh completion
        let zshCompletion = try XCSentinel.completionScript(for: .zsh)
        #expect(zshCompletion.contains("#compdef xcsentinel"))
        
        // Fish completion
        let fishCompletion = try XCSentinel.completionScript(for: .fish)
        #expect(fishCompletion.contains("complete -c xcsentinel"))
    }
    
    @Test("State persistence across command invocations", .serialized)
    func statePersistence() throws {
        let stateController = StateController.shared
        
        // First invocation: create some state
        try stateController.updateState { state in
            state.globalSessionCounter = 42
            state.logSessions["test"] = LogSession(
                pid: 12345,
                name: "test",
                targetUDID: "TEST",
                bundleID: "com.test",
                logPath: "/test.log",
                startTime: Date()
            )
        }
        
        // Simulate new invocation by creating new controller
        // (In reality, each CLI invocation gets a fresh StateController.shared)
        let loadedState = try stateController.loadState()
        
        #expect(loadedState.globalSessionCounter == 42)
        #expect(loadedState.logSessions["test"] != nil)
    }
    
    @Test("JSON output format validation")
    func jsonOutputFormat() throws {
        let formatter = OutputFormatter(json: true)
        
        let output = captureOutput {
            formatter.success(BuildSuccessResponse(success: true, message: "Test"))
        }
        
        // Verify it's valid JSON
        let data = Data(output.utf8)
        let json = try JSONSerialization.jsonObject(with: data)
        #expect(json != nil)
    }
    
    // Helper to capture stdout
    private func captureOutput(_ block: () throws -> Void) rethrows -> String {
        let pipe = Pipe()
        let original = dup(STDOUT_FILENO)
        
        setvbuf(stdout, nil, _IONBF, 0)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        
        try block()
        
        fflush(stdout)
        pipe.fileHandleForWriting.closeFile()
        dup2(original, STDOUT_FILENO)
        close(original)
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

@Suite("End-to-End Workflow Tests", .tags(.integration), .serialized)
final class EndToEndTests {
    let tempDirectory: URL
    
    init() throws {
        tempDirectory = try TestHelpers.createTemporaryDirectory()
    }
    
    deinit {
        try? FileManager.default.removeItem(at: tempDirectory)
    }
    
    @Test("Build workflow with Makefile", .timeLimit(.minutes(1)))
    func buildWorkflow() throws {
        // Create a mock project
        let projectURL = try TestHelpers.createMockXcodeProject(at: tempDirectory)
        
        // Create a simple Makefile
        let makefileContent = """
        .PHONY: all clean
        
        all:
        \t@echo "Building MyApp..."
        \t@mkdir -p build/Debug-iphonesimulator
        \t@echo "Build complete"
        
        clean:
        \t@rm -rf build
        """
        try makefileContent.write(
            to: tempDirectory.appendingPathComponent("Makefile"),
            atomically: true,
            encoding: .utf8
        )
        
        // Run build
        let engine = BuildEngine()
        let config = BuildEngine.BuildConfiguration(
            scheme: "MyApp",
            destination: "generic/platform=iOS",
            workspace: nil,
            project: projectURL.path,
            noIncremental: false
        )
        
        let result = try engine.build(configuration: config)
        
        #expect(result.exitCode == 0)
        #expect(result.output.contains("Build complete"))
        
        // Verify marker file was created
        let markerPath = tempDirectory.appendingPathComponent(".xcsentinel.rc").path
        #expect(FileManager.default.fileExists(atPath: markerPath))
    }
    
    @Test("Log session lifecycle", .timeLimit(.minutes(1)))
    func logSessionLifecycle() async throws {
        // Override HOME for this test
        let originalHome = FileManager.default.homeDirectoryForCurrentUser.path
        setenv("HOME", tempDirectory.path, 1)
        defer { setenv("HOME", originalHome, 1) }
        
        let manager = SessionManager()
        let stateController = StateController.shared
        
        // Manually create a session since we can't actually start log processes
        let logDir = tempDirectory.appendingPathComponent(".xcsentinel/logs")
        try FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        
        let logPath = logDir.appendingPathComponent("test-session.log").path
        try "Test log content\nLine 2\nLine 3".write(
            toFile: logPath,
            atomically: true,
            encoding: .utf8
        )
        
        try stateController.updateState { state in
            state.globalSessionCounter = 1
            state.logSessions["session-1"] = LogSession(
                pid: Int32(ProcessInfo.processInfo.processIdentifier),
                name: "session-1",
                targetUDID: "TEST-DEVICE",
                bundleID: "com.test.app",
                logPath: logPath,
                startTime: Date()
            )
        }
        
        // List sessions
        let sessions = try manager.listSessions()
        #expect(sessions.count == 1)
        #expect(sessions.first?.name == "session-1")
        
        // Stop session
        let output = try manager.stopLogSession(sessionName: "session-1", fullOutput: true)
        #expect(output.contains("Test log content"))
        #expect(output.contains("Line 3"))
        
        // Verify session was removed
        let finalSessions = try manager.listSessions()
        #expect(finalSessions.isEmpty)
    }
}