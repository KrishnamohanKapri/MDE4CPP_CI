#
#  MDE4CPP - Model Driven Engineering for C++
#
#  Copyright (c) TU Ilmenau, Systems and Software Engineering Group
#  All rights reserved.
#
#  MIT License
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy of this
#  software and associated documentation files (the "Software"), to deal in the Software
#  without restriction, including without limitation the rights to use, copy, modify, merge,
#  publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons
#  to whom the Software is furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included in all copies or
#  substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED *AS IS*, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
#  INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
#  PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
#  FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
#  OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
#  DEALINGS IN THE SOFTWARE.
#

CMAKE_MINIMUM_REQUIRED(VERSION 3.9)

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
        # Also try relative to current source directory
        IF(NOT CMAKE_TOOLCHAIN_FILE)
            SET(TOOLCHAIN_FILE "${CMAKE_SOURCE_DIR}/../../../../src/common/cmake/cmake-toolchain-mingw.cmake")
            IF(EXISTS ${TOOLCHAIN_FILE})
                get_filename_component(TOOLCHAIN_FILE_ABS ${TOOLCHAIN_FILE} ABSOLUTE)
                set(CMAKE_TOOLCHAIN_FILE ${TOOLCHAIN_FILE_ABS} CACHE FILEPATH "Toolchain file" FORCE)
            ENDIF()
        ENDIF()
    ENDIF()
ENDIF()

PROJECT(persistence)

IF(NOT CMAKE_BUILD_TYPE) 
    SET(CMAKE_BUILD_TYPE Debug)
ENDIF(NOT CMAKE_BUILD_TYPE)
SET(CMAKE_DEBUG_POSTFIX d)

SET(CMAKE_CXX_STANDARD 17)

SET(CMAKE_CXX_FLAGS "-Wall -Wno-overloaded-virtual -Wdeprecated-declarations -fmax-errors=5 -DXERCES_BUILDING_LIBRARY=1")
IF(APPLE)
  string(APPEND CMAKE_CXX_FLAGS " -Qunused-arguments")
ENDIF(APPLE)
SET(CMAKE_CXX_FLAGS_DEBUG " -Og -ggdb -DACTIVITY_DEBUG_ON")
SET(CMAKE_CXX_FLAGS_RELEASE " -O3 -DNDEBUG")

string(REPLACE "\\" "/" MDE4CPP_HOME $ENV{MDE4CPP_HOME})

SET(SOURCE_FILES
	base/Persistence.cpp
	base/Load.cpp
	base/Save.cpp
	base/LoadHandler.cpp
	base/SaveHandler.cpp
	base/HandlerHelper.cpp
	xml/XMLPersistence.cpp
	xml/XMLLoad.cpp
	xml/XMLSave.cpp
	xml/XMLLoadHandler.cpp
	xml/XMLSaveHandler.cpp
	xml/xerces/DOMPrintErrorHandler.cpp
	xml/xerces/DOMPrintFilter.cpp
	xml/xerces/DOMTreeErrorReporter.cpp
	xml/xerces/WStr.cpp
	xml/xerces/XStr.cpp
	crossguid/guid.cpp
)

INCLUDE_DIRECTORIES(
	../
 	$ENV{MDE4CPP_HOME}/application/include
)

# Apple specific stuff
if(APPLE)
  set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -undefined dynamic_lookup")
  set(CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS} -undefined dynamic_lookup")
endif(APPLE)

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
    # Use Windows GUID API instead of Linux uuid/uuid.h
    SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DGUID_WINDOWS")
    # Unset any previous NOTFOUND values first
    UNSET(PLUGINFRAMEWORK_DEBUG CACHE)
    UNSET(PLUGINFRAMEWORK_RELEASE CACHE)
    UNSET(ECORE_DEBUG CACHE)
    UNSET(ECORE_RELEASE CACHE)
    UNSET(TYPES_DEBUG CACHE)
    UNSET(TYPES_RELEASE CACHE)
    UNSET(XERCES_DEBUG CACHE)
    UNSET(XERCES_RELEASE CACHE)
    IF (CMAKE_BUILD_TYPE STREQUAL "Debug")
        SET(PLUGINFRAMEWORK_DEBUG "${MDE4CPP_HOME}/application/bin/pluginFrameworkd.dll" CACHE FILEPATH "PluginFramework debug library" FORCE)
        SET(ECORE_DEBUG "${MDE4CPP_HOME}/application/bin/ecored.dll" CACHE FILEPATH "Ecore debug library" FORCE)
        SET(TYPES_DEBUG "${MDE4CPP_HOME}/application/bin/typesd.dll" CACHE FILEPATH "Types debug library" FORCE)
        SET(XERCES_DEBUG "${MDE4CPP_HOME}/application/bin/xerces-c.dll" CACHE FILEPATH "Xerces debug library" FORCE)
    ELSE()
        SET(PLUGINFRAMEWORK_RELEASE "${MDE4CPP_HOME}/application/bin/pluginFramework.dll" CACHE FILEPATH "PluginFramework release library" FORCE)
        SET(ECORE_RELEASE "${MDE4CPP_HOME}/application/bin/ecore.dll" CACHE FILEPATH "Ecore release library" FORCE)
        SET(TYPES_RELEASE "${MDE4CPP_HOME}/application/bin/types.dll" CACHE FILEPATH "Types release library" FORCE)
        SET(XERCES_RELEASE "${MDE4CPP_HOME}/application/bin/xerces-c.dll" CACHE FILEPATH "Xerces release library" FORCE)
    ENDIF()
ELSEIF(UNIX AND NOT APPLE)
    # Native Linux build - use .so
	SET(CMAKE_CXX_FLAGS "-DGUID_LIBUUID")

	IF (CMAKE_BUILD_TYPE STREQUAL "Debug")
		FIND_LIBRARY(PLUGINFRAMEWORK_DEBUG pluginFrameworkd.so ${MDE4CPP_HOME}/application/bin)
		FIND_LIBRARY(ECORE_DEBUG ecored.so ${MDE4CPP_HOME}/application/bin)
		FIND_LIBRARY(TYPES_DEBUG typesd.so ${MDE4CPP_HOME}/application/bin)
		FIND_LIBRARY(XERCES_DEBUG xerces-c ${MDE4CPP_HOME}/application/bin)
	ELSE()
		FIND_LIBRARY(PLUGINFRAMEWORK_RELEASE pluginFramework.so ${MDE4CPP_HOME}/application/bin)
		FIND_LIBRARY(ECORE_RELEASE ecore.so ${MDE4CPP_HOME}/application/bin)
		FIND_LIBRARY(TYPES_RELEASE types.so ${MDE4CPP_HOME}/application/bin)
		FIND_LIBRARY(XERCES_RELEASE xerces-c ${MDE4CPP_HOME}/application/bin)
	ENDIF()
ELSEIF(APPLE)
	SET(CMAKE_CXX_FLAGS "-DGUID_CFUUID")

	IF (CMAKE_BUILD_TYPE STREQUAL "Debug")
		FIND_LIBRARY(PLUGINFRAMEWORK_DEBUG pluginFrameworkd.dylib ${MDE4CPP_HOME}/application/bin)
		FIND_LIBRARY(ECORE_DEBUG ecored.dylib ${MDE4CPP_HOME}/application/bin)
		FIND_LIBRARY(TYPES_DEBUG typesd.dylib ${MDE4CPP_HOME}/application/bin)
		FIND_LIBRARY(XERCES_DEBUG xerces-c ${MDE4CPP_HOME}/application/bin)		
	ELSE()
		FIND_LIBRARY(PLUGINFRAMEWORK_RELEASE pluginFramework.dylib ${MDE4CPP_HOME}/application/bin)
		FIND_LIBRARY(ECORE_RELEASE ecore.dylib ${MDE4CPP_HOME}/application/bin)
		FIND_LIBRARY(TYPES_RELEASE types.dylib ${MDE4CPP_HOME}/application/bin)
		FIND_LIBRARY(XERCES_RELEASE xerces-c ${MDE4CPP_HOME}/application/bin)		
	ENDIF()
ELSE()
	SET(CMAKE_CXX_FLAGS "-DGUID_WINDOWS")

	IF (CMAKE_BUILD_TYPE STREQUAL "Debug")
		FIND_LIBRARY(PLUGINFRAMEWORK_DEBUG pluginFrameworkd ${MDE4CPP_HOME}/application/lib)
		FIND_LIBRARY(ECORE_DEBUG ecored ${MDE4CPP_HOME}/application/lib)
		FIND_LIBRARY(TYPES_DEBUG typesd ${MDE4CPP_HOME}/application/lib)
		FIND_LIBRARY(XERCES_DEBUG xerces-c ${MDE4CPP_HOME}/application/lib)
	ELSE()
		FIND_LIBRARY(PLUGINFRAMEWORK_RELEASE pluginFramework ${MDE4CPP_HOME}/application/lib)
		FIND_LIBRARY(ECORE_RELEASE ecore ${MDE4CPP_HOME}/application/lib)
		FIND_LIBRARY(TYPES_RELEASE types ${MDE4CPP_HOME}/application/lib)
		FIND_LIBRARY(XERCES_RELEASE xerces-c ${MDE4CPP_HOME}/application/lib)
	ENDIF()
ENDIF()

ADD_LIBRARY(${PROJECT_NAME} SHARED ${SOURCE_FILES})
SET_TARGET_PROPERTIES(${PROJECT_NAME} PROPERTIES PREFIX "")

IF(CMAKE_BUILD_TYPE STREQUAL "Debug")
	TARGET_LINK_LIBRARIES(${PROJECT_NAME} 	
		debug ${ECORE_DEBUG}
		debug ${TYPES_DEBUG}
		debug ${PLUGINFRAMEWORK_DEBUG}
		debug ${XERCES_DEBUG}
	)
ELSE()
	TARGET_LINK_LIBRARIES(${PROJECT_NAME}
		optimized ${ECORE_RELEASE}
		optimized ${TYPES_RELEASE}
		optimized ${PLUGINFRAMEWORK_RELEASE}
		optimized ${XERCES_RELEASE}
	)
ENDIF()

#-----------------------------------------------------
# DELIVERING binaries and header to ${MDE4CPP_HOME}
#-----------------------------------------------------

INSTALL(TARGETS ${PROJECT_NAME} 
	RUNTIME DESTINATION ${MDE4CPP_HOME}/application/bin
    LIBRARY DESTINATION ${MDE4CPP_HOME}/application/bin
    ARCHIVE DESTINATION ${MDE4CPP_HOME}/application/lib
)

# Interface are installed from gradle task "deliverPersistenceInterface"
#INSTALL(DIRECTORY interfaces xml base DESTINATION ${MDE4CPP_HOME}/application/include/${PROJECT_NAME}
#  FILES_MATCHING 
#    PATTERN "interfaces/*.hpp"
#    PATTERN "xml/XMLPersistence.hpp"
#    PATTERN "base/Persistence.hpp"
#    PATTERN "xerces" EXCLUDE
#    PATTERN ".cmake" EXCLUDE
#)
