cmake_minimum_required(VERSION 3.20)
project(ShaderLibraryValidation NONE)

# Use per-input CMake 4.5 custom rules when explicitly opted in.
# Do not require experimental CMake for downstream consumers of the headers.
option(SHADERLIB_USE_CUSTOM_RULES "Use CMake 4.5 rules for fragment validation" OFF)

find_package(Python3 REQUIRED COMPONENTS Interpreter)
find_program(GLSLANG_VALIDATOR glslangValidator REQUIRED)

set(SHADERLIB_SOURCES
  AnimatedCircularGradient.h CheckerBoard.h HypnosisSpiral.h
  LoopingGradient.h NoiseAnimation.h ScanLines.h hearbeat.h
)

# DynamicColourGradient.h is empty; its existing Metal implementation is
# separate. Keep it excluded until a standalone GLSL source is provided.
set(_wrapper "${CMAKE_CURRENT_SOURCE_DIR}/tools/wrap_fragment.py")
set(_output "<CURRENT_BINARY_DIR>/validated/<BASE_NAME>.frag")

if(SHADERLIB_USE_CUSTOM_RULES)
  if(CMAKE_VERSION VERSION_LESS 4.5)
    message(FATAL_ERROR "SHADERLIB_USE_CUSTOM_RULES requires CMake 4.5 or later")
  endif()
  add_custom_rule(shaderlib_glsl
    OUTPUT "${_output}"
    COMMAND "${Python3_EXECUTABLE}" "${_wrapper}" "<SOURCE>" "${_output}"
    COMMAND "${GLSLANG_VALIDATOR}" -S frag "${_output}"
    DEPENDS "${_wrapper}"
  )
  add_custom_target(shaderlib_fragment_validation ALL)
  target_sources(shaderlib_fragment_validation PRIVATE
    FILE_SET shaderlib_original_sources TYPE shaderlib_glsl
    BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}"
    FILES ${SHADERLIB_SOURCES})
else()
  set(_generated)
  foreach(_source IN LISTS SHADERLIB_SOURCES)
    get_filename_component(_base "${_source}" NAME_WE)
    set(_target "${CMAKE_CURRENT_BINARY_DIR}/validated/${_base}.frag")
    add_custom_command(
      OUTPUT "${_target}"
      COMMAND "${Python3_EXECUTABLE}" "${_wrapper}"
        "${CMAKE_CURRENT_SOURCE_DIR}/${_source}" "${_target}"
      COMMAND "${GLSLANG_VALIDATOR}" -S frag "${_target}"
      DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/${_source}" "${_wrapper}"
      VERBATIM)
    list(APPEND _generated "${_target}")
  endforeach()
  add_custom_target(shaderlib_fragment_validation ALL DEPENDS ${_generated})
endif()

enable_testing()
add_test(NAME validate_generated_fragment_sources
  COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/tools/verify_wrappers.py"
    "${CMAKE_CURRENT_SOURCE_DIR}" "${CMAKE_CURRENT_BINARY_DIR}/validated")
