# MDE4CPP Cross-Compilation to Windows Implementation

## Overview

This document describes the complete implementation of cross-compilation support for building Windows PE binaries (.exe files) from Linux using MinGW-w64. The implementation allows developers to compile MDE4CPP projects for Windows targets without requiring a Windows machine.

## Table of Contents

1. [CMake Toolchain File](#cmake-toolchain-file)
2. [Gradle Plugin Changes](#gradle-plugin-changes)
3. [CMakeLists.txt Template Changes](#cmakeliststxt-template-changes)
4. [Manual CMakeLists.txt Files](#manual-cmakeliststxt-files)
5. [Build System Integration](#build-system-integration)
6. [Configuration Files](#configuration-files)
7. [How It Works](#how-it-works)
8. [Usage](#usage)

---

## CMake Toolchain File

### Location
**File:** `src/common/cmake/cmake-toolchain-mingw.cmake`

### Purpose
This is the core toolchain file that configures CMake to use MinGW-w64 cross-compilers instead of the native Linux compilers.

### Contents

```cmake
# CMake toolchain file for cross-compiling to Windows using MinGW-w64 on Linux
# This file enables building Windows PE binaries (.exe) from Linux

set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR x86_64)

# Set the cross compiler (must use CACHE FORCE to override default detection)
set(CMAKE_C_COMPILER x86_64-w64-mingw32-gcc CACHE FILEPATH "C compiler" FORCE)
set(CMAKE_CXX_COMPILER x86_64-w64-mingw32-g++ CACHE FILEPATH "C++ compiler" FORCE)
set(CMAKE_RC_COMPILER x86_64-w64-mingw32-windres CACHE FILEPATH "Resource compiler" FORCE)

# Set the find root path
set(CMAKE_FIND_ROOT_PATH /usr/x86_64-w64-mingw32)

# Search for programs in the build host directories
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)

# Search for libraries and headers in the target directories
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# Set the default behavior of the FIND commands
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
```

### How It Works

1. **System Configuration**: Sets `CMAKE_SYSTEM_NAME` to `Windows` and `CMAKE_SYSTEM_PROCESSOR` to `x86_64`, telling CMake to target Windows x64.

2. **Compiler Selection**: Forces CMake to use MinGW-w64 cross-compilers:
   - `x86_64-w64-mingw32-gcc` for C
   - `x86_64-w64-mingw32-g++` for C++
   - `x86_64-w64-mingw32-windres` for Windows resource files

3. **Find Root Path**: Points to `/usr/x86_64-w64-mingw32` where MinGW-w64 libraries and headers are typically installed.

4. **Search Modes**: 
   - `CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER`: Allows finding build tools (like CMake itself) on the host system
   - `CMAKE_FIND_ROOT_PATH_MODE_LIBRARY/INCLUDE/PACKAGE ONLY`: Forces CMake to search for libraries and headers only in the MinGW-w64 installation, not the host system

---

## Gradle Plugin Changes

### 1. GradlePropertyAnalyser.java

**Location:** `gradlePlugins/MDE4CPPCompilePlugin/src/tui/sse/mde4cpp/GradlePropertyAnalyser.java`

**Changes:**

Added method `isCrossCompileWindowsRequested()` (lines 189-232):

```java
/**
 * Checks, if cross-compilation to Windows is requested
 * First checks Gradle property, then MDE4CPP_Generator.properties file
 * 
 * @param project current project instance contains existing properties
 * @return {@code true} if cross-compilation to Windows is requested, otherwise {@code false}
 */
static boolean isCrossCompileWindowsRequested(Project project)
{
    // First check if explicitly set as Gradle property (takes precedence)
    if (project.hasProperty("CROSS_COMPILE_WINDOWS"))
    {
        return !project.property("CROSS_COMPILE_WINDOWS").equals("0") && !project.property("CROSS_COMPILE_WINDOWS").equals("false");
    }
    
    // Otherwise, read from MDE4CPP_Generator.properties file
    String mde4cppHome = System.getenv("MDE4CPP_HOME");
    if (mde4cppHome != null)
    {
        try
        {
            java.util.Properties prop = new java.util.Properties();
            java.io.File configFile = new java.io.File(mde4cppHome + java.io.File.separator + "MDE4CPP_Generator.properties");
            if (configFile.exists())
            {
                java.io.FileInputStream stream = new java.io.FileInputStream(configFile);
                prop.load(stream);
                stream.close();
                
                String crossCompile = prop.getProperty("CROSS_COMPILE_WINDOWS");
                if (crossCompile != null)
                {
                    return crossCompile.trim().equalsIgnoreCase("true") || crossCompile.trim().equals("1");
                }
            }
        }
        catch (Exception e)
        {
            // If properties file can't be read, default to false
        }
    }
    
    return false;
}
```

**Purpose:** 
- Checks if cross-compilation is requested via Gradle property `-PCROSS_COMPILE_WINDOWS=true`
- Falls back to reading from `MDE4CPP_Generator.properties` file
- Returns `true` if cross-compilation is enabled, `false` otherwise

### 2. MDE4CPPCompile.java

**Location:** `gradlePlugins/MDE4CPPCompilePlugin/src/tui/sse/mde4cpp/MDE4CPPCompile.java`

**Changes:**

Added environment variable setting in `executeCompileProcess()` method (lines 178-182):

```java
// Set CROSS_COMPILE_WINDOWS environment variable for CMake if cross-compilation is requested
if (GradlePropertyAnalyser.isCrossCompileWindowsRequested(getProject()))
{
    processBuilder.environment().put("CROSS_COMPILE_WINDOWS", "true");
}
```

**Purpose:** 
- Sets the `CROSS_COMPILE_WINDOWS` environment variable to `"true"` when executing CMake processes
- This environment variable is read by generated CMakeLists.txt files to conditionally apply the toolchain file

---

## CMakeLists.txt Template Changes

The following generator template files were modified to include cross-compilation support. These templates generate CMakeLists.txt files for various project types.

### Pattern Added to All Templates

All templates include the following CMake code block at the beginning (after `CMAKE_MINIMUM_REQUIRED`):

```cmake
# Cross-compilation support for Windows (MinGW)
# Set CMAKE_TOOLCHAIN_FILE if cross-compiling to Windows from Linux
IF(UNIX AND NOT APPLE)
    # Check if cross-compilation is requested via environment variable
    IF("$ENV{CROSS_COMPILE_WINDOWS}" STREQUAL "true" OR "$ENV{CROSS_COMPILE_WINDOWS}" STREQUAL "1")
        # Find toolchain file relative to MDE4CPP_HOME or project root
        string(REPLACE "\\" "/" MDE4CPP_HOME $ENV{MDE4CPP_HOME})
        IF(MDE4CPP_HOME)
            SET(TOOLCHAIN_FILE "${MDE4CPP_HOME}/src/common/cmake/cmake-toolchain-mingw.cmake")
            IF(EXISTS ${TOOLCHAIN_FILE})
                set(CMAKE_TOOLCHAIN_FILE ${TOOLCHAIN_FILE} CACHE FILEPATH "Toolchain file" FORCE)
            ENDIF()
        ENDIF()
        # Also try relative to current source directory (for cases where MDE4CPP_HOME is not set)
        IF(NOT CMAKE_TOOLCHAIN_FILE)
            SET(TOOLCHAIN_FILE "${CMAKE_SOURCE_DIR}/../../../../src/common/cmake/cmake-toolchain-mingw.cmake")
            IF(EXISTS ${TOOLCHAIN_FILE})
                get_filename_component(TOOLCHAIN_FILE_ABS ${TOOLCHAIN_FILE} ABSOLUTE)
                set(CMAKE_TOOLCHAIN_FILE ${TOOLCHAIN_FILE_ABS} CACHE FILEPATH "Toolchain file" FORCE)
            ENDIF()
        ENDIF()
    ENDIF()
ENDIF()
```

### Modified Template Files

#### 1. Ecore4CPP Generator Templates

**File:** `generator/ecore4CPP/ecore4CPP.generator/src/ecore4CPP/generator/main/generateBuildFile.mtl`
- **Lines:** 36-58
- **Purpose:** Adds cross-compilation support to generated CMakeLists.txt for Ecore model libraries

**File:** `generator/ecore4CPP/ecore4CPP.generator/src/ecore4CPP/generator/main/generateApplication.mtl`
- **Lines:** 106-122
- **Purpose:** Adds cross-compilation support to generated CMakeLists.txt for Ecore applications

#### 2. UML4CPP Generator Templates

**File:** `generator/UML4CPP/UML4CPP.generator/src/UML4CPP/generator/main/configuration/generateCMakeFiles.mtl`
- **Lines:** 36-62
- **Purpose:** Adds cross-compilation support to generated CMakeLists.txt for UML model libraries

**File:** `generator/UML4CPP/UML4CPP.generator/src/UML4CPP/generator/main/main_application/generateMainApplicationCMakeFile.mtl`
- **Lines:** 36-62
- **Purpose:** Adds cross-compilation support to generated CMakeLists.txt for UML applications

#### 3. fUML4CPP Generator Templates

**File:** `generator/fUML4CPP/fUML4CPP.generator/src/fUML4CPP/generator/main/build_files/generateExecutionCMakeFile.mtl`
- **Lines:** 36-62
- **Purpose:** Adds cross-compilation support to generated CMakeLists.txt for fUML execution projects

### How the Template Code Works

1. **Platform Check**: `IF(UNIX AND NOT APPLE)` ensures this only runs on Linux (not macOS or Windows)

2. **Environment Variable Check**: Checks if `CROSS_COMPILE_WINDOWS` environment variable is set to `"true"` or `"1"`

3. **Toolchain File Discovery**: 
   - First tries to find toolchain file using `MDE4CPP_HOME` environment variable
   - Falls back to relative path from source directory if `MDE4CPP_HOME` is not set
   - Uses `get_filename_component()` to convert relative path to absolute path

4. **Toolchain Application**: Sets `CMAKE_TOOLCHAIN_FILE` cache variable with `FORCE` to ensure CMake uses it

---

## Manual CMakeLists.txt Files

Several manually maintained CMakeLists.txt files were updated to include cross-compilation support:

### 1. Plugin Framework

**File:** `src/common/pluginFramework/src/pluginFramework/CMakeLists.txt`
- **Lines:** 29-50
- **Change:** Added the standard cross-compilation block

### 2. MDE4CPP Plugin API

**File:** `src/common/MDE4CPP_PluginAPI/src/CMakeLists.txt`
- **Lines:** 29-50
- **Change:** Added the standard cross-compilation block

### 3. Persistence

**File:** `src/common/persistence/CMakeLists.txt`
- **Lines:** 29-50 (approximate)
- **Change:** Added the standard cross-compilation block

### 4. OCL Parser

**File:** `src/ocl/oclParser/CMakeLists.txt`
- **Lines:** 9-31
- **Change:** Added the standard cross-compilation block

### 5. Example Projects

The following example CMakeLists.txt files were also updated:
- `src/examples/ecoreExamples/ecoreExample/src/ecoreExample/CMakeLists.txt`
- `src/examples/oclExamples/oclExample/src/CMakeLists.txt`
- `src/examples/UMLExamples/UMLExample/src/UMLExample/CMakeLists.txt`
- `src/examples/commonExamples/persistenceExample/src/CMakeLists.txt`

---

## Build System Integration

### 1. build.gradle (Root)

**Location:** `build.gradle`
- **Lines:** 35-50

**Changes:**

```groovy
// Note: The actual environment variable is set in MDE4CPPCompile.java when executing CMake processes
if (!project.hasProperty('CROSS_COMPILE_WINDOWS')) {
	def mde4cppHome = System.getenv('MDE4CPP_HOME')
	if (mde4cppHome) {
		def propsFile = new File(mde4cppHome, 'MDE4CPP_Generator.properties')
		if (propsFile.exists()) {
			def props = new Properties()
			props.withInputStream { props.load(it) }
			def crossCompile = props.getProperty('CROSS_COMPILE_WINDOWS', 'false').trim()
			if (crossCompile.equalsIgnoreCase('true') || crossCompile == '1') {
				// Set as Gradle property so it can be read by GradlePropertyAnalyser
				project.ext.CROSS_COMPILE_WINDOWS = 'true'
			}
		}
	}
}
```

**Purpose:** 
- Reads `CROSS_COMPILE_WINDOWS` from `MDE4CPP_Generator.properties` if not set as Gradle property
- Sets it as a Gradle extension property for use throughout the build

### 2. buildAll.sh

**Location:** `buildAll.sh`
- **Lines:** 21-26

**Changes:**

```bash
while [[ $# -gt 0 ]]; do
    case $1 in
        --cross-compile-windows)
            CROSS_COMPILE=true
            GRADLE_ARGS="-PCROSS_COMPILE_WINDOWS=true -PRELEASE=1 -PDEBUG=0"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--cross-compile-windows]"
            exit 1
            ;;
    esac
done
```

**Purpose:** 
- Adds command-line option `--cross-compile-windows` to the build script
- Passes `-PCROSS_COMPILE_WINDOWS=true` to Gradle when enabled

### 3. External Dependency Build Scripts

#### ANTLR4 Build Script

**File:** `src/common/parser/build.gradle`
- **Lines:** 67-80

**Changes:**

```groovy
def crossCompileWindows = project.hasProperty('CROSS_COMPILE_WINDOWS') && !project.property('CROSS_COMPILE_WINDOWS').equals('0') && !project.property('CROSS_COMPILE_WINDOWS').equals('false')
def cmakeArgs = '-DCMAKE_CXX_STANDARD:STRING=17 -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_INSTALL_PREFIX=' + file("./antlr4/bin").absolutePath

if (crossCompileWindows && !System.properties['os.name'].toLowerCase().contains('windows')) {
    // Cross-compile to Windows from Linux
    def toolchainFile = new File(project.getRootProject().getRootDir(), "src/common/cmake/cmake-toolchain-mingw.cmake")
    if (toolchainFile.exists()) {
        cmakeArgs = '-DCMAKE_TOOLCHAIN_FILE=' + toolchainFile.absolutePath + ' ' + cmakeArgs
    }
    // Disable tests when cross-compiling (can't run Windows executables on Linux)
    cmakeArgs = '-DBUILD_TESTING=OFF ' + cmakeArgs
    cmakeArgs = '-G "Unix Makefiles" ' + cmakeArgs
}
```

**Purpose:** 
- Detects cross-compilation mode
- Passes toolchain file to CMake for ANTLR4 compilation
- Disables tests (Windows executables can't run on Linux)

#### Xerces-C Build Script

**File:** `src/common/persistence/build.gradle`
- **Lines:** 87-98

**Changes:**

Similar to ANTLR4, adds toolchain file support for Xerces-C compilation when cross-compiling.

---

## Configuration Files

### MDE4CPP_Generator.properties

**Location:** `MDE4CPP_Generator.properties`
- **Lines:** 14-17

**Changes:**

```properties
# Cross-compilation to Windows: Set to true to enable cross-compilation from Linux to Windows using MinGW
# This will be used by Gradle and CMake to configure the build for Windows targets
# Can be overridden by passing -PCROSS_COMPILE_WINDOWS=true as Gradle property
CROSS_COMPILE_WINDOWS = false
```

**Purpose:** 
- Provides persistent configuration for cross-compilation
- Can be set to `true` or `1` to enable cross-compilation globally
- Can be overridden by Gradle property `-PCROSS_COMPILE_WINDOWS=true`

---

## How It Works

### Flow Diagram

```
1. User enables cross-compilation
   ├─ Via buildAll.sh: --cross-compile-windows
   ├─ Via Gradle: -PCROSS_COMPILE_WINDOWS=true
   └─ Via MDE4CPP_Generator.properties: CROSS_COMPILE_WINDOWS=true

2. build.gradle reads property
   └─ Sets project.ext.CROSS_COMPILE_WINDOWS

3. GradlePropertyAnalyser.isCrossCompileWindowsRequested()
   └─ Returns true if cross-compilation is enabled

4. MDE4CPPCompile.executeCompileProcess()
   └─ Sets environment variable: CROSS_COMPILE_WINDOWS=true

5. CMake processes are started
   └─ Environment variable is available to CMake

6. Generated CMakeLists.txt files
   ├─ Check IF(UNIX AND NOT APPLE)
   ├─ Check IF("$ENV{CROSS_COMPILE_WINDOWS}" STREQUAL "true")
   └─ Set CMAKE_TOOLCHAIN_FILE to cmake-toolchain-mingw.cmake

7. CMake reads toolchain file
   ├─ Sets CMAKE_SYSTEM_NAME=Windows
   ├─ Sets cross-compilers (x86_64-w64-mingw32-gcc/g++)
   └─ Configures find paths for MinGW-w64 libraries

8. Build produces Windows PE binaries (.exe)
```

### Key Mechanisms

1. **Environment Variable Propagation**: The `CROSS_COMPILE_WINDOWS` environment variable is set by the Gradle plugin and passed to all CMake processes.

2. **Toolchain File Discovery**: CMakeLists.txt files use two methods to find the toolchain file:
   - Absolute path via `MDE4CPP_HOME` environment variable
   - Relative path from source directory as fallback

3. **Conditional Application**: Cross-compilation is only enabled when:
   - Running on Linux (`UNIX AND NOT APPLE`)
   - Environment variable is set to `"true"` or `"1"`
   - Toolchain file exists

4. **Compiler Selection**: The toolchain file forces CMake to use MinGW-w64 cross-compilers instead of native compilers.

---

## Usage

### Method 1: Using buildAll.sh

```bash
./buildAll.sh --cross-compile-windows
```

### Method 2: Using Gradle Directly

```bash
source setenv
./application/tools/gradlew buildAll -PCROSS_COMPILE_WINDOWS=true -PRELEASE=1 -PDEBUG=0
```

### Method 3: Persistent Configuration

Edit `MDE4CPP_Generator.properties`:

```properties
CROSS_COMPILE_WINDOWS = true
```

Then run normally:

```bash
source setenv
./application/tools/gradlew buildAll
```

### Prerequisites

1. **MinGW-w64 Installation**: Must have `x86_64-w64-mingw32-gcc` and `x86_64-w64-mingw32-g++` installed
   - On Ubuntu/Debian: `sudo apt-get install mingw-w64`
   - Verify: `which x86_64-w64-mingw32-gcc`

2. **MinGW-w64 Libraries**: Libraries should be installed in `/usr/x86_64-w64-mingw32`
   - Standard location for most Linux distributions

3. **MDE4CPP_HOME**: Environment variable should be set (via `setenv`)

### Verification

After building, check that Windows executables are generated:

```bash
file application/bin/*.exe
```

Should show: `PE32+ executable (console) x86-64, for MS Windows`

---

## Summary of File Changes

### Created Files
- `src/common/cmake/cmake-toolchain-mingw.cmake` - CMake toolchain configuration

### Modified Gradle Files
- `gradlePlugins/MDE4CPPCompilePlugin/src/tui/sse/mde4cpp/GradlePropertyAnalyser.java` - Added cross-compilation detection
- `gradlePlugins/MDE4CPPCompilePlugin/src/tui/sse/mde4cpp/MDE4CPPCompile.java` - Added environment variable setting
- `build.gradle` - Added property reading from config file
- `src/common/parser/build.gradle` - Added toolchain support for ANTLR4
- `src/common/persistence/build.gradle` - Added toolchain support for Xerces-C
- `buildAll.sh` - Added command-line option

### Modified Generator Templates
- `generator/ecore4CPP/ecore4CPP.generator/src/ecore4CPP/generator/main/generateBuildFile.mtl`
- `generator/ecore4CPP/ecore4CPP.generator/src/ecore4CPP/generator/main/generateApplication.mtl`
- `generator/UML4CPP/UML4CPP.generator/src/UML4CPP/generator/main/configuration/generateCMakeFiles.mtl`
- `generator/UML4CPP/UML4CPP.generator/src/UML4CPP/generator/main/main_application/generateMainApplicationCMakeFile.mtl`
- `generator/fUML4CPP/fUML4CPP.generator/src/fUML4CPP/generator/main/build_files/generateExecutionCMakeFile.mtl`

### Modified Manual CMakeLists.txt Files
- `src/common/pluginFramework/src/pluginFramework/CMakeLists.txt`
- `src/common/MDE4CPP_PluginAPI/src/CMakeLists.txt`
- `src/common/persistence/CMakeLists.txt`
- `src/ocl/oclParser/CMakeLists.txt`
- `src/examples/ecoreExamples/ecoreExample/src/ecoreExample/CMakeLists.txt`
- `src/examples/oclExamples/oclExample/src/CMakeLists.txt`
- `src/examples/UMLExamples/UMLExample/src/UMLExample/CMakeLists.txt`
- `src/examples/commonExamples/persistenceExample/src/CMakeLists.txt`

### Modified Configuration Files
- `MDE4CPP_Generator.properties` - Added CROSS_COMPILE_WINDOWS property

---

## Technical Notes

### Why Environment Variable Instead of CMake Variable?

The implementation uses an environment variable (`CROSS_COMPILE_WINDOWS`) rather than a CMake variable because:
1. Environment variables are automatically inherited by all child processes
2. They work consistently across different CMake invocation methods
3. They don't require passing `-D` flags to every CMake command
4. They're easier to set from Gradle's ProcessBuilder

### Toolchain File Location

The toolchain file is located at `src/common/cmake/cmake-toolchain-mingw.cmake` because:
1. It's in a common location accessible to all generated projects
2. The relative path `../../../../src/common/cmake/` works from typical generated project structures
3. It can also be found via `MDE4CPP_HOME` for absolute path resolution

### Compiler Path Assumptions

The toolchain file assumes MinGW-w64 compilers are in the system PATH. If they're installed in a custom location, modify the toolchain file to use absolute paths:

```cmake
set(CMAKE_C_COMPILER /path/to/x86_64-w64-mingw32-gcc CACHE FILEPATH "C compiler" FORCE)
set(CMAKE_CXX_COMPILER /path/to/x86_64-w64-mingw32-g++ CACHE FILEPATH "C++ compiler" FORCE)
```

---

## Troubleshooting

### Issue: "x86_64-w64-mingw32-gcc: command not found"

**Solution:** Install MinGW-w64:
```bash
sudo apt-get install mingw-w64
```

### Issue: CMake can't find the toolchain file

**Solution:** Ensure `MDE4CPP_HOME` is set correctly:
```bash
echo $MDE4CPP_HOME
# Should point to the MDE4CPP root directory
```

### Issue: Libraries not found during linking

**Solution:** Ensure MinGW-w64 libraries are installed:
```bash
ls /usr/x86_64-w64-mingw32/lib
```

### Issue: Generated executables don't run on Windows

**Solution:** Check that the executable is actually a Windows PE:
```bash
file application/bin/yourprogram.exe
# Should show: PE32+ executable (console) x86-64, for MS Windows
```

---

## Future Enhancements

Potential improvements to the cross-compilation implementation:

1. **32-bit Windows Support**: Add support for `i686-w64-mingw32` toolchain
2. **Custom Toolchain Paths**: Allow configuration of custom MinGW-w64 installation paths
3. **Static Linking**: Add option to statically link all dependencies
4. **CI/CD Integration**: Document how to use cross-compilation in CI pipelines
5. **Dependency Management**: Automatically handle MinGW-w64 versions of dependencies

---

## References

- [CMake Cross Compiling Documentation](https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html#cross-compiling)
- [MinGW-w64 Project](https://www.mingw-w64.org/)
- [Gradle ProcessBuilder Documentation](https://docs.gradle.org/current/javadoc/org/gradle/process/ProcessBuilder.html)

---

**Document Version:** 1.0  
**Last Updated:** 2024  
**Author:** MDE4CPP Development Team

