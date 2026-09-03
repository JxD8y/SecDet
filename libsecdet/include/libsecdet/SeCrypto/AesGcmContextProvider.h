#pragma once

#include <expected>
#include <vector>
#include <span>
#include <system_error>
#include <sodium.h>

#include "libsecdet/SeError.h"

using namespace std;

class AesGcmStreamSession;
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
	
	expected<std::unique_ptr<AesGcmStreamSession>, error_code> createSession(
		uint64_t fileSubkeyId,
		const char kdfContext[KDF_CONTEXT_BYTES] = "file_enc"
	);

	expected<void,error_code> SetMasterKey(span<unsigned char> key);
	
	bool keyExists() const noexcept {
		return this->m_keyRegister;
	}

private:
	vector<unsigned char> m_masterKey = vector<unsigned char>(KEY_BYTES);

	bool m_keyRegister = false;

	AesGcmContextProvider();
	vector<unsigned char> generateSessionKey(span<unsigned char> fileIdx);

};