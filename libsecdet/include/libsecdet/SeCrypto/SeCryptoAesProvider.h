#pragma once 
#include <sodium.h>
#include <vector>
#include <stdexcept>
#include <cstddef>
#include <optional>

using namespace std;

#define SEBYTE unsigned char


class SeCryptoAesProvider{
public:
    static constexpr size_t KEY_BYTES   = crypto_aead_aes256gcm_KEYBYTES;  // 32 B
    static constexpr size_t NONCE_BYTES = crypto_aead_aes256gcm_NPUBBYTES; // 12 B
    static constexpr size_t TAG_BYTES   = crypto_aead_aes256gcm_ABYTES;    // 16 B

    SeCryptoAesProvider() = delete;
    
    SeCryptoAesProvider(vector<SEBYTE> nounce , vector<SEBYTE> key): m_nounce(nounce) , m_key(key){
        if(sodium_init() < 0) {
            throw runtime_error("Cannot initiate the libsodium");
        }
        if(!crypto_aead_aes256gcm_is_available()){
            throw runtime_error("AES256-GCM is not supported");
        }
    }

    optional<size_t> EncryptChunk(SEBYTE* encChunk, size_t encChunkLen, SEBYTE* plainChunk, size_t plainChunkLen , int chunkId ,bool isFinal = false);
    optional<size_t> DecryptChunk(SEBYTE* encChunk, size_t encChunkLen, SEBYTE* plainChunk, size_t plainChunkLen , int chunkId ,bool isFinal = false);

private:
    vector<SEBYTE> m_nounce;
    vector<SEBYTE> m_key;
    
    // Layout: [0]: is_last flag (0xFF or 0x00) | [1..3]: 0x00 | [4..11]: 8-byte chunk index
    void build_nonce(uint64_t chunk_idx, bool is_last, uint8_t out_nonce[NONCE_BYTES]) {
        out_nonce[0] = is_last ? 0xFF : 0x00;
        out_nonce[1] = 0;
        out_nonce[2] = 0;
        out_nonce[3] = 0;

        for (int i = 7; i >= 0; --i) {
            out_nonce[4 + (7 - i)] = static_cast<uint8_t>((chunk_idx >> (i * 8)) & 0xFF);
        }
    }
};