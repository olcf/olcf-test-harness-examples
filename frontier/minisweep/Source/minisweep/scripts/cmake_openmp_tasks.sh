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

CC=gcc
OMP_ARGS="-fopenmp"
OPT_ARGS="-O3 -fomit-frame-pointer -funroll-loops -finline-limit=10000000"

# CC=icc
# OMP_ARGS="-qopenmp"
# OPT_ARGS="-ip -prec-div -O3 -align -ansi-alias -fargument-noalias -fno-alias -fargument-noalias"

#------------------------------------------------------------------------------

cmake \
  -DCMAKE_BUILD_TYPE:STRING="$BUILD" \
  -DCMAKE_INSTALL_PREFIX:PATH="$INSTALL" \
 \
  -DCMAKE_C_COMPILER:STRING=gcc \
  -DCMAKE_C_FLAGS:STRING="-DNM_VALUE=$NM_VALUE -DUSE_OPENMP -DUSE_OPENMP_TASKS $OMP_ARGS" \
  -DCMAKE_C_FLAGS_DEBUG:STRING="-g" \
  -DCMAKE_C_FLAGS_RELEASE:STRING="$OPT_ARGS" \
 \
  $SOURCE

#------------------------------------------------------------------------------
