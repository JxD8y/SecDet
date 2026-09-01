#include "libsecdet/SeCrypto/AesGcmStreamSession.h"



expected<void, error_code> AesGcmStreamSession::encryptChunk(span<unsigned char> plainText, span<unsigned char> output) {
    if (m_mode != Mode::Encryption) {
        return unexpected(SeError::CRYPTOInvalidSessionMode);
    }
    if (output.size() < plainText.size() + TAG_BYTES) {
        return unexpected(SeError::CRYPTOGenericFailure);
    }

    unsigned long long ciphertextLen = 0;

    auto currentNonce = computeChunkNonce();

    int res = crypto_aead_aes256gcm_encrypt(
        output.data(),
        &ciphertextLen,
        plainText.data(),
        plainText.size(),
        nullptr, 0,             // No AAD
        nullptr,                // nsec
        currentNonce.data(),
        m_sessionKey.data()
    );

    if (res != 0) {
        return unexpected(SeError::CRYPTOGenericFailure);
    }

    m_chunkCtr++;
    return {};
}

expected<void, error_code> AesGcmStreamSession::decryptChunk(span<unsigned char> cipherText, span<unsigned char> output) {
    if (m_mode != Mode::Decryption) {
        return unexpected(SeError::CRYPTOInvalidSessionMode);
    }
    if (cipherText.size() < TAG_BYTES) {
        return unexpected(SeError::CRYPTOGenericFailure);
    }
    if (output.size() < cipherText.size() - TAG_BYTES)
        return unexpected(SeError::CRYPTOGenericFailure);


    unsigned long long plaintextLen = 0;

    auto currentNonce = computeChunkNonce();

    int res = crypto_aead_aes256gcm_decrypt(
        output.data(),
        &plaintextLen,
        nullptr,                // nsec
        cipherText.data(),
        cipherText.size(),
        nullptr, 0,             // No AAD
        currentNonce.data(),
        m_sessionKey.data()
    );

    if (res != 0) {
        return unexpected(SeError::CRYPTOGenericFailure);
    }

    m_chunkCtr++;
    return {};
}