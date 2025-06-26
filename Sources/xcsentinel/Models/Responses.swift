import Foundation

struct BuildSuccessResponse: Encodable {
    let success: Bool
    let message: String
}

struct RunSuccessResponse: Encodable {
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

struct LogStartResponse: Encodable {
    let sessionName: String
    
    enum CodingKeys: String, CodingKey {
        case sessionName = "session_name"
    }
}

struct LogStopResponse: Encodable {
    let logContent: String
    
    enum CodingKeys: String, CodingKey {
        case logContent = "log_content"
    }
}

struct LogSessionInfo: Encodable {
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

struct LogListResponse: Encodable {
    let activeSessions: [LogSessionInfo]
    
    enum CodingKeys: String, CodingKey {
        case activeSessions = "active_sessions"
    }
}

struct CleanResponse: Encodable {
    let message: String
}