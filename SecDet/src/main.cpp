#include <qcoreapplication.h>
#include <qqmlapplicationengine.h>
#include <qguiapplication.h>

int main(int argc, char** argv) {
	QGuiApplication app(argc, argv);

	QQmlApplicationEngine engine;

	engine.loadFromModule("UI", "MainWindow");

	return app.exec();
}
// VCPKG + ZSTD  then libarchive + decide to go with Windows or libsodium or both !!! 

// added files will get archived then compressed then the encryption via master key happens . 
// 			.TAR -> .tar.lzma -> .tar.lzma.aes256

// the SecDet will be created in a seperate library and exposes interfaces needed!

// the File Format for the final output file:

// with this approach which i used in the egorPwd the archive has zero tolerance from corruption in its begining sections
// one of the keySlots bits flip and user cannot use its keys

//By adding CRC32 + ECC and copying the metadata as a shadow to the trailing of the archive we will have a high chance to not lose our meta data (RAR5 - design)

// keep in mind that archive type and the compression level also need to be in the metadata (serve in the setting later but needed to correctly open the archive)

// the Final encrypted Archive data (not the final package with metadata!) should be chunked in 1 MB (i know that currently i didn't account for recovery but we need to implement it now and keep its level at 0 to avoid future mess!)
// and use a hash on each block to verify if its correct if not Use Reed Solomon GF(2^8) to fix the chunk.

// final library interface is abstracted into SeArchive (the struct holding the unpacked archive) , SePackage (the final file with the meta data)

// each of the Se* should have specific read / write functions + register functions to allow notify the UI 
// currently i ONLY impl the non-encrypted file metadata (CONTENT ONLY) mode which allows the archive that gets opened instantly return the password info , setting metadata
// and the file metadata like name size , ratio , ... . the decrypt will only prompt for password when extract is requested.

// SePackage::Open("archive.sda") SePackage::Archive -> SeArchive. SeArchive::GetFiles() -> list [SeFile] -> SeArchive::DecryptSingleFile(SeFile::Id,Output_path,callback)
// SePackage::Metadata . SeMetaData::SeSecurityContext& . SeSecurityContext::GetPasswords() -> List [string]
// SePackage::Archive::Addfile(path,callback)

//Most of the callbacks need to return a global status like failed <cause> or their status like IteratingDirectory loading file or ... 
// SePackage::WriteMetadata -> when metadata change happens .
// The Add file or remove file should start the write operation on a temp file then move it to the main file when the process is done !
