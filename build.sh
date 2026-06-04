#!/bin/bash
# Build script for boilerplate-cli-ui-nim

set -e

APP_NAME="boilerplate-cli-ui-nim"

echo "Building ${APP_NAME}..."

# Build with release optimizations
cd src
nim c -d:release --opt:size server.nim
cd ..
mv src/server ${APP_NAME}

echo "Built: ${APP_NAME}"
ls -lh ${APP_NAME}

echo ""
echo "Usage:"
echo "  ./${APP_NAME} start           # Start server with UI"
echo "  ./${APP_NAME} start -p 3000   # Start on custom port"
echo "  ./${APP_NAME} version         # Show version"
