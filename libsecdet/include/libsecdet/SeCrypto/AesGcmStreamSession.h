#pragma once

#include <expected>
#include <vector>
#include <span>
#include <system_error>
#include <sodium.h>

#include "libsecdet/SeError.h"

using namespace std;

class AesGcmStreamSession {
public:
	static constexpr size_t KEY_BYTES   = crypto_aead_aes256gcm_KEYBYTES;   // 32 bytes
    static constexpr size_t NONCE_BYTES = crypto_aead_aes256gcm_NPUBBYTES;  // 12 bytes
    static constexpr size_t TAG_BYTES   = crypto_aead_aes256gcm_ABYTES; // 16 bytes

    enum class Mode {
        Encryption,
        Decryption
    };

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

    std::vector<uint8_t> encryptChunk(span<unsigned char> plainText,span<unsigned char> output) {
        if (m_mode != Mode::Encrypt) {
            return unexpected(SeError::CRYPTOInvalidSessionMode);
        }
        if (output.size() < plainText + TAG_BYTES) {
            return unexpected(SeError::CRYPTOGenericFailure);
        }

        unsigned long long ciphertextLen = 0;

        auto currentNonce = computeChunkNonce();

        int res = crypto_aead_aes256gcm_encrypt(
            ciphertext.data(),
            &ciphertextLen,
            plaintext.data(),
            plainText.size(),
            nullptr, 0,             // No AAD
            nullptr,                // nsec
            currentNonce.data(),
            m_sessionKey.data()
        );

        if (res != 0) {
            return unexpected(SeError::CRYPTOGenericFailure);
        }

        chunkCounter_++;
        return {};
    }

    expected<void,error_code> decryptChunk(span<unsigned char> cipherText, span<unsigned char> output) {
        if (m_mode != Mode::Decrypt) {
            return unexpected(SeError::CRYPTOInvalidSessionMode);
        }
        if (cipherText.size() < TAG_BYTES) {
            return unexpected(SeError::CRYPTOGenericFailure);
        }
        if(output.size() < cipherText.size() - TAG_BYTES)
            return unexpected(SeError::CRYPTOGenericFailure);


        unsigned long long plaintextLen = 0;

        auto currentNonce = computeChunkNonce();

        int res = crypto_aead_aes256gcm_decrypt(
            output.data(),
            &plaintextLen,
            nullptr,                // nsec
            ciphertext.data(),
            cipherText.size(),
            nullptr, 0,             // No AAD
            currentNonce.data(),
            m_sessionKey.data()
        );

        if (res != 0) {
            return unexpected(SeError::CRYPTOGenericFailure);
        }

        chunkCounter_++;
        return {};
    }

private:
    vector<unsigned char> m_sessionKey{ KEY_BYTES };
    vector<unsigned char> m_baseNonce{ KEY_BYTES };
    Mode m_mode;
    uint64_t m_chunkCtr = 0;

    vector<unsigned char> computeChunkNonce() const{
        vector<unsigned char> nonce{ NONCE_BYTES } = m_baseNonce;

        for (uint64_t i = 0; i < m_chunkCtr; ++i) {
            sodium_increment(nonce.data(), NONCE_BYTES);
        }

        return nonce;
    }
};