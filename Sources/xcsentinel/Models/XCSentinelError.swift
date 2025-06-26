import Foundation

enum XCSentinelError: Error, LocalizedError, Equatable {
    case simulatorNotFound(name: String)
    case ambiguousSimulator(name: String, matches: [String])
    case buildFailed(message: String)
    case invalidDestination(String)
    case missingWorkspaceOrProject
    case stateFileError(String)
    case processExecutionFailed(String)
    case sessionNotFound(String)
    case invalidConfiguration(String)
    
    var errorDescription: String? {
        switch self {
        case .simulatorNotFound(let name):
            return "Simulator with name '\(name)' not found."
        case .ambiguousSimulator(let name, let matches):
            return "Ambiguous simulator name '\(name)'. Matches: \(matches.joined(separator: ", "))"
        case .buildFailed(let message):
            return "Build failed: \(message)"
        case .invalidDestination(let dest):
            return "Invalid destination: \(dest)"
        case .missingWorkspaceOrProject:
            return "Either --workspace or --project must be specified"
        case .stateFileError(let message):
            return "State file error: \(message)"
        case .processExecutionFailed(let message):
            return "Process execution failed: \(message)"
        case .sessionNotFound(let name):
            return "Session '\(name)' not found"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        }
    }
    
    var errorCode: String {
        switch self {
        case .simulatorNotFound: return "SIMULATOR_NOT_FOUND"
        case .ambiguousSimulator: return "AMBIGUOUS_SIMULATOR"
        case .buildFailed: return "BUILD_FAILED"
        case .invalidDestination: return "INVALID_DESTINATION"
        case .missingWorkspaceOrProject: return "MISSING_WORKSPACE_OR_PROJECT"
        case .stateFileError: return "STATE_FILE_ERROR"
        case .processExecutionFailed: return "PROCESS_EXECUTION_FAILED"
        case .sessionNotFound: return "SESSION_NOT_FOUND"
        case .invalidConfiguration: return "INVALID_CONFIGURATION"
        }
    }
}