import Foundation

struct BuildSuccessResponse: Encodable, Sendable {
    let success: Bool
    let message: String
}

struct RunSuccessResponse: Encodable, Sendable {
    let success: Bool
    let appPath: String
    let bundleId: String
    let targetUdid: String
    
    enum CodingKeys: String, CodingKey {
        case success
        case appPath = "app_path"
        case bundleId = "bundle_id"
        case targetUdid = "target_udid"
    }
}

struct LogStartResponse: Encodable, Sendable {
    let success: Bool
    let sessionName: String
    let pid: Int32
    
    enum CodingKeys: String, CodingKey {
        case success
        case sessionName = "session_name"
        case pid
    }
}

struct LogStopResponse: Encodable, Sendable {
    let success: Bool
    let logContent: String
    
    enum CodingKeys: String, CodingKey {
        case success
        case logContent = "log_content"
    }
}

struct LogSessionInfo: Encodable, Sendable {
    let name: String
    let pid: Int32
    let bundleId: String
    let targetUdid: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case pid
        case bundleId = "bundle_id"
        case targetUdid = "target_udid"
    }
}

struct LogListResponse: Encodable, Sendable {
    let success: Bool
    let activeSessions: [LogSessionInfo]
    
    enum CodingKeys: String, CodingKey {
        case success
        case activeSessions = "active_sessions"
    }
}

struct CleanResponse: Encodable, Sendable {
    let success: Bool
    let message: String
}