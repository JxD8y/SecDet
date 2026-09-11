#pragma once

#include <cstdint>
#include <string>
#include <filesystem>

#include "SeTOC.h"

#ifdef _WIN32
// Undefine the GetFileAttributes macro to avoid collision with our function name
#ifdef GetFileAttributes
#undef GetFileAttributes
#endif
#include <Windows.h>
// Windows.h re-defines the macro, so undefine it again after include
#ifdef GetFileAttributes
#undef GetFileAttributes
#endif
#else
#include <sys/stat.h>
#endif

namespace se {

/// Reads the OS file attributes for the given disk path and translates them
/// into portable SE_ATTR_* bit flags.  Returns 0 on failure or if the
/// platform doesn't support the queried attribute.
inline uint32_t GetFileAttributes(const std::u16string &diskPath) {
  uint32_t result = 0;

#ifdef _WIN32
  // On Windows, call GetFileAttributesW directly (not through the macro)
  DWORD attrs = ::GetFileAttributesW(
      reinterpret_cast<LPCWSTR>(diskPath.c_str()));

  if (attrs == INVALID_FILE_ATTRIBUTES)
    return 0;

  if (attrs & FILE_ATTRIBUTE_DIRECTORY)
    result |= SE_ATTR_DIR;
  if (attrs & FILE_ATTRIBUTE_READONLY)
    result |= SE_ATTR_READONLY;
  if (attrs & FILE_ATTRIBUTE_HIDDEN)
    result |= SE_ATTR_HIDDEN;
  if (attrs & FILE_ATTRIBUTE_SYSTEM)
    result |= SE_ATTR_SYSTEM;

#else
  // POSIX fallback using stat()
  std::filesystem::path p(diskPath);
  struct stat st;
  if (::stat(p.string().c_str(), &st) != 0)
    return 0;

  // Not writable by owner -> read-only
  if (!(st.st_mode & S_IWUSR))
    result |= SE_ATTR_READONLY;

  // Hidden: filename starts with '.'
  auto fname = p.filename().string();
  if (!fname.empty() && fname[0] == '.')
    result |= SE_ATTR_HIDDEN;

  // SE_ATTR_SYSTEM has no POSIX equivalent - leave unset
#endif

  return result;
}

} // namespace se
