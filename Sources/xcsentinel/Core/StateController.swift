import Foundation

class StateController {
    static let shared = StateController()
    
    private let stateDirectoryURL: URL
    private let stateFileURL: URL
    private let fileManager = FileManager.default
    
    private init() {
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        self.stateDirectoryURL = homeDirectory.appendingPathComponent(".xcsentinel")
        self.stateFileURL = stateDirectoryURL.appendingPathComponent("state.json")
    }
    
    func ensureStateDirectory() throws {
        if !fileManager.fileExists(atPath: stateDirectoryURL.path) {
            try fileManager.createDirectory(at: stateDirectoryURL, withIntermediateDirectories: true)
        }
    }
    
    func loadState() throws -> State {
        try ensureStateDirectory()
        
        guard fileManager.fileExists(atPath: stateFileURL.path) else {
            return State()
        }
        
        let data = try Data(contentsOf: stateFileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(State.self, from: data)
    }
    
    func saveState(_ state: State) throws {
        try ensureStateDirectory()
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        
        // Write to temp file and rename for atomicity
        let tempURL = stateFileURL.appendingPathExtension("tmp")
        try data.write(to: tempURL)
        
        // Atomic rename
        _ = try fileManager.replaceItem(at: stateFileURL, withItemAt: tempURL, backupItemName: nil, options: [], resultingItemURL: nil)
    }
    
    func updateState(_ block: (inout State) throws -> Void) throws {
        var state = try loadState()
        try block(&state)
        try saveState(state)
    }
    
    func cleanStaleSessions() throws {
        try updateState { state in
            var staleSessions: [String] = []
            
            for (name, session) in state.logSessions {
                // Check if process is still alive using kill -0
                let result = Process()
                result.executableURL = URL(fileURLWithPath: "/bin/kill")
                result.arguments = ["-0", "\(session.pid)"]
                
                do {
                    try result.run()
                    result.waitUntilExit()
                    
                    if result.terminationStatus != 0 {
                        // Process is not running
                        staleSessions.append(name)
                    }
                } catch {
                    // If kill command fails, consider session stale
                    staleSessions.append(name)
                }
            }
            
            // Remove stale sessions
            for name in staleSessions {
                state.logSessions.removeValue(forKey: name)
            }
        }
    }
}