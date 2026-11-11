cmake_minimum_required(VERSION 3.19)
project(hypr-floating VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

option(HYPR_FLOATING_PLUGIN "Build the Hyprland plugin (needs Hyprland's headers)" ON)

# The rules, with no Hyprland in them: built and tested on their own.
add_library(hypr-floating-core STATIC src/stacking.cpp src/floating.cpp)
target_include_directories(hypr-floating-core PUBLIC src)
target_compile_options(hypr-floating-core PRIVATE -Wall -Wextra)

include(CTest)
if(BUILD_TESTING)
  add_executable(stacking-test test/unit/stacking_test.cpp)
  target_link_libraries(stacking-test PRIVATE hypr-floating-core)
  add_test(NAME stacking COMMAND stacking-test)
  add_executable(floating-test test/unit/floating_test.cpp)
  target_link_libraries(floating-test PRIVATE hypr-floating-core)
  add_test(NAME floating COMMAND floating-test)
endif()

if(HYPR_FLOATING_PLUGIN)
  add_compile_definitions(WLR_USE_UNSTABLE)

  find_package(PkgConfig REQUIRED)
  pkg_check_modules(deps REQUIRED IMPORTED_TARGET hyprland cairo libdrm libinput libudev pixman-1 wayland-server xkbcommon)

  # Built as hypr-floating.so (no lib prefix). 
  add_library(hypr-floating SHARED src/main.cpp src/config.cpp src/stackingFix.cpp src/layout/modeSync.cpp src/layout/ownFloat.cpp src/layout/floatingAlgo.cpp src/layout/floatingLayout.cpp)
  set_target_properties(hypr-floating PROPERTIES PREFIX "" POSITION_INDEPENDENT_CODE ON)
  # -fno-gnu-unique: otherwise glibc marks the .so NODELETE, and a plugin unload
  # followed by a load of the same path returns the old image.
  target_compile_options(hypr-floating PRIVATE -Wall -Wextra -Wno-unused-parameter -fno-gnu-unique)
  target_link_libraries(hypr-floating PRIVATE hypr-floating-core PkgConfig::deps)

  install(TARGETS hypr-floating LIBRARY DESTINATION lib/hypr-floating)
  install(FILES lua/omarchy.lua DESTINATION lib/hypr-floating)
endif()
