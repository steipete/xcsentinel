import Foundation

actor BuildEngine {
    private let fileManager = FileManager.default
    
    struct BuildConfiguration: Sendable {
        let scheme: String
        let destination: String
        let workspace: String?
        let project: String?
        let noIncremental: Bool
    }
    
    func build(configuration: BuildConfiguration) async throws -> ProcessResult {
        // Validate workspace or project
        guard configuration.workspace != nil || configuration.project != nil else {
            throw XCSentinelError.missingWorkspaceOrProject
        }
        
        let projectPath = configuration.workspace ?? configuration.project!
        let projectURL = URL(fileURLWithPath: projectPath)
        
        // Check if we should use incremental build
        let shouldUseIncremental = await shouldUseIncrementalBuild(projectURL: projectURL)
        if !configuration.noIncremental && shouldUseIncremental {
            // Try incremental build
            if let makefileURL = findMakefile(near: projectURL) {
                let result = try await runMake(at: makefileURL.deletingLastPathComponent())
                
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
            if let xcodemakePath = await ProcessExecutor.findExecutable("xcodemake") {
                // Run xcodemake to generate Makefile
                let xcodemakeResult = try await ProcessExecutor.execute(
                    xcodemakePath,
                    arguments: buildXcodemakeArguments(configuration: configuration),
                    currentDirectory: projectURL.deletingLastPathComponent()
                )
                
                if xcodemakeResult.exitCode == 0 {
                    // Run make
                    let makeResult = try await runMake(at: projectURL.deletingLastPathComponent())
                    if makeResult.exitCode == 0 {
                        try updateMarkerFile(projectURL: projectURL)
                    }
                    return makeResult
                }
            }
        }
        
        // Fall back to xcodebuild
        return try await runXcodebuild(configuration: configuration)
    }
    
    private func shouldUseIncrementalBuild(projectURL: URL) async -> Bool {
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
    
    private func findMakefile(near projectURL: URL) -> URL? {
        let directory = projectURL.deletingLastPathComponent()
        let makefileURL = directory.appendingPathComponent("Makefile")
        
        if fileManager.fileExists(atPath: makefileURL.path) {
            return makefileURL
        }
        
        return nil
    }
    
    private func runMake(at directory: URL) async throws -> ProcessResult {
        return try await ProcessExecutor.execute(
            "/usr/bin/make",
            currentDirectory: directory
        )
    }
    
    private func runXcodebuild(configuration: BuildConfiguration) async throws -> ProcessResult {
        var arguments = ["build"]
        
        arguments.append(contentsOf: ["-scheme", configuration.scheme])
        arguments.append(contentsOf: ["-destination", configuration.destination])
        
        if let workspace = configuration.workspace {
            arguments.append(contentsOf: ["-workspace", workspace])
        } else if let project = configuration.project {
            arguments.append(contentsOf: ["-project", project])
        }
        
        return try await ProcessExecutor.execute(
            "/usr/bin/xcodebuild",
            arguments: arguments
        )
    }
    
    private func buildXcodemakeArguments(configuration: BuildConfiguration) -> [String] {
        var arguments: [String] = []
        
        arguments.append(contentsOf: ["-scheme", configuration.scheme])
        arguments.append(contentsOf: ["-destination", configuration.destination])
        
        if let workspace = configuration.workspace {
            arguments.append(contentsOf: ["-workspace", workspace])
        } else if let project = configuration.project {
            arguments.append(contentsOf: ["-project", project])
        }
        
        return arguments
    }
    
    private func markerFileURL(for projectURL: URL) -> URL {
        let directory = projectURL.deletingLastPathComponent()
        return directory.appendingPathComponent(".xcsentinel.rc")
    }
    
    private func updateMarkerFile(projectURL: URL) throws {
        let markerURL = markerFileURL(for: projectURL)
        
        if fileManager.fileExists(atPath: markerURL.path) {
            // Update timestamp
            try fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: markerURL.path)
        } else {
            // Create marker file
            try Data().write(to: markerURL)
        }
    }
    
    private func deleteMarkerFile(projectURL: URL) throws {
        let markerURL = markerFileURL(for: projectURL)
        
        if fileManager.fileExists(atPath: markerURL.path) {
            try fileManager.removeItem(at: markerURL)
        }
    }
    
    func getBuildSettings(configuration: BuildConfiguration) async throws -> [String: String] {
        var arguments = ["-showBuildSettings"]
        
        arguments.append(contentsOf: ["-scheme", configuration.scheme])
        arguments.append(contentsOf: ["-destination", configuration.destination])
        
        if let workspace = configuration.workspace {
            arguments.append(contentsOf: ["-workspace", workspace])
        } else if let project = configuration.project {
            arguments.append(contentsOf: ["-project", project])
        }
        
        let result = try await ProcessExecutor.execute(
            "/usr/bin/xcodebuild",
            arguments: arguments
        )
        
        if result.exitCode != 0 {
            throw XCSentinelError.buildFailed(message: "Failed to get build settings: \(result.error)")
        }
        
        // Parse build settings
        var settings: [String: String] = [:]
        let lines = result.output.split(separator: "\n")
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.contains(" = ") {
                let parts = trimmedLine.split(separator: "=", maxSplits: 1)
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