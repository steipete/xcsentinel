import Testing
import Foundation
@testable import xcsentinel

@Suite("Concurrency Tests", .tags(.unit, .slow), .disabled("Slow tests disabled in CI"))
struct ConcurrencyTests {
    
    // MARK: - State Management Concurrency
    
    @Test("Concurrent state updates maintain consistency", .timeLimit(.minutes(1)))
    func concurrentStateUpdates() async throws {
        let tempDir = try TestHelpers.createTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        setenv("HOME", tempDir.path, 1)
        defer { setenv("HOME", FileManager.default.homeDirectoryForCurrentUser.path, 1) }
        
        let stateController = StateController.shared
        try await stateController.updateState { state in
            // Initialize with clean state
            state = State()
        }
        
        let updateCount = 100
        let tasksPerUpdate = 10
        
        // Launch many concurrent updates
        await withTaskGroup(of: Void.self) { group in
            for i in 1...updateCount {
                for j in 1...tasksPerUpdate {
                    group.addTask {
                        try? await stateController.updateState { state in
                            // Increment counter
                            state.globalSessionCounter += 1
                            
                            // Add a session
                            let sessionId = "session-\(i)-\(j)-\(UUID().uuidString)"
                            state.logSessions[sessionId] = LogSession(
                                pid: Int32(10000 + i * 100 + j),
                                name: sessionId,
                                targetUDID: "UDID-\(i)-\(j)",
                                bundleID: "com.test.\(i).\(j)",
                                logPath: "/test-\(i)-\(j).log",
                                startTime: Date()
                            )
                        }
                    }
                }
            }
        }
        
        // Verify final state
        let finalState = try await stateController.loadState()
        
        // Counter should equal total operations
        #expect(finalState.globalSessionCounter == updateCount * tasksPerUpdate)
        
        // All sessions should be present
        #expect(finalState.logSessions.count == updateCount * tasksPerUpdate)
    }
    
    @Test("Concurrent reads don't interfere with writes")
    func concurrentReadsAndWrites() async throws {
        let tempDir = try TestHelpers.createTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        setenv("HOME", tempDir.path, 1)
        defer { setenv("HOME", FileManager.default.homeDirectoryForCurrentUser.path, 1) }
        
        let stateController = StateController.shared
        try await stateController.updateState { state in
            // Initialize with clean state
            state = State()
        }
        
        let duration: TimeInterval = 2.0
        let endTime = Date().addingTimeInterval(duration)
        
        await withTaskGroup(of: Void.self) { group in
            // Writer tasks
            for i in 1...5 {
                group.addTask {
                    while Date() < endTime {
                        try? await stateController.updateState { state in
                            state.globalSessionCounter += 1
                            state.logSessions["writer-\(i)-\(state.globalSessionCounter)"] = LogSession(
                                pid: Int32(20000 + i),
                                name: "writer-\(i)",
                                targetUDID: "WRITER-\(i)",
                                bundleID: "com.writer.\(i)",
                                logPath: "/writer-\(i).log",
                                startTime: Date()
                            )
                        }
                        // Small delay
                        try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
                    }
                }
            }
            
            // Reader tasks
            for j in 1...10 {
                group.addTask {
                    var readCount = 0
                    while Date() < endTime {
                        do {
                            let state = try await stateController.loadState()
                            #expect(state.globalSessionCounter >= 0)
                            readCount += 1
                        } catch {
                            Issue.record("Read failed: \(error)")
                        }
                        // Small delay
                        try? await Task.sleep(nanoseconds: 5_000_000) // 0.005 seconds
                    }
                    #expect(readCount > 0, "Reader \(j) completed \(readCount) reads")
                }
            }
        }
        
        // Final verification
        let finalState = try await stateController.loadState()
        #expect(finalState.globalSessionCounter > 0)
        #expect(!finalState.logSessions.isEmpty)
    }
    
    // MARK: - Session Management Concurrency
    
    @Test("Concurrent session operations")
    func concurrentSessionOperations() async throws {
        let tempDir = try TestHelpers.createTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        setenv("HOME", tempDir.path, 1)
        defer { setenv("HOME", FileManager.default.homeDirectoryForCurrentUser.path, 1) }
        
        let manager = SessionManager()
        
        // Test with actual session count
        let sessionCount = 20
        
        // Start sessions concurrently
        let sessionNames = await withTaskGroup(of: String?.self) { group in
            for i in 1...sessionCount {
                group.addTask {
                    do {
                        let result = try await manager.startLogSession(
                            udid: "UDID-\(i)",
                            bundleID: "com.test.\(i)"
                        )
                        return result.sessionName
                    } catch {
                        return nil
                    }
                }
            }
            
            var names: [String] = []
            for await name in group {
                if let name = name {
                    names.append(name)
                }
            }
            return names
        }
        
        // Verify all sessions were created with unique names
        let uniqueNames = Set(sessionNames)
        #expect(uniqueNames.count == sessionNames.count)
        
        // List sessions concurrently from multiple tasks
        await withTaskGroup(of: Void.self) { group in
            for _ in 1...10 {
                group.addTask {
                    do {
                        let sessions = try await manager.listSessions()
                        #expect(sessions.count > 0)
                    } catch {
                        Issue.record("List failed: \(error)")
                    }
                }
            }
        }
    }
    
    // MARK: - Process Execution Concurrency
    
    @Test("Concurrent process execution")
    func concurrentProcessExecution() async throws {
        let commands = [
            ("echo", ["Hello 1"]),
            ("echo", ["Hello 2"]),
            ("echo", ["Hello 3"]),
            ("echo", ["Hello 4"]),
            ("echo", ["Hello 5"])
        ]
        
        let results = await withTaskGroup(of: (Int, Result<ProcessResult, Error>).self) { group in
            for (index, (command, args)) in commands.enumerated() {
                group.addTask {
                    do {
                        let result = try await ProcessExecutor.execute("/bin/\(command)", arguments: args)
                        return (index, .success(result))
                    } catch {
                        return (index, .failure(error))
                    }
                }
            }
            
            var results: [(Int, Result<ProcessResult, Error>)] = []
            for await result in group {
                results.append(result)
            }
            return results.sorted { $0.0 < $1.0 }
        }
        
        // Verify all commands succeeded
        #expect(results.count == commands.count)
        
        for (index, result) in results {
            switch result {
            case .success(let processResult):
                #expect(processResult.exitCode == 0)
                #expect(processResult.output.contains("Hello \(index + 1)"))
            case .failure(let error):
                Issue.record("Command \(index) failed: \(error)")
            }
        }
    }
    
    @Test("Async process management with concurrent operations")
    func asyncProcessManagement() async throws {
        let tempDir = try TestHelpers.createTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let processCount = 10
        var processes: [Process] = []
        
        // Start multiple async processes
        for i in 1...processCount {
            let outputPath = tempDir.appendingPathComponent("output-\(i).txt").path
            let process = try await ProcessExecutor.executeAsync(
                "/bin/sh",
                arguments: ["-c", "for j in 1 2 3; do echo 'Process \(i) line $j'; sleep 0.1; done"],
                outputPath: outputPath
            )
            processes.append(process)
        }
        
        // Wait for all to complete
        await withTaskGroup(of: Void.self) { group in
            for process in processes {
                group.addTask {
                    process.waitUntilExit()
                }
            }
        }
        
        // Verify all completed successfully
        for (index, process) in processes.enumerated() {
            #expect(process.terminationStatus == 0)
            
            let outputPath = tempDir.appendingPathComponent("output-\(index + 1).txt").path
            let output = try String(contentsOfFile: outputPath)
            #expect(output.contains("Process \(index + 1)"))
        }
    }
    
    // MARK: - Resource Contention Tests
    
    @Test("Handles file lock contention")
    func fileLockContention() async throws {
        let tempDir = try TestHelpers.createTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let testFile = tempDir.appendingPathComponent("contention-test.txt")
        
        // Create multiple tasks trying to write to the same file
        await withTaskGroup(of: Bool.self) { group in
            for i in 1...20 {
                group.addTask {
                    do {
                        let data = "Writer \(i) was here\n".data(using: .utf8)!
                        
                        // Attempt atomic write
                        try data.write(to: testFile, options: .atomic)
                        return true
                    } catch {
                        return false
                    }
                }
            }
            
            var successCount = 0
            for await success in group {
                if success {
                    successCount += 1
                }
            }
            
            // At least some should succeed
            #expect(successCount > 0)
        }
        
        // File should exist and contain data
        #expect(FileManager.default.fileExists(atPath: testFile.path))
    }
    
    @Test("Stress test with mixed operations")
    func stressTestMixedOperations() async throws {
        let tempDir = try TestHelpers.createTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        setenv("HOME", tempDir.path, 1)
        defer { setenv("HOME", FileManager.default.homeDirectoryForCurrentUser.path, 1) }
        
        let duration: TimeInterval = 3.0
        let endTime = Date().addingTimeInterval(duration)
        
        await withTaskGroup(of: Void.self) { group in
            // State updates
            group.addTask {
                while Date() < endTime {
                    try? await StateController.shared.updateState { state in
                        state.globalSessionCounter += 1
                    }
                    try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                }
            }
            
            // Process execution
            group.addTask {
                while Date() < endTime {
                    _ = try? await ProcessExecutor.execute("/bin/echo", arguments: ["test"])
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                }
            }
            
            // File operations
            group.addTask {
                var counter = 0
                while Date() < endTime {
                    let file = tempDir.appendingPathComponent("test-\(counter).txt")
                    try? "test".write(to: file, atomically: true, encoding: .utf8)
                    try? FileManager.default.removeItem(at: file)
                    counter += 1
                    try? await Task.sleep(nanoseconds: 75_000_000) // 0.075 seconds
                }
            }
        }
        
        // System should still be in a valid state
        let finalState = try await StateController.shared.loadState()
        #expect(finalState.globalSessionCounter > 0)
    }
}