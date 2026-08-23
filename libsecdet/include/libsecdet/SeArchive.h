#pragma once
#include <string>
#include <vector>
#include <expected>
#include <span>
#include <algorithm>

#include "SeError.h"
#include "SeTOC.h"

using namespace std;


class SeArchive{
    // archive is the main part of the app , it will handle the file addition, final byte layout , encryption , callback registration , ... 
    // archive has a Se TOC object to keep track of its the archive layout and easily add and remove files into the archive
    // the mapped file after the metadata is the archive teritory 
    // also any archive file modification is required to happen in a temp file first then replace the main file !

    
};
