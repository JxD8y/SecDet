#include "libsecdet/SeCrypto/AesGcmContextProvider.h"
#include "libsecdet/SeCrypto/AesGcmStreamSession.h"


inline expected<std::unique_ptr<AesGcmStreamContext>, error_code> AesGcmContextProvider::createSession(
	uint64_t fileSubkeyId,
	const char kdfContext[KDF_CONTEXT_BYTES] = "file_enc"
){
	std::vector<unsigned char> subkey{ KEY_BYTES };

	// Securely derive a 256-bit key from the master key
	if (crypto_kdf_derive_from_key(
		subkey.data(),
		KEY_BYTES,
		fileSubkeyId,
		kdfContext,
		this->m_masterKey.data()) != 0) {

		return unexpected(SeError::CRYPTOKDFFail);
	}

	vector<unsigned char> baseNonce{ crypto_aead_aes256gcm_NPUBBYTES };
	randombytes_buf(baseNonce.data(), baseNonce.size());

	auto session = std::make_unique<AesGcmStreamContext>(
		subkey,
		baseNonce,
		Mode::Encryption
	);

	sodium_memzero(subkey.data(), KEY_BYTES);
	return session;
}