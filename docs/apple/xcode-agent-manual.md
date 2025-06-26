# Xcode Agent Command-Line Manual

This document is the complete guide for interacting with Xcode projects, simulators, and devices using a powerful, native command-line toolchain. This manual supersedes any MCP-based approach by providing direct access to a more robust and efficient set of tools.

The primary tools are `xcsentinel` for build orchestration and log management, and `axe` for UI automation.

### 1. Installation

These tools must be installed on the system. Use Homebrew for installation.

```bash
# Install the core orchestrator for build and logging workflows
brew install cameroncooke/tap/xcsentinel

# Install the UI automation tool
brew install cameroncooke/tap/axe
```

### 2. Core Workflows with `xcsentinel`

`xcsentinel` is the primary tool for high-level tasks. It intelligently manages builds and logging sessions.

#### Building an Application (`xcsentinel build`)

This command intelligently uses `make` for fast, incremental builds if a `Makefile` exists, or generates one with `xcodemake`. It falls back to `xcodebuild` if needed.

- **Synopsis:**
  ```bash
  xcsentinel build --scheme <name> --destination <specifier> [--workspace <path> | --project <path>] [--no-incremental]
  ```

- **Key Arguments:**
  *   `--scheme <name>`: **(Required)** The scheme to build.
  *   `--destination <specifier>`: **(Required)** The `xcodebuild` destination string (e.g., `'platform=macOS'`).
  *   `--no-incremental`: (Flag) Force a standard `xcodebuild`, bypassing the acceleration logic.

- **Example (iOS Simulator):**
  ```bash
  xcsentinel build --workspace "MyProject.xcworkspace" --scheme "MyApp" --destination "platform=iOS Simulator,name=iPhone 15 Pro,OS=latest"
  ```

#### Building, Installing, and Running an Application (`xcsentinel run`)

This command orchestrates the entire sequence of building, installing, and launching an app.

- **Synopsis:**
  ```bash
  xcsentinel run --scheme <name> --destination <specifier> [--workspace <path> | --project <path>]
  ```
- **Behavior:**
    1.  Builds the application using the intelligent build engine.
    2.  On success, automatically finds the `.app` bundle and its bundle identifier.
    3.  Resolves the destination name to a UDID (if necessary).
    4.  Ensures the target simulator is booted.
    5.  Installs and launches the application.
    6.  Fails with a clear error if a simulator name cannot be found.

- **Example (macOS):**
  ```bash
  xcsentinel run --project "MyCLI.xcodeproj" --scheme "MyCLI" --destination "platform=macOS,arch=arm64"
  ```

#### Managing Log Sessions (`xcsentinel log`)

`xcsentinel` manages background logging processes using named sessions, so you don't have to track PIDs.

- **Start a Log Session:**
  *   **Command:** `xcsentinel log start --udid <udid> --bundle-id <id>`
  *   **Description:** Starts a log stream in the background for a given app and device/simulator.
  *   **Example:** `xcsentinel log start --udid "ABC-123" --bundle-id "com.example.MyApp"`
  *   **Output:** `INFO: Started log session 'session-1' for com.example.MyApp. PID: 50123.`

- **Stop and View Logs:**
  *   **Command:** `xcsentinel log stop <session-name> [--full]`
  *   **Description:** Stops the session, prints its logs, and cleans up. Prints the last 100 lines by default.
  *   **Example:** `xcsentinel log stop session-1 --full`

- **View Live Logs:**
  *   **Command:** `xcsentinel log tail <session-name>`
  *   **Description:** Streams live logs from an active session without stopping it. Press `Ctrl-C` to exit.
  *   **Example:** `xcsentinel log tail session-1`

- **List Active Sessions:**
  *   **Command:** `xcsentinel log list`
  *   **Description:** Shows all running log sessions and automatically cleans up any that are stale.
  *   **Example:** `xcsentinel log list`

- **Clean Stale Sessions:**
  *   **Command:** `xcsentinel log clean`
  *   **Description:** Manually purges all stale (non-running) sessions from the state file.

### 3. UI Automation with `axe`

`axe` is the dedicated tool for all UI interactions with booted simulators. All `axe` commands require the `--udid <simulator_udid>` flag.

- **Get UI Hierarchy:**
  *   **Description:** Dumps the entire UI hierarchy as JSON, including element labels, identifiers, and frames. **This is the essential first step before any UI interaction.**
  *   **Command:** `axe describe-ui --udid <simulator_udid>`

- **Tap a Coordinate:**
  *   **Description:** Simulates a tap at a specific (x, y) coordinate derived from the `describe-ui` output.
  *   **Command:** `axe tap -x <x_coord> -y <y_coord> --udid <simulator_udid>`

- **Swipe Between Coordinates:**
  *   **Description:** Simulates a swipe from a start point to an end point.
  *   **Command:** `axe swipe --start-x <x1> --start-y <y1> --end-x <x2> --end-y <y2> --udid <simulator_udid>`

- **Type Text:**
  *   **Description:** Types a string of text. The target text field must already have focus.
  *   **Command:** `axe type "<your_text>" --udid <simulator_udid>`

### 4. Foundational System Commands

For basic inspection and direct control, use the standard system tools.

#### Project Inspection
- **List schemes, targets, and configurations:**
  ```bash
  xcodebuild -list -workspace <name>.xcworkspace
  # or
  xcodebuild -list -project <name>.xcodeproj
  ```

#### Simulator & Device Inspection
- **List available simulators (and their UDIDs):**
  ```bash
  xcrun simctl list devices available
  ```
- **List connected physical devices (and their UDIDs):**
  ```bash
  xcrun devicectl list devices
  ```

#### Application Information
- **Get Bundle ID from an `.app` bundle:**
  ```bash
  /usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "/path/to/YourApp.app/Info.plist"
  ```

- **Take a Screenshot:**
  ```bash
  xcrun simctl io <simulator_udid> screenshot screenshot.png
  ```

### 5. Common Workflow Examples

#### A. Full iOS Simulator Workflow: Build, Run, and Log
1.  **Find your scheme and simulator:**
    ```bash
    xcodebuild -list -workspace "MyApp.xcworkspace"
    xcrun simctl list devices available
    ```
2.  **Build and run the app:**
    ```bash
    xcsentinel run --workspace "MyApp.xcworkspace" --scheme "MyApp-Debug" --destination "platform=iOS Simulator,name=iPhone 15 Pro,OS=latest"
    ```
3.  **Start a logging session (app will continue running):**
    ```bash
    xcsentinel log start --udid <simulator_udid_from_step_1> --bundle-id "com.mycompany.myapp"
    ```
4.  **Interact with the app, then stop logging to see results:**
    ```bash
    xcsentinel log stop session-1
    ```

#### B. UI Interaction Workflow
1.  **Launch the app** using `xcsentinel run`.
2.  **Get the UI hierarchy to find your button's frame:**
    ```bash
    axe describe-ui --udid <simulator_udid>
    # Find the 'frame' object for your button in the JSON output, e.g., {"x": 100, "y": 200, "width": 80, "height": 40}
    ```
3.  **Calculate the center and tap the button:**
    *   Center X = 100 + (80 / 2) = 140
    *   Center Y = 200 + (40 / 2) = 220
    ```bash
    axe tap -x 140 -y 220 --udid <simulator_udid>
    ```
4.  **Take a screenshot to verify the result:**
    ```bash
    xcrun simctl io <simulator_udid> screenshot after_tap.png
    ```

### 6. Limitations
This toolchain provides comprehensive functionality for building, running, testing, and interacting with applications. The only feature from the original `xcodebuildmcp` that is not included is **project scaffolding**. Creating new projects must be done manually in Xcode or via other templating tools.