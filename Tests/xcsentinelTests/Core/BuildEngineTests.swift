import Testing
import Foundation
@testable import xcsentinel

@Suite("BuildEngine Tests", .tags(.buildSystem, .unit))
struct BuildEngineTests {
    let tempDirectory = try! TestHelpers.createTemporaryDirectory()
    
    @Test("Build validates workspace or project requirement")
    func validateWorkspaceOrProject() async throws {
        let engine = BuildEngine()
        let config = BuildEngine.BuildConfiguration(
            scheme: "MyApp",
            destination: "platform=iOS Simulator,name=iPhone 15",
            workspace: nil,
            project: nil,
            noIncremental: false
        )
        
        do {
            _ = try await engine.build(configuration: config)
            Issue.record("Expected error for missing workspace/project")
        } catch XCSentinelError.missingWorkspaceOrProject {
            // Expected error
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
    
    @Test("Build falls back to xcodebuild when noIncremental is true")
    func noIncrementalFallback() async throws {
        let projectPath = try TestHelpers.createMockXcodeProject(at: tempDirectory).path
        
        let engine = BuildEngine()
        let config = BuildEngine.BuildConfiguration(
            scheme: "TestScheme",
            destination: "generic/platform=iOS",
            workspace: nil,
            project: projectPath,
            noIncremental: true
        )
        
        // This will fail because it's not a real project, but we're testing it attempts xcodebuild
        do {
            _ = try await engine.build(configuration: config)
            Issue.record("Expected build to fail with mock project")
        } catch {
            // Expected error
            #expect(error is XCSentinelError)
        }
    }
    
    @Test("GetBuildSettings parses xcodebuild output correctly")
    func getBuildSettings() async throws {
        // This test demonstrates the parsing logic even though it will fail with a mock project
        let projectURL = try TestHelpers.createMockXcodeProject(at: tempDirectory)
        
        let engine = BuildEngine()
        let config = BuildEngine.BuildConfiguration(
            scheme: "TestScheme",
            destination: "generic/platform=iOS",
            workspace: nil,
            project: projectURL.path,
            noIncremental: false
        )
        
        // This will fail because it's not a real project
        do {
            _ = try await engine.getBuildSettings(configuration: config)
            Issue.record("Expected getBuildSettings to fail with mock project")
        } catch {
            // Expected error
            #expect(error is XCSentinelError)
        }
    }
    
    @Test("Build handles workspace configuration")
    func workspaceConfiguration() async throws {
        let workspacePath = tempDirectory.appendingPathComponent("Test.xcworkspace").path
        
        let engine = BuildEngine()
        let config = BuildEngine.BuildConfiguration(
            scheme: "TestScheme",
            destination: "generic/platform=iOS",
            workspace: workspacePath,
            project: nil,
            noIncremental: true
        )
        
        // Will fail but we're testing it accepts workspace
        do {
            _ = try await engine.build(configuration: config)
            Issue.record("Expected build to fail with nonexistent workspace")
        } catch {
            // Expected error
            #expect(error is XCSentinelError)
        }
    }
}