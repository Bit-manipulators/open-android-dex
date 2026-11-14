cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "stream_texture_windows.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app flutter_wrapper_plugin)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Windows FFmpeg SDK Integration for hardware/multithreaded video stream decoding
set(FFMPEG_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../ffmpeg" CACHE PATH "Path to FFmpeg SDK")
if(NOT EXISTS "${FFMPEG_DIR}/include/libavcodec/avcodec.h")
  if(EXISTS "${CMAKE_SOURCE_DIR}/ffmpeg/include/libavcodec/avcodec.h")
    set(FFMPEG_DIR "${CMAKE_SOURCE_DIR}/ffmpeg")
  elseif(EXISTS "${CMAKE_SOURCE_DIR}/../build/ffmpeg_windows/include/libavcodec/avcodec.h")
    set(FFMPEG_DIR "${CMAKE_SOURCE_DIR}/../build/ffmpeg_windows")
  elseif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../../build/ffmpeg_windows/include/libavcodec/avcodec.h")
    set(FFMPEG_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../build/ffmpeg_windows")
  endif()
endif()

if(EXISTS "${FFMPEG_DIR}/include/libavcodec/avcodec.h")
  message(STATUS "Found Windows FFmpeg SDK at: ${FFMPEG_DIR}")
  target_compile_definitions(${BINARY_NAME} PRIVATE "HAVE_FFMPEG")
  target_include_directories(${BINARY_NAME} PRIVATE "${FFMPEG_DIR}/include")
  target_link_directories(${BINARY_NAME} PRIVATE "${FFMPEG_DIR}/lib")
  target_link_libraries(${BINARY_NAME} PRIVATE avcodec avformat avutil swscale)
else()
  message(STATUS "Notice: FFmpeg SDK not detected at ${FFMPEG_DIR}; building in fallback mode.")
endif()

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)
