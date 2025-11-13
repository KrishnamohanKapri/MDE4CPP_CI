# MDE4CPP Setup Status on Debian 13

## ✅ Completed Steps

1. **Repository Cloned**: MDE4CPP repository successfully cloned to `/home/krish/Projects/RP/MDE4CPP`

2. **Eclipse Installed**: Eclipse Modeling Tools 2024-06 installed in `/home/krish/Projects/RP/eclipse`
   - ✅ Acceleo 3.7.16 installed
   - ✅ Papyrus 6.7.0 installed
   - ✅ EMF SDK 2.38.0 installed
   - ✅ UML2 SDK installed
   - ✅ GMF Runtime SDK installed
   - ✅ OCL SDK installed
   - ✅ EMF Ecore Tools installed
   - ✅ EMF Transaction SDK installed
   - ✅ XSD SDK installed

3. **Environment Configured**: `setenv` file created and configured with:
   - MDE4CPP_HOME: `/home/krish/Projects/RP/MDE4CPP`
   - MDE4CPP_ECLIPSE_HOME: `/home/krish/Projects/RP/eclipse`

4. **Documentation Created**: `commands.txt` with all verified setup commands

## ⚠️ Remaining Steps (Require sudo/root)

### 1. Install JDK 21
```bash
sudo apt-get update
sudo apt-get install -y openjdk-21-jdk
```

### 2. Install MinGW-w64
```bash
sudo apt-get install -y \
    build-essential \
    gcc \
    g++ \
    mingw-w64 \
    g++-mingw-w64-x86-64 \
    gcc-mingw-w64-x86-64

sudo update-alternatives --set x86_64-w64-mingw32-g++ /usr/bin/x86_64-w64-mingw32-g++-posix
sudo update-alternatives --set x86_64-w64-mingw32-gcc /usr/bin/x86_64-w64-mingw32-gcc-posix
```

### 3. Verify Installations
```bash
java -version  # Should show Java 21
javac -version # Should show Java 21
x86_64-w64-mingw32-g++ --version
cmake --version  # Already installed ✓
```

## 📝 Next Steps After Installing Dependencies

1. **Set JAVA_HOME** (adjust path if different):
   ```bash
   export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
   echo "export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64" >> ~/.bashrc
   ```

2. **Source the environment**:
   ```bash
   cd /home/krish/Projects/RP/MDE4CPP
   . ./setenv
   ```

3. **Build Gradle Plugins**:
   ```bash
   cd gradlePlugins
   ../application/tools/gradlew --no-daemon --stacktrace publishMDE4CPPPluginsToMavenLocal
   cd ..
   ```

4. **Build All Metamodels**:
   ```bash
   . ./setenv
   ./application/tools/gradlew buildAll
   ```

5. **Create All Generators**:
   ```bash
   ./application/tools/gradlew createAllGenerators
   ```

## 📋 Files Created

- `/home/krish/Projects/RP/commands.txt` - Complete setup commands
- `/home/krish/Projects/RP/check_prerequisites.sh` - Prerequisites checker
- `/home/krish/Projects/RP/install_dependencies.sh` - Installation helper script
- `/home/krish/Projects/RP/MDE4CPP/setenv` - Configured environment file

## 🔍 Verification

Run the prerequisites checker:
```bash
cd /home/krish/Projects/RP
./check_prerequisites.sh
```

This will show what's installed and what's missing.

## 📌 Notes

- Eclipse was installed in user space (`/home/krish/Projects/RP/eclipse`) to avoid sudo requirements
- Some Sirius features may not be available in Eclipse 2024-06 release, but the essential plugins are installed
- CMake is already installed (version 3.31.6)
- The `setenv` file has been configured with the correct paths
- All commands in `commands.txt` are ready to use once JDK and MinGW-w64 are installed

