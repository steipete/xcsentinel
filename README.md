# xcsentinel

A native macOS command-line tool that augments the Xcode development workflow with advanced, stateful functionality.

## Project Background

This project was greatly inspired by [XcodeBuildMCP](https://github.com/cameroncooke/XcodeBuildMCP) and serves as an experiment to explore whether Model Context Protocol (MCP) servers are necessary for Xcode automation, or if traditional CLI tools provide a better solution.

### CLI vs MCP: An Experiment

The goal of xcsentinel is to test the hypothesis that well-designed command-line tools can be more effective than MCP servers for developer tooling:

- **Direct Integration**: CLI tools integrate naturally with existing developer workflows, scripts, and CI/CD pipelines
- **Simplicity**: No additional protocol layer or server management required
- **Performance**: Direct execution without the overhead of client-server communication
- **Composability**: Unix philosophy - tools that do one thing well and compose together
- **AI-Friendly**: Structured output (JSON) makes it easy for AI agents to parse and use

While MCP servers have their place for certain integrations, this project demonstrates that for build automation and development workflows, a thoughtfully designed CLI tool can provide a superior developer experience.

## Features

- **Accelerated Builds**: Intelligent incremental build system leveraging `xcodemake` for fast, efficient builds
- **Workflow Automation**: Unified `run` command to build, install, and launch applications
- **Stateful Log Management**: Session-based management for background log streams with automatic cleanup
- **JSON Output Support**: Machine-readable output for automation and AI agents
- **Smart Device Handling**: Automatic resolution of simulators and devices with clear error messages

## Installation

### From Source

```bash
git clone https://github.com/steipete/xcsentinel.git
cd xcsentinel
swift build -c release
sudo cp .build/release/xcsentinel /usr/local/bin/
```

### Via Homebrew (Coming Soon)

```bash
brew tap steipete/xcsentinel
brew install xcsentinel
```

## Requirements

- macOS 14.0+
- Xcode Command Line Tools
- Swift 5.9+
- Optional: [xcodemake](https://github.com/xcodemake/xcodemake) for incremental builds

## Usage

### Building Projects

Build with automatic incremental build detection:

```bash
xcsentinel build --scheme MyApp --destination "platform=iOS Simulator,name=iPhone 15"
```

Build with workspace:

```bash
xcsentinel build --scheme MyApp --workspace MyApp.xcworkspace --destination "platform=iOS Simulator,name=iPhone 15"
```

Disable incremental builds:

```bash
xcsentinel build --scheme MyApp --project MyApp.xcodeproj --destination "id=ABC123" --no-incremental
```

### Running Applications

Build, install, and launch in one command:

```bash
xcsentinel run --scheme MyApp --destination "platform=iOS Simulator,name=iPhone 15 Pro"
```

With JSON output for automation:

```bash
xcsentinel run --scheme MyApp --destination "id=ABC123" --json
```

### Log Management

Start a log session:

```bash
xcsentinel log start --udid ABC123 --bundle-id com.example.MyApp
# Output: Started log session: session-1
```

View logs from a session:

```bash
# Last 100 lines (default)
xcsentinel log stop session-1

# Full log output
xcsentinel log stop session-1 --full
```

Stream live logs:

```bash
xcsentinel log tail session-1
```

List active sessions:

```bash
xcsentinel log list
# Output:
# Active log sessions:
#   session-1 - PID: 50123, Bundle: com.example.MyApp, Target: ABC123
```

Clean up stale sessions:

```bash
xcsentinel log clean
```

## How It Works

### Incremental Builds

1. xcsentinel checks for a `.xcsentinel.rc` marker file
2. Compares modification times against all project files
3. If valid, uses existing Makefile or generates one with xcodemake
4. Falls back to standard xcodebuild if needed
5. Automatically cleans up on build failures

### Log Sessions

- Logs are stored in `~/.xcsentinel/logs/`
- Session state is tracked in `~/.xcsentinel/state.json`
- Automatic cleanup of terminated processes
- Supports both simulators (via `simctl`) and devices (via `devicectl`)

### Error Handling

xcsentinel provides clear error messages for common issues:

- Ambiguous simulator names with suggestions
- Missing workspace/project specifications
- Build failures with detailed output
- Session not found errors

## JSON Output

All commands support `--json` flag for machine-readable output:

```json
{
  "success": true,
  "app_path": "/path/to/MyApp.app",
  "bundle_id": "com.example.MyApp",
  "target_udid": "ABC123"
}
```

Error responses:

```json
{
  "success": false,
  "error": {
    "code": "SIMULATOR_NOT_FOUND",
    "message": "Simulator with name 'iPhone 99' not found."
  }
}
```

## Why xcsentinel Over MCP?

After experimenting with both approaches, here's what we learned:

1. **Lower Barrier to Entry**: Developers already understand CLI tools. No need to learn MCP protocols or set up servers.

2. **Better Debugging**: When something goes wrong, it's much easier to debug a CLI tool than a client-server protocol.

3. **Ecosystem Integration**: Works seamlessly with Make, shell scripts, GitHub Actions, and other existing tools.

4. **Stateful When Needed**: The log session management demonstrates that CLI tools can maintain state effectively without requiring a persistent server.

5. **AI Integration**: The JSON output mode provides the same structured data that MCP would, but through a simpler interface that AI agents can easily invoke.

## Credits

Special thanks to [Cameron Cooke](https://github.com/cameroncooke) for creating [XcodeBuildMCP](https://github.com/cameroncooke/XcodeBuildMCP), which inspired this exploration into the best way to provide Xcode automation tools for both human developers and AI agents.

## Contributing

Contributions are welcome! Please read:
- [Software Design Document](docs/spec.md) - Original specification
- [Spec Compliance](SPEC_COMPLIANCE.md) - Implementation compliance and known limitations
- [Testing Guide](Tests/README.md) - How to write and run tests

## License

MIT License - see [LICENSE](LICENSE) file for details.