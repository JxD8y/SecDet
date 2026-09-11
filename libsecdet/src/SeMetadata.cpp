#include "libsecdet/SeMetadata.h"

SeMetadata::SeMetadata(uint16_t version, uint16_t compressionLevel, 
                       bool preserveMetadata, uint16_t pvv,
                       span<const unsigned char> salt):
    m_preserve_metadata(preserveMetadata),
    m_version(version),
    m_compression_level(compressionLevel),
    m_pvv(pvv)
{
    if (!salt.empty() && salt.size() >= SE_SALT_SIZE) {
        copy_n(salt.begin(), SE_SALT_SIZE, this->m_salt.begin());
    }
}

void SeMetadata::SetSalt(span<const unsigned char> value) noexcept {
    if (value.size() >= SE_SALT_SIZE) {
        copy_n(value.begin(), SE_SALT_SIZE, this->m_salt.begin());
        this->m_isReady = false;
    }
}

expected<SeMetadata,error_code> SeMetadata::LoadMetadataFromBytes(span<unsigned char> metadata_bytes){
    // The metadata is fixed length and is at begining of the file + the TOC offset

    // MAGIC 4
    // VERSION 2
    // COMPRESSION LEVEL 4
    // PRESERVE METADATA 1
    // TOC OFFSET 8
    // PVV 2
    // SALT 16

    if(metadata_bytes.size() < SE_METADATA_SIZE){
        return unexpected(make_error_code(errc::invalid_argument));
    }


    if(memcmp(metadata_bytes.data(),SE_METADATA_MAGIC,4)){
        return unexpected(SeError::InvalidMetadataMagic); // Not that the SDA is executable i used it to avoid defining custom
    }

    array<unsigned char,2> version_bytes;
    copy_n(metadata_bytes.data()+4,2,version_bytes.begin());
    auto version = bit_cast<uint16_t>(version_bytes);


    if(version != 0x1){
        return unexpected(make_error_code(errc::not_supported));
    }

    array<unsigned char,4> compression_bytes;
    copy_n(metadata_bytes.data()+6,4,compression_bytes.begin());
    auto compressionLevel = bit_cast<uint32_t>(compression_bytes);

    if( compressionLevel < 0x0 || compressionLevel > 0x3 ){
        return unexpected(make_error_code(errc::invalid_argument));
    }

    bool preserveMetadata = metadata_bytes[10] > 0 ? true : false; 

    array<unsigned char,8> toc_offset_bytes;
    copy_n(metadata_bytes.data()+11,8,toc_offset_bytes.begin());
    auto toc_offset = bit_cast<uint64_t>(toc_offset_bytes); // Consumer should check the validity of toc_offset

    array<unsigned char,2> pvv_bytes;
    copy_n(metadata_bytes.data()+19, 2, pvv_bytes.begin());
    auto pvv = bit_cast<uint16_t>(pvv_bytes);

    array<unsigned char, SE_SALT_SIZE> salt_bytes;
    copy_n(metadata_bytes.data()+21, SE_SALT_SIZE, salt_bytes.begin());

    SeMetadata _m(version, compressionLevel, preserveMetadata, pvv, salt_bytes);
    _m.m_toc_offset = toc_offset;
    return _m;
}

void SeMetadata::GetMetadataBytes(span<unsigned char> out_data) {
    if (out_data.size() < SE_METADATA_SIZE) {
        return;
    }

    // Offset 0..3: MAGIC (4 bytes)
    memcpy(out_data.data(), SE_METADATA_MAGIC, 4);

    // Offset 4..5: VERSION (2 bytes)
    auto version_bytes = bit_cast<array<unsigned char, 2>>(this->m_version);
    copy_n(version_bytes.data(), 2, out_data.data() + 4);

    // Offset 6..9: COMPRESSION LEVEL (4 bytes)
    auto compression_bytes = bit_cast<array<unsigned char, 4>>(this->m_compression_level);
    copy_n(compression_bytes.data(), 4, out_data.data() + 6);

    // Offset 10: PRESERVE METADATA (1 byte)
    out_data[10] = this->m_preserve_metadata ? 1 : 0;

    // Offset 11..18: TOC OFFSET (8 bytes)
    auto toc_offset_bytes = bit_cast<array<unsigned char, 8>>(this->m_toc_offset);
    copy_n(toc_offset_bytes.data(), 8, out_data.data() + 11);

    // Offset 19..20: PVV (2 bytes)
    auto pvv_bytes = bit_cast<array<unsigned char, 2>>(this->m_pvv);
    copy_n(pvv_bytes.data(), 2, out_data.data() + 19);

    // Offset 21..36: SALT (16 bytes)
    copy_n(this->m_salt.data(), SE_SALT_SIZE, out_data.data() + 21);

    this->m_isReady = true;
}

