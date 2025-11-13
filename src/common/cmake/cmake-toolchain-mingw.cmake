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

