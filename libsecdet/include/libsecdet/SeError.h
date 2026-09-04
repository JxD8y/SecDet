#pragma once 

#include <system_error>
#include <string>
#include <iostream>

enum class SeError{
    NoTOCFound = 0,
    InvalidTOCMagic,
    InvalidMetadataMagic,
    AddingExistingEntry,
    BufferUnderflow,
    BufferStringOverflow,
    VersionNotSupported,
    TocPathIsInvalid,
    CannotCreateJob,
    JobNotFound,
    ConflictingJobFound,
    JobIsNotIdle,
    InvalidJob,
    KeyLimitReached,
    KeyAlreadyExists,
    KeyDoesNotExist,
    ArchiveModified,
    OperationCanceled,
    ZstdInitiationFail,
    RequiredFieldMissing,
    SmallBuffer,
    ExpectedDirectory,


    CRYPTOBufferWasEmpty,
    CRYPTOStringWasEmpty,
    CRYPTOInvalidSessionMode,
    CRYPTOCannotInitSodium,
    CRYPTOGenericFailure,
    CRYPTOKDFFail,
    CRYPTOStageTooSmall, 

    StreamAlreadyOpen,

    ZSTDCompressionError,

    CrcChecksumFailed,
};

struct SeErrorCategory: std::error_category{
    const char* name() const noexcept override { return "SeError" ;}

    std::string message(int ev) const override {
        switch ((SeError)ev)
        {
            case SeError::NoTOCFound: return "No TOC data was found"; 
            case SeError::InvalidTOCMagic: return "TOC magic was not found possible trunc archive."; 
            case SeError::InvalidMetadataMagic: return "Metadata magic is invalid, possible wrong file type"; 
            case SeError::AddingExistingEntry: return "Entry was already in the container";
            case SeError::BufferUnderflow: return "Buffer ran out of bytes for requested field";
            case SeError::BufferStringOverflow: return "String field was larger than the buffer size";
            case SeError::VersionNotSupported: return "Requested version is not supported by this library";
            case SeError::TocPathIsInvalid: return "The path you requested does not exist within toc";
            case SeError::CannotCreateJob: return "Cannot create the archive job requested";
            case SeError::JobNotFound: return "Requested job was not found";
            case SeError::KeyAlreadyExists: return "Key already registered in the storage";
            case SeError::KeyDoesNotExist: return "No key was found in storage";
            case SeError::KeyLimitReached: return "Key count limit reached";
            case SeError::ConflictingJobFound: return "Found conflicting jobs";
            case SeError::ArchiveModified: return "Conflict between file TOC and internal TOC";
            case SeError::OperationCanceled: return "Operation canceled";
            case SeError::JobIsNotIdle: return "Job is not idle";
            case SeError::InvalidJob: return "Job object was not valid";
            case SeError::ZstdInitiationFail: return "Cannot initiate the zstd context";
            case SeError::RequiredFieldMissing: return "One of the required field is missing.";
            case SeError::SmallBuffer: return "Insufficient space in passed buffer";
            case SeError::ExpectedDirectory: return "Expected a directory";



            case SeError::CRYPTOStageTooSmall: return "Crypto: not an error, just keep pushing data until reach buffer size";
            case SeError::CRYPTOStringWasEmpty: return "Crypto: string was empty";
            case SeError::CRYPTOBufferWasEmpty: return "Crypto: byffer was empty";
            case SeError::CRYPTOCannotInitSodium: return "Crypto: cannot initiate libsodium";
            case SeError::CRYPTOGenericFailure: return "Crypto: crypto operation failed";
            case SeError::CRYPTOInvalidSessionMode: return "Crypto: wrong session mode";
            case SeError::CRYPTOKDFFail: return "Crypto: kdf failed";


            case SeError::StreamAlreadyOpen: return "Stream: file is already open";

            case SeError::ZSTDCompressionError: return "ZSTD: compression failed";

            case SeError::CrcChecksumFailed: return "CRC checksum failed";
            
            default: return "Unknown error";
        }
    }
};

inline const SeErrorCategory& get_seError_category(){
    static const SeErrorCategory seCat;
    return seCat;
}

inline std::error_code make_error_code(SeError e){
    return { (int)e , get_seError_category() };
}

template <>
struct std::is_error_code_enum<SeError> : std::true_type {};