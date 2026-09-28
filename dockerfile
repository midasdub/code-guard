# Use a lightweight official Node.js image
FROM node:22-alpine

# Install system dependencies, such as a secret scanning tool (e.g., TruffleHog)
RUN apk add --no-cache git curl && \
    curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh | sh -s -- -b /usr/local/bin

# Create a working directory for the code-guard scripts
WORKDIR /app

# Copy dependency configurations (assuming you have a package.json for linters)
COPY package*.json ./

# Install analysis tools (e.g., ESLint) locally within the container
RUN npm ci --omit=dev

# Copy the main analysis script
COPY entrypoint.sh .

# Make the script executable
RUN chmod +x entrypoint.sh

# Set the entrypoint to execute the script upon container startup
# The target project code is expected to be mounted at /workspace
ENTRYPOINT ["/app/entrypoint.sh"]