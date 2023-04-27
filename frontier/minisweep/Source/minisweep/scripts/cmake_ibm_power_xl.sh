#!/bin/bash -l
#------------------------------------------------------------------------------

# CLEANUP
rm -rf CMakeCache.txt
rm -rf CMakeFiles

# SOURCE AND INSTALL
if [ "$SOURCE" = "" ] ; then
  SOURCE=../minisweep
fi
if [ "$INSTALL" = "" ] ; then
  INSTALL=../install
fi

if [ "$BUILD" = "" ] ; then
  BUILD=Debug
  #BUILD=Release
fi

if [ "$NM_VALUE" = "" ] ; then
  NM_VALUE=4
fi

#------------------------------------------------------------------------------

cmake \
  -DCMAKE_BUILD_TYPE:STRING="$BUILD" \
  -DCMAKE_INSTALL_PREFIX:PATH="$INSTALL" \
 \
  -DCMAKE_C_COMPILER:STRING=xlc \
  -DCMAKE_CXX_COMPILER:STRING=xlC \
  -DCMAKE_C_FLAGS:STRING="-qxlcompatmacros -DNM_VALUE=$NM_VALUE $ALG_OPTIONS" \
  -DCMAKE_C_FLAGS_DEBUG:STRING="-g" \
  -DCMAKE_C_FLAGS_RELEASE:STRING="-O3" \
  -DCMAKE_CXX_FLAGS:STRING="-qxlcompatmacros" \
 \
  $SOURCE

#------------------------------------------------------------------------------
