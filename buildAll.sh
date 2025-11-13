#!/bin/bash
# Sequential build script for MDE4CPP
# This script runs generateAll, compileAll, and buildOCLAll tasks sequentially
# to ensure proper build order and avoid race conditions
#
# Prerequisites:
# - Run install_dependencies.sh to install system dependencies
# - Run check_prerequisites.sh to verify prerequisites
# - Ensure setenv file exists in the project directory
#
# Usage: ./buildAll.sh (run from MDE4CPP_CrossPlatform directory)

set -e  # Exit on any error

# Check if setenv exists in current directory
if [ ! -f "setenv" ]; then
    echo "ERROR: setenv file not found in the project directory."
    echo "Please ensure setenv file exists in the current directory."
    echo "You can copy setenv.default and configure it, or create setenv based on your setup."
    exit 1
fi

# Source setenv file
# Note: We need to source only the environment variables, not execute the interactive parts
# The setenv file ends with 'bash' which starts an interactive shell - we skip that
echo "Sourcing setenv..."
# Extract only export statements and source them, skipping cd/gradlew/bash commands
# This prevents the script from hanging on the interactive 'bash' command at the end
while IFS= read -r line; do
    # Skip comments, empty lines, cd commands, gradlew commands, and bash command
    if [[ "$line" =~ ^[[:space:]]*export ]] && [[ ! "$line" =~ ^[[:space:]]*# ]]; then
        eval "$line" 2>/dev/null || true
    fi
done < <(sed '/^cd \.\/gradlePlugins$/,$d' setenv)

# Use hardcoded gradlew path
GRADLEW="./application/tools/gradlew"

if [ ! -f "$GRADLEW" ]; then
    echo "Error: gradlew not found at $GRADLEW"
    echo "Please ensure you're running this script from the MDE4CPP_CrossPlatform directory."
    exit 1
fi

# Publish gradle plugins if needed (this is normally done in setenv)
# Do this after GRADLEW is defined so we can use it
if [ -d "gradlePlugins" ]; then
    echo "Publishing MDE4CPP Gradle plugins..."
    (./application/tools/gradlew publishMDE4CPPPluginsToMavenLocal >/dev/null 2>&1 || true)
fi

echo "=========================================="
echo "MDE4CPP Sequential Build Script"
echo "=========================================="
echo ""

# Step 1: Generate all models
echo "Step 1/3: Running generateAll..."
echo "----------------------------------------"
if ! "$GRADLEW" generateAll; then
    echo ""
    echo "ERROR: generateAll failed!"
    exit 1
fi
echo "✓ generateAll completed successfully"
echo ""

# Step 2: Compile all generated code
echo "Step 2/3: Running compileAll..."
echo "----------------------------------------"
if ! "$GRADLEW" compileAll; then
    echo ""
    echo "ERROR: compileAll failed!"
    exit 1
fi
echo "✓ compileAll completed successfully"
echo ""

# Step 3: Build OCL components
echo "Step 3/3: Running src:buildOCLAll..."
echo "----------------------------------------"
if ! "$GRADLEW" src:buildOCLAll; then
    echo ""
    echo "ERROR: src:buildOCLAll failed!"
    exit 1
fi
echo "✓ src:buildOCLAll completed successfully"
echo ""

echo "=========================================="
echo "BUILD SUCCESSFUL - All tasks completed!"
echo "=========================================="
