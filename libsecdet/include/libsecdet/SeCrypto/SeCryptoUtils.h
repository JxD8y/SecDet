#pragma once

#include <sodium.h>
#include <expected>
#include <span>

using namespace std;


expected<void,error_code> sha256String(string data,span<unsigned char> out_hash);

bool secureBufferCompare(const span<unsigned char> op1,const span<unsigned char> op2);