import Foundation

enum OutputFormat: Sendable {
    case plain
    case json
}

struct OutputFormatter: Sendable {
    let format: OutputFormat
    
    init(json: Bool) {
        self.format = json ? .json : .plain
    }
    
    func success<T: Encodable & Sendable>(_ data: T) {
        switch format {
        case .plain:
            if let string = data as? String {
                print(string)
            } else {
                print(String(describing: data))
            }
        case .json:
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                let jsonData = try encoder.encode(data)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print(jsonString)
                }
            } catch {
                print("{\"success\": false, \"error\": {\"code\": \"JSON_ENCODING_ERROR\", \"message\": \"\(error.localizedDescription)\"}}")
            }
        }
    }
    
    func error(_ error: XCSentinelError) {
        switch format {
        case .plain:
            if let description = error.errorDescription {
                print("Error: \(description)")
            }
        case .json:
            let errorResponse = ErrorResponse(
                success: false,
                error: ErrorInfo(code: error.errorCode, message: error.errorDescription ?? "Unknown error")
            )
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let jsonData = try encoder.encode(errorResponse)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print(jsonString)
                }
            } catch {
                print("{\"success\": false, \"error\": {\"code\": \"JSON_ENCODING_ERROR\", \"message\": \"\(error.localizedDescription)\"}}")
            }
        }
    }
}

struct ErrorResponse: Encodable, Sendable {
    let success: Bool
    let error: ErrorInfo
}

struct ErrorInfo: Encodable, Sendable {
    let code: String
    let message: String
}