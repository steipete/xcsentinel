import Foundation

enum Version {
    static let current = "1.0.0"
    
    static var fullVersion: String {
        let gitHash = getGitHash() ?? "unknown"
        return "\(current) (\(gitHash))"
    }
    
    private static func getGitHash() -> String? {
        // Try to get git hash at runtime
        let result = try? ProcessExecutor.execute(
            "/usr/bin/git",
            arguments: ["rev-parse", "--short", "HEAD"]
        )
        
        return result?.exitCode == 0 ? result?.output : nil
    }
}