#pragma once

#include <expected>
#include <vector>
#include <span>
#include <system_error>
#include <sodium.h>

#include "libsecdet/SeError.h"
#include "AesGcmStreamSession.h"

using namespace std;

class SeArchive;

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
	
	// Non-copiable
	AesGcmContextProvider& operator=(const AesGcmContextProvider&) = delete;
	AesGcmContextProvider(const AesGcmContextProvider&) = delete;

	AesGcmContextProvider(AesGcmContextProvider&& other) noexcept{
		memcpy(m_masterKey.data(), other.m_masterKey.data(), KEY_BYTES);
		this->m_keyRegister = other.m_keyRegister;
		other.m_keyRegister = false;
		sodium_memzero(other.m_masterKey.data(), KEY_BYTES);
	}

	AesGcmContextProvider& operator=(AesGcmContextProvider&& other) noexcept {
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
	
	template <Mode cryptoMode>
	expected<std::unique_ptr<AesGcmStreamSession<cryptoMode>>, error_code> createSession(
		uint64_t fileSubkeyId,
		const char kdfContext[KDF_CONTEXT_BYTES] = "file_enc"
	) {
		std::vector<unsigned char> subkey(KEY_BYTES);

		// Securely derive a 256-bit key from the master key
		if (crypto_kdf_derive_from_key(
			subkey.data(),
			KEY_BYTES,
			fileSubkeyId,
			kdfContext,
			this->m_masterKey.data()) != 0) {

			return unexpected(SeError::CRYPTOKDFFail);
		}

		// Securely and deterministically derive the 12-byte base nonce from the master key and fileSubkeyId
		vector<unsigned char> nonceDerivation(crypto_kdf_BYTES_MIN);
		if (crypto_kdf_derive_from_key(
			nonceDerivation.data(),
			crypto_kdf_BYTES_MIN,
			fileSubkeyId,
			"file_non",
			this->m_masterKey.data()) != 0) {

			sodium_memzero(subkey.data(), KEY_BYTES);
			return unexpected(SeError::CRYPTOKDFFail);
		}

		vector<unsigned char> baseNonce(crypto_aead_aes256gcm_NPUBBYTES);
		memcpy(baseNonce.data(), nonceDerivation.data(), crypto_aead_aes256gcm_NPUBBYTES);

		auto session = std::make_unique<AesGcmStreamSession<cryptoMode>>(
			subkey,
			baseNonce
		);

		sodium_memzero(subkey.data(), KEY_BYTES);
		sodium_memzero(nonceDerivation.data(), nonceDerivation.size());
		return session;
	}

	expected<void,error_code> SetMasterKey(span<unsigned char> key);
	
	bool keyExists() const noexcept {
		return this->m_keyRegister;
	}

private:
	vector<unsigned char> m_masterKey = vector<unsigned char>(KEY_BYTES);

	bool m_keyRegister = false;

	AesGcmContextProvider(){ }
	vector<unsigned char> generateSessionKey(span<unsigned char> fileIdx);

};