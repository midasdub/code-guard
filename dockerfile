# Use a lightweight official Node.js image, pinned to an exact version
# so that two builds of the same commit produce the same tools
FROM node:22.23.3-alpine3.24

# Secret scanner (TruffleHog), pinned to a release and verified by checksum
# instead of running the install script from the "main" branch
ARG TRUFFLEHOG_VERSION=3.97.9
ARG TRUFFLEHOG_SHA256_AMD64=40377e6572495412fb9ba0bc21c9401f73b72f1d2afd11b9931bc4a5ed622866
ARG TRUFFLEHOG_SHA256_ARM64=372c568695d49e53517075b5f74d1ee9a19053f13661d689c7928ee1fc27d705
# Set automatically by Docker to the architecture being built (amd64 or arm64)
ARG TARGETARCH

RUN apk add --no-cache git curl && \
    case "$TARGETARCH" in \
      amd64) SHA256="$TRUFFLEHOG_SHA256_AMD64" ;; \
      arm64) SHA256="$TRUFFLEHOG_SHA256_ARM64" ;; \
      *) echo "Unsupported architecture: $TARGETARCH" && exit 1 ;; \
    esac && \
    curl -sSfL -o /tmp/trufflehog.tar.gz \
      "https://github.com/trufflesecurity/trufflehog/releases/download/v${TRUFFLEHOG_VERSION}/trufflehog_${TRUFFLEHOG_VERSION}_linux_${TARGETARCH}.tar.gz" && \
    echo "${SHA256}  /tmp/trufflehog.tar.gz" | sha256sum -c - && \
    tar -xzf /tmp/trufflehog.tar.gz -C /usr/local/bin trufflehog && \
    rm /tmp/trufflehog.tar.gz

# Create a working directory for the code-guard scripts
WORKDIR /app

# Copy dependency manifest and lockfile (npm ci requires package-lock.json)
COPY package.json package-lock.json ./

# Install analysis tools (e.g., ESLint) exactly as locked
RUN npm ci --omit=dev

# Copy the ESLint configuration and the main analysis script
COPY eslint.config.js entrypoint.sh ./

# Make the script executable
RUN chmod +x entrypoint.sh

# Version of this image, passed by the build pipeline (--build-arg).
# Visible in every report and in the image labels (docker inspect).
ARG VERSION=dev
ARG REVISION=unknown
ENV CODE_GUARD_VERSION=$VERSION \
    CODE_GUARD_REVISION=$REVISION
LABEL org.opencontainers.image.title="code-guard" \
      org.opencontainers.image.version=$VERSION \
      org.opencontainers.image.revision=$REVISION \
      org.opencontainers.image.source="https://github.com/midasdub/code-guard"

# Set the entrypoint to execute the script upon container startup
# The target project code is expected to be mounted at /workspace
ENTRYPOINT ["/app/entrypoint.sh"]
