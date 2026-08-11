# The Flutter tooling requires that developers have CMake 3.10 or later installed. You should not increase this version,
# as doing so will cause the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

# Set policy for FetchContent timestamp handling
if(POLICY CMP0135)
  cmake_policy(SET CMP0135 NEW)
endif()

# Project-level configuration.
set(PROJECT_NAME "flutter_onnxruntime")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must not be changed.
set(PLUGIN_NAME "flutter_onnxruntime_plugin")

# === ONNX Runtime Configuration ===
# Option 1: Use pre-installed ONNX Runtime (preferred for system packages)
option(USE_SYSTEM_ONNXRUNTIME "Use system-installed ONNX Runtime" ON)

if(USE_SYSTEM_ONNXRUNTIME)
  # Try to find ONNX Runtime using pkg-config
  find_package(PkgConfig)
  if(PkgConfig_FOUND)
    pkg_check_modules(ONNXRUNTIME onnxruntime)
  endif()

  # If pkg-config didn't find it, try to find it manually
  if(NOT ONNXRUNTIME_FOUND)
    # Specify custom paths where ONNX Runtime might be installed
    set(ONNXRUNTIME_ROOT_DIR
        ""
        CACHE PATH "ONNX Runtime root directory")

    # Look for the library
    find_library(
      ONNXRUNTIME_LIBRARY
      NAMES onnxruntime
      PATHS ${ONNXRUNTIME_ROOT_DIR}/lib
      DOC "ONNX Runtime library")

    # Look for the include directory
    find_path(
      ONNXRUNTIME_INCLUDE_DIR
      NAMES onnxruntime_cxx_api.h
      PATHS ${ONNXRUNTIME_ROOT_DIR}/include
      DOC "ONNX Runtime include directory")

    if(ONNXRUNTIME_LIBRARY AND ONNXRUNTIME_INCLUDE_DIR)
      set(ONNXRUNTIME_FOUND TRUE)
      set(ONNXRUNTIME_LIBRARIES ${ONNXRUNTIME_LIBRARY})
      set(ONNXRUNTIME_INCLUDE_DIRS ${ONNXRUNTIME_INCLUDE_DIR})
      message(STATUS "Found ONNX Runtime: ${ONNXRUNTIME_LIBRARY}")
    else()
      set(ONNXRUNTIME_FOUND FALSE)
    endif()
  endif()

  if(NOT ONNXRUNTIME_FOUND)
    message(STATUS "System ONNX Runtime not found. Falling back to downloaded version.")
    set(USE_SYSTEM_ONNXRUNTIME OFF)
  endif()
endif()

# Option 2: Download ONNX Runtime if not using system installed version
if(NOT USE_SYSTEM_ONNXRUNTIME)
  include(FetchContent)

  # Set ONNX Runtime version - make sure this is defined Only set if not already defined, to allow the parent project to
  # override it
  if(NOT DEFINED ONNXRUNTIME_VERSION)
    set(ONNXRUNTIME_VERSION
        "1.23.0"
        CACHE STRING "ONNX Runtime version to use")
  endif()

  # Check if version is not empty
  if("${ONNXRUNTIME_VERSION}" STREQUAL "")
    set(ONNXRUNTIME_VERSION "1.23.0")
    message(STATUS "ONNX Runtime version was empty, defaulting to 1.23.0")
  endif()

  # Debug output
  message(STATUS "ONNX Runtime version set to: ${ONNXRUNTIME_VERSION}")

  # Determine platform and architecture for download URL
  if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(ONNXRUNTIME_PLATFORM "linux")
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64")
      set(ONNXRUNTIME_ARCH "x64")
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64")
      set(ONNXRUNTIME_ARCH "aarch64")
    else()
      message(FATAL_ERROR "Unsupported architecture: ${CMAKE_SYSTEM_PROCESSOR}")
    endif()
  else()
    message(FATAL_ERROR "Unsupported platform: ${CMAKE_SYSTEM_NAME}")
  endif()

  # Set download URL with correct naming pattern for 1.22.0 Make sure all parts of the version are included
  message(STATUS "Using ONNX Runtime version: ${ONNXRUNTIME_VERSION}")
  set(ONNXRUNTIME_URL
      "https://github.com/microsoft/onnxruntime/releases/download/v${ONNXRUNTIME_VERSION}/onnxruntime-linux-${ONNXRUNTIME_ARCH}-${ONNXRUNTIME_VERSION}.tgz"
  )

  message(STATUS "Downloading ONNX Runtime from: ${ONNXRUNTIME_URL}")

  # Create a directory for the downloaded library
  set(ONNXRUNTIME_DOWNLOAD_DIR "${CMAKE_CURRENT_BINARY_DIR}/onnxruntime")

  # Download and extract ONNX Runtime - using file(DOWNLOAD) for more direct control
  if(NOT
     EXISTS
     "${ONNXRUNTIME_DOWNLOAD_DIR}/onnxruntime-linux-${ONNXRUNTIME_ARCH}-${ONNXRUNTIME_VERSION}/include/onnxruntime_cxx_api.h"
  )
    message(STATUS "Downloading ONNX Runtime...")
    file(MAKE_DIRECTORY ${ONNXRUNTIME_DOWNLOAD_DIR})

    # Download the tarball
    set(ONNXRUNTIME_TARBALL "${ONNXRUNTIME_DOWNLOAD_DIR}/onnxruntime.tgz")
    file(DOWNLOAD ${ONNXRUNTIME_URL} ${ONNXRUNTIME_TARBALL} SHOW_PROGRESS)

    # Extract the tarball
    message(STATUS "Extracting ONNX Runtime...")
    execute_process(COMMAND ${CMAKE_COMMAND} -E tar xzf ${ONNXRUNTIME_TARBALL}
                    WORKING_DIRECTORY ${ONNXRUNTIME_DOWNLOAD_DIR})

    # Clean up the tarball
    file(REMOVE ${ONNXRUNTIME_TARBALL})
  endif()

  # Set paths to the extracted files
  set(ONNXRUNTIME_EXTRACT_DIR
      "${ONNXRUNTIME_DOWNLOAD_DIR}/onnxruntime-linux-${ONNXRUNTIME_ARCH}-${ONNXRUNTIME_VERSION}")

  # Verify the directory exists
  if(NOT EXISTS ${ONNXRUNTIME_EXTRACT_DIR})
    message(FATAL_ERROR "ONNX Runtime extraction directory doesn't exist: ${ONNXRUNTIME_EXTRACT_DIR}")
  endif()

  # Set include and library directories
  set(ONNXRUNTIME_INCLUDE_DIRS "${ONNXRUNTIME_EXTRACT_DIR}/include")

  # Log directory contents to help with debugging
  message(STATUS "ONNX Runtime extract directory: ${ONNXRUNTIME_EXTRACT_DIR}")
  file(GLOB_RECURSE ONNXRUNTIME_FILES "${ONNXRUNTIME_EXTRACT_DIR}/*")
  foreach(FILE ${ONNXRUNTIME_FILES})
    message(STATUS "Found file: ${FILE}")
  endforeach()

  # Find the library files
  if(EXISTS "${ONNXRUNTIME_EXTRACT_DIR}/lib/libonnxruntime.so")
    set(ONNXRUNTIME_LIBRARY "${ONNXRUNTIME_EXTRACT_DIR}/lib/libonnxruntime.so")
  else()
    # Try to find the library in case the structure changed
    file(GLOB_RECURSE ONNXRUNTIME_LIB_CANDIDATES
         "${ONNXRUNTIME_EXTRACT_DIR}/*onnxruntime*${CMAKE_SHARED_LIBRARY_SUFFIX}")

    if(ONNXRUNTIME_LIB_CANDIDATES)
      list(GET ONNXRUNTIME_LIB_CANDIDATES 0 ONNXRUNTIME_LIBRARY)
      message(STATUS "Found ONNX Runtime library: ${ONNXRUNTIME_LIBRARY}")
    else()
      message(FATAL_ERROR "Could not find ONNX Runtime library in extracted files")
    endif()
  endif()

  set(ONNXRUNTIME_LIBRARIES ${ONNXRUNTIME_LIBRARY})

  # Add to bundled libraries
  set(flutter_onnxruntime_bundled_libraries ${ONNXRUNTIME_LIBRARY})
endif()

# Any new source files that you add to the plugin should be added here.
list(APPEND PLUGIN_SOURCES "src/flutter_onnxruntime_plugin.cc" "src/session_manager.cc" "src/value_conversion.cc"
     "src/tensor_manager.cc")

# Define the plugin library target. Its name must not be changed (see comment on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED ${PLUGIN_SOURCES})

# Apply a standard set of build settings that are configured in the application-level CMakeLists.txt. This can be
# removed for plugins that want full control over build settings.
apply_standard_settings(${PLUGIN_NAME})

# Symbols are hidden by default to reduce the chance of accidental conflicts between plugins. This should not be
# removed; any symbols that should be exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Enable C++17 features (required for ONNX Runtime 1.22.0+)
target_compile_features(${PLUGIN_NAME} PRIVATE cxx_std_17)

# Source include directories and library dependencies. Add any plugin-specific dependencies here.
target_include_directories(
  ${PLUGIN_NAME} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/include" "${CMAKE_CURRENT_SOURCE_DIR}" "${FLUTTER_EPHEMERAL_DIR}"
                         "${FLUTTER_EPHEMERAL_DIR}/cpp_client_wrapper/include" "${ONNXRUNTIME_INCLUDE_DIRS}")

# Install debugging message
message(STATUS "Include directories: ${CMAKE_CURRENT_SOURCE_DIR}/include")
message(STATUS "Binary directory: ${CMAKE_CURRENT_BINARY_DIR}/include")
message(STATUS "This file: ${CMAKE_CURRENT_LIST_FILE}")

# Install public headers for the plugin
install(FILES "include/flutter_onnxruntime/flutter_onnxruntime_plugin.h"
        DESTINATION "${CMAKE_BINARY_DIR}/include/flutter_onnxruntime")

# Install utility header files with the proper path
install(FILES DESTINATION "${CMAKE_BINARY_DIR}/include")

# Also create symlinks in the build directory to ensure includes work during build
file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/include/flutter_onnxruntime")

# Copy headers with error handling
file(
  COPY "${CMAKE_CURRENT_SOURCE_DIR}/include/flutter_onnxruntime/flutter_onnxruntime_plugin.h"
  DESTINATION "${CMAKE_BINARY_DIR}/include/flutter_onnxruntime/"
  FOLLOW_SYMLINK_CHAIN)

file(
  COPY "${CMAKE_CURRENT_SOURCE_DIR}/include/flutter_onnxruntime/export.h"
  DESTINATION "${CMAKE_BINARY_DIR}/include/flutter_onnxruntime/"
  FOLLOW_SYMLINK_CHAIN)

# Add include directories for the plugin
target_include_directories(${PLUGIN_NAME} PUBLIC $<BUILD_INTERFACE:${CMAKE_BINARY_DIR}/include>
                                                 $<INSTALL_INTERFACE:include>)

# Add ONNX Runtime include directories
target_include_directories(${PLUGIN_NAME} PRIVATE ${ONNXRUNTIME_INCLUDE_DIRS})

target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)

# Link against ONNX Runtime
target_link_libraries(${PLUGIN_NAME} PRIVATE ${ONNXRUNTIME_LIBRARIES})

# Add a post-build command to copy ONNX Runtime libraries to the build directory
if(NOT USE_SYSTEM_ONNXRUNTIME AND ONNXRUNTIME_LIBRARY)
  add_custom_command(
    TARGET ${PLUGIN_NAME}
    POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different ${ONNXRUNTIME_LIBRARY} $<TARGET_FILE_DIR:${PLUGIN_NAME}>
    COMMENT "Copying ONNX Runtime library to build directory")
endif()

# List of absolute paths to libraries that should be bundled with the plugin. This list could contain prebuilt
# libraries, or libraries created by an external build triggered from this build file.
if(NOT USE_SYSTEM_ONNXRUNTIME AND ONNXRUNTIME_LIBRARY)
  # When using the downloaded version, we need to bundle the library
  set(bundled_libs ${ONNXRUNTIME_LIBRARY})
else()
  # When using system library, don't bundle it
  set(bundled_libs "")
endif()

set(flutter_onnxruntime_bundled_libraries
    ${bundled_libs}
    PARENT_SCOPE)

# === Tests ===
# These unit tests can be run from a terminal after building the example.

# Only enable test builds when building the example (which sets this variable) so that plugin clients aren't building
# the tests.
if(${include_${PROJECT_NAME}_tests})
  if(${CMAKE_VERSION} VERSION_LESS "3.11.0")
    message("Unit tests require CMake 3.11.0 or later")
  else()
    set(TEST_RUNNER "${PROJECT_NAME}_test")
    enable_testing()

    # Add the Google Test dependency.
    include(FetchContent)
    FetchContent_Declare(googletest URL https://github.com/google/googletest/archive/v1.17.0.zip
                                        DOWNLOAD_EXTRACT_TIMESTAMP TRUE)
    # Prevent overriding the parent project's compiler/linker settings
    set(gtest_force_shared_crt
        ON
        CACHE BOOL "" FORCE)
    # Disable install commands for gtest so it doesn't end up in the bundle.
    set(INSTALL_GTEST
        OFF
        CACHE BOOL "Disable installation of googletest" FORCE)

    FetchContent_MakeAvailable(googletest)

    # The plugin's exported API is not very useful for unit testing, so build the sources directly into the test binary
    # rather than using the shared library.
    add_executable(${TEST_RUNNER} test/flutter_onnxruntime_plugin_test.cc ${PLUGIN_SOURCES})
    apply_standard_settings(${TEST_RUNNER})
    target_include_directories(${TEST_RUNNER} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
    target_include_directories(${TEST_RUNNER} PRIVATE ${ONNXRUNTIME_INCLUDE_DIRS})
    target_link_libraries(${TEST_RUNNER} PRIVATE flutter)
    target_link_libraries(${TEST_RUNNER} PRIVATE PkgConfig::GTK)
    target_link_libraries(${TEST_RUNNER} PRIVATE ${ONNXRUNTIME_LIBRARIES})
    target_link_libraries(${TEST_RUNNER} PRIVATE gtest_main gmock)

    # Enable automatic test discovery.
    include(GoogleTest)
    gtest_discover_tests(${TEST_RUNNER})

  endif() # CMake version check
endif() # include_${PROJECT_NAME}_tests
