#!/bin/bash

echo "Running test summary..."

# Run tests with timeout and capture output
timeout 30 swift test 2>&1 | tee test-output.txt

# Count results
echo ""
echo "=== Test Summary ==="
echo "Passing tests: $(grep -c "✔ Test" test-output.txt || echo 0)"
echo "Failing tests: $(grep -c "✘ Test" test-output.txt || echo 0)"
echo "Total tests started: $(grep -c "◇ Test.*started" test-output.txt || echo 0)"
echo ""

# Show failures
echo "=== Test Failures ==="
grep "✘ Test" test-output.txt | head -10 || echo "No failures found in output"

# Clean up
rm -f test-output.txt