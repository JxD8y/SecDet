#include "libsecdet/SeCrypto/SeCryptoUtils.h"


expected<void,error_code> sha256String(string data,span<unsigned char> out_hash){
    if(data == "")
        return unexpected(SeError::CRYPTOStringWasEmpty);
    if(out_hash.size() == 0 || out_hash.data() == nullptr)
        return unexpected(SeError::CRYPTOBufferWasEmpty);

    if(sodium_init() < 0)
        return unexpected(SeError::CRYPTOCannotInitSodium);
    
    size_t hash = crypto_hash_sha256(out_hash.data(),reinterpret_cast<unsigned char*>(data.data()),data.size());
    if(hash != 0)
        return unexpected(SeError::CRYPTOGenericFailure);
    
    return {};
}

expected<void,error_code> sha256Buffer(span<const unsigned char> in_data, span<unsigned char> out_hash){
    if(in_data.empty() || in_data.data() == nullptr)
        return unexpected(SeError::CRYPTOBufferWasEmpty);
    if(out_hash.empty() || out_hash.data() == nullptr)
        return unexpected(SeError::CRYPTOBufferWasEmpty);

    if(sodium_init() < 0)
        return unexpected(SeError::CRYPTOCannotInitSodium);
    
    size_t hash = crypto_hash_sha256(out_hash.data(), in_data.data(), in_data.size());
    if(hash != 0)
        return unexpected(SeError::CRYPTOGenericFailure);
    
    return {};
}


bool secureBufferCompare(span<unsigned char> op1,span<unsigned char> op2){
    if(op1.size() != op2.size())
        return false;

    return sodium_memcmp(op1.data(),op2.data(),op1.size()) == 0;
}

uint64_t getSecureRandom() {
    sodium_init(); // dont want the extra expected here because this function rarely fails.

    uint64_t data;

    randombytes_buf(&data, sizeof(uint64_t));

    return data;
}

void generateSalt(span<unsigned char> out_salt) {
    sodium_init();
    randombytes_buf(out_salt.data(), out_salt.size());
}

expected<void, error_code> deriveMasterKeyArgon2id(string_view password, span<const unsigned char> salt, span<unsigned char> out_key) {
    if (password.empty())
        return unexpected(SeError::CRYPTOStringWasEmpty);
    if (out_key.size() < crypto_aead_aes256gcm_KEYBYTES)
        return unexpected(SeError::SmallBuffer);
    if (salt.size() < crypto_pwhash_SALTBYTES)
        return unexpected(SeError::SmallBuffer);

    if (sodium_init() < 0)
        return unexpected(SeError::CRYPTOCannotInitSodium);

    if (crypto_pwhash(out_key.data(), out_key.size(),
                      password.data(), password.size(),
                      salt.data(),
                      crypto_pwhash_OPSLIMIT_INTERACTIVE,
                      crypto_pwhash_MEMLIMIT_INTERACTIVE,
                      crypto_pwhash_ALG_DEFAULT) != 0) {
        return unexpected(SeError::CRYPTOKDFFail);
    }

    return {};
}

expected<uint16_t, error_code> calculatePVV(span<const unsigned char> masterKey) {
    if (masterKey.empty())
        return unexpected(SeError::CRYPTOBufferWasEmpty);

    array<unsigned char, crypto_hash_sha256_BYTES> pvvHash;
    auto exp = sha256Buffer(masterKey, pvvHash);
    if (!exp)
        return unexpected(exp.error());

    array<unsigned char, 2> pvv_bytes = { pvvHash[0], pvvHash[1] };
    uint16_t pvv = bit_cast<uint16_t>(pvv_bytes);
    sodium_memzero(pvvHash.data(), pvvHash.size());
    return pvv;
}