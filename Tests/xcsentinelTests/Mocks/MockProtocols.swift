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