import ArgumentParser
import Foundation

struct RunCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Build, install, and launch an application",
        discussion: """
            Performs a complete workflow: builds your app, installs it on the target
            device or simulator, and launches it.
            
            This command combines the build process with deployment, automatically
            resolving destination names to UDIDs and handling both simulators and
            physical devices.
            
            Examples:
              Run on simulator:
                xcsentinel run --scheme MyApp --workspace MyApp.xcworkspace \\
                  --destination "platform=iOS Simulator,name=iPhone 15 Pro"
              
              Run on device by UDID:
                xcsentinel run --scheme MyApp --project MyApp.xcodeproj \\
                  --destination "id=00008120-001234567890ABCD"
              
              Run with JSON output:
                xcsentinel run --scheme MyApp --workspace MyApp.xcworkspace \\
                  --destination "platform=iOS Simulator,name=iPhone 15" --json
            
            The command will:
            1. Build the specified scheme
            2. Extract app path and bundle ID from build settings
            3. Resolve the destination to a specific device UDID
            4. Install the app on the target device
            5. Launch the app
            """
    )
    
    @Option(name: .long, help: "The scheme to build and run")
    var scheme: String
    
    @Option(name: .long, help: "The destination specifier")
    var destination: String
    
    @Option(name: .long, help: "Path to the workspace")
    var workspace: String?
    
    @Option(name: .long, help: "Path to the project")
    var project: String?
    
    @OptionGroup var options: GlobalOptions
    
    func run() async throws {
        let formatter = OutputFormatter(json: options.json)
        
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
            
            let buildResult = try await buildEngine.build(configuration: configuration)
            
            if buildResult.exitCode != 0 {
                throw XCSentinelError.buildFailed(message: buildResult.error.isEmpty ? buildResult.output : buildResult.error)
            }
            
            // Get build settings
            let settings = try await buildEngine.getBuildSettings(configuration: configuration)
            
            guard let productsDir = settings["BUILT_PRODUCTS_DIR"],
                  let productName = settings["FULL_PRODUCT_NAME"],
                  let bundleID = settings["PRODUCT_BUNDLE_IDENTIFIER"] else {
                throw XCSentinelError.buildFailed(message: "Failed to retrieve build settings")
            }
            
            let appPath = "\(productsDir)/\(productName)"
            
            // Resolve destination to UDID
            let deviceManager = DeviceManager()
            let udid = try await deviceManager.resolveDestination(destination)
            
            // Install the app
            try await deviceManager.installApp(udid: udid, appPath: appPath)
            
            // Launch the app
            try await deviceManager.launchApp(udid: udid, bundleID: bundleID)
            
            if options.json {
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