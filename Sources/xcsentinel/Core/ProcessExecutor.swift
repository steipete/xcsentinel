import Foundation

struct ProcessResult: Sendable {
    let output: String
    let error: String
    let exitCode: Int32
}

enum ProcessExecutor {
    static func execute(
        _ executablePath: String,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        currentDirectory: URL? = nil
    ) async throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        
        if let env = environment {
            process.environment = ProcessInfo.processInfo.environment.merging(env) { _, new in new }
        }
        
        if let dir = currentDirectory {
            process.currentDirectoryURL = dir
        }
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try process.run()
                
                Task {
                    process.waitUntilExit()
                    
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    let error = String(data: errorData, encoding: .utf8) ?? ""
                    
                    continuation.resume(returning: ProcessResult(
                        output: output.trimmingCharacters(in: .whitespacesAndNewlines),
                        error: error.trimmingCharacters(in: .whitespacesAndNewlines),
                        exitCode: process.terminationStatus
                    ))
                }
            } catch {
                continuation.resume(throwing: XCSentinelError.processExecutionFailed(error.localizedDescription))
            }
        }
    }
    
    static func executeAsync(
        _ executablePath: String,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        currentDirectory: URL? = nil,
        outputPath: String? = nil
    ) async throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        
        if let env = environment {
            process.environment = ProcessInfo.processInfo.environment.merging(env) { _, new in new }
        }
        
        if let dir = currentDirectory {
            process.currentDirectoryURL = dir
        }
        
        // If output path is provided, redirect to file
        if let outputPath = outputPath {
            let outputURL = URL(fileURLWithPath: outputPath)
            
            // Ensure directory exists
            let directory = outputURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            
            // Create or truncate the file
            FileManager.default.createFile(atPath: outputPath, contents: nil)
            
            let fileHandle = try FileHandle(forWritingTo: outputURL)
            process.standardOutput = fileHandle
            process.standardError = fileHandle
        }
        
        try process.run()
        return process
    }
    
    static func findExecutable(_ name: String) async -> String? {
        let result = try? await execute("/usr/bin/which", arguments: [name])
        return result?.exitCode == 0 ? result?.output : nil
    }
}