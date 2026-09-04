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

template<Mode CRYPTOMODE>
class AesGcmStreamSession {
public:
	static constexpr size_t KEY_BYTES   = crypto_aead_aes256gcm_KEYBYTES;   // 32 bytes
    static constexpr size_t NONCE_BYTES = crypto_aead_aes256gcm_NPUBBYTES;  // 12 bytes
    static constexpr size_t TAG_BYTES   = crypto_aead_aes256gcm_ABYTES; // 16 bytes
    static constexpr size_t BUFFER_SIZE = (128 * 1024); // 128 KB + 16 byte tag

    AesGcmStreamSession(const span<unsigned char> sessionKey, const span<unsigned char> baseNonce) {
        memcpy(this->m_sessionKey.data(), sessionKey.data(), KEY_BYTES);
        memcpy(this->m_baseNonce.data(), baseNonce.data(), NONCE_BYTES);
        this->m_mode = CRYPTOMODE;
        this->m_stagerBuffer.reserve(BUFFER_SIZE + (64 * 1024));
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

    template<Mode mode = CRYPTOMODE>
        requires (mode == Mode::Encryption)
    expected<void, error_code> encrypt(span<unsigned char> plainText, span<unsigned char> output) { // plainText will be pushed into stager buffer before being encrypted
       
        unsigned long long ciphertextLen = 0;

        auto currentNonce = computeChunkNonce();

        this->m_stagerBuffer.insert(m_stagerBuffer.end(), plainText.data(), plainText.data() + plainText.size());

        size_t available = m_stagerBuffer.size() - m_stagerOffset;

        if (available < BUFFER_SIZE) {
            return unexpected(SeError::CRYPTOStageTooSmall); // Not an error it will signal to not process the output
        }

        if (output.size() < BUFFER_SIZE + TAG_BYTES) {
            return unexpected(SeError::SmallBuffer);
        }

        int res = crypto_aead_aes256gcm_encrypt(
            output.data(),
            &ciphertextLen,
            m_stagerBuffer.data() + m_stagerOffset,
            BUFFER_SIZE,
            nullptr, 0,             // No AAD
            nullptr,                // nsec
            currentNonce.data(),
            m_sessionKey.data()
        );

        if (res != 0) {
            return unexpected(SeError::CRYPTOGenericFailure);
        }

        this->m_stagerOffset += BUFFER_SIZE;

        m_chunkCtr++;

        if (m_stagerOffset == m_stagerBuffer.size()) {
            m_stagerBuffer.clear();
            m_stagerOffset = 0;
        }
        else if (m_stagerOffset >= 4096) { // Compact when dead-space gets large
            m_stagerBuffer.erase(m_stagerBuffer.begin(), m_stagerBuffer.begin() + m_stagerOffset);
            m_stagerOffset = 0;
        }

        return {};
    }

    template<Mode mode = CRYPTOMODE>
        requires (mode == Mode::Encryption)
    expected<size_t, error_code> finalizeEncryption(span<unsigned char> output) {
        
        size_t available = m_stagerBuffer.size() - m_stagerOffset;
        if (available == 0)
            return 0;
        else {
            unsigned long long ciphertextLen = 0;
            auto currentNonce = computeChunkNonce();

            if (output.size() < available + TAG_BYTES) {
                return unexpected(SeError::SmallBuffer);
            }

            int res = crypto_aead_aes256gcm_encrypt(
                output.data(),
                &ciphertextLen,
                m_stagerBuffer.data() + m_stagerOffset,
                available,
                nullptr, 0,             // No AAD
                nullptr,                // nsec
                currentNonce.data(),
                m_sessionKey.data()
            );

            if (res != 0) {
                return unexpected(SeError::CRYPTOGenericFailure);
            }

            m_stagerOffset = 0;
            m_stagerBuffer.clear();
            m_chunkCtr++;

            return ciphertextLen;
        }
    }

    template<Mode mode = CRYPTOMODE>
        requires (mode == Mode::Decryption)
    expected<void, error_code> decrypt(span<unsigned char> cipherText, span<unsigned char> output){

        m_stagerBuffer.insert(m_stagerBuffer.begin(), cipherText.data(), cipherText.data() + cipherText.size());
        
        size_t available = m_stagerBuffer.size() - m_stagerOffset;

        if (available < BUFFER_SIZE) {
            return unexpected(SeError::CRYPTOStageTooSmall);
        }


        if (output.size() < BUFFER_SIZE)
            return unexpected(SeError::SmallBuffer);

        unsigned long long plaintextLen = 0;

        auto currentNonce = computeChunkNonce();

        int res = crypto_aead_aes256gcm_decrypt(
            output.data(),
            &plaintextLen,
            nullptr,                // nsec
            m_stagerBuffer.data() + m_stagerOffset,
            BUFFER_SIZE,
            nullptr, 0,             // No AAD
            currentNonce.data(),
            m_sessionKey.data()
        );

        if (res != 0) {
            return unexpected(SeError::CRYPTOGenericFailure);
        }

        m_stagerOffset += BUFFER_SIZE;
        m_chunkCtr++;

        if (m_stagerBuffer.size() == m_stagerOffset) {
            this->m_stagerBuffer.clear();
            this->m_stagerOffset = 0;
        }
        else if (m_stagerOffset >= 4096) {
            m_stagerBuffer.erase(m_stagerBuffer.begin(), m_stagerBuffer.begin() + m_stagerOffset);
            m_stagerOffset = 0;
        }

        return {};
    }

    template<Mode mode = CRYPTOMODE>
        requires (CRYPTOMODE == Mode::Decryption)
    expected<size_t, error_code> finalizeDecryption(span<unsigned char> output){
        size_t available = m_stagerBuffer.size() - m_stagerOffset;
        if (available == 0) {
            return 0;
        }
        else {
            if (output.size() < BUFFER_SIZE)
                return unexpected(SeError::CRYPTOGenericFailure);

            unsigned long long plaintextLen = 0;

            auto currentNonce = computeChunkNonce();

            int res = crypto_aead_aes256gcm_decrypt(
                output.data(),
                &plaintextLen,
                nullptr,                // nsec
                m_stagerBuffer.data() + m_stagerOffset,
                BUFFER_SIZE,
                nullptr, 0,             // No AAD
                currentNonce.data(),
                m_sessionKey.data()
            );

            if (res != 0) {
                return unexpected(SeError::CRYPTOGenericFailure);
            }

            m_stagerOffset += BUFFER_SIZE;
            m_chunkCtr++;

            return plaintextLen;
        }
    }

private:
    vector<unsigned char> m_sessionKey = vector<unsigned char>(KEY_BYTES);
    vector<unsigned char> m_baseNonce = vector<unsigned char>(KEY_BYTES);
    vector<unsigned char> m_stagerBuffer;

    size_t m_stagerOffset = 0;

    Mode m_mode;
    uint64_t m_chunkCtr = 0;

    vector<unsigned char> computeChunkNonce() const{

        vector<unsigned char> nonce = m_baseNonce;

        sodium_increment(nonce.data(), NONCE_BYTES);

        return nonce;
    }
};