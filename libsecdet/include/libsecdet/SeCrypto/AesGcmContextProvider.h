#pragma once

#include <expected>
#include <vector>
#include <span>
#include <system_error>
#include <sodium.h>

#include "libsecdet/SeError.h"

using namespace std;

class AesGcmStreamContext;

class AesGcmContextProvider {
public:
	static constexpr size_t KEY_BYTES = crypto_aead_aes256gcm_KEYBYTES;
	static constexpr size_t KDF_CONTEXT_BYTES = crypto_kdf_CONTEXTBYTES;

	static expected<AesGcmContextProvider, error_code> CreateContext() {
		if (sodium_init() < 0) {
			return unexpected(SeError::CRYPTOCannotInitSodium);
		}
		if (crypto_aead_aes256gcm_is_available() == 0) {
			return unexpected(SeError::CRYPTOCannotInitSodium);
		}
		return AesGcmContextProvider();
	}

	static GenerateSecureRandom(span<unsigned char> in, size_t count);
	
	// Non-copiable
	AesGcmContextProvider& operator=(const AesGcmContextProvider&) = delete;
	AesGcmContextProvider(const AesGcmContextProvider&) = delete;

	AesGcmContextProvider(const AesGcmContextProvider&& other) noexcept{
		memcpy(m_masterKey.data(), other.m_masterKey.data(), KEY_BYTES);
		sodium_memzero(other.m_masterKey.data(), KEY_BYTES);
	}

	AesGcmContextProvider& operator=(const AesGcmContextProvider&& other) noexcept {
		if (this != &other) {
			sodium_memzero(this->m_masterKey.data(), KEY_BYTES);
			memcpy(this->m_masterKey.data(), other.m_masterKey.data(), KEY_BYTES);
			sodium_memzero(other.m_masterKey.data(), KEY_BYTES);
		}
		return *this;
	}

	~AesGcmContextProvider() {
		sodium_memzero(this->m_masterKey.data(), KEY_BYTES);
	}
	
	inline expected<std::unique_ptr<AesGcmStreamContext>,error_code> createSession(
		uint64_t fileSubkeyId,
		const char kdfContext[KDF_CONTEXT_BYTES] = "file_enc"
	) const {
		std::vector<unsigned char> subkey{KEY_BYTES};

		// Securely derive a 256-bit key from the master key
		if (crypto_kdf_derive_from_key(
			subkey.data(),
			KEY_BYTES,
			fileSubkeyId,
			kdfContext,
			masterKey_.data()) != 0) {
			
			return unexpected(SeError::CRYPTOKDFFail);
		}

		vector<unsigned char> baseNonce{ crypto_aead_aes256gcm_NPUBBYTES };
		randombytes_buf(baseNonce.data(), baseNonce.size());

		auto session = std::make_unique<AesGcmStreamSession>(
			subkey,
			baseNonce,
			AesGcmStreamSession::Mode::Encrypt
		);

		sodium_memzero(subkey.data(), KEY_BYTES);
		return session;
	}

private:
	vector<unsigned char> m_masterKey{ KEY_BYTES };

	AesGcmContextProvider();
	vector<unsigned char> generateSessionKey(span<unsigned char> fileIdx);

};