/*
    A normal .SDA file should be like this:

    [META DATA (xBYTES)]
    [encrypted compressed archive]
    [no tailing needed becaused the crypto stream is aware of the final block preventing unwanted chunk addition and removal!]

    META DATA: (Mostly the user settings packed structure) (data is mostly inside the SeMetadata object)

        {SDA MAGIC BYTES}
        version number ( current version is 1 and it does not support the dynamic password list so it will prompt the user upon extraction )
        Compression level
        preserve the file metadata ( with the archive_entry_copy_stat)
        Offset of TOC

    [LH 1]
    [Encrypted file 1]
    [LH 2]
    [Encrypted file 2]
    .
    .
    .
    
    [ TOC:
        "folder/file1",  
        "folder/file",
        "file"]

*/
#pragma once

#include <cstdio>

