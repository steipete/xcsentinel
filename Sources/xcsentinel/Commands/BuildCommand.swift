import ArgumentParser
import Foundation

struct BuildCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Build an Xcode project or workspace"
    )
    
    @Option(name: .long, help: "The scheme to build")
    var scheme: String
    
    @Option(name: .long, help: "The destination specifier")
    var destination: String
    
    @Option(name: .long, help: "Path to the workspace")
    var workspace: String?
    
    @Option(name: .long, help: "Path to the project")
    var project: String?
    
    @Flag(name: .long, help: "Disable incremental builds")
    var noIncremental = false
    
    @Flag(name: .long, help: "Output in JSON format")
    var json = false
    
    func run() throws {
        let formatter = OutputFormatter(json: json)
        
        do {
            let buildEngine = BuildEngine()
            let configuration = BuildEngine.BuildConfiguration(
                scheme: scheme,
                destination: destination,
                workspace: workspace,
                project: project,
                noIncremental: noIncremental
            )
            
            let result = try buildEngine.build(configuration: configuration)
            
            if result.exitCode == 0 {
                if json {
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