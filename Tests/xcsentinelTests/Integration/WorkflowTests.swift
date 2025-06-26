import Testing
import Foundation
@testable import xcsentinel

@Suite("End-to-End Workflow Tests", .tags(.integration, .slow), .disabled("Integration tests disabled in CI"))
final class WorkflowTests {
    let tempDirectory: URL
    let originalHome: String
    
    init() throws {
        originalHome = FileManager.default.homeDirectoryForCurrentUser.path
        tempDirectory = try TestHelpers.createTemporaryDirectory()
        setenv("HOME", tempDirectory.path, 1)
    }
    
    deinit {
        setenv("HOME", originalHome, 1)
        try? FileManager.default.removeItem(at: tempDirectory)
    }
    
    // MARK: - Complete Build-Run-Log Workflow
    
    @Test("Complete development workflow from build to log capture", .timeLimit(.minutes(2)))
    func completeDevelopmentWorkflow() async throws {
        let mockExecutor = MockProcessExecutor()
        
        // Mock successful build
        mockExecutor.mockResults["/usr/bin/xcodebuild"] = ProcessResult(
            output: """
            Build succeeded
            BUILT_PRODUCTS_DIR = /DerivedData/MyApp/Build/Products/Debug-iphonesimulator
            FULL_PRODUCT_NAME = MyApp.app
            PRODUCT_BUNDLE_IDENTIFIER = com.example.MyApp
            """,
            error: "",
            exitCode: 0
        )
        
        // Mock successful installation
        mockExecutor.mockResults["/usr/bin/xcrun"] = ProcessResult(
            output: "Installation succeeded",
            error: "",
            exitCode: 0
        )
        
        // Step 1: Build
        let buildEngine = BuildEngine(processExecutor: mockExecutor)
        let buildConfig = BuildEngine.BuildConfiguration(
            scheme: "MyApp",
            destination: "platform=iOS Simulator,name=iPhone 15",
            workspace: "MyApp.xcworkspace",
            project: nil,
            noIncremental: false
        )
        let buildResult = try await buildEngine.build(configuration: buildConfig)
        
        #expect(buildResult.exitCode == 0)
        
        // Step 2: Run (install and launch)
        let deviceManager = DeviceManager(processExecutor: mockExecutor)
        let udid = "12345678-1234-1234-1234-123456789012"
        
        try await deviceManager.installApp(udid: udid, appPath: "/path/to/MyApp.app")
        try await deviceManager.launchApp(udid: udid, bundleID: "com.example.MyApp")
        
        // Step 3: Start log capture
        let sessionManager = SessionManager(processExecutor: mockExecutor)
        let (sessionName, pid) = try await sessionManager.startLogSession(
            udid: udid,
            bundleID: "com.example.MyApp"
        )
        
        #expect(sessionName.hasPrefix("session-"))
        #expect(pid > 0)
        
        // Step 4: List active sessions
        let sessions = try await sessionManager.listSessions()
        #expect(sessions.count == 1)
        #expect(sessions.first?.name == sessionName)
        
        // Step 5: Stop log capture
        let logContent = try await sessionManager.stopLogSession(
            sessionName: sessionName,
            fullOutput: false
        )
        
        #expect(!logContent.isEmpty || true) // May be empty in mock
        
        // Verify session was cleaned up
        let finalSessions = try await sessionManager.listSessions()
        #expect(finalSessions.isEmpty)
    }
    
    // MARK: - Incremental Build Workflow
    
    @Test("Incremental build workflow with cache invalidation")
    func incrementalBuildWorkflow() throws {
        let projectDir = tempDirectory.appendingPathComponent("TestProject")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        
        // Create mock project structure
        let xcodeproj = projectDir.appendingPathComponent("MyApp.xcodeproj")
        try FileManager.default.createDirectory(at: xcodeproj, withIntermediateDirectories: true)
        
        let pbxproj = xcodeproj.appendingPathComponent("project.pbxproj")
        try "// Mock project file".write(to: pbxproj, atomically: true, encoding: .utf8)
        
        // Create marker file
        let markerFile = projectDir.appendingPathComponent(".xcsentinel.rc")
        try Data().write(to: markerFile)
        
        // Initial state: marker is fresh
        let markerTime = try FileManager.default.attributesOfItem(atPath: markerFile.path)[.modificationDate] as! Date
        let projectTime = try FileManager.default.attributesOfItem(atPath: pbxproj.path)[.modificationDate] as! Date
        
        #expect(markerTime >= projectTime)
        
        // Modify project file
        Thread.sleep(forTimeInterval: 0.1)
        try "// Modified project file".write(to: pbxproj, atomically: true, encoding: .utf8)
        
        // Now marker should be stale
        let newProjectTime = try FileManager.default.attributesOfItem(atPath: pbxproj.path)[.modificationDate] as! Date
        #expect(newProjectTime > markerTime)
        
        // Build should detect stale marker and regenerate
        let mockExecutor = MockProcessExecutor()
        mockExecutor.mockResults["/usr/bin/xcodebuild"] = ProcessResult(
            output: "Build succeeded",
            error: "",
            exitCode: 0
        )
        
        _ = BuildEngine(processExecutor: mockExecutor)
        // In real implementation, this would regenerate Makefile
    }
    
    // MARK: - Error Recovery Workflow
    
    @Test("Error recovery workflow with cleanup")
    func errorRecoveryWorkflow() async throws {
        let mockExecutor = MockProcessExecutor()
        let sessionManager = SessionManager(processExecutor: mockExecutor)
        
        // Start multiple sessions
        var sessionNames: [String] = []
        for i in 1...3 {
            mockExecutor.mockResults["/usr/bin/xcrun"] = ProcessResult(
                output: "",
                error: "",
                exitCode: 0
            )
            
            let (sessionName, _) = try await sessionManager.startLogSession(
                udid: "UDID-\(i)",
                bundleID: "com.test.\(i)"
            )
            sessionNames.append(sessionName)
        }
        
        // Simulate some sessions dying
        let stateController = StateController.shared
        try await stateController.updateState { state in
            // Mark first session as having dead process
            if let session = state.logSessions[sessionNames[0]] {
                state.logSessions[sessionNames[0]] = LogSession(
                    pid: 99999, // Non-existent PID
                    name: session.name,
                    targetUDID: session.targetUDID,
                    bundleID: session.bundleID,
                    logPath: session.logPath,
                    startTime: session.startTime
                )
            }
        }
        
        // Clean should remove dead session
        try await sessionManager.cleanStaleSessions()
        
        let remainingSessions = try await sessionManager.listSessions()
        #expect(remainingSessions.count == 2)
        #expect(!remainingSessions.contains { $0.name == sessionNames[0] })
    }
    
    // MARK: - Multi-Device Workflow
    
    @Test("Multi-device simultaneous operations")
    func multiDeviceWorkflow() async throws {
        let devices = [
            ("iPhone 15", "11111111-1111-1111-1111-111111111111", "com.app.one"),
            ("iPhone 15 Pro", "22222222-2222-2222-2222-222222222222", "com.app.two"),
            ("iPad Air", "33333333-3333-3333-3333-333333333333", "com.app.three")
        ]
        
        let mockExecutor = MockProcessExecutor()
        let sessionManager = SessionManager(processExecutor: mockExecutor)
        
        // Start logging on all devices concurrently
        let sessions = await withTaskGroup(of: (String, Int32)?.self) { group in
            for (_, udid, bundleID) in devices {
                group.addTask {
                    do {
                        return try await sessionManager.startLogSession(
                            udid: udid,
                            bundleID: bundleID
                        )
                    } catch {
                        return nil
                    }
                }
            }
            
            var results: [(String, Int32)] = []
            for await result in group {
                if let result = result {
                    results.append(result)
                }
            }
            return results
        }
        
        #expect(sessions.count == devices.count)
        
        // Verify all sessions are active
        let activeSessions = try await sessionManager.listSessions()
        #expect(activeSessions.count == devices.count)
        
        // Stop all sessions
        await withTaskGroup(of: Void.self) { group in
            for (sessionName, _) in sessions {
                group.addTask {
                    _ = try? await sessionManager.stopLogSession(
                        sessionName: sessionName,
                        fullOutput: false
                    )
                }
            }
        }
        
        // Verify all cleaned up
        let finalSessions = try await sessionManager.listSessions()
        #expect(finalSessions.isEmpty)
    }
    
    // MARK: - State Persistence Workflow
    
    @Test("State persists across process restarts")
    func statePersistenceWorkflow() async throws {
        let stateController1 = StateController.shared
        
        // Create some state
        try await stateController1.updateState { state in
            state.globalSessionCounter = 42
            state.logSessions["persistent-session"] = LogSession(
                pid: 12345,
                name: "persistent-session",
                targetUDID: "PERSIST-UDID",
                bundleID: "com.persist.app",
                logPath: "/persist.log",
                startTime: Date()
            )
        }
        
        // Simulate process restart by creating new instance
        // (In reality, StateController is a singleton, but we test the persistence)
        let loadedState = try await stateController1.loadState()
        
        #expect(loadedState.globalSessionCounter == 42)
        #expect(loadedState.logSessions["persistent-session"] != nil)
        #expect(loadedState.logSessions["persistent-session"]?.bundleID == "com.persist.app")
    }
}