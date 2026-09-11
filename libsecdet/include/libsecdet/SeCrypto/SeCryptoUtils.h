#pragma once

#include <sodium.h>
#include <string>
#include <string_view>
#include <system_error>
#include <expected>
#include <span>
#include <array>
#include <vector>
#include <bit>

#include "libsecdet/SeError.h"

using namespace std;


expected<void,error_code> sha256String(string data,span<unsigned char> out_hash);
expected<void,error_code> sha256Buffer(span<const unsigned char> in_data, span<unsigned char> out_hash);

bool secureBufferCompare(const span<unsigned char> op1,const span<unsigned char> op2);

uint64_t getSecureRandom();

void generateSalt(span<unsigned char> out_salt);

expected<void, error_code> deriveMasterKeyArgon2id(string_view password, span<const unsigned char> salt, span<unsigned char> out_key);

expected<uint16_t, error_code> calculatePVV(span<const unsigned char> masterKey);