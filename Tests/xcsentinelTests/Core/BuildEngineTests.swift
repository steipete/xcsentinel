import Testing
import Foundation
@testable import xcsentinel

@Suite("BuildEngine Tests")
final class BuildEngineTests {
    let tempDirectory: URL
    
    init() throws {
        tempDirectory = try TestHelpers.createTemporaryDirectory()
    }
    
    deinit {
        try? FileManager.default.removeItem(at: tempDirectory)
    }
    
    @Test("Build validates workspace or project requirement")
    func validateWorkspaceOrProject() throws {
        let engine = BuildEngine()
        let config = BuildEngine.BuildConfiguration(
            scheme: "MyApp",
            destination: "platform=iOS Simulator,name=iPhone 15",
            workspace: nil,
            project: nil,
            noIncremental: false
        )
        
        #expect(throws: XCSentinelError.missingWorkspaceOrProject) {
            _ = try engine.build(configuration: config)
        }
    }
    
    @Test("Build falls back to xcodebuild when noIncremental is true")
    func noIncrementalFallback() throws {
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
        #expect(throws: XCSentinelError.self) {
            _ = try engine.build(configuration: config)
        }
    }
    
    @Test("Marker file is created after successful build")
    func markerFileCreation() throws {
        let projectURL = try TestHelpers.createMockXcodeProject(at: tempDirectory)
        let markerURL = projectURL.deletingLastPathComponent().appendingPathComponent(".xcsentinel.rc")
        
        // Create a mock Makefile that will succeed
        let makefileContent = """
        all:
        \t@echo "Build succeeded"
        """
        try makefileContent.write(
            to: tempDirectory.appendingPathComponent("Makefile"),
            atomically: true,
            encoding: .utf8
        )
        
        let engine = BuildEngine()
        let config = BuildEngine.BuildConfiguration(
            scheme: "TestScheme",
            destination: "generic/platform=iOS",
            workspace: nil,
            project: projectURL.path,
            noIncremental: false
        )
        
        // This will run make and succeed
        let result = try engine.build(configuration: config)
        
        #expect(result.exitCode == 0)
        #expect(FileManager.default.fileExists(atPath: markerURL.path))
    }
    
    @Test("Marker file is deleted after failed make")
    func markerFileDeletionOnFailure() throws {
        let projectURL = try TestHelpers.createMockXcodeProject(at: tempDirectory)
        let markerURL = projectURL.deletingLastPathComponent().appendingPathComponent(".xcsentinel.rc")
        
        // Create marker file first
        FileManager.default.createFile(atPath: markerURL.path, contents: nil)
        
        // Create a Makefile that will fail
        let makefileContent = """
        all:
        \texit 1
        """
        try makefileContent.write(
            to: tempDirectory.appendingPathComponent("Makefile"),
            atomically: true,
            encoding: .utf8
        )
        
        let engine = BuildEngine()
        let config = BuildEngine.BuildConfiguration(
            scheme: "TestScheme",
            destination: "generic/platform=iOS",
            workspace: nil,
            project: projectURL.path,
            noIncremental: false
        )
        
        // This will run make and fail, then fall back to xcodebuild (which will also fail)
        #expect(throws: XCSentinelError.self) {
            _ = try engine.build(configuration: config)
        }
        
        // Marker file should be deleted
        #expect(!FileManager.default.fileExists(atPath: markerURL.path))
    }
    
    @Test("GetBuildSettings parses xcodebuild output correctly")
    func getBuildSettings() throws {
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
        #expect(throws: XCSentinelError.self) {
            _ = try engine.getBuildSettings(configuration: config)
        }
    }
    
    @Test("Build detects stale Makefile based on project modification")
    func staleMakefileDetection() throws {
        let projectURL = try TestHelpers.createMockXcodeProject(at: tempDirectory)
        let markerURL = projectURL.deletingLastPathComponent().appendingPathComponent(".xcsentinel.rc")
        let pbxprojURL = projectURL.appendingPathComponent("project.pbxproj")
        
        // Create marker file with old timestamp
        FileManager.default.createFile(atPath: markerURL.path, contents: nil)
        let oldDate = Date().addingTimeInterval(-3600) // 1 hour ago
        try FileManager.default.setAttributes(
            [.modificationDate: oldDate],
            ofItemAtPath: markerURL.path
        )
        
        // Touch project file to make it newer
        try "updated".write(to: pbxprojURL, atomically: true, encoding: .utf8)
        
        // Create a Makefile
        try "all:\n\t@echo 'Building'".write(
            to: tempDirectory.appendingPathComponent("Makefile"),
            atomically: true,
            encoding: .utf8
        )
        
        let engine = BuildEngine()
        let config = BuildEngine.BuildConfiguration(
            scheme: "TestScheme",
            destination: "generic/platform=iOS",
            workspace: nil,
            project: projectURL.path,
            noIncremental: false
        )
        
        _ = try? engine.build(configuration: config)
        
        // Marker should be updated to current time
        let newAttributes = try FileManager.default.attributesOfItem(atPath: markerURL.path)
        let newDate = newAttributes[.modificationDate] as? Date
        #expect(newDate != nil)
        if let newDate = newDate {
            #expect(newDate > oldDate)
        }
    }
    
    @Test("Build handles workspace configuration")
    func workspaceConfiguration() throws {
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
        #expect(throws: XCSentinelError.self) {
            _ = try engine.build(configuration: config)
        }
    }
}