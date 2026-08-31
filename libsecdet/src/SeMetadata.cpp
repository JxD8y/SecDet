#include "libsecdet/SeMetadata.h"

SeMetadata::SeMetadata(uint16_t version,uint16_t compressionLevel, 
                                        bool preserveMetadata):
                                        m_version(version),
                                        m_compression_level(compressionLevel),
                                        m_preserve_metadata(preserveMetadata)
{};


expected<SeMetadata,error_code> SeMetadata::LoadMetadataFromBytes(span<unsigned char> metadata_bytes){
    // The metadata is fixed length and is at begining of the file + the TOC offset

    // MAGIC 4
    // VERSION 2
    // COMPRESSION LEVEL 4
    // PRESERVE METADATA 1
    // TOC OFFSET 8

    if(metadata_bytes.size() < SE_METADATA_SIZE){
        return unexpected(make_error_code(errc::invalid_argument));
    }


    if(!memcmp(metadata_bytes.data(),SE_METADATA_MAGIC,4)){
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

    SeMetadata _m(version,compressionLevel,preserveMetadata);
    return _m;
}
