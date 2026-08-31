cmake_minimum_required(VERSION 3.10)

project("libsecdet")

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_subdirectory(src)

find_package(zstd CONFIG REQUIRED)

add_library(libsecdet STATIC src/LibSecDet.cpp)

target_compile_features(libsecdet PUBLIC cxx_std_23)

target_link_libraries(libsecdet PUBLIC 
                        SeCrypto
                        zstd::libzstd)
                        
target_include_directories(libsecdet PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)

target_sources(libsecdet PUBLIC 
                "src/SeArchive.cpp"
                "src/SeMetadata.cpp"
                "src/SeTOC.cpp")