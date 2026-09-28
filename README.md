# code-guard

A containerized code-quality and security scanner. code-guard packages static analysis tools into a single Docker image that you can run against any project, locally or in CI, without installing the tools on the host.

> **Status:** early development. The container image is defined, but the scan script (`entrypoint.sh`) and the ESLint configuration (`eslint.config.js`) are still empty placeholders.

## What's included

| Tool | Purpose | Installed via |
| --- | --- | --- |
| [TruffleHog](https://github.com/trufflesecurity/trufflehog) | Detects leaked secrets (API keys, tokens, credentials) in code and git history | Official install script |
| [ESLint](https://eslint.org/) v10 | Lints JavaScript/TypeScript code | `package.json` |
| git, curl | Support utilities for the scanners | Alpine `apk` |

The image is based on `node:22-alpine` to keep it small.

## Project structure

```
.
├── dockerfile         # Builds the code-guard image
├── entrypoint.sh      # Scan script run when the container starts
├── eslint.config.js   # ESLint flat config applied to scanned code
└── package.json       # Node dependencies (ESLint)
```

## Requirements

- [Docker](https://docs.docker.com/get-docker/)

## Usage

### Build the image

```sh
docker build -t code-guard -f dockerfile .
```

### Scan a project

Mount the project you want to check at `/workspace`:

```sh
docker run --rm -v "$(pwd)":/workspace code-guard
```

To scan a different directory, replace `$(pwd)` with its absolute path.

## How it works

1. The image installs git, curl, and TruffleHog (to `/usr/local/bin`).
2. Node dependencies from `package.json` are installed into `/app`.
3. `entrypoint.sh` is copied into `/app` and set as the container entrypoint.
4. On `docker run`, the entrypoint scans the code mounted at `/workspace`.

## Configuration

- **ESLint rules:** edit `eslint.config.js` (ESLint [flat config](https://eslint.org/docs/latest/use/configure/configuration-files) format).
- **Scan steps:** edit `entrypoint.sh` to add, remove, or reorder tools.
- **Additional tools:** add Node-based tools to `package.json`, or system tools to the `RUN apk add` line in `dockerfile`.

After changing any of these, rebuild the image.
