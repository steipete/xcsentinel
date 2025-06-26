# Changelog

## [Unreleased]

### Fixed
- **Critical**: Fixed simulator log streaming to use `simctl spawn <udid> log stream` instead of `simctl log stream`
  - Previous implementation had race conditions when multiple simulators were running
  - The ambiguous command would stream from the "default" simulator instead of the specified UDID
  - This could cause logs to be captured from the wrong simulator or mixed between simulators
  - Updated both specification (spec.md) and implementation (SessionManager.swift)
  - Added comprehensive test coverage in LogStreamingTests.swift and LogCommandIntegrationTests.swift

### Changed
- Updated Software Design Document to version 3.0 with corrected log streaming specification
- Enhanced SPEC_COMPLIANCE.md to document the fix and test coverage

## [1.0.0] - 2025-06-26

### Added
- Initial implementation of xcsentinel CLI tool
- Accelerated builds with xcodemake integration
- Unified run command for build, install, and launch
- Stateful log session management
- JSON output support for automation
- Comprehensive test suite using Swift Testing framework
- Full compliance with Software Design Document v2.0

### Credits
- Inspired by [XcodeBuildMCP](https://github.com/cameroncooke/XcodeBuildMCP) by Cameron Cooke
- Created as an experiment to compare CLI tools vs MCP servers for developer automation