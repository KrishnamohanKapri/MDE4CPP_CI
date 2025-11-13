# Setting Up MDE4CPP from a Fresh Clone

This guide will help you set up MDE4CPP from a fresh clone and build everything successfully.

## Prerequisites

Before building, you need to install the following:

### 1. System Dependencies

Run the installation script (requires sudo for system packages):
```bash
sudo ./install_dependencies.sh
```

Or install manually:
```bash
sudo apt-get update
sudo apt-get install -y \
    openjdk-21-jdk \
    build-essential \
    gcc \
    g++ \
    git \
    wget \
    unzip \
    tar \
    mingw-w64 \
    g++-mingw-w64-x86-64 \
    gcc-mingw-w64-x86-64 \
    uuid-dev \
    cmake
```

### 2. Eclipse Modeling Tools

Eclipse is required for code generation. You can either:

**Option A: Use the install script (recommended)**
```bash
./install_dependencies.sh
```
This will download and install Eclipse Modeling Tools automatically.

**Option B: Install manually**
1. Download Eclipse Modeling Tools from: https://www.eclipse.org/downloads/packages/release/2025-06
2. Extract to a location of your choice (e.g., `~/eclipse`)
3. Install required plugins (Acceleo, Sirius, Papyrus) - see README.md for details

### 3. Verify Prerequisites

Run the check script:
```bash
./check_prerequisites.sh
```

## Setup Steps

### Step 1: Clone the Repository

```bash
git clone git@github.com:KrishnamohanKapri/MDE4CPP_CI_Implementation.git
cd MDE4CPP_CI_Implementation
```

### Step 2: Configure Environment

1. Copy the environment template:
   ```bash
   cp setenv.default setenv
   ```

2. Edit `setenv` and configure:
   - `MDE4CPP_HOME`: Set to the absolute path of your cloned repository
     ```bash
     export MDE4CPP_HOME=/path/to/MDE4CPP_CI_Implementation
     ```
   - `MDE4CPP_ECLIPSE_HOME`: Set to your Eclipse installation path
     ```bash
     export MDE4CPP_ECLIPSE_HOME=/path/to/eclipse
     ```

3. Make gradlew executable:
   ```bash
   chmod +x application/tools/gradlew
   ```

### Step 3: Publish Gradle Plugins

The Gradle plugins need to be published to your local Maven repository before building:

```bash
cd gradlePlugins
./application/tools/gradlew publishMDE4CPPPluginsToMavenLocal
cd ..
```

Or use the setenv script (which does this automatically):
```bash
. ./setenv
```

### Step 4: Build Everything

**Option A: Use the buildAll script (recommended)**
```bash
./buildAll.sh
```

**Option B: Build manually with Gradle**
```bash
./application/tools/gradlew generateAll
./application/tools/gradlew compileAll
./application/tools/gradlew src:buildOCLAll
```

### Step 5: Cross-Compilation (Optional)

To cross-compile to Windows from Linux:

1. Ensure MinGW-w64 is installed (included in prerequisites)
2. Set `CROSS_COMPILE_WINDOWS = true` in `MDE4CPP_Generator.properties`
3. Build with cross-compilation:
   ```bash
   ./buildAll.sh --cross-compile-windows
   ```

Or use Gradle directly:
```bash
./application/tools/gradlew generateAll -PCROSS_COMPILE_WINDOWS=true
./application/tools/gradlew compileAll -PCROSS_COMPILE_WINDOWS=true -PRELEASE=1 -PDEBUG=0
./application/tools/gradlew src:buildOCLAll -PCROSS_COMPILE_WINDOWS=true -PRELEASE=1 -PDEBUG=0
```

## What Gets Built

The build process will:

1. **Download third-party dependencies automatically:**
   - ANTLR4 C++ runtime (downloaded by Gradle)
   - Xerces-C XML parser (downloaded by Gradle)

2. **Generate code:**
   - All model code is generated into `src_gen/` directories
   - Generated headers are copied to `application/include/`
   - Generated CMakeLists.txt files are created

3. **Compile everything:**
   - All libraries are built and placed in `application/lib/`
   - All executables are built and placed in `application/bin/`

## Troubleshooting

### Issue: "gradlew not found"
**Solution:** Make sure you're in the repository root and run:
```bash
chmod +x application/tools/gradlew
```

### Issue: "MDE4CPP_HOME not set"
**Solution:** Make sure you've created and configured the `setenv` file:
```bash
cp setenv.default setenv
# Edit setenv and set MDE4CPP_HOME to your repository path
. ./setenv
```

### Issue: "Eclipse not found"
**Solution:** Install Eclipse Modeling Tools and set `MDE4CPP_ECLIPSE_HOME` in your `setenv` file.

### Issue: "ANTLR or Xerces download fails"
**Solution:** The build scripts automatically download these. If download fails:
- Check your internet connection
- The files will be cached in `src/common/parser/antlr4/` and `src/common/persistence/xerces/`

### Issue: "Permission denied"
**Solution:** Make sure gradlew is executable:
```bash
chmod +x application/tools/gradlew
```

## Verification

After building, verify the build was successful:

```bash
# Check for generated libraries
ls -lh application/lib/*.a application/lib/*.dll.a 2>/dev/null | head -5

# Check for compiled executables
ls -lh application/bin/*.exe application/bin/* 2>/dev/null | head -5

# Check for generated headers
ls -d application/include/*/ | head -5
```

## Notes

- The repository contains **only source files** - no generated or compiled files
- All generated code goes into `src_gen/` directories (ignored by git)
- All compiled binaries go into `application/` (ignored by git)
- Third-party source code (ANTLR, Xerces) is downloaded automatically during build
- The toolchain file for cross-compilation is at: `src/common/cmake/cmake-toolchain-mingw.cmake`

