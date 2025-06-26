import Foundation

struct LogSession: Codable, Sendable {
    let pid: Int32
    let name: String
    let targetUDID: String
    let bundleID: String
    let logPath: String
    let startTime: Date
    
    enum CodingKeys: String, CodingKey {
        case pid
        case name
        case targetUDID = "target_udid"
        case bundleID = "bundle_id"
        case logPath = "log_path"
        case startTime = "start_time"
    }
}