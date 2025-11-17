# MDE4CPP Cross-Compilation to Windows Implementation

## Overview

This document describes the complete implementation of cross-compilation support for building Windows PE binaries (.dll and .exe files) from Linux using MinGW-w64. The implementation follows a **model-driven engineering approach**, where cross-compilation is controlled through properties files that can be set globally or per-model, allowing granular control over which models are cross-compiled.

## Table of Contents

1. [CMake Toolchain File](#cmake-toolchain-file)
2. [Property-Based Configuration](#property-based-configuration)
3. [Generator Infrastructure Changes](#generator-infrastructure-changes)
4. [CMakeLists.txt Template Changes](#cmakeliststxt-template-changes)
5. [Library Finding for Cross-Compilation](#library-finding-for-cross-compilation)
6. [Gradle Plugin Changes](#gradle-plugin-changes)
7. [Manual CMakeLists.txt Files](#manual-cmakeliststxt-files)
8. [External Dependencies](#external-dependencies)
9. [How It Works](#how-it-works)
10. [Usage](#usage)
11. [Troubleshooting](#troubleshooting)

---

## CMake Toolchain File

### Location
**File:** `src/common/cmake/cmake-toolchain-mingw.cmake`

### Purpose
This is the core toolchain file that configures CMake to use MinGW-w64 cross-compilers instead of the native Linux compilers. It must be passed to CMake via command-line argument (`-DCMAKE_TOOLCHAIN_FILE=...`) **before** CMake initializes.

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

## Property-Based Configuration

### Configuration Hierarchy

Cross-compilation can be controlled at three levels (in order of priority):

1. **Model-Specific Properties** (Highest Priority)
   - File: `ModelName.properties` (next to `ModelName.ecore` or `ModelName.uml`)
   - Example: `MyModel.properties` next to `MyModel.ecore`
   - Property: `CROSS_COMPILE_WINDOWS = true`

2. **Generator-Specific Properties** (Medium Priority)
   - Files: `./uml.properties`, `./fuml.properties` (in project root)
   - Property: `CROSS_COMPILE_WINDOWS = true`

3. **Global Properties** (Lowest Priority)
   - File: `MDE4CPP_Generator.properties` (in project root)
   - Property: `CROSS_COMPILE_WINDOWS = true`

### MDE4CPP_Generator.properties

**Location:** `MDE4CPP_Generator.properties`

**Configuration:**
```properties
# Cross-compilation to Windows: Set to true to enable cross-compilation from Linux to Windows using MinGW
# This will be used by Gradle and CMake to configure the build for Windows targets
# Can be overridden by passing -PCROSS_COMPILE_WINDOWS=true as Gradle property
# Can also be overridden by model-specific or generator-specific properties files
CROSS_COMPILE_WINDOWS = true
```

**Purpose:** 
- Provides persistent global configuration for cross-compilation
- Can be set to `true` or `1` to enable cross-compilation globally
- Can be overridden by Gradle property `-PCROSS_COMPILE_WINDOWS=true`
- Can be overridden by model-specific or generator-specific properties files

---

## Generator Infrastructure Changes

### 1. Property Loading in Generators

To enable property-based control, the generators needed to load properties files in the correct order.

#### UML4CPP Generator

**File:** `generator/UML4CPP/UML4CPP.generator/src/UML4CPP/generator/main/Generate.java`

**Changes:** Modified `getProperties()` method to load:
1. Model-specific properties (`.uml.properties`)
2. Generator-specific properties (`./uml.properties`)
3. Global properties (`MDE4CPP_Generator.properties`)

**Code Added:**
```java
@Override
public List<String> getProperties() {
    // ... existing code ...

    // Add model-specific properties
    if (model != null && model.eResource() != null) {
        String modelPropertyPath = model.eResource().getURI().toString().replace(".uml", ".properties");
        addToPropertiesFile(modelPropertyPath);
    }

    // Add generator-specific properties
    addToPropertiesFile("./uml.properties");

    // Add global generator properties
    String mde4cppHome = System.getenv("MDE4CPP_HOME");
    if (mde4cppHome != null) {
        addToPropertiesFile(mde4cppHome + "/MDE4CPP_Generator.properties");
    }

    return propertiesFiles;
}

protected void addToPropertiesFile(String propertyPath) {
    File testFile = new File(propertyPath);
    if (testFile.exists()) {
        System.out.println("property file found: " + propertyPath);
        propertiesFiles.add(propertyPath);
    }
}
```

#### fUML4CPP Generator

**File:** `generator/fUML4CPP/fUML4CPP.generator/src/fUML4CPP/generator/main/GenerateFUML.java`

**Changes:** Similar to UML4CPP, modified to load:
1. Model-specific properties (`.fuml.properties` or `.uml.properties`)
2. Generator-specific properties (`./fuml.properties`)
3. Global properties (`MDE4CPP_Generator.properties`)

#### ecore4CPP Generator

**File:** `generator/ecore4CPP/ecore4CPP.generator/src/ecore4CPP/generator/main/Generate.java`

**Status:** Already had property loading support, no changes needed.

### 2. Keyword Additions

Added keywords to generator templates to access the `CROSS_COMPILE_WINDOWS` property.

#### ecore4CPP Keywords

**File:** `generator/ecore4CPP/ecore4CPP.generator/src/ecore4CPP/generator/main/helpers/keywords.mtl`

**Added:**
```mtl
[query public keyCrossCompileWindows(any : OclAny) : String = 'CROSS_COMPILE_WINDOWS'/]
[** indicates that cross-compilation to Windows should be enabled/]
```

#### UML4CPP Keywords

**File:** `generator/UML4CPP/UML4CPP.generator/src/UML4CPP/generator/main/helpers/keywords.mtl`

**Added:**
```mtl
[query public keyCrossCompileWindows(any : OclAny) : String = 'CROSS_COMPILE_WINDOWS'/]
[** indicates that cross-compilation to Windows should be enabled/]
```

#### fUML4CPP Keywords

**File:** `generator/fUML4CPP/fUML4CPP.generator/src/fUML4CPP/generator/main/helpers/fUMLKeywords.mtl`

**Added:**
```mtl
[query public keyCrossCompileWindows(any : OclAny) : String = 'CROSS_COMPILE_WINDOWS'/]
[** indicates that cross-compilation to Windows should be enabled/]
```

### 3. Helper Query Additions

Added helper queries to check if cross-compilation is enabled for a package.

#### ecore4CPP Helper

**File:** `generator/ecore4CPP/ecore4CPP.generator/src/ecore4CPP/generator/main/helper.mtl`

**Added:**
```mtl
[query public isCrossCompileWindowsEnabled(ePackage : EPackage) : Boolean = ePackage.getProperty(keyCrossCompileWindows()).toBoolean() /]
```

#### UML4CPP Helper

**File:** `generator/UML4CPP/UML4CPP.generator/src/UML4CPP/generator/main/helpers/generalHelper.mtl`

**Added:**
```mtl
[query public isCrossCompileWindowsEnabled(aPackage : Package) : Boolean = aPackage.getProperty(keyCrossCompileWindows()).toBoolean() /]
```

#### fUML4CPP Helper

**File:** `generator/fUML4CPP/fUML4CPP.generator/src/fUML4CPP/generator/main/build_files/generateExecutionCMakeFile.mtl`

**Added:** Import for `generalHelper` to access the helper query:
```mtl
[import UML4CPP::generator::main::helpers::generalHelper /]
```

---

## CMakeLists.txt Template Changes

### Pattern Added to All Templates

All generator templates include a conditional cross-compilation block that checks if cross-compilation is enabled for the package. The block is placed immediately after `CMAKE_MINIMUM_REQUIRED` and before `PROJECT()`.

**Template Pattern:**
```mtl
CMAKE_MINIMUM_REQUIRED(VERSION 3.9)

[if (aPackage.isCrossCompileWindowsEnabled())]
# Cross-compilation support for Windows (MinGW)
# Set CMAKE_TOOLCHAIN_FILE if cross-compiling to Windows from Linux
IF(UNIX AND NOT APPLE)
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
[/if]

PROJECT([packageName/])
```

**Note:** While this block is generated in CMakeLists.txt files, it is **not sufficient** by itself. The toolchain file must also be passed via command-line argument (see [Gradle Plugin Changes](#gradle-plugin-changes)).

### Modified Template Files

#### 1. Ecore4CPP Generator Templates

**File:** `generator/ecore4CPP/ecore4CPP.generator/src/ecore4CPP/generator/main/generateBuildFile.mtl`
- **Purpose:** Adds cross-compilation support to generated CMakeLists.txt for Ecore model libraries
- **Condition:** `[if (aPackage.isCrossCompileWindowsEnabled())]`

**File:** `generator/ecore4CPP/ecore4CPP.generator/src/ecore4CPP/generator/main/generateApplication.mtl`
- **Purpose:** Adds cross-compilation support to generated CMakeLists.txt for Ecore applications
- **Condition:** `[if (aPackage.isCrossCompileWindowsEnabled())]`

#### 2. UML4CPP Generator Templates

**File:** `generator/UML4CPP/UML4CPP.generator/src/UML4CPP/generator/main/configuration/generateCMakeFiles.mtl`
- **Purpose:** Adds cross-compilation support to generated CMakeLists.txt for UML model libraries
- **Condition:** `[if (aPackage.isCrossCompileWindowsEnabled())]`

**File:** `generator/UML4CPP/UML4CPP.generator/src/UML4CPP/generator/main/main_application/generateMainApplicationCMakeFile.mtl`
- **Purpose:** Adds cross-compilation support to generated CMakeLists.txt for UML applications
- **Condition:** `[if (aPackage.isCrossCompileWindowsEnabled())]`
- **Note:** Also added import: `[import UML4CPP::generator::main::helpers::generalHelper /]`

#### 3. fUML4CPP Generator Templates

**File:** `generator/fUML4CPP/fUML4CPP.generator/src/fUML4CPP/generator/main/build_files/generateExecutionCMakeFile.mtl`
- **Purpose:** Adds cross-compilation support to generated CMakeLists.txt for fUML execution projects
- **Condition:** `[if (aPackage.isCrossCompileWindowsEnabled())]`
- **Note:** Added import: `[import UML4CPP::generator::main::helpers::generalHelper /]`

---

## Library Finding for Cross-Compilation

### Problem: FIND_LIBRARY Doesn't Work with .dll Files

When cross-compiling to Windows, `FIND_LIBRARY` fails to locate `.dll` files because:
1. CMake's `FIND_LIBRARY` is designed for Unix-style libraries (`.so`, `.dylib`, `.a`)
2. Windows `.dll` files don't follow the same naming conventions
3. The find root path configuration interferes with library discovery

### Solution: Use SET with CACHE FORCE

For cross-compilation (when `CMAKE_SYSTEM_NAME STREQUAL "Windows"`), we use `SET` with `CACHE FORCE` instead of `FIND_LIBRARY`.

### Implementation in Generator Templates

**File:** `generator/ecore4CPP/ecore4CPP.generator/src/ecore4CPP/generator/main/generateBuildFile.mtl`

**Template Pattern:**
```mtl
[template private generateCMakeFindLibraryCommand(aPackage : EPackage, ending : String, folderName : String, debugMode : Boolean)]
[if (ending = '.dll')]
[comment When cross-compiling to Windows, use SET with CACHE FORCE since FIND_LIBRARY doesn't work well with .dll files /]
[comment Unset any previous NOTFOUND values first /]
[for (pack : EPackage | aPackage.metaModelLibraries()->reject(doNotGenerateEPackage())->asOrderedSet()) ? (not(pack.name = aPackage.name))]
UNSET([pack.name.toUpperCase()/]_[libraryVariableNameSuffix(debugMode)/] CACHE)
SET([pack.name.toUpperCase()/]_[libraryVariableNameSuffix(debugMode)/] "${MDE4CPP_HOME}/application/[folderName/]/[pack.name/][libraryNameSuffix(debugMode)/][ending/]" CACHE FILEPATH "[pack.name/] [libraryVariableNameSuffix(debugMode)/] library" FORCE)
[/for]
[else]
[comment For .so, .dylib, or Windows native, use FIND_LIBRARY /]
[for (pack : EPackage | aPackage.metaModelLibraries()->reject(doNotGenerateEPackage())->asOrderedSet()) ? (not(pack.name = aPackage.name))]
FIND_LIBRARY([pack.name.toUpperCase()/]_[libraryVariableNameSuffix(debugMode)/] [pack.name/][libraryNameSuffix(debugMode)/][ending/] ${MDE4CPP_HOME}/application/[folderName/])
[/for]
[/if]
[/template]
```

### Generated CMakeLists.txt Pattern

The generated CMakeLists.txt files include conditional library finding. **Important:** The cross-compilation check must be done **before** checking `IF(UNIX AND NOT APPLE)` because when cross-compiling, `CMAKE_SYSTEM_NAME` is set to "Windows" by the toolchain file, which would cause the `IF(UNIX AND NOT APPLE)` block to be skipped.

```cmake
# Check if cross-compiling to Windows (CMAKE_SYSTEM_NAME will be Windows, or MinGW compiler/toolchain is used)
# Note: When cross-compiling, CMAKE_SYSTEM_NAME is "Windows", so we check for cross-compilation first
SET(IS_CROSS_COMPILING FALSE)
IF(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    SET(IS_CROSS_COMPILING TRUE)
ELSEIF(CMAKE_TOOLCHAIN_FILE)
    string(FIND "${CMAKE_TOOLCHAIN_FILE}" "mingw" MINGW_POS)
    IF(MINGW_POS GREATER_EQUAL 0)
        SET(IS_CROSS_COMPILING TRUE)
    ENDIF()
ELSEIF(CMAKE_C_COMPILER)
    string(FIND "${CMAKE_C_COMPILER}" "mingw" MINGW_POS)
    IF(MINGW_POS GREATER_EQUAL 0)
        SET(IS_CROSS_COMPILING TRUE)
    ENDIF()
ENDIF()

IF(IS_CROSS_COMPILING)
    # Cross-compiling to Windows from Linux - use .dll
    IF (CMAKE_BUILD_TYPE STREQUAL "Debug")
        UNSET(ECORE_DEBUG CACHE)
        SET(ECORE_DEBUG "${MDE4CPP_HOME}/application/bin/ecored.dll" CACHE FILEPATH "ecore DEBUG library" FORCE)
    ELSE()
        UNSET(ECORE_RELEASE CACHE)
        SET(ECORE_RELEASE "${MDE4CPP_HOME}/application/bin/ecore.dll" CACHE FILEPATH "ecore RELEASE library" FORCE)
    ENDIF()
ELSEIF(UNIX AND NOT APPLE)
    # Native Linux build - use .so
    IF (CMAKE_BUILD_TYPE STREQUAL "Debug")
        FIND_LIBRARY(ECORE_DEBUG ecored.so ${MDE4CPP_HOME}/application/bin)
    ELSE()
        FIND_LIBRARY(ECORE_RELEASE ecore.so ${MDE4CPP_HOME}/application/bin)
    ENDIF()
ELSEIF(APPLE)
    # Native macOS build - use .dylib
    # ...
ENDIF()
```

### Why UNSET is Required

CMake caches variable values, including `NOTFOUND` values from previous runs. If a variable was previously set to `NOTFOUND`, using `SET` with `CACHE FORCE` may not override it properly. The `UNSET` command clears the cached value before setting the new one.

### Critical Fix: Condition Ordering

**Important Discovery:** The original implementation wrapped the cross-compilation check inside `IF(UNIX AND NOT APPLE)`. However, when cross-compiling to Windows, the CMake toolchain file sets `CMAKE_SYSTEM_NAME` to "Windows", which causes `IF(UNIX AND NOT APPLE)` to evaluate to `FALSE`, skipping the entire cross-compilation block.

**Solution:** The cross-compilation check must be done **first**, before checking `IF(UNIX AND NOT APPLE)`. The condition checks:
1. `CMAKE_SYSTEM_NAME STREQUAL "Windows"` - Direct detection when toolchain is active
2. `CMAKE_TOOLCHAIN_FILE` contains "mingw" - Detection via toolchain file path
3. `CMAKE_C_COMPILER` contains "mingw" - Detection via compiler path

Only after determining cross-compilation status should we check for native Linux builds with `ELSEIF(UNIX AND NOT APPLE)`.

This fix was applied to:
- `generator/ecore4CPP/ecore4CPP.generator/src/ecore4CPP/generator/main/generateBuildFile.mtl`
- `generator/ecore4CPP/ecore4CPP.generator/src/ecore4CPP/generator/main/generateApplication.mtl`
- `generator/UML4CPP/UML4CPP.generator/src/UML4CPP/generator/main/configuration/generateCMakeFiles.mtl`
- `src/ocl/oclParser/CMakeLists.txt`
- `src/common/persistence/CMakeLists.txt`

---

## Gradle Plugin Changes

### Critical Discovery: Toolchain File Must Be Passed via Command Line

**Important:** CMake toolchain files **must** be passed as a command-line argument (`-DCMAKE_TOOLCHAIN_FILE=...`) **before** CMake initializes. Setting `CMAKE_TOOLCHAIN_FILE` within a CMakeLists.txt file does **not** work because CMake reads the toolchain file during its initial configuration phase, before processing the CMakeLists.txt file.

This is why Gradle plugin changes were necessary, despite the initial goal of avoiding them.

### 1. GradlePropertyAnalyser.java

**Location:** `gradlePlugins/MDE4CPPCompilePlugin/src/tui/sse/mde4cpp/GradlePropertyAnalyser.java`

**Changes:** Added method `isCrossCompileWindowsRequested()`:

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
        String value = project.property("CROSS_COMPILE_WINDOWS").toString();
        return !value.equals("0") && !value.equals("false");
    }
    
    // Check MDE4CPP_Generator.properties file
    String mde4cppHome = System.getenv("MDE4CPP_HOME");
    if (mde4cppHome != null)
    {
        File propsFile = new File(mde4cppHome, "MDE4CPP_Generator.properties");
        if (propsFile.exists())
        {
            try
            {
                Properties props = new Properties();
                props.load(new FileInputStream(propsFile));
                String crossCompile = props.getProperty("CROSS_COMPILE_WINDOWS", "false").trim();
                return crossCompile.equalsIgnoreCase("true") || crossCompile.equals("1");
            }
            catch (Exception e)
            {
                // If we can't read the file, default to false
                return false;
			}
		}
	}
    return false;
}
```

**Purpose:** 
- Checks if cross-compilation is requested via Gradle property `-PCROSS_COMPILE_WINDOWS=true`
- Falls back to reading from `MDE4CPP_Generator.properties` file
- Returns `true` if cross-compilation is enabled, `false` otherwise

### 2. CommandBuilder.java

**Location:** `gradlePlugins/MDE4CPPCompilePlugin/src/tui/sse/mde4cpp/CommandBuilder.java`

**Changes:** Modified `getCMakeCommand()` method to accept a `Project` object and conditionally add the toolchain file argument:

```java
static List<String> getCMakeCommand(BUILD_MODE buildMode, File projectFolder, Project project)
{
    List<String> commandList = CommandBuilder.initialCommandList();
    String cmakeCommand = "cmake -G \"" + getCMakeGenerator() + "\" -D CMAKE_BUILD_TYPE=" + buildMode.getName();
    
    // Add toolchain file for cross-compilation if enabled
    if (GradlePropertyAnalyser.isCrossCompileWindowsRequested(project) && !isWindowsSystem()) {
        String mde4cppHome = System.getenv("MDE4CPP_HOME");
        if (mde4cppHome != null) {
            File toolchainFile = new File(mde4cppHome, "src/common/cmake/cmake-toolchain-mingw.cmake");
            if (toolchainFile.exists()) {
                cmakeCommand += " -DCMAKE_TOOLCHAIN_FILE=" + toolchainFile.getAbsolutePath();
            }
        }
    }
    
    cmakeCommand += " " + projectFolder.getAbsolutePath();
    commandList.add(cmakeCommand);
    return commandList;
}
```

**Purpose:** 
- Constructs the CMake command with the toolchain file argument when cross-compilation is enabled
- Only adds the toolchain file on non-Windows systems (cross-compiling from Linux)
- Uses absolute path to the toolchain file

### 3. MDE4CPPCompile.java

**Location:** `gradlePlugins/MDE4CPPCompilePlugin/src/tui/sse/mde4cpp/MDE4CPPCompile.java`

**Changes:** Updated the call to `CommandBuilder.getCMakeCommand()` to pass the `Project` instance:

```java
List<String> command = CommandBuilder.getCMakeCommand(buildMode, projectFolderFile, getProject());
```

**Purpose:** 
- Aligns with the updated method signature in `CommandBuilder.java`
- Allows the command builder to access project properties

---

## Manual CMakeLists.txt Files

Several manually maintained CMakeLists.txt files were updated to include cross-compilation support and proper library finding for Windows DLLs.

### Pattern for Manual Files

Manual CMakeLists.txt files include:
1. Cross-compilation toolchain block (conditional on environment variable or property)
2. Conditional library finding (SET for .dll, FIND_LIBRARY for .so/.dylib)
3. UNSET commands to clear cached NOTFOUND values

### Updated Files

1. **Plugin Framework**
   - File: `src/common/pluginFramework/src/pluginFramework/CMakeLists.txt`
   - Added cross-compilation block

2. **MDE4CPP Plugin API**
   - File: `src/common/MDE4CPP_PluginAPI/src/CMakeLists.txt`
   - Added cross-compilation block

3. **Persistence**
   - File: `src/common/persistence/CMakeLists.txt`
   - Added cross-compilation block

4. **OCL Parser**
   - File: `src/ocl/oclParser/CMakeLists.txt`
   - Added cross-compilation block
   - Added UNSET commands for all library variables
   - Uses SET with CACHE FORCE for .dll files

5. **Example Projects**
   - `src/examples/ecoreExamples/ecoreExample/src/ecoreExample/CMakeLists.txt`
   - `src/examples/oclExamples/oclExample/src/CMakeLists.txt`
   - `src/examples/UMLExamples/UMLExample/src/UMLExample/CMakeLists.txt`
   - `src/examples/commonExamples/persistenceExample/src/CMakeLists.txt`
   - `src/examples/commonExamples/pluginFrameworkExample/src/CMakeLists.txt`
   - `src/examples/commonExamples/SimpleUML/src/CMakeLists.txt`
   - `src/examples/benchmarks/ecoreBenchmark/src/ecoreBenchmark/CMakeLists.txt`
   - `src/examples/benchmarks/memoryBenchmarkEcore/src/memoryBenchmarkEcore/CMakeLists.txt`
   - `src/examples/benchmarks/UMLBenchmark/src/UMLBenchmark/CMakeLists.txt`

---

## External Dependencies

### Why Only Parser and Persistence Build Scripts Needed Changes

**Question:** Why did only `src/common/parser/build.gradle` and `src/common/persistence/build.gradle` need cross-compilation changes, while other components didn't?

**Answer:** These two components are the **only external dependencies** that MDE4CPP builds from source using Gradle build scripts. All other components follow different build paths:

1. **Standard MDE4CPP Components** (Ecore, UML, fUML, etc.):
   - Use the standard **Generator → CMake → Compile** pipeline
   - Cross-compilation is handled automatically by:
     - Generator templates (which generate cross-compilation blocks in CMakeLists.txt)
     - Gradle plugin (which passes toolchain file to CMake)
   - No manual build.gradle changes needed

2. **System Libraries**:
   - Standard C++ libraries, system headers
   - Already available on the target system or provided by MinGW-w64
   - No build needed

3. **Pre-compiled Dependencies**:
   - Already compiled binaries
   - No build needed

4. **ANTLR4 and Xerces** (The Two Exceptions):
   - **Built from source** using Gradle tasks
   - **Not part of the standard generator pipeline**
   - **Use CMake directly** (not through MDE4CPP's generator system)
   - **Require explicit cross-compilation configuration** in their build scripts

**Summary Table:**

| Component Type | Build Method | Cross-Compilation Support | Changes Needed? |
|---------------|--------------|---------------------------|-----------------|
| Standard MDE4CPP Models | Generator → CMake | Automatic (via templates) | ❌ No |
| ANTLR4 (Parser) | Gradle → CMake | Manual (build.gradle) | ✅ Yes |
| Xerces (Persistence) | Gradle → CMake | Manual (build.gradle) | ✅ Yes |
| System Libraries | N/A | Provided by MinGW-w64 | ❌ No |
| Pre-compiled | N/A | Already compiled | ❌ No |

---

### ANTLR4 Build Script

**File:** `src/common/parser/build.gradle`

**Purpose:** Downloads and builds ANTLR4 C++ runtime from source. ANTLR4 is used by the OCL parser for grammar parsing.

**Why Changes Were Needed:**
1. **External dependency built from source**: ANTLR4 is downloaded as source code and compiled via Gradle, not through the standard MDE4CPP generator/CMake flow
2. **CMake-based build**: Uses CMake directly, so it needs the MinGW toolchain file passed explicitly
3. **Test executables**: ANTLR4's test suite tries to build and run Windows executables during cross-compilation, which fails on Linux
4. **DLL location variability**: When cross-compiling, `.dll` files may be installed in either `lib/` or `bin/` directory depending on ANTLR4's installation layout

**Changes:** Added cross-compilation support for building ANTLR4 with MinGW-w64:

```groovy
doLast {
    // Check if cross-compilation to Windows is requested
    def crossCompileWindows = false
    if (project.hasProperty("CROSS_COMPILE_WINDOWS")) {
        def value = project.property("CROSS_COMPILE_WINDOWS").toString()
        crossCompileWindows = !value.equals("0") && !value.equals("false")
    } else {
        // Check MDE4CPP_Generator.properties file
        def mde4cppHome = System.getenv("MDE4CPP_HOME")
        if (mde4cppHome != null) {
            def propsFile = new File(mde4cppHome, "MDE4CPP_Generator.properties")
            if (propsFile.exists()) {
                def props = new Properties()
                props.load(new FileInputStream(propsFile))
                def crossCompile = props.getProperty("CROSS_COMPILE_WINDOWS", "false").trim()
                crossCompileWindows = crossCompile.equalsIgnoreCase("true") || crossCompile.equals("1")
            }
        }
    }
    
def cmakeArgs = '-DCMAKE_CXX_STANDARD:STRING=17 -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_INSTALL_PREFIX=' + file("./antlr4/bin").absolutePath

if (crossCompileWindows && !System.properties['os.name'].toLowerCase().contains('windows')) {
    // Cross-compile to Windows from Linux
    def toolchainFile = new File(project.getRootProject().getRootDir(), "src/common/cmake/cmake-toolchain-mingw.cmake")
    if (toolchainFile.exists()) {
        cmakeArgs = '-DCMAKE_TOOLCHAIN_FILE=' + toolchainFile.absolutePath + ' ' + cmakeArgs
    }
    // Disable tests when cross-compiling (can't run Windows executables on Linux)
        cmakeArgs = '-DBUILD_TESTING=OFF -DANTLR_BUILD_CPP_TESTS=OFF ' + cmakeArgs
    }
    
    // ... rest of build script ...
    
    // Copy shared libraries - handle .dll files when cross-compiling
    if (crossCompileWindows && !System.properties['os.name'].toLowerCase().contains('windows')) {
        // Cross-compiling to Windows - .dll files might be in lib/ or bin/
        copy {
            from "antlr4/bin/lib"
            into System.getenv('MDE4CPP_HOME')+"/application/bin"
            include "**/*.dll"
        }
        copy {
            from "antlr4/bin/bin"
            into System.getenv('MDE4CPP_HOME')+"/application/bin"
            include "**/*.dll"
        }
    }
}
```

**Purpose:** 
- Detects cross-compilation mode from properties
- Passes toolchain file to CMake for ANTLR4 compilation
- Disables tests (Windows executables can't run on Linux)
- Copies `.dll` files from both `lib/` and `bin/` directories (ANTLR4 installs them in different locations)

**Detailed Changes Made:**

1. **Cross-Compilation Detection (Lines 70-87)**:
   ```groovy
   // Check if cross-compilation to Windows is requested
   def crossCompileWindows = false
   if (project.hasProperty("CROSS_COMPILE_WINDOWS")) {
       def value = project.property("CROSS_COMPILE_WINDOWS").toString()
       crossCompileWindows = !value.equals("0") && !value.equals("false")
   } else {
       // Check MDE4CPP_Generator.properties file
       def mde4cppHome = System.getenv("MDE4CPP_HOME")
       if (mde4cppHome != null) {
           def propsFile = new File(mde4cppHome, "MDE4CPP_Generator.properties")
           if (propsFile.exists()) {
               def props = new Properties()
               props.load(new FileInputStream(propsFile))
               def crossCompile = props.getProperty("CROSS_COMPILE_WINDOWS", "false").trim()
               crossCompileWindows = crossCompile.equalsIgnoreCase("true") || crossCompile.equals("1")
           }
       }
   }
   ```
   - Checks Gradle property `CROSS_COMPILE_WINDOWS` first (highest priority)
   - Falls back to reading from `MDE4CPP_Generator.properties` file
   - Uses same detection logic as Gradle plugin for consistency

2. **Toolchain File Passing (Lines 91-99)**:
   ```groovy
   if (crossCompileWindows && !System.properties['os.name'].toLowerCase().contains('windows')) {
       // Cross-compile to Windows from Linux
       def toolchainFile = new File(project.getRootProject().getRootDir(), "src/common/cmake/cmake-toolchain-mingw.cmake")
       if (toolchainFile.exists()) {
           cmakeArgs = '-DCMAKE_TOOLCHAIN_FILE=' + toolchainFile.absolutePath + ' ' + cmakeArgs
       }
       // Disable tests when cross-compiling (can't run Windows executables on Linux)
       cmakeArgs = '-DBUILD_TESTING=OFF -DANTLR_BUILD_CPP_TESTS=OFF ' + cmakeArgs
   }
   ```
   - Passes `-DCMAKE_TOOLCHAIN_FILE=...` to CMake when cross-compiling
   - Disables tests: `-DBUILD_TESTING=OFF -DANTLR_BUILD_CPP_TESTS=OFF` (Windows executables can't run on Linux)

3. **DLL File Copying (Lines 132-143)**:
   ```groovy
   } else if (crossCompileWindows) {
       // Cross-compiling to Windows - .dll files might be in lib/ or bin/
       copy {
           from "antlr4/bin/lib"
           into System.getenv('MDE4CPP_HOME')+"/application/bin"
           include "**/*.dll"
       }
       copy {
           from "antlr4/bin/bin"
           into System.getenv('MDE4CPP_HOME')+"/application/bin"
           include "**/*.dll"
       }
   }
   ```
   - Copies `.dll` files from both `antlr4/bin/lib` and `antlr4/bin/bin`
   - Handles different installation layouts (ANTLR4 may install DLLs in either location)
   - Ensures DLLs are available in `application/bin/` for linking

**Imports Added:**
- `java.io.File`
- `java.io.FileInputStream`
- `java.util.Properties`

---

### Xerces Build Script

**File:** `src/common/persistence/build.gradle`

**Purpose:** Downloads and builds Xerces-C XML parser from source. Xerces is used by the persistence layer for XML serialization/deserialization.

**Why Changes Were Needed:**
1. **External dependency built from source**: Xerces is downloaded as source code and compiled via Gradle, not through the standard MDE4CPP generator/CMake flow
2. **CMake-based build**: Uses CMake directly, so it needs the MinGW toolchain file passed explicitly
3. **DLL naming mismatch**: Xerces generates `libxerces-c.dll` (with `lib` prefix), but CMakeLists.txt expects `xerces-c.dll` (without prefix)
4. **DLL location variability**: When cross-compiling, `.dll` files may be installed in either `lib/` or `bin/` directory depending on Xerces's installation layout

**Changes:** Added cross-compilation support for building Xerces with MinGW-w64:

```groovy
doLast {
    // Check if cross-compilation to Windows is requested
    def crossCompileWindows = false
    if (project.hasProperty("CROSS_COMPILE_WINDOWS")) {
        def value = project.property("CROSS_COMPILE_WINDOWS").toString()
        crossCompileWindows = !value.equals("0") && !value.equals("false")
    } else {
        // Check MDE4CPP_Generator.properties file
        def mde4cppHome = System.getenv("MDE4CPP_HOME")
        if (mde4cppHome != null) {
            def propsFile = new File(mde4cppHome, "MDE4CPP_Generator.properties")
            if (propsFile.exists()) {
                def props = new Properties()
                props.load(new FileInputStream(propsFile))
                def crossCompile = props.getProperty("CROSS_COMPILE_WINDOWS", "false").trim()
                crossCompileWindows = crossCompile.equalsIgnoreCase("true") || crossCompile.equals("1")
            }
        }
    }
    
    def cmakeArgs = '-DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=' + file("./xerces/bin").absolutePath
    
    if (crossCompileWindows && !System.properties['os.name'].toLowerCase().contains('windows')) {
        // Cross-compile to Windows from Linux
        def toolchainFile = new File(project.getRootProject().getRootDir(), "src/common/cmake/cmake-toolchain-mingw.cmake")
        if (toolchainFile.exists()) {
            cmakeArgs = '-DCMAKE_TOOLCHAIN_FILE=' + toolchainFile.absolutePath + ' ' + cmakeArgs
        }
    }
    
    // ... CMake and make commands ...
    
    // When cross-compiling, .dll files might be in lib/ or bin/
    if (crossCompileWindows && !System.properties['os.name'].toLowerCase().contains('windows')) {
        copy {
            from "xerces/bin/lib"
            into System.getenv('MDE4CPP_HOME')+"/application/bin"
            include "**/*.dll"
        }
        copy {
            from "xerces/bin/bin"
            into System.getenv('MDE4CPP_HOME')+"/application/bin"
            include "**/*.dll"
            // Rename libxerces-c.dll to xerces-c.dll for compatibility
            rename { filename ->
                if (filename == 'libxerces-c.dll') {
                    return 'xerces-c.dll'
                }
                return filename
            }
        }
    }
}
```

**Purpose:** 
- Detects cross-compilation mode from properties
- Passes toolchain file to CMake for Xerces compilation
- Copies and renames `.dll` files from both `lib/` and `bin/` directories
- Renames `libxerces-c.dll` to `xerces-c.dll` to match CMakeLists.txt expectations

**Detailed Changes Made:**

1. **Cross-Compilation Detection (Lines 90-107)**:
   ```groovy
   // Check if cross-compilation to Windows is requested
   def crossCompileWindows = false
   if (project.hasProperty("CROSS_COMPILE_WINDOWS")) {
       def value = project.property("CROSS_COMPILE_WINDOWS").toString()
       crossCompileWindows = !value.equals("0") && !value.equals("false")
   } else {
       // Check MDE4CPP_Generator.properties file
       def mde4cppHome = System.getenv("MDE4CPP_HOME")
       if (mde4cppHome != null) {
           def propsFile = new File(mde4cppHome, "MDE4CPP_Generator.properties")
           if (propsFile.exists()) {
               def props = new Properties()
               props.load(new FileInputStream(propsFile))
               def crossCompile = props.getProperty("CROSS_COMPILE_WINDOWS", "false").trim()
               crossCompileWindows = crossCompile.equalsIgnoreCase("true") || crossCompile.equals("1")
           }
       }
   }
   ```
   - Checks Gradle property `CROSS_COMPILE_WINDOWS` first (highest priority)
   - Falls back to reading from `MDE4CPP_Generator.properties` file
   - Uses same detection logic as ANTLR4 and Gradle plugin for consistency

2. **Toolchain File Passing (Lines 111-117)**:
   ```groovy
   if (crossCompileWindows && !System.properties['os.name'].toLowerCase().contains('windows')) {
       // Cross-compile to Windows from Linux
       def toolchainFile = new File(project.getRootProject().getRootDir(), "src/common/cmake/cmake-toolchain-mingw.cmake")
       if (toolchainFile.exists()) {
           cmakeArgs = '-DCMAKE_TOOLCHAIN_FILE=' + toolchainFile.absolutePath + ' ' + cmakeArgs
       }
   }
   ```
   - Passes `-DCMAKE_TOOLCHAIN_FILE=...` to CMake when cross-compiling
   - Uses absolute path to toolchain file

3. **DLL File Copying and Renaming (Lines 153-171)**:
   ```groovy
   // When cross-compiling, .dll files might be in lib/ or bin/
   if (crossCompileWindows && !System.properties['os.name'].toLowerCase().contains('windows')) {
       copy {
           from "xerces/bin/lib"
           into System.getenv('MDE4CPP_HOME')+"/application/bin"
           include "**/*.dll"
       }
       copy {
           from "xerces/bin/bin"
           into System.getenv('MDE4CPP_HOME')+"/application/bin"
           include "**/*.dll"
           // Rename libxerces-c.dll to xerces-c.dll for compatibility
           rename { filename ->
               if (filename == 'libxerces-c.dll') {
                   return 'xerces-c.dll'
               }
               return filename
           }
       }
   }
   ```
   - Copies `.dll` files from both `xerces/bin/lib` and `xerces/bin/bin`
   - **Critical**: Renames `libxerces-c.dll` to `xerces-c.dll` during copy
   - This is essential because CMakeLists.txt files expect `xerces-c.dll`, but Xerces generates `libxerces-c.dll`
   - Ensures DLLs are available in `application/bin/` with the correct name for linking

**Imports Added:**
- `java.io.File`
- `java.io.FileInputStream`
- `java.util.Properties`

**Key Difference from ANTLR4:**
- Xerces requires **DLL renaming** (`libxerces-c.dll` → `xerces-c.dll`) because of naming convention mismatch
- ANTLR4 doesn't require renaming (uses `libantlr4-runtime.dll` consistently)

---

## How It Works

### Flow Diagram

```
1. User enables cross-compilation
   ├─ Via MDE4CPP_Generator.properties: CROSS_COMPILE_WINDOWS=true (global)
   ├─ Via ModelName.properties: CROSS_COMPILE_WINDOWS=true (per-model)
   ├─ Via Gradle: -PCROSS_COMPILE_WINDOWS=true (command-line)
   └─ Via generator-specific properties: ./uml.properties (generator-level)

2. Generator reads properties during code generation
   ├─ Loads model-specific properties (highest priority)
   ├─ Loads generator-specific properties (medium priority)
   └─ Loads global properties (lowest priority)

3. Generator templates check property
   └─ [if (aPackage.isCrossCompileWindowsEnabled())]
      └─ Generates cross-compilation CMake block in CMakeLists.txt

4. GradlePropertyAnalyser.isCrossCompileWindowsRequested()
   ├─ Checks Gradle property (highest priority)
   └─ Falls back to MDE4CPP_Generator.properties

5. CommandBuilder.getCMakeCommand()
   └─ Adds -DCMAKE_TOOLCHAIN_FILE=... to CMake command if cross-compilation enabled

6. CMake processes are started
   └─ Toolchain file is passed via command-line argument

7. CMake reads toolchain file (before processing CMakeLists.txt)
   ├─ Sets CMAKE_SYSTEM_NAME=Windows
   ├─ Sets cross-compilers (x86_64-w64-mingw32-gcc/g++)
   └─ Configures find paths for MinGW-w64 libraries

8. CMake processes CMakeLists.txt
   ├─ Generated files: Cross-compilation block already included (if property was true)
   ├─ Manual files: Check environment variable or property
   └─ Library finding: 
       ├─ First checks for cross-compilation (IS_CROSS_COMPILING)
       ├─ Uses SET with CACHE FORCE for .dll files when cross-compiling
       └─ Falls back to FIND_LIBRARY for .so/.dylib files for native builds

9. Build produces Windows PE binaries (.dll/.exe)
```

### Key Mechanisms

1. **Property-Based Control**: Cross-compilation is controlled through properties files, allowing granular per-model control while maintaining a model-driven approach.

2. **Toolchain File Passing**: The toolchain file is passed via command-line argument (`-DCMAKE_TOOLCHAIN_FILE=...`) by the Gradle plugin, which is **required** for cross-compilation to work.

3. **Library Finding Strategy**: 
   - For `.dll` files (cross-compilation): Use `UNSET` + `SET` with `CACHE FORCE`
   - For `.so`/`.dylib` files (native): Use `FIND_LIBRARY`
   - **Critical:** Cross-compilation check must come **before** `IF(UNIX AND NOT APPLE)` check

4. **Conditional Application**: Cross-compilation is only enabled when:
   - Property is set to `true` or `1`
   - Running on Linux (`UNIX AND NOT APPLE`)
   - Toolchain file exists
   - MinGW-w64 compilers are available

---

## Usage

### Method 1: Global Configuration

Edit `MDE4CPP_Generator.properties`:
```properties
CROSS_COMPILE_WINDOWS = true
```

Then run:
```bash
source setenv
./application/tools/gradlew generateAll
./application/tools/gradlew compileAll
```

### Method 2: Per-Model Configuration

Create `MyModel.properties` next to `MyModel.ecore`:
```properties
CROSS_COMPILE_WINDOWS = true
```

Then run:
```bash
source setenv
./application/tools/gradlew generateAll
./application/tools/gradlew compileAll
```

### Method 3: Command-Line Override

```bash
source setenv
./application/tools/gradlew generateAll
./application/tools/gradlew compileAll -PCROSS_COMPILE_WINDOWS=true
```

### Prerequisites

1. **MinGW-w64 Installation**: Must have `x86_64-w64-mingw32-gcc` and `x86_64-w64-mingw32-g++` installed
   - On Ubuntu/Debian: `sudo apt-get install mingw-w64`
   - Verify: `which x86_64-w64-mingw32-gcc`

2. **MinGW-w64 Libraries**: Libraries should be installed in `/usr/x86_64-w64-mingw32`
   - Standard location for most Linux distributions

3. **MDE4CPP_HOME**: Environment variable should be set (via `setenv`)

### Verification

After building, check that Windows binaries are generated:

```bash
# Check for Windows DLLs
file application/bin/*.dll
# Should show: PE32+ executable (DLL) x86-64, for MS Windows

# Check for Windows executables
file application/bin/*.exe
# Should show: PE32+ executable (console) x86-64, for MS Windows
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

### Issue: Libraries not found during linking (NOTFOUND errors)

**Solution:** 
1. Ensure the library `.dll` files exist in `application/bin/`
2. Check that the CMakeLists.txt uses `UNSET` before `SET` for cross-compilation
3. Verify the library path in the `SET` command is correct
4. Clean CMake cache: `find . -type d -name ".cmake" -exec rm -rf {} +`
5. **Verify the condition ordering**: The cross-compilation check must come **before** `IF(UNIX AND NOT APPLE)`. If the condition is wrapped inside `IF(UNIX AND NOT APPLE)`, it will be skipped when cross-compiling because `CMAKE_SYSTEM_NAME` is "Windows".

### Issue: Cross-compilation block is generated but libraries still use .so instead of .dll

**Solution:**
This indicates the condition ordering issue. The cross-compilation check is being skipped because it's wrapped in `IF(UNIX AND NOT APPLE)`. Fix by:
1. Moving the cross-compilation check **before** the `IF(UNIX AND NOT APPLE)` check
2. Using `IF(IS_CROSS_COMPILING)` followed by `ELSEIF(UNIX AND NOT APPLE)` for native Linux builds
3. Regenerating CMakeLists.txt files: `./application/tools/gradlew generateAll`

### Issue: Generated executables don't run on Windows

**Solution:** Check that the executable is actually a Windows PE:
```bash
file application/bin/yourprogram.exe
# Should show: PE32+ executable (console) x86-64, for MS Windows
```

### Issue: Cross-compilation block not generated in CMakeLists.txt

**Solution:** 
1. Verify `CROSS_COMPILE_WINDOWS = true` is set in properties file
2. Check that the property is loaded by the generator (check generator output)
3. Regenerate: `./application/tools/gradlew generateAll`

### Issue: Toolchain file not being passed to CMake

**Solution:**
1. Verify Gradle plugins are rebuilt: `./application/tools/gradlew publishMDE4CPPPluginsToMavenLocal`
2. Check that `GradlePropertyAnalyser.isCrossCompileWindowsRequested()` returns `true`
3. Verify `CommandBuilder.getCMakeCommand()` includes the toolchain file argument

---

## Summary of File Changes

### Created Files
- `src/common/cmake/cmake-toolchain-mingw.cmake` - CMake toolchain configuration

### Modified Generator Java Files
- `generator/UML4CPP/UML4CPP.generator/src/UML4CPP/generator/main/Generate.java` - Added property loading
- `generator/fUML4CPP/fUML4CPP.generator/src/fUML4CPP/generator/main/GenerateFUML.java` - Added property loading

### Modified Generator Template Files (.mtl)
- `generator/ecore4CPP/ecore4CPP.generator/src/ecore4CPP/generator/main/helpers/keywords.mtl` - Added `keyCrossCompileWindows`
- `generator/ecore4CPP/ecore4CPP.generator/src/ecore4CPP/generator/main/helper.mtl` - Added `isCrossCompileWindowsEnabled`
- `generator/ecore4CPP/ecore4CPP.generator/src/ecore4CPP/generator/main/generateBuildFile.mtl` - Added cross-compilation block and library finding logic
- `generator/ecore4CPP/ecore4CPP.generator/src/ecore4CPP/generator/main/generateApplication.mtl` - Added cross-compilation block and library finding logic
- `generator/UML4CPP/UML4CPP.generator/src/UML4CPP/generator/main/helpers/keywords.mtl` - Added `keyCrossCompileWindows`
- `generator/UML4CPP/UML4CPP.generator/src/UML4CPP/generator/main/helpers/generalHelper.mtl` - Added `isCrossCompileWindowsEnabled`
- `generator/UML4CPP/UML4CPP.generator/src/UML4CPP/generator/main/configuration/generateCMakeFiles.mtl` - Added cross-compilation block
- `generator/UML4CPP/UML4CPP.generator/src/UML4CPP/generator/main/main_application/generateMainApplicationCMakeFile.mtl` - Added cross-compilation block and import
- `generator/fUML4CPP/fUML4CPP.generator/src/fUML4CPP/generator/main/helpers/fUMLKeywords.mtl` - Added `keyCrossCompileWindows`
- `generator/fUML4CPP/fUML4CPP.generator/src/fUML4CPP/generator/main/build_files/generateExecutionCMakeFile.mtl` - Added cross-compilation block and import

### Modified Gradle Plugin Files
- `gradlePlugins/MDE4CPPCompilePlugin/src/tui/sse/mde4cpp/GradlePropertyAnalyser.java` - Added `isCrossCompileWindowsRequested()` method
- `gradlePlugins/MDE4CPPCompilePlugin/src/tui/sse/mde4cpp/CommandBuilder.java` - Modified `getCMakeCommand()` to pass toolchain file
- `gradlePlugins/MDE4CPPCompilePlugin/src/tui/sse/mde4cpp/MDE4CPPCompile.java` - Updated to pass `Project` to `CommandBuilder`

### Modified Build Scripts
- `src/common/parser/build.gradle` - Added cross-compilation support for ANTLR4

### Modified Manual CMakeLists.txt Files
- `src/common/pluginFramework/src/pluginFramework/CMakeLists.txt`
- `src/common/MDE4CPP_PluginAPI/src/CMakeLists.txt`
- `src/common/persistence/CMakeLists.txt`
- `src/ocl/oclParser/CMakeLists.txt`
- `src/examples/ecoreExamples/ecoreExample/src/ecoreExample/CMakeLists.txt`
- `src/examples/oclExamples/oclExample/src/CMakeLists.txt`
- `src/examples/UMLExamples/UMLExample/src/UMLExample/CMakeLists.txt`
- `src/examples/commonExamples/persistenceExample/src/CMakeLists.txt`
- `src/examples/commonExamples/pluginFrameworkExample/src/CMakeLists.txt`
- `src/examples/commonExamples/SimpleUML/src/CMakeLists.txt`
- `src/examples/benchmarks/ecoreBenchmark/src/ecoreBenchmark/CMakeLists.txt`
- `src/examples/benchmarks/memoryBenchmarkEcore/src/memoryBenchmarkEcore/CMakeLists.txt`
- `src/examples/benchmarks/UMLBenchmark/src/UMLBenchmark/CMakeLists.txt`

### Modified Configuration Files
- `MDE4CPP_Generator.properties` - Added `CROSS_COMPILE_WINDOWS` property

---

## Technical Notes

### Why Gradle Plugin Changes Were Necessary

Initially, we attempted to implement cross-compilation using only generator templates and CMakeLists.txt files. However, we discovered that **CMake toolchain files must be passed via command-line argument** (`-DCMAKE_TOOLCHAIN_FILE=...`) **before** CMake initializes. Setting `CMAKE_TOOLCHAIN_FILE` within a CMakeLists.txt file does not work because:

1. CMake reads the toolchain file during its initial configuration phase
2. This happens before CMake processes the CMakeLists.txt file
3. The toolchain file must be specified when CMake is invoked, not after

Therefore, the Gradle plugin must pass the toolchain file as a command-line argument to CMake. This is documented in detail in `docs/WHY_GRADLE_PLUGIN_CHANGES_NEEDED.md`.

### Property Loading Order

Properties are loaded in the following order (highest to lowest priority):
1. Model-specific properties (e.g., `MyModel.properties`)
2. Generator-specific properties (e.g., `./uml.properties`)
3. Global properties (`MDE4CPP_Generator.properties`)
4. Gradle properties (`-PCROSS_COMPILE_WINDOWS=true`)

### Library Finding Strategy

- **Cross-compilation (Windows .dll)**: Use `UNSET` + `SET` with `CACHE FORCE` to directly specify the library path
- **Native Linux (.so)**: Use `FIND_LIBRARY` to search for libraries
- **Native macOS (.dylib)**: Use `FIND_LIBRARY` to search for libraries
- **Native Windows**: Use `FIND_LIBRARY` to search for libraries in `lib/` directory

### Toolchain File Location

The toolchain file is located at `src/common/cmake/cmake-toolchain-mingw.cmake` because:
1. It's in a common location accessible to all generated projects
2. The relative path `../../../../src/common/cmake/` works from typical generated project structures
3. It can also be found via `MDE4CPP_HOME` for absolute path resolution

---

## References

- [CMake Cross Compiling Documentation](https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html#cross-compiling)
- [MinGW-w64 Project](https://www.mingw-w64.org/)
- [Why Gradle Plugin Changes Were Necessary](docs/WHY_GRADLE_PLUGIN_CHANGES_NEEDED.md)

---

## Recent Updates (Version 2.1)

### Critical Fix: Cross-Compilation Condition Ordering (November 2024)

**Problem:** When cross-compiling to Windows, the CMake toolchain file sets `CMAKE_SYSTEM_NAME` to "Windows". The original implementation wrapped the cross-compilation check inside `IF(UNIX AND NOT APPLE)`, which evaluated to `FALSE` during cross-compilation, causing the entire cross-compilation block to be skipped.

**Impact:** Libraries were not found during linking, resulting in `NOTFOUND` errors for variables like `ECORE_RELEASE`, `OCL_RELEASE`, etc.

**Solution:** Reordered the condition checks to detect cross-compilation **first**, before checking for native Linux builds. The new pattern:
1. Check for cross-compilation (works even when `CMAKE_SYSTEM_NAME` is "Windows")
2. Use `IF(IS_CROSS_COMPILING)` for cross-compilation handling
3. Use `ELSEIF(UNIX AND NOT APPLE)` for native Linux builds

**Files Updated:**
- `generator/ecore4CPP/ecore4CPP.generator/src/ecore4CPP/generator/main/generateBuildFile.mtl`
- `generator/ecore4CPP/ecore4CPP.generator/src/ecore4CPP/generator/main/generateApplication.mtl`
- `generator/UML4CPP/UML4CPP.generator/src/UML4CPP/generator/main/configuration/generateCMakeFiles.mtl`
- `src/ocl/oclParser/CMakeLists.txt`
- `src/common/persistence/CMakeLists.txt`

**Verification:** After this fix, OCL components (`ocl.dll`, `oclParser.dll`) and reflection models (`ecoreReflection.dll`, `primitivetypesReflection.dll`) compile successfully during cross-compilation.

---

## Summary of Fixes Applied During Cross-Compilation Testing

During testing of cross-compilation with `CROSS_COMPILE_WINDOWS = true`, several issues were identified and fixed:

### 1. Persistence CMakeLists.txt: GUID Library Selection

**Issue:** When cross-compiling to Windows, the persistence library was trying to use Linux's `uuid/uuid.h` header (via `GUID_LIBUUID`), which doesn't exist in MinGW-w64.

**Fix:** Changed the GUID library selection in `src/common/persistence/CMakeLists.txt`:
- **Before:** `SET(CMAKE_CXX_FLAGS "-DGUID_LIBUUID")` when cross-compiling
- **After:** `SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DGUID_WINDOWS")` when cross-compiling

**Result:** The persistence library now uses Windows' `CoCreateGuid` API (via `objbase.h`) when cross-compiling, which is available in MinGW-w64.

**File Modified:** `src/common/persistence/CMakeLists.txt` (line 121)

### 2. FoundationalModelLibrary: Missing Cross-Compilation Support

**Issue:** The generated `CMakeLists.txt` for FoundationalModelLibrary only had `IF(UNIX AND NOT APPLE)` condition, which evaluated to `FALSE` when cross-compiling (since `CMAKE_SYSTEM_NAME` is "Windows"), causing library finding to fail.

**Fix:** Added cross-compilation detection and library finding logic:
- Added `IS_CROSS_COMPILING` detection (checks `CMAKE_SYSTEM_NAME`, `CMAKE_TOOLCHAIN_FILE`, and `CMAKE_C_COMPILER`)
- Added `UNSET` + `SET` with `CACHE FORCE` for all required libraries (`.dll` files)
- Reordered conditions to check cross-compilation **before** `IF(UNIX AND NOT APPLE)`

**Result:** FoundationalModelLibrary now correctly finds and links against Windows DLLs during cross-compilation.

**File Modified:** `src/common/FoundationalModelLibrary/src_gen/FoundationalModelLibrary/CMakeLists.txt`

### 3. Xerces Build Script: Cross-Compilation Support

**Issue:** The xerces build script (`src/common/persistence/build.gradle`) did not support cross-compilation, and the generated DLL was named `libxerces-c.dll` instead of `xerces-c.dll` (which CMakeLists.txt expects).

**Why This Component Needed Changes:**
Xerces is an **external dependency** that MDE4CPP builds from source using Gradle tasks. Unlike standard MDE4CPP components (which use the Generator → CMake pipeline), Xerces uses CMake directly and requires explicit cross-compilation configuration in its build script.

**Fix:** 
- Added cross-compilation detection (checks Gradle property and `MDE4CPP_Generator.properties`)
- Added toolchain file passing to CMake when cross-compiling
- Added DLL renaming from `libxerces-c.dll` to `xerces-c.dll` during copy
- Added copying of `.dll` files from both `lib/` and `bin/` directories (xerces installs them in different locations)

**Result:** Xerces now builds correctly for Windows when cross-compiling, and the DLL is properly named and copied to `application/bin/`.

**File Modified:** `src/common/persistence/build.gradle`

**Detailed Changes:**
- Added imports: `java.io.File`, `java.io.FileInputStream`, `java.util.Properties`
- Modified `compileXerces` task to detect cross-compilation and pass toolchain file
- Added DLL renaming logic in the copy task (renames `libxerces-c.dll` to `xerces-c.dll`)
- Added copying from both `xerces/bin/lib` and `xerces/bin/bin` directories

**Note:** See the [External Dependencies](#external-dependencies) section for a complete explanation of why only ANTLR4 and Xerces build scripts needed changes.

### 4. UML4CPPProfile and StandardProfile: Missing Virtual Function Implementations

**Issue:** When cross-compiling, linker errors occurred for Stereotype classes in `UML4CPPProfile` and `StandardProfile`:
- `undefined reference to 'UML4CPPProfile::DoNotGenerateImpl::get(...)'`
- `undefined reference to 'StandardProfile::UtilityImpl::get(...)'`
- Similar errors for `set`, `add`, `unset`, and `remove` methods

**Root Cause:** The generator template `setGetHelper.mtl` explicitly skips generating implementations for `Stereotype` classes (line 84), expecting them from the base class `uml::StereotypeImpl`. However, `uml::StereotypeImpl` itself does not implement these methods directly but inherits them from `uml::ObjectImpl`. The virtual functions are declared in the header files but not implemented in the source files.

**Fix:** Modified `generator/UML4CPP/UML4CPP.generator/src/UML4CPP/generator/main/helpers/setGetHelper.mtl` to generate implementations for Stereotype classes:
- Split `generateeGetSetImpl` template into two templates with guards:
  - One for non-Stereotype classes (existing behavior)
  - One for Stereotype classes (new behavior)
- Added new templates: `generateStereotypeGetImplementation`, `generateStereotypeSetImplementation`, `generateStereotypeAddImplementation`, `generateStereotypeUnSetImplementation`, `generateStereotypeRemoveImplementation`
- These templates delegate to `uml::ObjectImpl` methods for the `std::shared_ptr<uml::Property>` overloads
- For `std::string` and `unsigned long` overloads, they return `nullptr` or `false` since Stereotypes don't have properties

**Files Modified:**
- `generator/UML4CPP/UML4CPP.generator/src/UML4CPP/generator/main/helpers/setGetHelper.mtl`
- `generator/UML4CPP/UML4CPP.generator/src/UML4CPP/generator/main/classes/generateClassImplementationSource.mtl` (added `#include "uml/impl/ObjectImpl.hpp"` for Stereotypes)

**Status:** Partially fixed - `set`, `add`, `unset`, and `remove` methods are being generated correctly, but `get` methods are still not being generated (Acceleo parsing issue with `uml::ObjectImpl::get`).

### 5. StandardProfile: Namespace Qualification Issues - RESOLVED

**Issue:** Initially reported compilation errors in `StandardProfile` stereotypes:
- `error: reference to 'TypeImpl' is ambiguous` - Both `StandardProfile::TypeImpl` and `uml::TypeImpl` exist, and both namespaces were in scope
- `error: template argument 1 is invalid` and `error: no declaration matches 'int StandardProfile::RealizationImpl::getThisRealizationPtr()'` - Missing namespace qualification in method signatures

**Root Cause:** These errors would occur if both `using namespace StandardProfile;` and `using namespace uml;` were present in the same file, causing class name ambiguity.

**Resolution:** The official repository already handles this correctly:
- Stereotype implementation files only include `using namespace StandardProfile;` (or the appropriate profile namespace)
- They do NOT include `using namespace uml;` for Stereotype classes
- This prevents namespace ambiguity, and the code compiles successfully without explicit namespace qualification in method signatures

**Current Implementation:**
The generator templates correctly generate:
```cpp
using namespace StandardProfile;  // Only profile namespace
// No "using namespace uml;" for Stereotypes
```

**Status:** ✅ **RESOLVED** - No template changes are required. The current implementation correctly handles namespace qualification, and all builds succeed without modification.

### 6. Acceleo Parsing Issue with `uml::ObjectImpl::get`

**Issue:** The `generateStereotypeGetImplementation` template is being called (evidenced by the "//Get" comment in generated files), but the implementation code is not being generated. This suggests an Acceleo parsing issue.

**Attempted Solutions:**
1. `uml::ObjectImpl::get(_property)` - Not generated
2. `ObjectImpl::get(_property)` - Not generated (relies on `using namespace uml;`)
3. `this->ObjectImpl::get(_property)` - Not generated
4. `uml[comment prevent parsing /]::ObjectImpl::get(_property)` - Not generated
5. `[aClass.getNearestPackage().generateNamespace(false)/]::ObjectImpl::get(_property)` - Not generated

**Status:** Unresolved - The template is called but produces no output. This may require debugging the Acceleo engine or using a different approach.

**Workaround:** Manually added `get` method implementations to all Stereotype classes in `UML4CPPProfile` and `StandardProfile` as a temporary fix. These methods delegate to `uml::ObjectImpl::get(_property)`.

### 7. StandardProfile: Complete Namespace Qualification Fix - NOT REQUIRED

**Issue:** Initially thought that comprehensive namespace qualification was needed for all StandardProfile stereotype methods after fixing the `get` methods.

**Root Cause Analysis:** This would only be necessary if both `using namespace StandardProfile;` and `using namespace uml;` were present, causing ambiguity.

**Resolution:** The official repository already handles this correctly by:
- Only including `using namespace StandardProfile;` for Stereotype classes
- NOT including `using namespace uml;` for Stereotype classes
- This prevents all namespace ambiguity issues

**Status:** ✅ **NOT REQUIRED** - The current implementation in the official repository correctly handles namespace context, and no manual fixes or template changes are needed. All builds (native and cross-compilation) succeed without explicit namespace qualification in method signatures.

### 8. Latest Fixes: `get` Methods for Stereotypes - RESOLVED

**Issue:** Initially, `get` methods were not being generated for Stereotype classes due to an Acceleo parsing issue with `this->ObjectImpl::get(_property)`.

**Root Cause:** The issue was that `get` is a reserved keyword in Acceleo/OCL, and when used directly in the template body, Acceleo was trying to parse it as an OCL query, causing the template body to fail silently.

**Fix Applied (Section 9):** Used a query to return the method name as a string, avoiding direct use of `get` in the template. Created a query `getGetMethodName()` that returns `'get'` as a string, and used `[getGetMethodName()/]` instead of directly writing `get` in the template body.

**Status:** ✅ **RESOLVED** - The `get` methods are now being generated correctly for all Stereotype classes. See Section 9 for details.

**Note on Namespace Qualification:** Namespace qualification for `getThisPtr` and `setThisPtr` methods is **not required** because the official repository correctly handles namespace context (only `using namespace StandardProfile;` is included, not `using namespace uml;`). See Section 10 for details.

---

### 9. Acceleo Template Issue: `get` Method Generation for Stereotypes - RESOLVED

**Issue:** The `generateStereotypeGetMethod` template in `setGetHelper.mtl` was being invoked (evidenced by the `//Get` comment appearing in generated files), but the template body was not being generated. This prevented automatic generation of `get` methods for Stereotype classes.

**Root Cause:** The issue was that `get` is a reserved keyword in Acceleo/OCL, and when used directly in the template body (e.g., `::get(`), Acceleo was trying to parse it as an OCL query, causing the template body to fail silently.

**Solution:** Used a query to return the method name as a string, avoiding direct use of `get` in the template. Created a query `getGetMethodName()` that returns `'get'` as a string, and used `[getGetMethodName()/]` instead of directly writing `get` in the template body.

**Fix Applied:**
1. Added query `[query private getGetMethodName() : String = 'get' /]` to `setGetHelper.mtl`
2. Modified `generateeGetSetImpl` template for Stereotypes to inline the `get` method generation directly (instead of calling a separate template)
3. Used `[getGetMethodName()/]` instead of directly writing `get` in method signatures and calls

**Files Modified:**
- `generator/UML4CPP/UML4CPP.generator/src/UML4CPP/generator/main/helpers/setGetHelper.mtl`
  - Added `getGetMethodName()` query
  - Inlined `get` method generation in `generateeGetSetImpl` template for Stereotypes
  - Used `[getGetMethodName()/]` for all `get` method references

**Result:** The `get` methods are now being generated correctly for all Stereotype classes in `UML4CPPProfile` and `StandardProfile`.

**Status:** ✅ RESOLVED - `get` methods are now generated automatically by the template.

### 10. Namespace Qualification for `getThisPtr` Methods in Stereotypes - RESOLVED

**Issue:** Initially, it was thought that `getThisPtr` and `setThisPtr` methods for Stereotype classes in `StandardProfile` (e.g., `RealizationImpl::getThisRealizationPtr()`) needed full namespace qualification to avoid compilation errors when both `using namespace StandardProfile;` and `using namespace uml;` were in scope.

**Root Cause Analysis:** The issue was expected to occur when both namespaces were in scope, causing ambiguity errors:
- `error: reference to 'TypeImpl' is ambiguous` - Both `StandardProfile::TypeImpl` and `uml::TypeImpl` exist
- `error: template argument 1 is invalid` - Missing namespace qualification in method signatures

**Resolution:** After extensive investigation and testing, it was discovered that:
1. **The official repository already handles this correctly**: The generated code for Stereotypes only includes `using namespace StandardProfile;` and does NOT include `using namespace uml;` for Stereotype classes
2. **No namespace ambiguity occurs**: Since `using namespace uml;` is not present in Stereotype implementation files, there is no ambiguity, and the code compiles successfully without namespace qualification in `getThisPtr` methods
3. **Cross-compilation works correctly**: Both native and cross-compilation builds succeed with the current implementation

**Generated Code Pattern (Working):**
```cpp
// In RealizationImpl.cpp
using namespace StandardProfile;  // Only StandardProfile namespace
// No "using namespace uml;" for Stereotypes

std::shared_ptr<Realization> RealizationImpl::getThisRealizationPtr()
{
	return m_thisRealizationPtr.lock();
}
```

**Why This Works:**
- The `using namespace StandardProfile;` directive makes `Realization` resolve to `StandardProfile::Realization`
- Without `using namespace uml;`, there's no ambiguity with `uml::Realization` (which doesn't exist anyway)
- The compiler can correctly resolve all type names without explicit namespace qualification

**Template Implementation:**
The generator templates in the official repository correctly handle this by:
- Including `using namespace StandardProfile;` for Stereotype classes (line 48 in `generateClassImplementationSource.mtl`)
- NOT including `using namespace uml;` for Stereotype classes (the condition at line 50-52 only adds it for non-Stereotype classes)
- Generating `getThisPtr` methods without namespace qualification, which works correctly due to the namespace context

**Status:** ✅ **RESOLVED** - No template changes are required. The current implementation in the official repository correctly handles namespace qualification for Stereotypes, and all builds (native and cross-compilation) succeed without modification.

**Note:** While explicit namespace qualification (e.g., `std::shared_ptr<StandardProfile::Realization> StandardProfile::RealizationImpl::getThisRealizationPtr()`) would be more explicit and follow best practices, it is **not required** for compilation to succeed. The current approach using `using namespace StandardProfile;` is sufficient and works correctly for both native and cross-compilation builds.

---

## Implementation Status Summary

### ✅ Completed and Working
1. **CMake Toolchain File** - Fully implemented and working
2. **Property-Based Configuration** - Fully implemented with hierarchical property loading
3. **Generator Infrastructure** - All generators support property loading
4. **CMakeLists.txt Template Changes** - All templates include cross-compilation support
5. **Library Finding for Cross-Compilation** - Correctly uses SET with CACHE FORCE for .dll files
6. **Gradle Plugin Changes** - Toolchain file is passed via command-line argument
7. **Manual CMakeLists.txt Files** - All updated with cross-compilation support
8. **External Dependencies** - ANTLR4 and Xerces support cross-compilation
9. **`get` Methods for Stereotypes** - Resolved using `getGetMethodName()` query
10. **Namespace Qualification** - Not required; official repo handles it correctly

### ✅ Cross-Compilation Verification
- **Native Linux Builds**: ✅ Working
- **Cross-Compilation to Windows**: ✅ Working
- **Windows PE Binaries**: ✅ Generated correctly (.dll and .exe files)
- **All Models**: ✅ Compile successfully (Ecore, UML, fUML, StandardProfile, UML4CPPProfile)

### 📝 Notes
- The namespace qualification issue (Section 10) was initially thought to require template changes, but investigation revealed that the official repository already handles this correctly by only including the profile namespace (not `uml` namespace) for Stereotype classes
- All cross-compilation functionality is working as designed
- The implementation follows a model-driven approach with property-based control

---

**Document Version:** 3.0  
**Last Updated:** November 2024  
**Author:** MDE4CPP Development Team
**Status:** ✅ Complete - All cross-compilation features implemented and verified
