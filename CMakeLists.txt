cmake_minimum_required(VERSION 3.10)

project("SecDet")

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_subdirectory(libsecdet)
add_subdirectory(SecDet)