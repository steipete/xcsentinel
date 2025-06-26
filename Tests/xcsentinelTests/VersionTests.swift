import Testing
import Foundation
@testable import xcsentinel

@Suite("Version Tests", .tags(.unit, .fast))
struct VersionTests {
    
    @Test("Version string format is correct")
    func versionStringFormat() {
        let version = Version.current
        
        // Should contain major.minor.patch format
        let components = version.split(separator: ".")
        #expect(components.count >= 2) // At least major.minor
        
        // Each component should be numeric
        for component in components {
            #expect(Int(component) != nil, "Version component '\(component)' is not numeric")
        }
    }
    
    @Test("Version with git hash includes hash")
    func versionWithGitHash() {
        let versionWithHash = Version.fullVersion
        
        // Should contain the base version
        #expect(versionWithHash.contains(Version.current))
        
        // Might contain git hash if in git repo
        if versionWithHash.contains("(") && versionWithHash.contains(")") {
            // Extract hash
            if let start = versionWithHash.firstIndex(of: "("),
               let end = versionWithHash.firstIndex(of: ")") {
                let hashRange = versionWithHash.index(after: start)..<end
                let hash = String(versionWithHash[hashRange])
                
                // Git short hash is typically 7 characters or "unknown"
                #expect(hash.count >= 7 || hash == "unknown")
                
                // Should be hexadecimal if not "unknown"
                if hash != "unknown" {
                    let hexCharacters = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
                    let hashCharacters = CharacterSet(charactersIn: hash)
                    #expect(hashCharacters.isSubset(of: hexCharacters))
                }
            }
        }
    }
    
    @Test("Version constants are defined")
    func versionConstantsDefined() {
        // Version should not be empty
        #expect(!Version.current.isEmpty)
        
        // Version should not be a placeholder
        #expect(Version.current != "0.0.0")
    }
}