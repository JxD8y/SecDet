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
        [ A list of files that are inside the archive like this:
        "folder/file1",  
        "folder/file",
        "file"]

        ** A Dynamic List space for encrypted master password and the corresponding hash data **
        [MetaEnd Bytes Either a string or byte pattern ]

    [Encrypted Compressed archive] (is mostly inside the SeArchive)

        !whether the archive is being created or opened , the existance of metadata is necessary for the next steps

        suppose user created a new .sda archive like this: compression level 2 , version is 1 , preserve metadata true + added some files
        
        SePackage works like this : SePackage::CreatePackage(Version,bool preserv,...keyData,,,);
        
        //It is only possible to create an archive with these two
        SeArchive::CreateArchive(bool preservedata, callbacks) 
        SeArchive::LoadArchive(fileName , offsets) (the encryption does not matter)

        SeArchive.GetFileAsync("File Path",password,callback) -> Task

*/