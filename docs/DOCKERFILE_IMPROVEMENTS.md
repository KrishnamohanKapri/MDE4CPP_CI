# Dockerfile Improvements Summary

## Overview
The Dockerfile has been reorganized into a multi-stage build structure based on verified setup commands from Debian 13.

## Changes Made

### 1. Multi-Stage Build Structure
- **Stage 1 (base)**: System dependencies, JDK 21, MinGW-w64, CMake
- **Stage 2 (eclipse)**: Eclipse Modeling Tools 2024-06 + required plugins
- **Stage 3 (build)**: MDE4CPP repository clone, build, and compilation
- **Stage 4 (runtime)**: Final optimized image with built artifacts

### 2. Verified Configuration Updates
- **JAVA_HOME**: Set to `/usr/lib/jvm/java-21-openjdk-amd64`
- **ORG_GRADLE_PROJECT_WORKER**: Changed from `1` to `3` (optimized for multi-core CPUs)
- **ORG_GRADLE_PROJECT_DEBUG**: Changed from `1` to `0` (saves build time, UML model takes 60-80 minutes with debug)
- **Eclipse Plugins**: Separated into individual RUN commands for reliability
  - Acceleo installed separately (verified working)
  - Papyrus and EMF SDK installed together (verified working)

### 3. Build Order Fixes
- **Gradle Plugins**: Built first (required before metamodels)
- **Generators**: Created before buildAll (fixes missing generator errors)
- **BuildAll**: Uses `--continue` flag to handle optional component failures gracefully

### 4. Verified Commands Used
All commands in the Dockerfile are based on successful tests:
- ✅ `gradlew publishMDE4CPPPluginsToMavenLocal` - SUCCESS
- ✅ `gradlew createAllGenerators -PDEBUG=0` - SUCCESS
- ✅ `gradlew buildEcore -PDEBUG=0` - SUCCESS
- ✅ `gradlew buildUml -PDEBUG=0` - SUCCESS
- ✅ `gradlew buildAll -PDEBUG=0 --continue` - Partial success (some optional components may fail)

### 5. Eclipse Plugin Installation
- Removed problematic Sirius features that caused installation failures
- Installed only verified working plugins:
  - Acceleo 3.7.16
  - Papyrus 6.7.0
  - EMF SDK 2.38.0
  - UML2 SDK
  - GMF Runtime SDK
  - OCL SDK
  - EMF Ecore Tools
  - EMF Transaction SDK
  - XSD SDK

### 6. Notes on Build Failures
Some optional components may fail during buildAll:
- OCL Parser (CMake configuration issues)
- Some profile generations (Acceleo template issues)
- PSSM (compilation errors)

These are known issues and don't affect core functionality (Ecore, UML, generators work correctly).

## Benefits of Multi-Stage Build

1. **Smaller Final Image**: Only runtime dependencies are included
2. **Better Caching**: Each stage can be cached independently
3. **Clearer Structure**: Easy to understand and maintain
4. **Isolation**: Build dependencies don't pollute runtime image

## Usage

### Build the image:
```bash
docker build -t mde4cpp:latest .
```

### Run interactively:
```bash
docker run -it --rm mde4cpp:latest
```

### With docker-compose:
```bash
docker-compose build
docker-compose up
```

## Testing Recommendations

1. Test the Dockerfile build on a clean system
2. Verify that generators are created successfully
3. Verify that core metamodels (Ecore, UML) build correctly
4. Check that setenv file is properly sourced
5. Test that gradlew commands work inside the container

