#pragma once

#include <expected>
#include <vector>
#include <span>
#include <system_error>
#include <sodium.h>

#include "libsecdet/SeError.h"

using namespace std;


enum class Mode {
    Encryption,
    Decryption
};

class AesGcmStreamSession {
public:
	static constexpr size_t KEY_BYTES   = crypto_aead_aes256gcm_KEYBYTES;   // 32 bytes
    static constexpr size_t NONCE_BYTES = crypto_aead_aes256gcm_NPUBBYTES;  // 12 bytes
    static constexpr size_t TAG_BYTES   = crypto_aead_aes256gcm_ABYTES; // 16 bytes

    AesGcmStreamSession(const span<unsigned char> sessionKey, const span<unsigned char> baseNonce, Mode mode) {
        memcpy(this->m_sessionKey.data(), sessionKey.data(), KEY_BYTES);
        memcpy(this->m_baseNonce.data(), baseNonce.data(), NONCE_BYTES);
        this->m_mode = mode;
    }

    ~AesGcmStreamSession() {
        sodium_memzero(this->m_sessionKey.data(), KEY_BYTES);
    }

    AesGcmStreamSession(const AesGcmStreamSession&) = delete;
    AesGcmStreamSession& operator=(const AesGcmStreamSession&) = delete;
    AesGcmStreamSession(AesGcmStreamSession&&) noexcept = default;
    AesGcmStreamSession& operator=(AesGcmStreamSession&&) noexcept = default;

    const vector<unsigned char>& getBaseNonce() {
        return this->m_baseNonce;
    }

    expected<void, error_code> encryptChunk(span<unsigned char> plainText, span<unsigned char> output);

    expected<void, error_code> decryptChunk(span<unsigned char> cipherText, span<unsigned char> output);

private:
    vector<unsigned char> m_sessionKey{ KEY_BYTES };
    vector<unsigned char> m_baseNonce{ KEY_BYTES };
    Mode m_mode;
    uint64_t m_chunkCtr = 0;

    vector<unsigned char> computeChunkNonce() const{

        vector<unsigned char> nonce = m_baseNonce;

        for (uint64_t i = 0; i < m_chunkCtr; ++i) {
            sodium_increment(nonce.data(), NONCE_BYTES);
        }

        return nonce;
    }
};