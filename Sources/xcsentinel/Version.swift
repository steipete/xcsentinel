import Foundation

enum Version {
    static let current = "1.0.0"
    
    static var fullVersion: String {
        let gitHash = getGitHash() ?? "unknown"
        return "\(current) (\(gitHash))"
    }
    
    private static func getGitHash() -> String? {
        // Use Process directly in a synchronous way
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "--short", "HEAD"]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return output
            }
        } catch {
            // Ignore errors, return nil
        }
        
        return nil
    }
}