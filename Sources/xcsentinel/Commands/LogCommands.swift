import ArgumentParser
import Foundation

struct LogCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "log",
        abstract: "Manage log sessions",
        discussion: """
            Provides session-based log management for device and simulator logs.
            
            Log sessions run in the background, allowing you to start logging,
            continue with other tasks, and retrieve logs later. Each session
            gets a unique identifier (e.g., session-1) and is automatically
            cleaned up when the process terminates.
            
            Subcommands:
              start  - Start a new log session for a specific app
              stop   - Stop a session and retrieve its logs
              tail   - Stream live logs from an active session
              list   - Show all active log sessions
              clean  - Clean up stale sessions
            
            Examples:
              Start logging for an app:
                xcsentinel log start --udid ABC123 --bundle-id com.example.MyApp
              
              View collected logs:
                xcsentinel log stop session-1
              
              Stream logs in real-time:
                xcsentinel log tail session-1
              
              List active sessions:
                xcsentinel log list
            """,
        subcommands: [LogStartCommand.self, LogStopCommand.self, LogTailCommand.self, LogListCommand.self, LogCleanCommand.self]
    )
    
    @OptionGroup var options: GlobalOptions
}

struct LogStartCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "start",
        abstract: "Start a new log session",
        discussion: """
            Starts a background log session that captures logs from the specified
            device and bundle ID. Returns a session identifier for later retrieval.
            
            For simulators, uses 'simctl spawn' to capture logs from a specific
            simulator instance. For devices, uses 'devicectl device console'.
            """
    )
    
    @Option(name: .long, help: ArgumentHelp(
        "The UDID of the target device or simulator",
        discussion: "Use 'xcrun simctl list devices' or 'xcrun devicectl list devices' to find UDIDs."
    ))
    var udid: String
    
    @Option(name: .long, help: ArgumentHelp(
        "The bundle identifier to filter logs",
        discussion: "Only logs from this app bundle will be captured (e.g., com.example.MyApp)."
    ))
    var bundleId: String
    
    @OptionGroup var options: GlobalOptions
    
    func run() async throws {
        let formatter = OutputFormatter(json: options.json)
        
        do {
            let sessionManager = SessionManager()
            let result = try await sessionManager.startLogSession(udid: udid, bundleID: bundleId)
            
            if options.json {
                formatter.success(LogStartResponse(success: true, sessionName: result.sessionName, pid: result.pid))
            } else {
                print("Started log session: \(result.sessionName) (PID: \(result.pid))")
            }
        } catch let error as XCSentinelError {
            formatter.error(error)
            throw ExitCode.failure
        } catch {
            formatter.error(XCSentinelError.processExecutionFailed(error.localizedDescription))
            throw ExitCode.failure
        }
    }
}

struct LogStopCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stop",
        abstract: "Stop a log session and retrieve its logs",
        discussion: """
            Terminates the specified log session and returns the captured logs.
            By default, returns the last 100 lines. Use --full to get all logs.
            
            The session is removed from active sessions after stopping.
            """
    )
    
    @Argument(help: "The session name to stop")
    var sessionName: String
    
    @Flag(name: .long, help: "Print the full log instead of last 100 lines")
    var full = false
    
    @OptionGroup var options: GlobalOptions
    
    func run() async throws {
        let formatter = OutputFormatter(json: options.json)
        
        do {
            let sessionManager = SessionManager()
            let logContent = try await sessionManager.stopLogSession(sessionName: sessionName, fullOutput: full)
            
            if options.json {
                formatter.success(LogStopResponse(success: true, logContent: logContent))
            } else {
                print(logContent)
            }
        } catch let error as XCSentinelError {
            formatter.error(error)
            throw ExitCode.failure
        } catch {
            formatter.error(XCSentinelError.processExecutionFailed(error.localizedDescription))
            throw ExitCode.failure
        }
    }
}

struct LogTailCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tail",
        abstract: "Stream live logs from a session",
        discussion: """
            Follows the log file in real-time, similar to 'tail -f'.
            Press Ctrl+C to stop streaming.
            
            Note: JSON output is not supported for live streaming.
            """
    )
    
    @Argument(help: "The session name to tail")
    var sessionName: String
    
    @OptionGroup var options: GlobalOptions
    
    func run() async throws {
        let formatter = OutputFormatter(json: options.json)
        
        if options.json {
            formatter.error(XCSentinelError.invalidConfiguration("JSON output not supported for tail command"))
            throw ExitCode.failure
        }
        
        do {
            let sessionManager = SessionManager()
            try await sessionManager.tailLogSession(sessionName: sessionName)
        } catch let error as XCSentinelError {
            formatter.error(error)
            throw ExitCode.failure
        } catch {
            formatter.error(XCSentinelError.processExecutionFailed(error.localizedDescription))
            throw ExitCode.failure
        }
    }
}

struct LogListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List active log sessions",
        discussion: """
            Shows all currently active log sessions with their PIDs,
            bundle IDs, and target devices.
            
            Automatically cleans up sessions for terminated processes.
            """
    )
    
    @OptionGroup var options: GlobalOptions
    
    func run() async throws {
        let formatter = OutputFormatter(json: options.json)
        
        do {
            let sessionManager = SessionManager()
            let sessions = try await sessionManager.listSessions()
            
            let sessionData = sessions.map { session in
                LogSessionInfo(
                    name: session.name,
                    pid: session.pid,
                    bundleId: session.bundleID,
                    targetUdid: session.targetUDID
                )
            }
            
            if options.json {
                formatter.success(LogListResponse(success: true, activeSessions: sessionData))
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
            formatter.error(XCSentinelError.processExecutionFailed(error.localizedDescription))
            throw ExitCode.failure
        }
    }
}

struct LogCleanCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clean",
        abstract: "Clean up stale log sessions",
        discussion: """
            Removes log sessions where the logging process has terminated.
            This is automatically done by 'list', but can be run manually.
            """
    )
    
    @OptionGroup var options: GlobalOptions
    
    func run() async throws {
        let formatter = OutputFormatter(json: options.json)
        
        do {
            let sessionManager = SessionManager()
            try await sessionManager.cleanStaleSessions()
            
            if options.json {
                formatter.success(CleanResponse(success: true, message: "Stale sessions cleaned"))
            } else {
                print("Cleaned up stale log sessions")
            }
        } catch let error as XCSentinelError {
            formatter.error(error)
            throw ExitCode.failure
        } catch {
            formatter.error(XCSentinelError.processExecutionFailed(error.localizedDescription))
            throw ExitCode.failure
        }
    }
}