import Foundation

struct Device {
    let udid: String
    let name: String
    let osVersion: String?
    let isSimulator: Bool
}

class DeviceManager {
    
    func resolveDestination(_ destination: String) throws -> String {
        // Parse destination string
        let components = parseDestination(destination)
        
        if let id = components["id"] {
            // Direct UDID provided
            return id
        }
        
        guard let platform = components["platform"],
              let name = components["name"] else {
            throw XCSentinelError.invalidDestination(destination)
        }
        
        let isSimulator = platform.lowercased().contains("simulator")
        
        if isSimulator {
            return try resolveSimulator(name: name, os: components["OS"])
        } else {
            return try resolveDevice(name: name)
        }
    }
    
    private func parseDestination(_ destination: String) -> [String: String] {
        var components: [String: String] = [:]
        
        // Split by comma first
        let pairs = destination.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        for pair in pairs {
            if pair.contains("=") {
                let keyValue = pair.split(separator: "=", maxSplits: 1)
                if keyValue.count == 2 {
                    let key = String(keyValue[0]).trimmingCharacters(in: .whitespaces)
                    let value = String(keyValue[1]).trimmingCharacters(in: .whitespaces)
                    components[key] = value
                }
            }
        }
        
        return components
    }
    
    private func resolveSimulator(name: String, os: String?) throws -> String {
        let result = try ProcessExecutor.execute(
            "/usr/bin/xcrun",
            arguments: ["simctl", "list", "devices", "-j"]
        )
        
        if result.exitCode != 0 {
            throw XCSentinelError.processExecutionFailed("Failed to list simulators: \(result.error)")
        }
        
        guard let data = result.output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devices = json["devices"] as? [String: Any] else {
            throw XCSentinelError.processExecutionFailed("Failed to parse simulator list")
        }
        
        var matches: [(udid: String, fullName: String)] = []
        
        for (runtime, deviceList) in devices {
            guard let deviceArray = deviceList as? [[String: Any]] else { continue }
            
            for device in deviceArray {
                guard let deviceName = device["name"] as? String,
                      let udid = device["udid"] as? String,
                      let state = device["state"] as? String,
                      state == "Booted" || state == "Shutdown" else { continue }
                
                if deviceName == name {
                    let osVersion = runtime.replacingOccurrences(of: "com.apple.CoreSimulator.SimRuntime.", with: "")
                    let fullName = "\(deviceName) (\(osVersion))"
                    matches.append((udid: udid, fullName: fullName))
                }
            }
        }
        
        if matches.isEmpty {
            throw XCSentinelError.simulatorNotFound(name: name)
        }
        
        if matches.count > 1 {
            let fullNames = matches.map { $0.fullName }
            throw XCSentinelError.ambiguousSimulator(name: name, matches: fullNames)
        }
        
        return matches[0].udid
    }
    
    private func resolveDevice(name: String) throws -> String {
        let result = try ProcessExecutor.execute(
            "/usr/bin/xcrun",
            arguments: ["devicectl", "list", "devices", "-j"]
        )
        
        if result.exitCode != 0 {
            throw XCSentinelError.processExecutionFailed("Failed to list devices: \(result.error)")
        }
        
        guard let data = result.output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let devices = result["devices"] as? [[String: Any]] else {
            throw XCSentinelError.processExecutionFailed("Failed to parse device list")
        }
        
        var matches: [(udid: String, name: String)] = []
        
        for device in devices {
            guard let deviceName = device["name"] as? String,
                  let udid = device["identifier"] as? String else { continue }
            
            if deviceName == name {
                matches.append((udid: udid, name: deviceName))
            }
        }
        
        if matches.isEmpty {
            throw XCSentinelError.simulatorNotFound(name: name) // Reuse error type
        }
        
        if matches.count > 1 {
            let names = matches.map { $0.name }
            throw XCSentinelError.ambiguousSimulator(name: name, matches: names)
        }
        
        return matches[0].udid
    }
    
    func installApp(udid: String, appPath: String) throws {
        // Check if simulator or device
        let isSimulator = try isSimulatorUDID(udid)
        
        if isSimulator {
            let result = try ProcessExecutor.execute(
                "/usr/bin/xcrun",
                arguments: ["simctl", "install", udid, appPath]
            )
            
            if result.exitCode != 0 {
                throw XCSentinelError.processExecutionFailed("Failed to install app: \(result.error)")
            }
        } else {
            let result = try ProcessExecutor.execute(
                "/usr/bin/xcrun",
                arguments: ["devicectl", "device", "install", "app", "--device", udid, appPath]
            )
            
            if result.exitCode != 0 {
                throw XCSentinelError.processExecutionFailed("Failed to install app: \(result.error)")
            }
        }
    }
    
    func launchApp(udid: String, bundleID: String) throws {
        let isSimulator = try isSimulatorUDID(udid)
        
        if isSimulator {
            let result = try ProcessExecutor.execute(
                "/usr/bin/xcrun",
                arguments: ["simctl", "launch", udid, bundleID]
            )
            
            if result.exitCode != 0 {
                throw XCSentinelError.processExecutionFailed("Failed to launch app: \(result.error)")
            }
        } else {
            let result = try ProcessExecutor.execute(
                "/usr/bin/xcrun",
                arguments: ["devicectl", "device", "process", "launch", "--device", udid, bundleID]
            )
            
            if result.exitCode != 0 {
                throw XCSentinelError.processExecutionFailed("Failed to launch app: \(result.error)")
            }
        }
    }
    
    private func isSimulatorUDID(_ udid: String) throws -> Bool {
        let result = try ProcessExecutor.execute(
            "/usr/bin/xcrun",
            arguments: ["simctl", "list", "devices", "-j"]
        )
        
        if result.exitCode != 0 {
            throw XCSentinelError.processExecutionFailed("Failed to list devices: \(result.error)")
        }
        
        return result.output.contains(udid)
    }
}