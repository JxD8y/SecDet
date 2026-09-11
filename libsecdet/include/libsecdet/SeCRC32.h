#pragma once
/*
    Hardware accelarated CRC32 impl that uses Castagnoli polynomial 0x82F63B78
*/

#include <iostream>
#include <cstdint>
#include <cstring>
#include <immintrin.h> // SSE4.2 header for msvc


// Default initial state
inline constexpr uint32_t CRC32C_INIT = 0xFFFFFFFF;


// 1. Process a single chunk into the running CRC accumulator
inline uint32_t crc32c_update(uint32_t current_crc, const void* data, size_t length) {
    const auto* p = static_cast<const uint8_t*>(data);
    uint64_t crc = current_crc; // Keep the running state directly

    // Align pointer to 8-byte boundary
    while (length && (reinterpret_cast<uintptr_t>(p) & 7)) {
        crc = _mm_crc32_u8(static_cast<uint32_t>(crc), *p++);
        --length;
    }

    // Process 8 bytes per iteration
    while (length >= 8) {
        crc = _mm_crc32_u64(crc, *reinterpret_cast<const uint64_t*>(p));
        p += 8;
        length -= 8;
    }

    // Process remaining 4-byte chunk
    if (length >= 4) {
        crc = _mm_crc32_u32(static_cast<uint32_t>(crc), *reinterpret_cast<const uint32_t*>(p));
        p += 4;
        length -= 4;
    }

    // Process remaining trailing bytes
    while (length > 0) {
        crc = _mm_crc32_u8(static_cast<uint32_t>(crc), *p++);
        --length;
    }

    return static_cast<uint32_t>(crc);
}

// 2. Finalize when the entire stream is completed
inline uint32_t crc32c_finalize(uint32_t crc) {
    return crc ^ 0xFFFFFFFF;
}