import Foundation
@testable import xcsentinel

final class MockProcess: ProcessProtocol {
    var executableURL: URL?
    var arguments: [String]?
    var environment: [String: String]?
    var currentDirectoryURL: URL?
    var standardOutput: Any?
    var standardError: Any?
    
    // Mock properties
    var mockProcessIdentifier: Int32 = 12345
    var mockTerminationStatus: Int32 = 0
    var mockOutput: String = ""
    var mockError: String = ""
    var shouldThrowOnRun = false
    var runWasCalled = false
    var waitUntilExitWasCalled = false
    var terminateWasCalled = false
    
    var processIdentifier: Int32 {
        return mockProcessIdentifier
    }
    
    var terminationStatus: Int32 {
        return mockTerminationStatus
    }
    
    func run() throws {
        runWasCalled = true
        if shouldThrowOnRun {
            throw NSError(domain: "MockProcess", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock process failed to run"])
        }
        
        // Write mock output to pipes if they exist
        if let outputPipe = standardOutput as? Pipe {
            outputPipe.fileHandleForWriting.write(mockOutput.data(using: .utf8)!)
            try? outputPipe.fileHandleForWriting.close()
        }
        
        if let errorPipe = standardError as? Pipe {
            errorPipe.fileHandleForWriting.write(mockError.data(using: .utf8)!)
            try? errorPipe.fileHandleForWriting.close()
        }
    }
    
    func waitUntilExit() {
        waitUntilExitWasCalled = true
    }
    
    func terminate() {
        terminateWasCalled = true
        mockTerminationStatus = 15 // SIGTERM
    }
}

// Factory for creating configured mock processes
struct MockProcessFactory {
    static func xcodebuildSuccess() -> MockProcess {
        let process = MockProcess()
        process.mockTerminationStatus = 0
        process.mockOutput = """
        Build settings from command line:
            SCHEME = MyApp
            DESTINATION = platform=iOS Simulator,name=iPhone 15
        
        Build settings for action build and target MyApp:
            BUILT_PRODUCTS_DIR = /path/to/DerivedData/Build/Products/Debug-iphonesimulator
            FULL_PRODUCT_NAME = MyApp.app
            PRODUCT_BUNDLE_IDENTIFIER = com.example.MyApp
        """
        return process
    }
    
    static func xcodebuildFailure() -> MockProcess {
        let process = MockProcess()
        process.mockTerminationStatus = 65
        process.mockError = "error: no such module 'Testing'"
        return process
    }
    
    static func simctlListDevices() -> MockProcess {
        let process = MockProcess()
        process.mockTerminationStatus = 0
        process.mockOutput = """
        {
          "devices" : {
            "com.apple.CoreSimulator.SimRuntime.iOS-17-2" : [
              {
                "state" : "Shutdown",
                "isAvailable" : true,
                "name" : "iPhone 15",
                "udid" : "ABC123",
                "deviceTypeIdentifier" : "com.apple.CoreSimulator.SimDeviceType.iPhone-15"
              }
            ],
            "com.apple.CoreSimulator.SimRuntime.iOS-17-5" : [
              {
                "state" : "Booted",
                "isAvailable" : true,
                "name" : "iPhone 15",
                "udid" : "DEF456",
                "deviceTypeIdentifier" : "com.apple.CoreSimulator.SimDeviceType.iPhone-15"
              }
            ]
          }
        }
        """
        return process
    }
    
    static func killProcessCheck(exists: Bool) -> MockProcess {
        let process = MockProcess()
        process.mockTerminationStatus = exists ? 0 : 1
        return process
    }
}