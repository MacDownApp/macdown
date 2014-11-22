#!/bin/bash

pushd `dirname $0` > /dev/null
source $(pwd -P)/utils.sh
popd > /dev/null

VERSION=$(get_short_version)

printf "#ifndef VERSION_H
#define VERSION_H

static const char * const kMPApplicationVersion = \"$VERSION\";

#endif
" > version.h
