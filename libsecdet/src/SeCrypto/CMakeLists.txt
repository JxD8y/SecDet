set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(SeCrypto 
            SeCryptoUtils.cpp
            AesGcmContextProvider.cpp)

find_package(unofficial-sodium CONFIG REQUIRED)

if(libsodium_FOUND)
    message(STATUS "Found libsodium at ${libsodium_DIR}")
endif()

target_link_libraries(SeCrypto PRIVATE unofficial-sodium::sodium)

target_include_directories(SeCrypto PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/../../include)
