#!/bin/sh

# CODE_GUARD_VERSION / CODE_GUARD_REVISION are baked into the image at build time,
# so every report says which version of code-guard produced the verdict
echo "Starting Code-Guard ${CODE_GUARD_VERSION} (commit ${CODE_GUARD_REVISION}): initializing analysis..."

# Verify that the target code directory exists
if [ ! -d "/workspace" ]; then
  echo "Error: Directory /workspace not found. Target code is not mounted."
  exit 1
fi

# Navigate to the directory containing the mounted code
cd /workspace

# --- CHECK 0: Read-Only Isolation Proof (Défi 1) ---
echo "--- ISOLATION CHECK: Testing Read-Only File System ---"
# Attempt to create a test file. Redirect stderr to keep output controlled.
if touch /workspace/test_file.txt 2>/dev/null; then
    echo "::error::CRITICAL ISOLATION FAILURE: Container has write permissions to the PR code!"
    # Clean up the file if created and terminate immediately
    rm -f /workspace/test_file.txt
    exit 1
else
    echo "ISOLATION SUCCESS: System returned 'Read-only file system' error. Agent cannot modify code."
fi

# --- CHECK 1: Secret Scanning (TruffleHog) ---
echo "--- Scanning for secrets (TruffleHog) ---"
# --fail: exit 183 when secrets are found (by default trufflehog exits 0 even with findings)
# --no-verification: never send found credentials over the network; also keeps results
#   identical offline, locally and in CI
# --no-update: never self-update, so the scanned version is the one pinned in the image
trufflehog filesystem . --fail --no-verification --no-update
TRUFFLEHOG_STATUS=$?

if [ $TRUFFLEHOG_STATUS -ne 0 ]; then
    echo "::error::Potential secret leaks detected!"
fi

# --- CHECK 2: Code Linting (ESLint) ---
echo "--- Code Linting (ESLint) ---"
# Run ESLint installed inside the container at /app
# "." + the "files" patterns in the config cover .js, .cjs and .mjs.
# --no-inline-config: ignore "/* eslint-disable */" comments, otherwise the agent
#   could switch the rules off from inside its own code
# --no-error-on-unmatched-pattern: a project with no JavaScript file (e.g. a PR that
#   only changes the README) is not an error; any other ESLint failure still blocks
/app/node_modules/.bin/eslint . --config /app/eslint.config.js --no-inline-config --no-error-on-unmatched-pattern
ESLINT_STATUS=$?

if [ $ESLINT_STATUS -ne 0 ]; then
    echo "::error::Linting errors or suspicious code detected."
fi

# --- FINAL VERDICT ---
if [ $TRUFFLEHOG_STATUS -ne 0 ] || [ $ESLINT_STATUS -ne 0 ]; then
    echo "VERDICT: BLOCKED. Analysis identified issues."
    exit 1
fi

echo "VERDICT: SUCCESS. Code is safe and passed all checks."
exit 0