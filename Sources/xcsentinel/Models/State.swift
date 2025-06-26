import Foundation

struct State: Codable, Sendable {
    var globalSessionCounter: Int
    var logSessions: [String: LogSession]
    
    enum CodingKeys: String, CodingKey {
        case globalSessionCounter = "global_session_counter"
        case logSessions = "log_sessions"
    }
    
    init() {
        self.globalSessionCounter = 0
        self.logSessions = [:]
    }
}