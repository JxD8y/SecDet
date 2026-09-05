#include "libsecdet/SeCrypto/AesGcmContextProvider.h"
#include "libsecdet/SeCrypto/AesGcmStreamSession.h"


expected<void, error_code> AesGcmContextProvider::SetMasterKey(span<unsigned char> key) {
	if (key.size() < AesGcmContextProvider::KEY_BYTES) {
		return unexpected(SeError::SmallBuffer);
	}

	memcpy(this->m_masterKey.data(), key.data(), AesGcmContextProvider::KEY_BYTES);

	this->m_keyRegister = true;
	return {};

}
