#!/bin/bash
# Installation script for MDE4CPP dependencies
# Run commands that require sudo separately, or run this script with sudo

set -e

echo "=== MDE4CPP Dependency Installation Script ==="
echo ""

# Check if running as root for system packages
if [ "$EUID" -eq 0 ]; then 
    IS_ROOT=true
    echo "Running as root - will install system packages"
else
    IS_ROOT=false
    echo "Not running as root - will only install user-space dependencies"
    echo "For system packages, run: sudo ./install_dependencies.sh"
fi
echo ""

# Install system packages (requires root)
if [ "$IS_ROOT" = true ]; then
    echo "Installing system packages..."
    apt-get update
    apt-get install -y \
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
        gnupg \
        ca-certificates \
        uuid-dev
    
    # Configure MinGW-w64 alternatives
    update-alternatives --set x86_64-w64-mingw32-g++ /usr/bin/x86_64-w64-mingw32-g++-posix 2>/dev/null || true
    update-alternatives --set x86_64-w64-mingw32-gcc /usr/bin/x86_64-w64-mingw32-gcc-posix 2>/dev/null || true
    
    # Install CMake from Kitware (if not already installed or needs update)
    if ! command -v cmake &> /dev/null || [ "$(cmake --version | head -n1 | awk '{print $3}' | cut -d. -f1)" -lt 3 ]; then
        echo "Setting up CMake repository..."
        wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc | gpg --dearmor -o /usr/share/keyrings/kitware-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ jammy main" > /etc/apt/sources.list.d/kitware.list
        apt-get update
        apt-get install -y cmake
    fi
    
    echo "✓ System packages installed"
else
    echo "Skipping system package installation (requires root)"
    echo "Please run these commands manually:"
    echo "  sudo apt-get update"
    echo "  sudo apt-get install -y openjdk-21-jdk build-essential gcc g++ git wget unzip tar mingw-w64 g++-mingw-w64-x86-64 gcc-mingw-w64-x86-64 uuid-dev"
    echo "  sudo update-alternatives --set x86_64-w64-mingw32-g++ /usr/bin/x86_64-w64-mingw32-g++-posix"
    echo "  sudo update-alternatives --set x86_64-w64-mingw32-gcc /usr/bin/x86_64-w64-mingw32-gcc-posix"
fi
echo ""

# Install Eclipse in user space (no root required)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ECLIPSE_DIR="$SCRIPT_DIR/eclipse"

if [ ! -d "$ECLIPSE_DIR" ] || [ ! -f "$ECLIPSE_DIR/eclipse" ]; then
    echo "Installing Eclipse Modeling Tools..."
    mkdir -p "$ECLIPSE_DIR"
    cd /tmp
    
    # Try 2025-06 first, fallback to 2024-06
    ECLIPSE_URL_2025="https://www.eclipse.org/downloads/download.php?file=/technology/epp/downloads/release/2025-06/R/eclipse-modeling-2025-06-R-linux-gtk-x86_64.tar.gz&r=1"
    ECLIPSE_URL_2024="https://www.eclipse.org/downloads/download.php?file=/technology/epp/downloads/release/2024-06/R/eclipse-modeling-2024-06-R-linux-gtk-x86_64.tar.gz&r=1"
    
    if wget -q --spider "$ECLIPSE_URL_2025" 2>/dev/null; then
        echo "Downloading Eclipse 2025-06..."
        wget -O eclipse.tar.gz "$ECLIPSE_URL_2025"
    else
        echo "Eclipse 2025-06 not available, trying 2024-06..."
        wget -O eclipse.tar.gz "$ECLIPSE_URL_2024"
    fi
    
    echo "Extracting Eclipse..."
    tar -xzf eclipse.tar.gz -C "$ECLIPSE_DIR" --strip-components=1
    rm -f eclipse.tar.gz
    
    chmod +x "$ECLIPSE_DIR/eclipse"
    echo "✓ Eclipse installed in $ECLIPSE_DIR"
else
    echo "✓ Eclipse already installed in $ECLIPSE_DIR"
fi
echo ""

# Install Eclipse plugins
if [ -f "$ECLIPSE_DIR/eclipse" ]; then
    echo "Installing Eclipse plugins (this may take a while)..."
    
    # Check if Eclipse directory is writable, if not, we'll need sudo
    ECLIPSE_NEEDS_SUDO=false
    if [ ! -w "$ECLIPSE_DIR" ]; then
        ECLIPSE_NEEDS_SUDO=true
        echo "Eclipse directory is not writable, will use sudo for plugin installation"
    fi
    
    # Determine Eclipse release year from directory or try both
    ECLIPSE_REPO_2025="https://download.eclipse.org/releases/2025-06/"
    ECLIPSE_REPO_2024="https://download.eclipse.org/releases/2024-06/"
    
    # Run plugin installation (with sudo if needed)
    if [ "$ECLIPSE_NEEDS_SUDO" = true ]; then
        if sudo -n true 2>/dev/null; then
            # Sudo password already cached
            sudo "$ECLIPSE_DIR/eclipse" -nosplash -application org.eclipse.equinox.p2.director \
                -repository "$ECLIPSE_REPO_2025,$ECLIPSE_REPO_2024" \
                -installIU org.eclipse.acceleo.feature.group \
                -installIU org.eclipse.emf.sdk.feature.group \
                -installIU org.eclipse.uml2.sdk.feature.group \
                -installIU org.eclipse.ocl.all.sdk.feature.group \
                -destination "$ECLIPSE_DIR" \
                -profileProperties org.eclipse.update.install.features=true \
                -bundlepool "$ECLIPSE_DIR" \
                -p2.os linux \
                -p2.ws gtk \
                -p2.arch x86_64 || {
                echo "⚠ Plugin installation failed. You may need to run manually with sudo."
                exit 1
            }
        else
            echo "⚠ Plugin installation requires sudo. Please run:"
            echo "  sudo \"$ECLIPSE_DIR/eclipse\" -nosplash -application org.eclipse.equinox.p2.director \\"
            echo "    -repository \"$ECLIPSE_REPO_2025,$ECLIPSE_REPO_2024\" \\"
            echo "    -installIU org.eclipse.acceleo.feature.group \\"
            echo "    -installIU org.eclipse.emf.sdk.feature.group \\"
            echo "    -installIU org.eclipse.uml2.sdk.feature.group \\"
            echo "    -installIU org.eclipse.ocl.all.sdk.feature.group \\"
            echo "    -destination \"$ECLIPSE_DIR\" \\"
            echo "    -profileProperties org.eclipse.update.install.features=true \\"
            echo "    -bundlepool \"$ECLIPSE_DIR\" \\"
            echo "    -p2.os linux -p2.ws gtk -p2.arch x86_64"
            echo ""
            echo "Or run this script with sudo: sudo ./install_dependencies.sh"
            exit 1
        fi
    else
        "$ECLIPSE_DIR/eclipse" -nosplash -application org.eclipse.equinox.p2.director \
            -repository "$ECLIPSE_REPO_2025,$ECLIPSE_REPO_2024" \
            -installIU org.eclipse.acceleo.feature.group \
            -installIU org.eclipse.emf.sdk.feature.group \
            -installIU org.eclipse.uml2.sdk.feature.group \
            -installIU org.eclipse.ocl.all.sdk.feature.group \
            -destination "$ECLIPSE_DIR" \
            -profileProperties org.eclipse.update.install.features=true \
            -bundlepool "$ECLIPSE_DIR" \
            -p2.os linux \
            -p2.ws gtk \
            -p2.arch x86_64 || {
            echo "⚠ Plugin installation failed"
            exit 1
        }
    fi
    
    # Verify critical JARs are present (required by build.gradle)
    echo "Verifying required JARs installation..."
    REQUIRED_JARS=(
        # Acceleo (for code generation)
        "org.eclipse.acceleo.common_*.jar"
        "org.eclipse.acceleo.engine_*.jar"
        "org.eclipse.acceleo.model_*.jar"
        "org.eclipse.acceleo.parser_*.jar"
        # EMF (for model handling)
        "org.eclipse.emf.common_*.jar"
        "org.eclipse.emf.ecore_*.jar"
        "org.eclipse.emf.ecore.xmi_*.jar"
        # UML2 (for UML support)
        "org.eclipse.uml2.common_*.jar"
        "org.eclipse.uml2.uml_*.jar"
        "org.eclipse.uml2.types_*.jar"
        # OCL (for OCL support)
        "org.eclipse.ocl.common_*.jar"
        "org.eclipse.ocl.ecore_*.jar"
        "org.eclipse.ocl_*.jar"
        # Eclipse Core (for runtime)
        "org.eclipse.core.runtime_*.jar"
        "org.eclipse.equinox.app_*.jar"
        "org.eclipse.equinox.common_*.jar"
        "org.eclipse.equinox.preferences_*.jar"
        "org.eclipse.equinox.registry_*.jar"
        "org.eclipse.osgi_*.jar"
        # Third-party
        "com.google.guava_*.jar"
        "jakarta.inject.jakarta.inject-api_*.jar"
        "jakarta.annotation-api_*.jar"
        "lpg.runtime.java_*.jar"
    )
    
    MISSING_JARS=()
    # Enable nullglob so unmatched patterns return empty array
    shopt -s nullglob
    for jar_pattern in "${REQUIRED_JARS[@]}"; do
        # Expand the pattern and check if any files match
        files=("$ECLIPSE_DIR/plugins/$jar_pattern")
        if [ ${#files[@]} -eq 0 ]; then
            MISSING_JARS+=("$jar_pattern")
        fi
    done
    shopt -u nullglob  # Disable nullglob after use
    
    if [ ${#MISSING_JARS[@]} -gt 0 ]; then
        echo "⚠ Warning: Some required JARs are missing:"
        for jar in "${MISSING_JARS[@]}"; do
            echo "  - $jar"
        done
        echo "  The build may fail. Please re-run the plugin installation."
    else
        echo "✓ All required JARs are present"
    fi
    
    echo "✓ Eclipse plugins installation completed"
else
    echo "⚠ Eclipse not found, skipping plugin installation"
fi
echo ""

echo "=== Installation Complete ==="
echo ""
echo "Eclipse location: $ECLIPSE_DIR"
echo "Set ECLIPSE_HOME=$ECLIPSE_DIR in your setenv file"

