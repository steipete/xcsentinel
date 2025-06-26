import Foundation

class BuildEngine {
    private let fileManager = FileManager.default
    
    struct BuildConfiguration {
        let scheme: String
        let destination: String
        let workspace: String?
        let project: String?
        let noIncremental: Bool
    }
    
    func build(configuration: BuildConfiguration) throws -> ProcessResult {
        // Validate workspace or project
        guard configuration.workspace != nil || configuration.project != nil else {
            throw XCSentinelError.missingWorkspaceOrProject
        }
        
        let projectPath = configuration.workspace ?? configuration.project!
        let projectURL = URL(fileURLWithPath: projectPath)
        
        // Check if we should use incremental build
        if !configuration.noIncremental && shouldUseIncrementalBuild(projectURL: projectURL) {
            // Try incremental build
            if let makefileURL = findMakefile(near: projectURL) {
                let result = try runMake(at: makefileURL.deletingLastPathComponent())
                
                if result.exitCode == 0 {
                    // Update marker file on successful make
                    try updateMarkerFile(projectURL: projectURL)
                    return result
                } else {
                    // Delete marker file on make failure
                    try deleteMarkerFile(projectURL: projectURL)
                    // Fall through to regenerate
                }
            }
            
            // Check if xcodemake is available
            if let xcodemakePath = ProcessExecutor.findExecutable("xcodemake") {
                // Run xcodemake to generate Makefile
                let xcodemakeResult = try ProcessExecutor.execute(
                    xcodemakePath,
                    arguments: buildXcodemakeArguments(configuration: configuration),
                    currentDirectory: projectURL.deletingLastPathComponent()
                )
                
                if xcodemakeResult.exitCode == 0 {
                    // Run make
                    let makeResult = try runMake(at: projectURL.deletingLastPathComponent())
                    if makeResult.exitCode == 0 {
                        try updateMarkerFile(projectURL: projectURL)
                    }
                    return makeResult
                }
            }
        }
        
        // Fall back to xcodebuild
        return try runXcodebuild(configuration: configuration)
    }
    
    private func shouldUseIncrementalBuild(projectURL: URL) -> Bool {
        let markerURL = markerFileURL(for: projectURL)
        
        guard fileManager.fileExists(atPath: markerURL.path) else {
            return true // No marker means we should try incremental
        }
        
        do {
            let markerAttributes = try fileManager.attributesOfItem(atPath: markerURL.path)
            guard let markerDate = markerAttributes[.modificationDate] as? Date else {
                return true
            }
            
            // Check if any project files are newer than marker
            let projectDate = try getMostRecentModificationDate(in: projectURL)
            return projectDate <= markerDate
            
        } catch {
            return true // On error, try incremental
        }
    }
    
    private func getMostRecentModificationDate(in url: URL) throws -> Date {
        var mostRecentDate = Date.distantPast
        
        let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        
        while let fileURL = enumerator?.nextObject() as? URL {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            if let modDate = attributes[FileAttributeKey.modificationDate] as? Date {
                mostRecentDate = max(mostRecentDate, modDate)
            }
        }
        
        return mostRecentDate
    }
    
    private func markerFileURL(for projectURL: URL) -> URL {
        return projectURL.deletingLastPathComponent().appendingPathComponent(".xcsentinel.rc")
    }
    
    private func updateMarkerFile(projectURL: URL) throws {
        let markerURL = markerFileURL(for: projectURL)
        
        if fileManager.fileExists(atPath: markerURL.path) {
            // Touch existing file
            try fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: markerURL.path)
        } else {
            // Create new marker file
            fileManager.createFile(atPath: markerURL.path, contents: nil)
        }
    }
    
    private func deleteMarkerFile(projectURL: URL) throws {
        let markerURL = markerFileURL(for: projectURL)
        if fileManager.fileExists(atPath: markerURL.path) {
            try fileManager.removeItem(at: markerURL)
        }
    }
    
    private func findMakefile(near projectURL: URL) -> URL? {
        let directory = projectURL.deletingLastPathComponent()
        let makefileURL = directory.appendingPathComponent("Makefile")
        
        return fileManager.fileExists(atPath: makefileURL.path) ? makefileURL : nil
    }
    
    private func runMake(at directory: URL) throws -> ProcessResult {
        return try ProcessExecutor.execute(
            "/usr/bin/make",
            currentDirectory: directory
        )
    }
    
    private func buildXcodemakeArguments(configuration: BuildConfiguration) -> [String] {
        var args: [String] = []
        
        if let workspace = configuration.workspace {
            args.append(contentsOf: ["-workspace", workspace])
        } else if let project = configuration.project {
            args.append(contentsOf: ["-project", project])
        }
        
        args.append(contentsOf: [
            "-scheme", configuration.scheme,
            "-destination", configuration.destination
        ])
        
        return args
    }
    
    private func runXcodebuild(configuration: BuildConfiguration) throws -> ProcessResult {
        var args: [String] = []
        
        if let workspace = configuration.workspace {
            args.append(contentsOf: ["-workspace", workspace])
        } else if let project = configuration.project {
            args.append(contentsOf: ["-project", project])
        }
        
        args.append(contentsOf: [
            "-scheme", configuration.scheme,
            "-destination", configuration.destination,
            "build"
        ])
        
        return try ProcessExecutor.execute("/usr/bin/xcodebuild", arguments: args)
    }
    
    func getBuildSettings(configuration: BuildConfiguration) throws -> [String: String] {
        var args: [String] = []
        
        if let workspace = configuration.workspace {
            args.append(contentsOf: ["-workspace", workspace])
        } else if let project = configuration.project {
            args.append(contentsOf: ["-project", project])
        }
        
        args.append(contentsOf: [
            "-scheme", configuration.scheme,
            "-destination", configuration.destination,
            "-showBuildSettings"
        ])
        
        let result = try ProcessExecutor.execute("/usr/bin/xcodebuild", arguments: args)
        
        if result.exitCode != 0 {
            throw XCSentinelError.buildFailed(message: "Failed to get build settings: \(result.error)")
        }
        
        // Parse build settings
        var settings: [String: String] = [:]
        
        for line in result.output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains(" = ") {
                let parts = trimmed.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespaces)
                    let value = parts[1].trimmingCharacters(in: .whitespaces)
                    settings[key] = value
                }
            }
        }
        
        return settings
    }
}