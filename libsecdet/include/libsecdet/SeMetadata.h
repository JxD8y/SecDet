/*
    META DATA: (Mostly the user settings packed structure) (data is mostly inside the SeMetadata object)

        {SDA MAGIC BYTES}
        version number ( current version is 1 and it does not support the dynamic password list so it will prompt the user upon extraction )
        Compression level
        preserve the file metadata ( with the archive_entry_copy_stat )

        ** A Dynamic List space for encrypted master password and the corresponding hash data **
        [MetaEnd Bytes Either a string or byte pattern ]
*/

#pragma once

#include <vector>
#include <string>
#include <expected>
#include <span>
#include <filesystem>
#include <bit>
#include <array>

#include "SeError.h"
#include "SeMMStream.h"

#define SE_METADATA_MAGIC "\x7F\x53\x44\x41" // >> 0x7F SDA

#define SE_METADATA_SIZE 19u

using namespace std;

class SeArchive;

class SeMetadata{
public:
    static expected<SeMetadata,error_code> LoadMetadataFromBytes(span<unsigned char> metadata_bytes);
    
    
    void GetMetadataBytes(span<unsigned char> out_data);
    
    uint16_t GetCompressionLevel() noexcept {return this->m_compression_level;}
    bool GetPreserveMetadata() noexcept {return this->m_preserve_metadata;}
    
    
    void SetCompressionLevel(uint16_t value) { 
        if(value > 0x3 || value < 0x0)
        return;
        this->m_compression_level = value;
        this->m_isReady = false;
    }
    void SetPreserveMetadata(bool value) {
        if(value == m_preserve_metadata)
        return;
        this->m_preserve_metadata = value;
        this->m_isReady = false;
    }

    bool operator==(const SeMetadata& b) const{
        return b.m_archive_file_name == this->m_archive_file_name && 
                b.m_compression_level == this->m_compression_level &&
                b.m_preserve_metadata == this->m_preserve_metadata &&
                b.m_toc_offset == this->m_toc_offset &&
                b.m_version == this->m_version;
    }
    
    friend class SeArchive;

private:
    SeMetadata(uint16_t version,uint16_t compressionLevel, bool preserveMetadata);
    SeMetadata() {};
   
    // header metadata size: 19 byte
    bool m_preserve_metadata = false;
    bool m_isReady = false;

    uint16_t m_version = 0x0;
    uint32_t m_compression_level = 0x0; //Supported Values: 0x1 , 0x2 , 0x3 
    
    uint64_t m_toc_offset = 0x0;

    u16string m_archive_file_name = u"";
};