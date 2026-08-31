add_executable(SeCrypto_app secrypto_app.cpp)

target_link_libraries(SeCrypto_app PRIVATE unofficial-sodium::sodium)