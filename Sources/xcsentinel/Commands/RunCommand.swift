import ArgumentParser
import Foundation

struct RunCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Build, install, and launch an application"
    )
    
    @Option(name: .long, help: "The scheme to build and run")
    var scheme: String
    
    @Option(name: .long, help: "The destination specifier")
    var destination: String
    
    @Option(name: .long, help: "Path to the workspace")
    var workspace: String?
    
    @Option(name: .long, help: "Path to the project")
    var project: String?
    
    @Flag(name: .long, help: "Output in JSON format")
    var json = false
    
    func run() throws {
        let formatter = OutputFormatter(json: json)
        
        do {
            // Build the project
            let buildEngine = BuildEngine()
            let configuration = BuildEngine.BuildConfiguration(
                scheme: scheme,
                destination: destination,
                workspace: workspace,
                project: project,
                noIncremental: false
            )
            
            let buildResult = try buildEngine.build(configuration: configuration)
            
            if buildResult.exitCode != 0 {
                throw XCSentinelError.buildFailed(message: buildResult.error.isEmpty ? buildResult.output : buildResult.error)
            }
            
            // Get build settings
            let settings = try buildEngine.getBuildSettings(configuration: configuration)
            
            guard let productsDir = settings["BUILT_PRODUCTS_DIR"],
                  let productName = settings["FULL_PRODUCT_NAME"],
                  let bundleID = settings["PRODUCT_BUNDLE_IDENTIFIER"] else {
                throw XCSentinelError.buildFailed(message: "Failed to retrieve build settings")
            }
            
            let appPath = "\(productsDir)/\(productName)"
            
            // Resolve destination to UDID
            let deviceManager = DeviceManager()
            let udid = try deviceManager.resolveDestination(destination)
            
            // Install the app
            try deviceManager.installApp(udid: udid, appPath: appPath)
            
            // Launch the app
            try deviceManager.launchApp(udid: udid, bundleID: bundleID)
            
            if json {
                let response = RunSuccessResponse(
                    success: true,
                    appPath: appPath,
                    bundleId: bundleID,
                    targetUdid: udid
                )
                formatter.success(response)
            } else {
                print("Successfully built and launched \(productName)")
                print("Bundle ID: \(bundleID)")
                print("Target: \(udid)")
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