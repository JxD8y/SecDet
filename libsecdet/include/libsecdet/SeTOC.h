#pragma once
#include <string>
#include <vector>
#include <expected>
#include <span>
#include <algorithm>

#include "SeError.h"

using namespace std;


#define SE_TOC_MAGIC "\x7F\x54\x4F\x43" // 7F TOC
#define SE_TOC_ENTRY_PAD "\x04\x03\x4B\x50" // ZIP similar delimiter

class SeArchive;

class SeArchiveEntry{

public:
    static expected<SeArchiveEntry,error_code> CreateFromBytes(span<unsigned char>);

    SeArchiveEntry() = default;

    SeArchiveEntry(u16string _path, uint64_t _uncompressed_sz , uint64_t _compressed_sz, 
                    uint32_t _attributes, uint32_t _offset, uint32_t _crc32): path(_path),
                                                                                uncompressed_size(_uncompressed_sz),
                                                                                compressed_size(_compressed_sz),
                                                                                attributes(_attributes),
                                                                                offset(_offset),
                                                                                crc32(_crc32)
    {

    }


    u16string path; //Relative path
    uint64_t uncompressed_size = 0;
    uint64_t compressed_size = 0;
    uint32_t attributes = 0;
    uint64_t offset = 0;
    uint32_t crc32 = 0;

    vector<unsigned char> Serialize();

    bool isDirectory() const { return (attributes & 1) != 0; }
    // Entries should serialize their size !
    bool operator==(const SeArchiveEntry& value){
        if(path == value.path && offset == value.offset && crc32 == value.crc32)
            return true;
        return false;
    }


};

class SeTableOfContent{

public:
    static expected<SeTableOfContent,error_code> LoadTableOfContentFromBytes(span<unsigned char> data);

    static SeTableOfContent CreateNewTableOfContent();

    // Again , any tampering with the TOC will set the is ready to false until you serialize it again

    expected<void,error_code> AddEntry(SeArchiveEntry);
    bool RemoveEntry(u16string);
    bool RemoveEntry(SeArchiveEntry&);

    expected<void,error_code> CheckPath(u16string);
    expected<void,error_code> CheckParentPath(u16string);//Check if the parent directory exist

    [[nodiscard]] span<const SeArchiveEntry> GetEntries() const noexcept{
        return m_entries;
    }


    expected<size_t,error_code> Serialize();

    
    bool IsReady() const noexcept { return m_isReady ;}

    // Iterate through the toc tree and find the next empty spot

    size_t getNextAvailOffset();

    friend class SeArchive;

    //should add a relative path verifier and logic
    // ex. should user add a file named: Dir/ then add files in it ? 
    // which causes the entry become polluted with tons of byte less entries
    // or we should add the directory when the user adds files into it
    // which again causes that user loss all the empty directories which are many of theM!

    bool operator==(const SeTableOfContent&);

    bool operator!=(const SeTableOfContent& b){
        return *this == b;
    }
    
private:
    SeTableOfContent();

    vector<SeArchiveEntry> m_entries; // Possible high memroy usage if the archive contains too many files
    bool m_isReady = false;
};
