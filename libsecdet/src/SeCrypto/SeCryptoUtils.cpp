#include "libsecdet/SeCrypto/SeCryptoUtils.h"


expected<void,error_code> sha256String(string data,span<unsigned char,crypto_hash_sha256_BYTES> out_hash){
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