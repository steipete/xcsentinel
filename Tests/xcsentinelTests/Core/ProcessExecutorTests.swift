import Testing
import Foundation
@testable import xcsentinel

@Suite("ProcessExecutor Tests", .tags(.fast))
struct ProcessExecutorTests {
    
    @Test("Execute runs simple command successfully")
    func executeSimpleCommand() throws {
        let result = try ProcessExecutor.execute("/bin/echo", arguments: ["Hello, World!"])
        
        #expect(result.exitCode == 0)
        #expect(result.output == "Hello, World!")
        #expect(result.error.isEmpty)
    }
    
    @Test("Execute captures error output")
    func captureErrorOutput() throws {
        // Use a command that writes to stderr
        let result = try ProcessExecutor.execute("/bin/sh", arguments: ["-c", "echo 'Error message' >&2"])
        
        #expect(result.exitCode == 0)
        #expect(result.output.isEmpty)
        #expect(result.error == "Error message")
    }
    
    @Test("Execute handles non-zero exit codes")
    func nonZeroExitCode() throws {
        let result = try ProcessExecutor.execute("/bin/false")
        
        #expect(result.exitCode != 0)
    }
    
    @Test("Execute respects working directory")
    func workingDirectory() throws {
        let tempDir = try TestHelpers.createTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let result = try ProcessExecutor.execute(
            "/bin/pwd",
            currentDirectory: tempDir
        )
        
        #expect(result.output == tempDir.path)
        #expect(result.exitCode == 0)
    }
    
    @Test("Execute passes environment variables")
    func environmentVariables() throws {
        let result = try ProcessExecutor.execute(
            "/bin/sh",
            arguments: ["-c", "echo $TEST_VAR"],
            environment: ["TEST_VAR": "test_value"]
        )
        
        #expect(result.output == "test_value")
        #expect(result.exitCode == 0)
    }
    
    @Test("Execute throws on invalid executable")
    func invalidExecutable() {
        #expect(throws: XCSentinelError.self) {
            _ = try ProcessExecutor.execute("/nonexistent/command")
        }
    }
    
    @Test("ExecuteAsync starts process without blocking", .timeLimit(.minutes(1)))
    func executeAsync() async throws {
        let tempDir = try TestHelpers.createTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let outputPath = tempDir.appendingPathComponent("output.txt").path
        
        // Start async process that sleeps briefly then writes
        let process = try ProcessExecutor.executeAsync(
            "/bin/sh",
            arguments: ["-c", "sleep 0.1 && echo 'Async output'"],
            outputPath: outputPath
        )
        
        // Process should be running
        #expect(process.isRunning)
        
        // Wait for completion
        process.waitUntilExit()
        
        // Check output was written
        let output = try String(contentsOfFile: outputPath)
        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "Async output")
    }
    
    @Test("FindExecutable locates system commands")
    func findExecutable() {
        // Test with common system commands
        #expect(ProcessExecutor.findExecutable("ls") != nil)
        #expect(ProcessExecutor.findExecutable("echo") != nil)
        #expect(ProcessExecutor.findExecutable("swift") != nil)
        
        // Test with non-existent command
        #expect(ProcessExecutor.findExecutable("nonexistent_command_xyz") == nil)
    }
    
    @Test("Execute handles commands with complex arguments")
    func complexArguments() throws {
        let args = [
            "-c",
            "echo 'Line 1'; echo 'Line 2'; echo 'Line 3'"
        ]
        
        let result = try ProcessExecutor.execute("/bin/sh", arguments: args)
        
        #expect(result.exitCode == 0)
        let lines = result.output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        #expect(lines.count == 3)
        #expect(lines[0] == "Line 1")
        #expect(lines[1] == "Line 2")
        #expect(lines[2] == "Line 3")
    }
    
    @Test("Execute handles very long output")
    func longOutput() throws {
        // Generate 1000 lines of output
        let result = try ProcessExecutor.execute(
            "/bin/sh",
            arguments: ["-c", "for i in $(seq 1 1000); do echo \"Line $i\"; done"]
        )
        
        #expect(result.exitCode == 0)
        let lines = result.output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        #expect(lines.count == 1000)
        #expect(lines.first == "Line 1")
        #expect(lines.last == "Line 1000")
    }
}