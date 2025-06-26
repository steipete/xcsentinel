import Testing
import Foundation
@testable import xcsentinel

@Suite("OutputFormatter Tests", .tags(.fast))
struct OutputFormatterTests {
    
    // Helper to capture print output
    func captureOutput(_ block: () throws -> Void) rethrows -> String {
        let pipe = Pipe()
        let original = dup(STDOUT_FILENO)
        
        setvbuf(stdout, nil, _IONBF, 0)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        
        try block()
        
        fflush(stdout)
        pipe.fileHandleForWriting.closeFile()
        dup2(original, STDOUT_FILENO)
        close(original)
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    @Test("Plain formatter outputs simple strings")
    func plainStringOutput() throws {
        let formatter = OutputFormatter(json: false)
        
        let output = try captureOutput {
            formatter.success("Build succeeded")
        }
        
        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "Build succeeded")
    }
    
    @Test("Plain formatter outputs error messages")
    func plainErrorOutput() throws {
        let formatter = OutputFormatter(json: false)
        let error = XCSentinelError.buildFailed(message: "Compilation error")
        
        let output = try captureOutput {
            formatter.error(error)
        }
        
        #expect(output.contains("Error: Build failed: Compilation error"))
    }
    
    @Test("JSON formatter outputs success response")
    func jsonSuccessOutput() throws {
        let formatter = OutputFormatter(json: true)
        let response = BuildSuccessResponse(success: true, message: "Build completed")
        
        let output = try captureOutput {
            formatter.success(response)
        }
        
        let data = Data(output.utf8)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        #expect(json?["success"] as? Bool == true)
        
        // The response is wrapped in a SuccessResponse container
        if let dataField = json?["data"] as? [String: Any] {
            #expect(dataField["success"] as? Bool == true)
            #expect(dataField["message"] as? String == "Build completed")
        }
    }
    
    @Test("JSON formatter outputs error response")
    func jsonErrorOutput() throws {
        let formatter = OutputFormatter(json: true)
        let error = XCSentinelError.simulatorNotFound(name: "iPhone 99")
        
        let output = try captureOutput {
            formatter.error(error)
        }
        
        let data = Data(output.utf8)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        #expect(json?["success"] as? Bool == false)
        
        let errorInfo = try #require(json?["error"] as? [String: String])
        #expect(errorInfo["code"] == "SIMULATOR_NOT_FOUND")
        #expect(errorInfo["message"] == "Simulator with name 'iPhone 99' not found.")
    }
    
    @Test("JSON formatter handles complex response types")
    func jsonComplexResponse() throws {
        let formatter = OutputFormatter(json: true)
        
        let response = RunSuccessResponse(
            success: true,
            appPath: "/path/to/MyApp.app",
            bundleId: "com.example.MyApp",
            targetUdid: "ABC123"
        )
        
        let output = try captureOutput {
            formatter.success(response)
        }
        
        let data = Data(output.utf8)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        #expect(json?["success"] as? Bool == true)
        
        if let dataField = json?["data"] as? [String: Any] {
            #expect(dataField["app_path"] as? String == "/path/to/MyApp.app")
            #expect(dataField["bundle_id"] as? String == "com.example.MyApp")
            #expect(dataField["target_udid"] as? String == "ABC123")
        }
    }
    
    @Test("JSON formatter produces pretty-printed output")
    func jsonPrettyPrinting() throws {
        let formatter = OutputFormatter(json: true)
        let response = CleanResponse(message: "Cleaned")
        
        let output = try captureOutput {
            formatter.success(response)
        }
        
        // Pretty-printed JSON should have newlines and indentation
        #expect(output.contains("\n"))
        #expect(output.contains("  ")) // Indentation
    }
    
    @Test("Error formatter handles all error types", arguments: [
        XCSentinelError.simulatorNotFound(name: "test"),
        XCSentinelError.ambiguousSimulator(name: "test", matches: ["a", "b"]),
        XCSentinelError.buildFailed(message: "test"),
        XCSentinelError.invalidDestination("test"),
        XCSentinelError.missingWorkspaceOrProject,
        XCSentinelError.stateFileError("test"),
        XCSentinelError.processExecutionFailed("test"),
        XCSentinelError.sessionNotFound("test"),
        XCSentinelError.invalidConfiguration("test")
    ])
    func allErrorTypes(error: XCSentinelError) throws {
        let formatter = OutputFormatter(json: true)
        
        let output = try captureOutput {
            formatter.error(error)
        }
        
        let data = Data(output.utf8)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        #expect(json?["success"] as? Bool == false)
        #expect(json?["error"] != nil)
    }
}