import ArgumentParser
import Foundation

struct LogCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "log",
        abstract: "Manage log sessions",
        subcommands: [LogStartCommand.self, LogStopCommand.self, LogTailCommand.self, LogListCommand.self, LogCleanCommand.self]
    )
}

struct LogStartCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "start",
        abstract: "Start a new log session"
    )
    
    @Option(name: .long, help: "The UDID of the target device or simulator")
    var udid: String
    
    @Option(name: .long, help: "The bundle identifier to filter logs")
    var bundleId: String
    
    @Flag(name: .long, help: "Output in JSON format")
    var json = false
    
    func run() throws {
        let formatter = OutputFormatter(json: json)
        
        do {
            let sessionManager = SessionManager()
            let sessionName = try sessionManager.startLogSession(udid: udid, bundleID: bundleId)
            
            if json {
                formatter.success(LogStartResponse(sessionName: sessionName))
            } else {
                print("Started log session: \(sessionName)")
            }
        } catch let error as XCSentinelError {
            formatter.error(error)
            throw ExitCode.failure
        } catch {
            formatter.error(.processExecutionFailed(error.localizedDescription))
            throw ExitCode.failure
        }
    }
}

struct LogStopCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stop",
        abstract: "Stop a log session"
    )
    
    @Argument(help: "The session name to stop")
    var sessionName: String
    
    @Flag(name: .long, help: "Print the full log instead of last 100 lines")
    var full = false
    
    @Flag(name: .long, help: "Output in JSON format")
    var json = false
    
    func run() throws {
        let formatter = OutputFormatter(json: json)
        
        do {
            let sessionManager = SessionManager()
            let logContent = try sessionManager.stopLogSession(sessionName: sessionName, fullOutput: full)
            
            if json {
                formatter.success(LogStopResponse(logContent: logContent))
            } else {
                print(logContent)
            }
        } catch let error as XCSentinelError {
            formatter.error(error)
            throw ExitCode.failure
        } catch {
            formatter.error(.processExecutionFailed(error.localizedDescription))
            throw ExitCode.failure
        }
    }
}

struct LogTailCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tail",
        abstract: "Stream live logs from a session"
    )
    
    @Argument(help: "The session name to tail")
    var sessionName: String
    
    @Flag(name: .long, help: "Output in JSON format")
    var json = false
    
    func run() throws {
        let formatter = OutputFormatter(json: json)
        
        if json {
            formatter.error(.invalidConfiguration("JSON output not supported for tail command"))
            throw ExitCode.failure
        }
        
        do {
            let sessionManager = SessionManager()
            try sessionManager.tailLogSession(sessionName: sessionName)
        } catch let error as XCSentinelError {
            formatter.error(error)
            throw ExitCode.failure
        } catch {
            formatter.error(.processExecutionFailed(error.localizedDescription))
            throw ExitCode.failure
        }
    }
}

struct LogListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List active log sessions"
    )
    
    @Flag(name: .long, help: "Output in JSON format")
    var json = false
    
    func run() throws {
        let formatter = OutputFormatter(json: json)
        
        do {
            let sessionManager = SessionManager()
            let sessions = try sessionManager.listSessions()
            
            if json {
                let sessionData = sessions.map { session in
                    LogSessionInfo(
                        name: session.name,
                        pid: session.pid,
                        bundleId: session.bundleID,
                        targetUdid: session.targetUDID
                    )
                }
                formatter.success(LogListResponse(activeSessions: sessionData))
            } else {
                if sessions.isEmpty {
                    print("No active log sessions")
                } else {
                    print("Active log sessions:")
                    for session in sessions {
                        print("  \(session.name) - PID: \(session.pid), Bundle: \(session.bundleID), Target: \(session.targetUDID)")
                    }
                }
            }
        } catch let error as XCSentinelError {
            formatter.error(error)
            throw ExitCode.failure
        } catch {
            formatter.error(.processExecutionFailed(error.localizedDescription))
            throw ExitCode.failure
        }
    }
}

struct LogCleanCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clean",
        abstract: "Clean up stale log sessions"
    )
    
    @Flag(name: .long, help: "Output in JSON format")
    var json = false
    
    func run() throws {
        let formatter = OutputFormatter(json: json)
        
        do {
            let sessionManager = SessionManager()
            try sessionManager.cleanStaleSessions()
            
            if json {
                formatter.success(CleanResponse(message: "Stale sessions cleaned"))
            } else {
                print("Cleaned up stale log sessions")
            }
        } catch let error as XCSentinelError {
            formatter.error(error)
            throw ExitCode.failure
        } catch {
            formatter.error(.processExecutionFailed(error.localizedDescription))
            throw ExitCode.failure
        }
    }
}