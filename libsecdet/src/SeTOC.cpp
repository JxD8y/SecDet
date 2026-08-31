#include "libsecdet/SeTOC.h"


expected<SeArchiveEntry,error_code> SeArchiveEntry::CreateFromBytes(span<unsigned char> bytes){
    SeArchiveEntry _sEntry;
    size_t offset = 0;

    auto read = [&bytes,&offset](void*dest,size_t size){
        if(offset + size > bytes.size()){
            return unexpected(SeError::BufferUnderflow);
        }
        memcpy(dest,bytes.data()+offset , size);
        offset += size;
    };
    uint32_t cCount = 0;
    read(&cCount,sizeof(cCount));
    if(cCount > 0){
        size_t path_bytes = cCount * sizeof(char16_t);
        if(offset + path_bytes > bytes.size()){
            return unexpected(SeError::BufferStringOverflow);
        }
        _sEntry.path.resize(cCount);
        memcpy(_sEntry.path.data(),bytes.data()+offset,path_bytes);
        offset += path_bytes;
    }
    read(&_sEntry.uncompressed_size,sizeof(_sEntry.uncompressed_size));
    read(&_sEntry.compressed_size,sizeof(_sEntry.compressed_size));
    read(&_sEntry.attributes,sizeof(_sEntry.attributes));
    read(&_sEntry.offset,sizeof(_sEntry.offset));
    read(&_sEntry.crc32,sizeof(_sEntry.crc32));

    return _sEntry;
}

//important to return the Vector ,returning span causes RVO to fail and vector to be freed before return
vector<unsigned char> SeArchiveEntry::Serialize(){
    vector<unsigned char> buffer;

    auto append_buffer = [&buffer](const void* src, size_t size){
        const unsigned char* byte_ptr = reinterpret_cast<const unsigned char*>(src);
        buffer.insert(buffer.end(), byte_ptr, byte_ptr + size);
    };

    uint32_t cCount = (uint32_t)(path.size()); // Damn sure that the path wont exceed 2^32 len
    append_buffer(&cCount,sizeof(cCount));
    if(cCount > 0)
        append_buffer(this->path.data(),cCount * sizeof(char16_t));
    
    append_buffer(&this->uncompressed_size,sizeof(this->uncompressed_size));
    append_buffer(&this->compressed_size,sizeof(this->compressed_size));
    append_buffer(&this->attributes,sizeof(this->attributes));
    append_buffer(&this->offset,sizeof(this->offset));
    append_buffer(&this->crc32,sizeof(this->crc32));
    
    return buffer;
}

SeTableOfContent SeTableOfContent::CreateNewTableOfContent(){
    SeTableOfContent _sTOC;
    return _sTOC;
}

expected<SeTableOfContent,error_code> SeTableOfContent::LoadTableOfContentFromBytes(span<unsigned char> data){

    // Overview of TOC in byte: 
    // [Entry1]
    // [PAD - bytes]
    // [ENTRY2]
    // ...
    // [ENTRY N]
    // [PAD]

    if(!memcmp(data.data(),SE_TOC_MAGIC,4)){
        return unexpected(SeError::InvalidTOCMagic);
    }
    
    SeTableOfContent _toc;

    while(data.size() != 0){
        auto m_range = ranges::search(data,SE_TOC_ENTRY_PAD);
        if(m_range.empty()){
            break;
        }
        size_t tEntry_sz = (size_t)(std::distance(data.begin(),m_range.begin()));
        span<unsigned char> tEntry_bytes = data.first(tEntry_sz);
        
        auto _aEE = SeArchiveEntry::CreateFromBytes(tEntry_bytes);
        if(!_aEE){
            return unexpected(_aEE.error());
        }
        auto _aE = *_aEE;
        _toc.m_entries.push_back(_aE);
        
        data = data.subspan(tEntry_sz + 4);
    }
    return _toc;
}

expected<void,error_code> SeTableOfContent::AddEntry(SeArchiveEntry entry){
    if (!any_of(this->m_entries.begin(), this->m_entries.end(), [&](const SeArchiveEntry& val) {
        return entry == val;
    })) {
        this->m_entries.push_back(entry);
        this->m_isReady = false;
        return {};
    }
    else{
        return unexpected(SeError::AddingExistingEntry);
    }
}

bool SeTableOfContent::RemoveEntry(u16string entryPath){
    auto n = erase_if(this->m_entries , [&](const SeArchiveEntry& sEntry){
        return sEntry.path == entryPath;
    });
    this->m_isReady = false;
    return n > 0;
}

bool SeTableOfContent::RemoveEntry(SeArchiveEntry& entry){
    auto n = erase(this->m_entries , entry);
    this->m_isReady = false;
    return n > 0;
}