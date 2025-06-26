https://aistudio.google.com/prompts/10z8B5GOaUi4xbpp8xWDYmf5CehfAOpMM

## Software Design Document: `xcsentinel`

**Version:** 3.0
**Date:** 2025-06-26
**Status:** Final, Ready for Implementation

### 1. Introduction

#### 1.1 Purpose
This document specifies the complete and final design for `xcsentinel`, a native macOS command-line interface (CLI) tool engineered to augment the Xcode development workflow. It provides advanced, stateful functionality to simplify and accelerate common development tasks which are complex or tedious to perform using individual, stateless terminal commands. The tool is designed for both human developers and automated AI agents who require a robust, scriptable interface for Xcode project interaction.

#### 1.2 Scope
`xcsentinel` focuses on orchestrating complex workflows and managing background processes.

**In-Scope Features:**
*   **Accelerated Builds:** An intelligent build system that leverages `xcodemake` to enable fast, incremental builds, with a robust invalidation strategy.
*   **Workflow Automation:** A unified `run` command to orchestrate the build, installation, and launch of an application, with detailed device/simulator handling.
*   **Stateful Log Management:** Session-based management for starting, stopping, and viewing multiple background log streams from simulators and devices, with automatic stale session cleanup.

**Out-of-Scope Features:**
*   Simple wrappers for single `xcodebuild` or `xcrun` commands.
*   Project scaffolding and template generation.
*   UI automation.
*   Direct manipulation of Xcode project files (`.pbxproj`).

#### 1.3 Definitions, Acronyms, and Abbreviations
*   **CLI:** Command-Line Interface
*   **PID:** Process ID
*   **UDID:** Unique Device Identifier
*   **`xcodemake`:** An optional, external tool that generates a `Makefile` for incremental builds.
*   **State File:** A local JSON file (`~/.xcsentinel/state.json`) used to persist information about active log sessions.
*   **Marker File:** An empty file (`.xcsentinel.rc`) whose modification timestamp is used to detect if the `Makefile` is stale.

---

### 2. System Overview

#### 2.1 System Architecture
`xcsentinel` acts as an orchestrator, sitting between the user and the standard Xcode command-line tools. It maintains its own state via private files, abstracting this complexity from the user.

```
+----------------+      +------------------+      +--------------------------+
|  User / Agent  |----->|   xcsentinel CLI   |----->|   Xcode Command Tools    |
+----------------+      | (ArgumentParser) |      | (xcodebuild, xcrun, etc.)|
                       +------------------+      +--------------------------+
                                |
                                | Manages
                                v
                       +--------------------+
                       | State & Marker Files|
                       | (~/.xcsentinel/)   |
                       +--------------------+
```

#### 2.2 Core Components
*   **Command Parser:** Leverages `apple/swift-argument-parser` for robust parsing of commands, arguments, and options.
*   **Build Engine:** Orchestrates build commands, selecting the most efficient build method.
*   **Session Manager:** Manages the lifecycle of background logging processes via the state file.
*   **Process Executor:** A wrapper around Swift's `Process` API for executing external commands.
*   **State Controller:** A component ensuring atomic read/write operations on the state file using a write-to-temp-and-rename strategy.
*   **Output Formatter:** Renders command output in either human-readable plain text or machine-readable JSON.

---

### 3. Design Decisions and Implementation Details

This section documents the final resolutions for key design questions, providing specific implementation guidance.

#### 3.1 On the Build Process & Makefile Invalidation

1.  **Makefile Invalidation Strategy:**
    *   **Decision:** The check for a stale `Makefile` will be comprehensive. The modification time of the `.xcsentinel.rc` marker file will be compared against the **most recent modification time of any file within the `.xcodeproj` or `.xcworkspace` directory bundle, scanned recursively.** While potentially slower on massive projects, this guarantees accuracy, which is paramount for build correctness. To mitigate performance impact, this deep scan will only be performed when an incremental build is attempted.

2.  **`make` Failure Handling:**
    *   **Decision:** If `xcsentinel` runs `make` and the command fails, `xcsentinel` will **delete the `.xcsentinel.rc` marker file immediately.** This signals that the last incremental build attempt was unsuccessful and the `Makefile` is now considered invalid. On the subsequent run of `xcsentinel build`, the absence of the marker file will trigger the invalidation logic, causing `xcodemake` to regenerate a fresh `Makefile` and perform a clean build. This prevents the user from getting stuck in a failing `make` loop.

#### 3.2 On Destination & Device Handling

3.  **Ambiguous Simulator Name Resolution:**
    *   **Decision:** If a user provides an ambiguous simulator name (e.g., `name=iPhone 15`) that matches multiple available simulators, `xcsentinel` will **fail with a clear error message.** The error message will list the specific, fully-qualified names of the conflicting simulators (e.g., `"iPhone 15 (17.2)"`, `"iPhone 15 (17.5)"`) and instruct the user to provide a more specific name to resolve the ambiguity. This prioritizes correctness and user clarity over making an assumption.

4.  **Destination String Parsing:**
    *   **Decision:** The destination string parsing will be robust. `xcsentinel` will parse the string into key-value pairs (e.g., `platform`, `name`, `id`, `OS`). The logic for choosing between `simctl` and `devicectl` will be based on the value of the `platform` key. If the string contains "Simulator" (e.g., `platform=iOS Simulator`), `simctl` will be used. For all other valid platforms ("iOS", "macOS", etc.), `devicectl` (or the macOS equivalent) will be used. This allows for precise control and avoids simple string searching.

#### 3.3 On Build Information & App Launch

5.  **Build Information Retrieval (`PlistBuddy` vs. `showBuildSettings`):**
    *   **Decision:** For consistency and robustness, `xcsentinel run` will rely **exclusively on `xcodebuild -showBuildSettings`** for all build-related metadata. After a successful build, it will invoke this command once and parse its output to retrieve `BUILT_PRODUCTS_DIR`, `FULL_PRODUCT_NAME`, and `PRODUCT_BUNDLE_IDENTIFIER`. This centralizes the information source and respects any project-specific customizations to the `Info.plist` path or bundle ID generation.

#### 3.4 On Log Management

6.  **Underlying Log Command:**
    *   **Decision:** The `xcsentinel log start` command will use the most efficient and precise system tool available:
        *   **For Simulators:** It will use `xcrun simctl log stream --predicate 'subsystem == "<bundle_id>"'`. This uses the system's native predicate-based filtering, which is highly performant and accurate, avoiding the overhead of `grep`.
        *   **For Devices:** It will use `xcrun devicectl device console --device <udid> <bundle_id>`.

7.  **Stale PID Check Mechanism:**
    *   **Decision:** The stale session check will be performed by executing `kill -0 <pid>`. This command does not send a signal but checks for the existence of the process and whether the current user has permission to signal it. It is a lightweight, POSIX-compliant method. If the command returns a non-zero exit code, the PID is considered stale and the session will be pruned.

#### 3.5 On Error Handling for Agents

8.  **JSON Error Output:**
    *   **Decision:** The `--json` flag will apply to both success and failure states. If a command fails while the `--json` flag is active, it will print a structured JSON error object to `stdout` and exit with a non-zero status code. This ensures that automated agents can parse both success and error responses consistently. The JSON error schema will be:
        ```json
        {
          "success": false,
          "error": {
            "code": "SIMULATOR_NOT_FOUND",
            "message": "Simulator with name 'iPhone 99' not found."
          }
        }
        ```

---

### 4. Detailed Command Specification

*A global `--json` flag is available for all commands to switch to machine-readable output.*

#### `xcsentinel build`
*   **Synopsis:** `xcsentinel build --scheme <name> --destination <specifier> [--workspace <path> | --project <path>] [--no-incremental]`
*   **Behavior:**
    1.  Recursively checks project file modification times to validate the `.xcsentinel.rc` marker.
    2.  If the marker is stale or a previous `make` command failed, it forces a regeneration.
    3.  Executes the build using the most efficient available method (`make`, `xcodemake`, or `xcodebuild`).
    4.  On a successful `make` or `xcodemake` run, it updates the `.xcsentinel.rc` timestamp.

#### `xcsentinel run`
*   **Synopsis:** `xcsentinel run --scheme <name> --destination <specifier> [--workspace <path> | --project <path>]`
*   **Behavior:**
    1.  Executes the `build` logic.
    2.  On success, runs `xcodebuild -showBuildSettings` to get all necessary build metadata.
    3.  Resolves the destination to a specific UDID, failing on ambiguity.
    4.  Installs and launches the app using the appropriate system tool (`simctl` or `devicectl`).
*   **JSON Output (`--json`):** On success, outputs a JSON object with `success`, `app_path`, `bundle_id`, and `target_udid`. On failure, outputs a structured error JSON object.

#### `xcsentinel log`
*   **`start --udid <udid> --bundle-id <id>`**: Starts a background log stream using the optimal system tool and records the session.
*   **`stop <session-name> [--full]`**: Stops the session. Prints the last 100 lines of the log by default. `--full` prints the entire log.
*   **`tail <session-name>`**: Streams live logs from an active session.
*   **`list`**: Lists active sessions, automatically cleaning up stale sessions found via a `kill -0 <pid>` check.
*   **`clean`**: Manually purges all stale sessions.
*   **JSON Output for `list` (`--json`):**
    ```json
    {
      "active_sessions": [
        { "name": "session-1", "pid": 50123, "bundle_id": "com.example.MyApp", "target_udid": "UDID" }
      ]
    }
    ```

---

### 5. State Management Schema

The state file at `~/.xcsentinel/state.json` will use the following schema:
```json
{
  "global_session_counter": 2,
  "log_sessions": {
    "session-1": {
      "pid": 50123,
      "name": "session-1",
      "target_udid": "ABC-123-DEF-456",
      "bundle_id": "com.example.MyApp",
      "log_path": "/path/to/log.txt",
      "start_time": "2025-06-26T10:00:00Z"
    },
    "session-2": {
      "pid": 50456,
      "name": "session-2",
      "target_udid": "XYZ-789-GHI-012",
      "bundle_id": "com.another.App",
      "log_path": "/path/to/another-log.txt",
      "start_time": "2025-06-26T10:05:00Z"
    }
  }
}
```

---

### 6. Installation and Dependencies
*   **Runtime Dependencies:** macOS 14.0+; Xcode Command Line Tools.
*   **Optional Dependency:** `xcodemake`.
*   **Development Dependencies:** Swift Package Manager; `apple/swift-argument-parser`.
*   **Installation:** Recommended via Homebrew (`brew install <user>/<repo>/xcsentinel`).