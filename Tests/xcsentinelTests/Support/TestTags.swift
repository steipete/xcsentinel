import Testing

extension Tag {
    @Tag static var unit: Self
    @Tag static var integration: Self
    @Tag static var fileSystem: Self
    @Tag static var processExecution: Self
    @Tag static var stateManagement: Self
    @Tag static var errorHandling: Self
    @Tag static var commandParsing: Self
    @Tag static var buildSystem: Self
    @Tag static var logManagement: Self
    @Tag static var deviceHandling: Self
    @Tag static var fast: Self
    @Tag static var slow: Self
    @Tag static var network: Self
    @Tag static var flaky: Self
}