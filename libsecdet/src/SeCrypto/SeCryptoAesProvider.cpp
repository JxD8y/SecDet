#include "libsecdet/SeCrypto/SeCryptoAesProvider.h"

// non-zero return is success
// chunk_len should be always allocated plainlen+ 16 for the mac!
optional<size_t> SeCryptoAesProvider::EncryptChunk(SEBYTE* encChunk, size_t encChunkLen, SEBYTE* plainChunk, size_t plainChunkLen , int chunkId ,bool isFinal){
    
    if(encChunkLen < plainChunkLen + TAG_BYTES)
        return nullopt;
    
    SEBYTE nonce[NONCE_BYTES] = {0}; 
    build_nonce(chunkId,isFinal,nonce);

    size_t output_bytes = 0;
    int ret = crypto_aead_aes256gcm_encrypt(encChunk,&output_bytes,plainChunk,
                                            plainChunkLen,nullptr,0,nullptr,nonce,this->m_key.data());
    
    if(ret < 0) //probable that crypto_aead_aes256gcm_is_available is 0 !
        return nullopt;
    
    return (size_t)output_bytes;
}

//here the encChunkLen is 16 more than the plainChunk len !
optional<size_t> SeCryptoAesProvider::DecryptChunk(SEBYTE* encChunk, size_t encChunkLen, SEBYTE* plainChunk, size_t plainChunkLen , int chunkId ,bool isFinal){

    if(encChunkLen < TAG_BYTES)
        return nullopt;
    
    SEBYTE nonce[NONCE_BYTES] = {0};
    build_nonce(chunkId,isFinal,nonce);

    size_t output_bytes = 0;

    int ret = crypto_aead_aes256gcm_decrypt(plainChunk,&output_bytes,nullptr,encChunk,encChunkLen,nullptr,0,nonce,this->m_key.data());
    if(ret < 0)
        return nullopt;

    return (size_t)output_bytes;
}

