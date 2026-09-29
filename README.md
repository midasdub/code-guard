# code-guard

A containerized code-quality and security scanner. code-guard packages static analysis tools into a single Docker image that you can run against any project, locally or in CI, without installing the tools on the host.

> **Status:** early development. The image runs a read-only check, a secret scan (TruffleHog) and a lint pass (ESLint), and exits `0` (allowed) or `1` (blocked).

## What's included

| Tool | Purpose | Installed via |
| --- | --- | --- |
| [TruffleHog](https://github.com/trufflesecurity/trufflehog) | Detects leaked secrets (API keys, tokens, credentials) in the mounted files | Pinned release, SHA-256 verified |
| [ESLint](https://eslint.org/) v10 | Lints JavaScript code (`.js`, `.cjs`, `.mjs`) | `package.json` + `package-lock.json` |
| git, curl | Support utilities for the scanners | Alpine `apk` |

The image is based on `node:22.23.3-alpine3.24` (pinned) to keep it small and reproducible.

## Project structure

```
.
├── dockerfile         # Builds the code-guard image
├── entrypoint.sh      # Scan script run when the container starts
├── eslint.config.js   # ESLint flat config applied to scanned code
├── package.json       # Node dependencies (ESLint), exact versions
└── package-lock.json  # Locked dependency tree used by `npm ci`
```

## Requirements

- [Docker](https://docs.docker.com/get-docker/)

## Usage

### Build the image

```sh
docker build -t code-guard -f dockerfile .
```

### Scan a project

Mount the project you want to check at `/workspace`, **read-only** (`:ro`). If the mount is writable, code-guard refuses to run and blocks:

```sh
docker run --rm -v "$(pwd)":/workspace:ro code-guard
```

To scan a different directory, replace `$(pwd)` with its absolute path.

## How it works

1. The image installs git, curl, and a pinned TruffleHog release (to `/usr/local/bin`).
2. Node dependencies are installed into `/app` with `npm ci` from `package-lock.json`.
3. `eslint.config.js` and `entrypoint.sh` are copied into `/app`; the script is the container entrypoint.
4. On `docker run`, the entrypoint scans the code mounted at `/workspace`:
   - fails if `/workspace` is writable;
   - `trufflehog filesystem --fail --no-verification` (exit 183 on findings, no network calls to verify credentials);
   - `eslint . --no-inline-config` (`/* eslint-disable */` comments in the scanned code are ignored).
5. Exit code `0` = allowed, `1` = blocked.

## Configuration

- **ESLint rules:** edit `eslint.config.js` (ESLint [flat config](https://eslint.org/docs/latest/use/configure/configuration-files) format).
- **Scan steps:** edit `entrypoint.sh` to add, remove, or reorder tools.
- **Additional tools:** add Node-based tools to `package.json`, or system tools to the `RUN apk add` line in `dockerfile`.

After changing any of these, rebuild the image.

## Decisions

Design decisions and their reasons are recorded in [JOURNAL.md](JOURNAL.md) (in French).
