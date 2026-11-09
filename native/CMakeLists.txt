# Motor de áudio nativo (C++17). Compilado pelo Gradle via externalNativeBuild no
# Android e também no desktop para os testes (native/test).
cmake_minimum_required(VERSION 3.18)
project(pedal_engine CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(ENGINE_SOURCES
    src/api.cpp
    src/engine.cpp
    src/pedals.cpp
    src/amps.cpp
    src/convolver.cpp
    src/catalog.cpp)

if(ANDROID)
    list(APPEND ENGINE_SOURCES src/audio_android.cpp)
else()
    list(APPEND ENGINE_SOURCES src/audio_stub.cpp)
endif()

add_library(pedal_engine SHARED ${ENGINE_SOURCES})
target_include_directories(pedal_engine PRIVATE src)
target_compile_options(pedal_engine PRIVATE -O3 -fno-math-errno -Wall -Wextra -Wno-unused-parameter)
set_target_properties(pedal_engine PROPERTIES CXX_VISIBILITY_PRESET hidden)

if(ANDROID)
    target_link_libraries(pedal_engine PRIVATE aaudio log)
    # Exigência do Google Play: suporte a páginas de memória de 16 KB (Android 15+).
    target_link_options(pedal_engine PRIVATE "-Wl,-z,max-page-size=16384")
endif()

option(PEDAL_BUILD_TESTS "Compila os testes de desktop" OFF)
if(PEDAL_BUILD_TESTS AND NOT ANDROID)
    add_executable(engine_tests test/engine_tests.cpp ${ENGINE_SOURCES})
    target_include_directories(engine_tests PRIVATE src)
    target_compile_options(engine_tests PRIVATE -O2 -fno-math-errno)
    find_package(Threads REQUIRED)
    target_link_libraries(engine_tests PRIVATE Threads::Threads)
endif()
