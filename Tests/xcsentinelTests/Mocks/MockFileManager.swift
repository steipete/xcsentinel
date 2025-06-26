import Foundation
@testable import xcsentinel

final class MockFileManager: FileManagerProtocol {
    var files: Set<String> = []
    var directories: Set<String> = []
    var fileAttributes: [String: [FileAttributeKey: Any]] = [:]
    var shouldThrowError = false
    var errorToThrow: Error?
    
    func fileExists(atPath path: String) -> Bool {
        return files.contains(path) || directories.contains(path)
    }
    
    func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey : Any]?) throws {
        if shouldThrowError {
            throw errorToThrow ?? NSError(domain: "MockError", code: 1)
        }
        directories.insert(url.path)
        
        if createIntermediates {
            var currentPath = "/"
            for component in url.pathComponents.dropFirst() {
                currentPath = (currentPath as NSString).appendingPathComponent(component)
                directories.insert(currentPath)
            }
        }
    }
    
    func removeItem(at url: URL) throws {
        if shouldThrowError {
            throw errorToThrow ?? NSError(domain: "MockError", code: 2)
        }
        files.remove(url.path)
        directories.remove(url.path)
        fileAttributes.removeValue(forKey: url.path)
    }
    
    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey : Any] {
        if shouldThrowError {
            throw errorToThrow ?? NSError(domain: "MockError", code: 3)
        }
        return fileAttributes[path] ?? [.modificationDate: Date()]
    }
    
    func setAttributes(_ attributes: [FileAttributeKey : Any], ofItemAtPath path: String) throws {
        if shouldThrowError {
            throw errorToThrow ?? NSError(domain: "MockError", code: 4)
        }
        fileAttributes[path] = attributes
    }
    
    func createFile(atPath path: String, contents data: Data?, attributes attr: [FileAttributeKey : Any]?) -> Bool {
        if shouldThrowError {
            return false
        }
        files.insert(path)
        if let attr = attr {
            fileAttributes[path] = attr
        }
        return true
    }
    
    func contentsOfDirectory(atPath path: String) throws -> [String] {
        if shouldThrowError {
            throw errorToThrow ?? NSError(domain: "MockError", code: 5)
        }
        
        let pathWithSlash = path.hasSuffix("/") ? path : path + "/"
        var contents: [String] = []
        
        for file in files {
            if file.hasPrefix(pathWithSlash) {
                let relativePath = String(file.dropFirst(pathWithSlash.count))
                if !relativePath.contains("/") {
                    contents.append(relativePath)
                }
            }
        }
        
        for dir in directories {
            if dir.hasPrefix(pathWithSlash) && dir != path {
                let relativePath = String(dir.dropFirst(pathWithSlash.count))
                if !relativePath.contains("/") {
                    contents.append(relativePath)
                }
            }
        }
        
        return contents
    }
}