# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

xcsentinel is a native macOS CLI tool that enhances Xcode development workflows with advanced, stateful functionality. It demonstrates that well-designed CLI tools can be more effective than MCP servers for developer tooling.

## Common Development Commands

### Building and Testing
```bash
# Build debug version
swift build

# Build release version  
swift build -c release

# Run all tests
swift test

# Run fast tests only
swift test --filter .fast

# Skip integration tests
swift test --skip .integration

# Build universal binary for distribution
make -f Makefile.install build
```

### Installation
```bash
# Install to /usr/local/bin
make -f Makefile.install install

# Or manually
swift build -c release
sudo cp .build/release/xcsentinel /usr/local/bin/
```

## Architecture Overview

### Project Structure
- **Commands/** - CLI command implementations using ArgumentParser
- **Core/** - Business logic (BuildEngine, SessionManager, DeviceManager, etc.)
- **Models/** - Data structures and error types
- **Tests/** - Comprehensive test suite using Swift Testing framework

### Key Design Patterns
1. **Protocol-based design** for testability (see ProcessExecutorProtocol, StateControllerProtocol)
2. **Dependency injection** throughout for testing
3. **Atomic file operations** for state management (StateController.swift:55-65)
4. **Session-based log management** with PID tracking (SessionManager.swift)

### State Management
- State persisted in `~/.xcsentinel/state.json`
- Log files stored in `~/.xcsentinel/logs/`
- Atomic writes using temp file + rename pattern
- Automatic cleanup of stale sessions

## Key Implementation Details

### Incremental Build System
The BuildEngine (Sources/xcsentinel/Core/BuildEngine.swift) implements intelligent incremental builds:
1. Checks for `.xcsentinel.rc` marker file
2. Validates timestamps recursively against project files
3. Uses or generates Makefile with xcodemake
4. Falls back to xcodebuild if needed

### Log Streaming Fix
**Important**: Use `simctl spawn <udid> log stream` instead of `simctl log stream` to target specific simulators (LogSession.swift:45-50). This prevents race conditions with multiple simulators.

### Error Handling
All errors use typed XCSentinelError enum with:
- Structured error codes for JSON output
- Clear user-facing messages
- Proper localization support

## Testing Guidelines

### Running Tests
Tests use Swift Testing framework (@Test, #expect, #require):
- Tag tests appropriately: .fast, .integration, .fileSystem
- Use MockProcessExecutor for command execution tests
- Use temporary directories for file system tests

### Test Organization
- Unit tests mirror source structure in Tests/xcsentinelTests/
- Integration tests in Tests/xcsentinelTests/Integration/
- Mock objects in Tests/xcsentinelTests/Mocks/

## Documentation Guide

### Core Project Documentation

#### `docs/spec.md` - xcsentinel Specification
**Load when:**
- Implementing new xcsentinel features or commands
- Understanding the overall architecture
- Working on build system integration
- Implementing log session management
- Debugging error handling for humans or AI agents
- Understanding state management and configuration

### Swift Development Documentation

#### `docs/apple/modern-swift.md` - Modern SwiftUI Patterns
**Load when:**
- Building SwiftUI interfaces
- Implementing state management (@State, @Binding, @Observable)
- Migrating from UIKit patterns
- Working with async/await in SwiftUI
- Organizing code by features

#### `docs/apple/swift-concurrency.md` - Swift 6 Concurrency
**Load when:**
- Implementing concurrent code with actors
- Ensuring data race safety
- Working with Sendable types
- Migrating to Swift 6's strict concurrency
- Debugging concurrency issues

#### `docs/apple/swift6-migration.mdc` - Swift 6 Migration
**Load when:**
- Upgrading code from Swift 5 to Swift 6
- Dealing with Swift 6 breaking changes
- Understanding deprecated patterns

### Command-Line Tool Development

#### `docs/apple/swift-argument-parser.mdc` - ArgumentParser Framework
**Load when:**
- Adding new CLI commands to xcsentinel
- Implementing command-line parsing
- Adding custom completions
- Working with subcommands
- Implementing validation logic

### Testing Documentation

#### `docs/apple/swift-testing-api.mdc` - Swift Testing API Reference
**Load when:**
- Looking up specific Swift Testing APIs
- Understanding test organization patterns
- Working with test traits and tags
- Quick API reference needed

#### `docs/apple/swift-testing-playbook.mdc` - Swift Testing Migration Guide
**Load when:**
- Migrating tests from XCTest to Swift Testing
- Implementing complex test scenarios
- Learning Swift Testing best practices
- Understanding #expect vs #require
- Working with async tests

## Quick Reference

- **New feature development**: Load `spec.md` + relevant Swift docs
- **CLI work**: Load `spec.md` + `swift-argument-parser.mdc`
- **Testing**: Load both testing documents
- **Concurrency issues**: Load `swift-concurrency.md`
- **UI development**: Load `modern-swift.md`
- **Swift 6 upgrade**: Load `swift6-migration.mdc` + `swift-concurrency.md`

## Development Tips

### Adding New Commands
1. Create new command file in Commands/
2. Inherit from ParsableCommand
3. Add to XCSentinel.subcommands array
4. Write tests using MockProcessExecutor

### Working with State
- Always use StateController for persistence
- Handle concurrent access with atomic operations
- Clean up resources in error paths

### JSON Output
- All commands support --json flag
- Use OutputFormatter for consistent formatting
- Snake_case for all JSON fields (via CodingKeys)