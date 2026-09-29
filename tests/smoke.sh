#!/bin/sh
# Smoke test of a built code-guard image: runs it on small generated projects
# and checks the verdict (exit code) for each one.
#
# Usage: tests/smoke.sh [image]     (default image: code-guard:dev)
#
# Fixtures are generated in a temporary directory instead of being committed:
# a fake secret committed to the repository would itself be a leaked secret
# (and would be caught by GitHub secret scanning).

IMAGE="${1:-code-guard:dev}"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
FAILURES=0

# expect <name> <expected exit code> [extra docker run options...]
expect() {
  name=$1; expected=$2; shift 2
  docker run --rm "$@" "$IMAGE" > "$WORK/$name.log" 2>&1
  actual=$?
  if [ "$actual" -eq "$expected" ]; then
    echo "PASS  $name (exit $actual)"
  else
    echo "FAIL  $name: expected exit $expected, got $actual"
    sed 's/^/      /' "$WORK/$name.log"
    FAILURES=$((FAILURES + 1))
  fi
}

# 1. Clean project: must pass
mkdir -p "$WORK/clean"
printf 'const fs = require("fs");\nmodule.exports = () => fs.existsSync(__dirname);\n' > "$WORK/clean/index.js"

# 2. Project without any JavaScript file (e.g. README-only PR): must pass
mkdir -p "$WORK/no-js"
printf '# Hello\n' > "$WORK/no-js/README.md"

# 3. Secret in the code: must be blocked. Random GitHub-token-shaped string,
#    generated at run time, never valid.
mkdir -p "$WORK/secret"
TOKEN=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 36)
printf 'module.exports = "ghp_%s";\n' "$TOKEN" > "$WORK/secret/config.js"

# 4. eval() hidden behind an eslint-disable comment: must be blocked
mkdir -p "$WORK/eval-disabled"
printf '/* eslint-disable */\nmodule.exports = (s) => eval(s);\n' > "$WORK/eval-disabled/index.js"

# 5. eval() in a .cjs file: must be blocked
mkdir -p "$WORK/eval-cjs"
printf 'module.exports = (s) => eval(s);\n' > "$WORK/eval-cjs/index.cjs"

expect clean          0 -v "$WORK/clean:/workspace:ro"
expect no-js          0 -v "$WORK/no-js:/workspace:ro"
expect secret         1 -v "$WORK/secret:/workspace:ro"
expect eval-disabled  1 -v "$WORK/eval-disabled:/workspace:ro"
expect eval-cjs       1 -v "$WORK/eval-cjs:/workspace:ro"
# 6. Writable mount: code-guard must refuse to run
expect writable-mount 1 -v "$WORK/clean:/workspace"
# 7. Nothing mounted: code-guard must refuse to run
expect no-mount       1

if [ "$FAILURES" -ne 0 ]; then
  echo "$FAILURES smoke test(s) failed"
  exit 1
fi
echo "All smoke tests passed"
