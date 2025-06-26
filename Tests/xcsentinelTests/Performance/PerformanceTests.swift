import Testing
import Foundation
@testable import xcsentinel

@Suite("Performance Tests", .tags(.slow))
struct PerformanceTests {
    
    // MARK: - State Management Performance
    
    @Test("State file operations perform within acceptable time", .timeLimit(.minutes(1)))
    func stateFilePerformance() async throws {
        let tempDir = try TestHelpers.createTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        setenv("HOME", tempDir.path, 1)
        defer { setenv("HOME", FileManager.default.homeDirectoryForCurrentUser.path, 1) }
        
        let stateController = StateController.shared
        
        // Measure time for various operations
        let measurements = PerformanceMeasurements()
        
        // Test 1: Write performance with increasing data
        for sessionCount in [10, 50, 100, 500, 1000] {
            let startTime = Date()
            
            try await stateController.updateState { state in
                state.globalSessionCounter = sessionCount
                for i in 1...sessionCount {
                    state.logSessions["perf-session-\(i)"] = LogSession(
                        pid: Int32(30000 + i),
                        name: "perf-session-\(i)",
                        targetUDID: "PERF-UDID-\(i)",
                        bundleID: "com.perf.test.\(i)",
                        logPath: "/perf/test-\(i).log",
                        startTime: Date()
                    )
                }
            }
            
            let writeTime = Date().timeIntervalSince(startTime)
            measurements.record("write_\(sessionCount)_sessions", writeTime)
            
            // Test read performance
            let readStart = Date()
            _ = try await stateController.loadState()
            let readTime = Date().timeIntervalSince(readStart)
            measurements.record("read_\(sessionCount)_sessions", readTime)
            
            // Performance expectations
            #expect(writeTime < 1.0, "Write of \(sessionCount) sessions took \(writeTime)s")
            #expect(readTime < 0.5, "Read of \(sessionCount) sessions took \(readTime)s")
        }
        
        measurements.printSummary()
    }
    
    @Test("Concurrent state updates scale appropriately")
    func concurrentStateUpdatePerformance() async throws {
        let tempDir = try TestHelpers.createTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        setenv("HOME", tempDir.path, 1)
        defer { setenv("HOME", FileManager.default.homeDirectoryForCurrentUser.path, 1) }
        
        let stateController = StateController.shared
        let measurements = PerformanceMeasurements()
        
        for concurrentTasks in [1, 5, 10, 20, 50] {
            let startTime = Date()
            
            await withTaskGroup(of: Void.self) { group in
                for i in 1...concurrentTasks {
                    group.addTask {
                        for j in 1...10 {
                            try? await stateController.updateState { state in
                                state.globalSessionCounter += 1
                                let sessionId = "concurrent-\(i)-\(j)"
                                state.logSessions[sessionId] = LogSession(
                                    pid: Int32(40000 + i * 100 + j),
                                    name: sessionId,
                                    targetUDID: "CONC-\(i)-\(j)",
                                    bundleID: "com.concurrent.\(i).\(j)",
                                    logPath: "/concurrent-\(i)-\(j).log",
                                    startTime: Date()
                                )
                            }
                        }
                    }
                }
            }
            
            let duration = Date().timeIntervalSince(startTime)
            measurements.record("concurrent_\(concurrentTasks)_tasks", duration)
            
            // Should complete in reasonable time even with high concurrency
            #expect(duration < Double(concurrentTasks) * 0.5, 
                   "\(concurrentTasks) concurrent tasks took \(duration)s")
        }
        
        measurements.printSummary()
    }
    
    // MARK: - Process Execution Performance
    
    @Test("Process execution overhead is minimal")
    func processExecutionPerformance() async throws {
        let measurements = PerformanceMeasurements()
        
        // Test single command execution
        let singleStart = Date()
        _ = try await ProcessExecutor.execute("/bin/echo", arguments: ["test"])
        let singleDuration = Date().timeIntervalSince(singleStart)
        measurements.record("single_echo_command", singleDuration)
        
        // Test multiple sequential commands
        let sequentialStart = Date()
        for i in 1...100 {
            _ = try await ProcessExecutor.execute("/bin/echo", arguments: ["test \(i)"])
        }
        let sequentialDuration = Date().timeIntervalSince(sequentialStart)
        measurements.record("100_sequential_commands", sequentialDuration)
        
        // Test concurrent command execution
        let concurrentStart = Date()
        await withTaskGroup(of: Void.self) { group in
            for i in 1...100 {
                group.addTask {
                    _ = try? await ProcessExecutor.execute("/bin/echo", arguments: ["concurrent \(i)"])
                }
            }
        }
        let concurrentDuration = Date().timeIntervalSince(concurrentStart)
        measurements.record("100_concurrent_commands", concurrentDuration)
        
        // Performance expectations
        #expect(singleDuration < 0.1, "Single command took \(singleDuration)s")
        #expect(sequentialDuration < 5.0, "100 sequential commands took \(sequentialDuration)s")
        #expect(concurrentDuration < sequentialDuration * 0.5, 
               "Concurrent execution should be faster than sequential")
        
        measurements.printSummary()
    }
    
    // MARK: - Build System Performance
    
    @Test("Makefile staleness check performs efficiently")
    func makefileStalenessCheckPerformance() throws {
        let measurements = PerformanceMeasurements()
        
        // Create a mock project structure
        let projectDir = try TestHelpers.createTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: projectDir) }
        
        let xcodeproj = projectDir.appendingPathComponent("BigProject.xcodeproj")
        try FileManager.default.createDirectory(at: xcodeproj, withIntermediateDirectories: true)
        
        // Create many files to simulate large project
        let fileCount = 1000
        for i in 1...fileCount {
            let file = xcodeproj.appendingPathComponent("file\(i).pbxproj")
            try "// File \(i)".write(to: file, atomically: true, encoding: .utf8)
        }
        
        // Create marker file
        let markerFile = projectDir.appendingPathComponent(".xcsentinel.rc")
        try Data().write(to: markerFile)
        
        // Measure staleness check performance
        let checkStart = Date()
        
        // In real implementation, this would check all files
        let allFiles = try FileManager.default.contentsOfDirectory(atPath: xcodeproj.path)
        var latestModification = Date.distantPast
        
        for file in allFiles {
            let filePath = xcodeproj.appendingPathComponent(file).path
            if let attrs = try? FileManager.default.attributesOfItem(atPath: filePath),
               let modDate = attrs[.modificationDate] as? Date {
                latestModification = max(latestModification, modDate)
            }
        }
        
        let markerAttrs = try FileManager.default.attributesOfItem(atPath: markerFile.path)
        let markerDate = markerAttrs[.modificationDate] as! Date
        let isStale = latestModification > markerDate
        
        let checkDuration = Date().timeIntervalSince(checkStart)
        measurements.record("staleness_check_\(fileCount)_files", checkDuration)
        
        #expect(checkDuration < 1.0, "Checking \(fileCount) files took \(checkDuration)s")
        #expect(!isStale) // Should be fresh initially
        
        measurements.printSummary()
    }
    
    // MARK: - Log Management Performance
    
    @Test("Log file operations handle large files efficiently")
    func logFilePerformance() async throws {
        let tempDir = try TestHelpers.createTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let measurements = PerformanceMeasurements()
        
        // Create log files of various sizes
        let lineCounts = [100, 1000, 10000, 100000]
        
        for lineCount in lineCounts {
            let logFile = tempDir.appendingPathComponent("test-\(lineCount).log")
            
            // Write log file
            let writeStart = Date()
            var logContent = ""
            for i in 1...lineCount {
                logContent += "2024-01-01 12:00:00.000 MyApp[12345:67890] Log line \(i) with some additional content\n"
            }
            try logContent.write(to: logFile, atomically: true, encoding: .utf8)
            let writeDuration = Date().timeIntervalSince(writeStart)
            measurements.record("write_\(lineCount)_lines", writeDuration)
            
            // Read last 100 lines (common operation)
            let readStart = Date()
            let fullContent = try String(contentsOf: logFile)
            let lines = fullContent.components(separatedBy: .newlines)
            let lastHundred = lines.suffix(100).joined(separator: "\n")
            let readDuration = Date().timeIntervalSince(readStart)
            measurements.record("read_last_100_from_\(lineCount)", readDuration)
            
            #expect(!lastHundred.isEmpty)
            #expect(readDuration < 1.0, "Reading from \(lineCount) lines took \(readDuration)s")
        }
        
        measurements.printSummary()
    }
    
    // MARK: - Memory Performance
    
    @Test("Memory usage remains reasonable under load")
    func memoryUsageUnderLoad() async throws {
        let tempDir = try TestHelpers.createTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        setenv("HOME", tempDir.path, 1)
        defer { setenv("HOME", FileManager.default.homeDirectoryForCurrentUser.path, 1) }
        
        let stateController = StateController.shared
        
        // Get baseline memory
        let baselineMemory = getMemoryUsage()
        
        // Create many sessions
        let sessionCount = 10000
        try await stateController.updateState { state in
            for i in 1...sessionCount {
                state.logSessions["memory-test-\(i)"] = LogSession(
                    pid: Int32(50000 + i),
                    name: "memory-test-\(i)",
                    targetUDID: "MEM-\(i)",
                    bundleID: "com.memory.test.\(i)",
                    logPath: "/memory/test-\(i).log",
                    startTime: Date()
                )
            }
        }
        
        // Check memory after load
        let loadedMemory = getMemoryUsage()
        let memoryIncrease = loadedMemory - baselineMemory
        let memoryPerSession = Double(memoryIncrease) / Double(sessionCount)
        
        // Each session should use reasonable memory
        #expect(memoryPerSession < 1024, "Each session uses \(memoryPerSession) bytes")
        
        // Clean up and verify memory is released
        try await stateController.updateState { state in
            state.logSessions.removeAll()
        }
        
        // Give time for memory to be released
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        let finalMemory = getMemoryUsage()
        #expect(finalMemory < loadedMemory, "Memory should decrease after cleanup")
    }
}

// MARK: - Helper Types

class PerformanceMeasurements {
    private var measurements: [String: [TimeInterval]] = [:]
    
    func record(_ operation: String, _ duration: TimeInterval) {
        measurements[operation, default: []].append(duration)
    }
    
    func printSummary() {
        print("\n=== Performance Measurements ===")
        for (operation, durations) in measurements.sorted(by: { $0.key < $1.key }) {
            let avg = durations.reduce(0, +) / Double(durations.count)
            let min = durations.min() ?? 0
            let max = durations.max() ?? 0
            print("\(operation):")
            print("  Average: \(String(format: "%.3f", avg))s")
            print("  Min: \(String(format: "%.3f", min))s")
            print("  Max: \(String(format: "%.3f", max))s")
        }
        print("================================\n")
    }
}

private func getMemoryUsage() -> Int64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
    
    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_,
                     task_flavor_t(MACH_TASK_BASIC_INFO),
                     $0,
                     &count)
        }
    }
    
    return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
}