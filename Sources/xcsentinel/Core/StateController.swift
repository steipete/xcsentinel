import Foundation

actor StateController {
    static let shared = StateController()
    
    private let stateDirectoryURL: URL
    private let stateFileURL: URL
    private let fileManager = FileManager.default
    
    private init() {
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        self.stateDirectoryURL = homeDirectory.appendingPathComponent(".xcsentinel")
        self.stateFileURL = stateDirectoryURL.appendingPathComponent("state.json")
    }
    
    private func ensureStateDirectory() throws {
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
    
    private func saveState(_ state: State) throws {
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
    
    func updateState<T>(_ block: (inout State) throws -> T) async throws -> T {
        var state = try loadState()
        let result = try block(&state)
        try saveState(state)
        return result
    }
    
    func cleanStaleSessions() async throws {
        // First, get the current state and check which sessions are stale
        var staleSessions: [String] = []
        let currentState = try loadState()
        
        for (name, session) in currentState.logSessions {
            // Check if process is still alive using kill -0
            let isAlive = await withCheckedContinuation { continuation in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/kill")
                process.arguments = ["-0", "\(session.pid)"]
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    continuation.resume(returning: process.terminationStatus == 0)
                } catch {
                    continuation.resume(returning: false)
                }
            }
            
            if !isAlive {
                staleSessions.append(name)
            }
        }
        
        // Now update the state to remove stale sessions
        if !staleSessions.isEmpty {
            try await updateState { state in
                for name in staleSessions {
                    state.logSessions.removeValue(forKey: name)
                }
            }
        }
    }
}