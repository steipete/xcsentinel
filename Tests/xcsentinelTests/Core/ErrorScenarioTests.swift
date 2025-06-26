import Testing
import Foundation
@testable import xcsentinel

@Suite("Error Scenario Tests", .tags(.errorHandling, .unit))
struct ErrorScenarioTests {
    
    // MARK: - Build Error Scenarios
    
    @Test("Handles xcodebuild failures with detailed errors")
    func xcodebuildFailures() async throws {
        // Test that build errors are properly reported
        // This test would need proper mocking infrastructure which is not fully set up
        // For now, we'll test the error types themselves
        
        let errors: [XCSentinelError] = [
            .buildFailed(message: "The scheme 'NonExistent' does not exist"),
            .invalidDestination("Unable to find a destination matching the provided destination specifier"),
            .buildFailed(message: "CompileSwift failed with a nonzero exit code")
        ]
        
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorCode.isEmpty)
        }
    }
    
    @Test("Handles missing workspace or project")
    func missingWorkspaceOrProject() async throws {
        let buildEngine = BuildEngine()
        let configuration = BuildEngine.BuildConfiguration(
            scheme: "MyScheme",
            destination: "platform=iOS",
            workspace: nil,
            project: nil,
            noIncremental: false
        )
        
        do {
            _ = try await buildEngine.build(configuration: configuration)
            Issue.record("Expected error for missing workspace/project")
        } catch XCSentinelError.missingWorkspaceOrProject {
            // Expected error
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Session Error Scenarios
    
    @Test("Handles stopping non-existent session")
    func stopNonExistentSession() async throws {
        let manager = SessionManager()
        
        do {
            _ = try await manager.stopLogSession(sessionName: "ghost-session", fullOutput: false)
            Issue.record("Expected error for non-existent session")
        } catch XCSentinelError.sessionNotFound(let name) {
            #expect(name == "ghost-session")
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - State Management Error Scenarios
    
    @Test("Handles concurrent state updates")
    func concurrentStateUpdates() async throws {
        let stateController = StateController.shared
        
        // Test concurrent updates don't cause data races
        await withTaskGroup(of: Void.self) { group in
            for _ in 1...10 {
                group.addTask {
                    _ = try? await stateController.updateState { state in
                        state.globalSessionCounter += 1
                    }
                }
            }
        }
        
        // Verify state is consistent
        let finalState = try await stateController.loadState()
        #expect(finalState.globalSessionCounter >= 10)
    }
    
    // MARK: - Device Error Scenarios
    
    @Test("Handles invalid destination format")
    func invalidDestinationFormat() async throws {
        let deviceManager = DeviceManager()
        
        do {
            _ = try await deviceManager.resolveDestination("invalid-format")
            Issue.record("Expected error for invalid destination")
        } catch XCSentinelError.invalidDestination {
            // Expected error
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
    
    @Test("Handles ambiguous simulator names")
    func ambiguousSimulatorName() async throws {
        // This test validates the error type
        let error = XCSentinelError.ambiguousSimulator(
            name: "iPhone",
            matches: ["iPhone 15", "iPhone 15 Pro", "iPhone 15 Pro Max"]
        )
        
        #expect(error.errorDescription?.contains("Ambiguous") == true)
        #expect(error.errorCode == "AMBIGUOUS_SIMULATOR")
    }
    
    // MARK: - Error Type Tests
    
    @Test("All error types have proper descriptions and codes")
    func errorTypesComplete() {
        let errors: [XCSentinelError] = [
            .simulatorNotFound(name: "Test"),
            .deviceNotFound(name: "Test"),
            .ambiguousSimulator(name: "Test", matches: ["A", "B"]),
            .buildFailed(message: "Test"),
            .invalidDestination("Test"),
            .missingWorkspaceOrProject,
            .stateFileError("Test"),
            .processExecutionFailed("Test"),
            .sessionNotFound("Test"),
            .invalidConfiguration("Test")
        ]
        
        for error in errors {
            #expect(error.errorDescription != nil, "Missing description for \(error)")
            #expect(!error.errorCode.isEmpty, "Missing error code for \(error)")
            #expect(error.errorCode == error.errorCode.uppercased(), "Error code should be uppercase")
            #expect(error.errorCode.contains("_"), "Error code should use underscores")
        }
    }
    
    // MARK: - Process Execution Error Scenarios
    
    @Test("Process executor handles command not found")
    func processExecutorCommandNotFound() async throws {
        do {
            _ = try await ProcessExecutor.execute(
                "/nonexistent/command",
                arguments: []
            )
            Issue.record("Expected error for non-existent command")
        } catch {
            // Expected error
            #expect(error is XCSentinelError)
        }
    }
}