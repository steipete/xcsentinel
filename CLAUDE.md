# xcsentinel Documentation Guide

This guide helps you understand which documentation to load for different tasks in the xcsentinel project.

## Core Project Documentation

### `docs/spec.md` - xcsentinel Specification
**Load when:**
- Implementing new xcsentinel features or commands
- Understanding the overall architecture
- Working on build system integration
- Implementing log session management
- Debugging error handling for humans or AI agents
- Understanding state management and configuration

## Swift Development Documentation

### `docs/apple/modern-swift.md` - Modern SwiftUI Patterns
**Load when:**
- Building SwiftUI interfaces
- Implementing state management (@State, @Binding, @Observable)
- Migrating from UIKit patterns
- Working with async/await in SwiftUI
- Organizing code by features

### `docs/apple/swift-concurrency.md` - Swift 6 Concurrency
**Load when:**
- Implementing concurrent code with actors
- Ensuring data race safety
- Working with Sendable types
- Migrating to Swift 6's strict concurrency
- Debugging concurrency issues

### `docs/apple/swift6-migration.mdc` - Swift 6 Migration
**Load when:**
- Upgrading code from Swift 5 to Swift 6
- Dealing with Swift 6 breaking changes
- Understanding deprecated patterns

## Command-Line Tool Development

### `docs/apple/swift-argument-parser.mdc` - ArgumentParser Framework
**Load when:**
- Adding new CLI commands to xcsentinel
- Implementing command-line parsing
- Adding custom completions
- Working with subcommands
- Implementing validation logic

## Testing Documentation

### `docs/apple/swift-testing-api.mdc` - Swift Testing API Reference
**Load when:**
- Looking up specific Swift Testing APIs
- Understanding test organization patterns
- Working with test traits and tags
- Quick API reference needed

### `docs/apple/swift-testing-playbook.mdc` - Swift Testing Migration Guide
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