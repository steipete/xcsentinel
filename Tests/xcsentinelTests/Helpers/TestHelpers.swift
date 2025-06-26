import Foundation
@testable import xcsentinel

enum TestHelpers {
    static func createTemporaryDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("xcsentinel-tests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
    
    static func createTemporaryFile(in directory: URL, name: String, contents: String = "") throws -> URL {
        let fileURL = directory.appendingPathComponent(name)
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    static func createMockXcodeProject(at directory: URL) throws -> URL {
        let projectURL = directory.appendingPathComponent("Test.xcodeproj")
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        
        // Create a minimal project.pbxproj file
        let pbxprojURL = projectURL.appendingPathComponent("project.pbxproj")
        let minimalProject = """
        // !$*UTF8*$!
        {
            archiveVersion = 1;
            classes = {
            };
            objectVersion = 56;
            objects = {
            };
            rootObject = ABC123;
        }
        """
        try minimalProject.write(to: pbxprojURL, atomically: true, encoding: .utf8)
        
        return projectURL
    }
}