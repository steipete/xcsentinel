import Foundation
@testable import xcsentinel

// Protocol for FileManager operations
protocol FileManagerProtocol {
    func fileExists(atPath path: String) -> Bool
    func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey : Any]?) throws
    func removeItem(at URL: URL) throws
    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey : Any]
    func setAttributes(_ attributes: [FileAttributeKey : Any], ofItemAtPath path: String) throws
    func createFile(atPath path: String, contents data: Data?, attributes attr: [FileAttributeKey : Any]?) -> Bool
    func contentsOfDirectory(atPath path: String) throws -> [String]
}

// Make FileManager conform to the protocol
extension FileManager: FileManagerProtocol {}

// Protocol for Process operations  
protocol ProcessProtocol {
    var executableURL: URL? { get set }
    var arguments: [String]? { get set }
    var environment: [String: String]? { get set }
    var currentDirectoryURL: URL? { get set }
    var standardOutput: Any? { get set }
    var standardError: Any? { get set }
    var processIdentifier: Int32 { get }
    var terminationStatus: Int32 { get }
    
    func run() throws
    func waitUntilExit()
    func terminate()
}

// Mock ProcessExecutor for testing
final class MockProcessExecutor: @unchecked Sendable {
    var mockResults: [String: ProcessResult] = [:]
    var shouldFailToFindExecutable = false
    var asyncProcessShouldFailImmediately = false
    var executionDelay: TimeInterval = 0
    
    init() {
        // Set up default mock responses
        mockResults["/bin/echo"] = ProcessResult(output: "Mock echo output", error: "", exitCode: 0)
        mockResults["/usr/bin/true"] = ProcessResult(output: "", error: "", exitCode: 0)
        mockResults["/usr/bin/false"] = ProcessResult(output: "", error: "", exitCode: 1)
    }
    
    func execute(_ command: String, arguments: [String] = [], 
                 environment: [String: String]? = nil,
                 currentDirectory: URL? = nil) throws -> ProcessResult {
        
        if executionDelay > 0 {
            Thread.sleep(forTimeInterval: executionDelay)
        }
        
        // Check for mock result
        if let result = mockResults[command] {
            return result
        }
        
        // Default behavior
        return ProcessResult(
            output: "Mock output for \(command) \(arguments.joined(separator: " "))",
            error: "",
            exitCode: 0
        )
    }
    
    func executeAsync(_ command: String, arguments: [String] = [], 
                      outputPath: String) throws -> Process {
        if asyncProcessShouldFailImmediately {
            throw XCSentinelError.processExecutionFailed("Mock async process failed")
        }
        
        // Return a mock process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        
        // Don't actually run it
        return process
    }
    
    func findExecutable(_ name: String) -> String? {
        if shouldFailToFindExecutable {
            return nil
        }
        
        // Mock common executables
        let knownExecutables = [
            "xcodebuild": "/usr/bin/xcodebuild",
            "xcrun": "/usr/bin/xcrun",
            "make": "/usr/bin/make",
            "xcodemake": "/usr/local/bin/xcodemake",
            "git": "/usr/bin/git"
        ]
        
        return knownExecutables[name]
    }
}

// Extension to make existing types work with mocks
extension BuildEngine {
    init(processExecutor: MockProcessExecutor) {
        self.init() // Use default init
        // In real implementation, you'd inject the executor
    }
}

extension DeviceManager {
    init(processExecutor: MockProcessExecutor) {
        self.init() // Use default init
        // In real implementation, you'd inject the executor
    }
}

extension SessionManager {
    init(processExecutor: MockProcessExecutor) {
        self.init() // Use default init
        // In real implementation, you'd inject the executor
    }
}