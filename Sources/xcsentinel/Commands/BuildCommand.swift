import ArgumentParser
import Foundation

struct BuildCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Build an Xcode project or workspace",
        discussion: """
            Builds your Xcode project with intelligent incremental build support.
            
            The build command automatically detects and uses xcodemake for faster
            incremental builds when available. It creates a .xcsentinel.rc marker
            file to track build state and falls back to standard xcodebuild when
            necessary.
            
            Examples:
              Build with workspace:
                xcsentinel build --scheme MyApp --workspace MyApp.xcworkspace \\
                  --destination "platform=iOS Simulator,name=iPhone 15"
              
              Build with project:
                xcsentinel build --scheme MyApp --project MyApp.xcodeproj \\
                  --destination "platform=iOS Simulator,name=iPhone 15"
              
              Force clean build (no incremental):
                xcsentinel build --scheme MyApp --workspace MyApp.xcworkspace \\
                  --destination "id=ABC123" --no-incremental
              
              Build with JSON output:
                xcsentinel build --scheme MyApp --project MyApp.xcodeproj \\
                  --destination "platform=iOS Simulator,name=iPhone 15" --json
            """
    )
    
    @Option(name: .long, help: ArgumentHelp(
        "The scheme to build",
        discussion: "The Xcode scheme name that defines build settings and targets."
    ))
    var scheme: String
    
    @Option(name: .long, help: ArgumentHelp(
        "The destination specifier",
        discussion: "Xcode destination in format: 'platform=iOS Simulator,name=iPhone 15' or 'id=UDID'"
    ))
    var destination: String
    
    @Option(name: .long, help: ArgumentHelp(
        "Path to the workspace",
        discussion: "Path to .xcworkspace file. Either --workspace or --project must be specified."
    ))
    var workspace: String?
    
    @Option(name: .long, help: ArgumentHelp(
        "Path to the project",
        discussion: "Path to .xcodeproj file. Either --workspace or --project must be specified."
    ))
    var project: String?
    
    @Flag(name: .long, help: ArgumentHelp(
        "Disable incremental builds",
        discussion: "Forces a clean build, ignoring xcodemake and .xcsentinel.rc marker files."
    ))
    var noIncremental = false
    
    @OptionGroup var options: GlobalOptions
    
    func run() async throws {
        let formatter = OutputFormatter(json: options.json)
        
        do {
            let buildEngine = BuildEngine()
            let configuration = BuildEngine.BuildConfiguration(
                scheme: scheme,
                destination: destination,
                workspace: workspace,
                project: project,
                noIncremental: noIncremental
            )
            
            let result = try await buildEngine.build(configuration: configuration)
            
            if result.exitCode == 0 {
                if options.json {
                    formatter.success(BuildSuccessResponse(success: true, message: "Build succeeded"))
                } else {
                    print("Build succeeded")
                }
            } else {
                throw XCSentinelError.buildFailed(message: result.error.isEmpty ? result.output : result.error)
            }
        } catch let error as XCSentinelError {
            formatter.error(error)
            throw ExitCode.failure
        } catch {
            formatter.error(.buildFailed(message: error.localizedDescription))
            throw ExitCode.failure
        }
    }
}