# Code Coverage Setup

This project uses [Codecov](https://codecov.io) for code coverage reporting. Coverage reports are automatically generated in CI and posted as comments on pull requests.

## Setup Instructions

### 1. Enable Codecov for the Repository

1. Go to [codecov.io](https://codecov.io) and sign in with GitHub
2. Find the `xcsentinel` repository and enable it
3. Copy the upload token from the repository settings

### 2. Add the Codecov Token to GitHub Secrets

1. Go to the repository settings on GitHub
2. Navigate to Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. Name: `CODECOV_TOKEN`
5. Value: Paste the token from Codecov

### 3. How It Works

- Tests run with `--enable-code-coverage` flag
- Coverage data is converted to LCOV format using `xcrun llvm-cov`
- Codecov Action uploads the coverage report
- Pull requests automatically get coverage comments
- Comments are updated in-place (not recreated)

## Coverage Configuration

The `codecov.yml` file configures:
- Target coverage thresholds (auto-detected with 1% threshold)
- PR comment layout and behavior
- Files to ignore (Tests, .build, etc.)

## Running Coverage Locally

```bash
# Run tests with coverage
swift test --enable-code-coverage

# Generate coverage report
xcrun llvm-cov report \
  .build/debug/xcsentinelPackageTests.xctest/Contents/MacOS/xcsentinelPackageTests \
  -instr-profile=.build/debug/codecov/default.profdata \
  -ignore-filename-regex=".build|Tests"
```

## Troubleshooting

If coverage shows 0%:
1. Ensure tests are actually running (not hanging)
2. Check that integration tests are properly skipped
3. Verify the test binary path is correct
4. Ensure profdata file exists after test run