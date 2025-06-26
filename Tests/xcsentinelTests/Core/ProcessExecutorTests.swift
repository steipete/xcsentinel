import Testing
import Foundation
@testable import xcsentinel

@Suite("ProcessExecutor Tests", .tags(.processExecution, .unit, .fast))
struct ProcessExecutorTests {
    
    // MARK: - Basic Command Execution
    
    @Test("Executes commands and captures output", arguments: [
        ("/bin/echo", ["Hello"], "Hello", "", 0),
        ("/bin/echo", ["Multiple", "Words"], "Multiple Words", "", 0),
        ("/bin/echo", ["-n", "No newline"], "No newline", "", 0),
        ("/usr/bin/true", [], "", "", 0),
        ("/usr/bin/false", [], "", "", 1)
    ])
    func executeCommands(
        command: String,
        arguments: [String],
        expectedOutput: String,
        expectedError: String,
        expectedExitCode: Int32
    ) async throws {
        let result = try await ProcessExecutor.execute(command, arguments: arguments)
        
        #expect(result.exitCode == expectedExitCode)
        #expect(result.output.trimmingCharacters(in: .whitespacesAndNewlines) == expectedOutput)
        #expect(result.error.trimmingCharacters(in: .whitespacesAndNewlines) == expectedError)
    }
    
    @Test("Captures stdout and stderr separately")
    func capturesOutputStreams() async throws {
        // Test stderr capture
        let stderrResult = try await ProcessExecutor.execute(
            "/bin/sh",
            arguments: ["-c", "echo 'To stderr' >&2; echo 'To stdout'"]
        )
        
        #expect(stderrResult.output.trimmingCharacters(in: .whitespacesAndNewlines) == "To stdout")
        #expect(stderrResult.error.trimmingCharacters(in: .whitespacesAndNewlines) == "To stderr")
        #expect(stderrResult.exitCode == 0)
    }
    
    @Test("Execute respects working directory")
    func workingDirectory() async throws {
        let tempDir = try TestHelpers.createTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let result = try await ProcessExecutor.execute(
            "/bin/pwd",
            currentDirectory: tempDir
        )
        
        #expect(result.output == tempDir.path)
        #expect(result.exitCode == 0)
    }
    
    @Test("Execute passes environment variables")
    func environmentVariables() async throws {
        let result = try await ProcessExecutor.execute(
            "/bin/sh",
            arguments: ["-c", "echo $TEST_VAR"],
            environment: ["TEST_VAR": "test_value"]
        )
        
        #expect(result.output == "test_value")
        #expect(result.exitCode == 0)
    }
    
    @Test("Execute throws on invalid executable")
    func invalidExecutable() async {
        await #expect(throws: XCSentinelError.self) {
            _ = try await ProcessExecutor.execute("/nonexistent/command")
        }
    }
    
    // MARK: - Asynchronous Execution
    
    @Test("Executes processes asynchronously with file output", .timeLimit(.minutes(1)))
    func executeAsync() async throws {
        let tempDir = try TestHelpers.createTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let outputPath = tempDir.appendingPathComponent("async-output.txt").path
        
        // Start async process
        let process = try await ProcessExecutor.executeAsync(
            "/bin/sh",
            arguments: ["-c", "for i in 1 2 3; do echo \"Line $i\"; sleep 0.1; done"],
            outputPath: outputPath
        )
        
        // Verify process started
        #expect(process.isRunning || process.terminationStatus == 0)
        
        // Wait for completion
        process.waitUntilExit()
        #expect(!process.isRunning)
        #expect(process.terminationStatus == 0)
        
        // Verify output was written correctly
        let output = try String(contentsOfFile: outputPath)
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        #expect(lines.count == 3)
        #expect(lines == ["Line 1", "Line 2", "Line 3"])
    }
    
    @Test("Async process can be terminated")
    func terminateAsyncProcess() async throws {
        let tempDir = try TestHelpers.createTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let outputPath = tempDir.appendingPathComponent("terminated.txt").path
        
        // Start long-running process
        let process = try await ProcessExecutor.executeAsync(
            "/bin/sh",
            arguments: ["-c", "while true; do echo 'Running'; sleep 0.1; done"],
            outputPath: outputPath
        )
        
        #expect(process.isRunning)
        
        // Terminate after a short delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        process.terminate()
        process.waitUntilExit()
        
        #expect(!process.isRunning)
        #expect(process.terminationStatus != 0)
    }
    
    // MARK: - Executable Discovery
    
    @Test("Finds executables in PATH", arguments: [
        ("ls", true),
        ("echo", true),
        ("cat", true),
        ("grep", true),
        ("nonexistent_command_xyz_123", false),
        ("this-should-not-exist", false)
    ])
    func findExecutables(command: String, shouldExist: Bool) async {
        let path = await ProcessExecutor.findExecutable(command)
        
        if shouldExist {
            #expect(path != nil, "Expected to find \(command) in PATH")
            if let foundPath = path {
                #expect(FileManager.default.fileExists(atPath: foundPath))
            }
        } else {
            #expect(path == nil, "Expected \(command) to not exist")
        }
    }
    
    // MARK: - Complex Command Scenarios
    
    @Test("Handles shell scripts with multiple commands")
    func shellScripts() async throws {
        let script = "echo 'First'; echo 'Second' >&2; echo 'Third'; exit 42"
        let result = try await ProcessExecutor.execute("/bin/sh", arguments: ["-c", script])
        
        #expect(result.exitCode == 42)
        #expect(result.output.contains("First"))
        #expect(result.output.contains("Third"))
        #expect(result.error.contains("Second"))
    }
    
    @Test("Handles large output efficiently", .timeLimit(.minutes(1)))
    func largeOutput() async throws {
        // Generate substantial output to test buffer handling
        let lineCount = 10_000
        let result = try await ProcessExecutor.execute(
            "/bin/sh",
            arguments: ["-c", "seq 1 \(lineCount)"]
        )
        
        #expect(result.exitCode == 0)
        
        let lines = result.output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        #expect(lines.count == lineCount)
        #expect(lines.first == "1")
        #expect(lines.last == "\(lineCount)")
    }
}