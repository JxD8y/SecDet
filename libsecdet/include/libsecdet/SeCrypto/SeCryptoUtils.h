#pragma once

#include <sodium.h>
#include <string>
#include <system_error>
#include <expected>
#include <span>

#include "libsecdet/SeError.h"

using namespace std;


expected<void,error_code> sha256String(string data,span<unsigned char> out_hash);

bool secureBufferCompare(const span<unsigned char> op1,const span<unsigned char> op2);

uint64_t getSecureRandom();