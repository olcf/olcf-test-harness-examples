#!/bin/bash -l
#------------------------------------------------------------------------------

if [ "$COMPILER" != "" -a "$COMPILER" != "nvcc" ] ; then
  COMPILER_FLAG="-ccbin;${COMPILER};"
else
  COMPILER_FLAG=""
  COMPILER_FLAGS_HOST="-Xcompiler;-fstrict-aliasing;-Xcompiler;-fargument-noalias-global;-Xcompiler;-O3;-Xcompiler;-fomit-frame-pointer;-Xcompiler;-funroll-loops;-Xcompiler;-finline-limit=100000000;"
fi

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

if [ "$BUILD" = "Release" ] ; then
  DEBUG_FLAG="-DNDEBUG;"
else
  DEBUG_FLAG=""
fi

#------------------------------------------------------------------------------

# See also `which mpcc`
MPI_INCLUDE_DIR=${OMPI_DIR}/include
OMPI_CC=clang
OMPI_CXX=clang++
OMPI_FC=xlflang

cmake \
  -DCMAKE_BUILD_TYPE:STRING="$BUILD" \
  -DCMAKE_INSTALL_PREFIX:PATH="$INSTALL" \
 \
  -DCMAKE_C_COMPILER:STRING="clang" \
  -DCMAKE_C_FLAGS:STRING="-DNM_VALUE=$NM_VALUE" \
 \
  -DUSE_MPI:BOOL=ON \
 \
  -DUSE_OPENMP:BOOL=ON \
 \
  $SOURCE

#------------------------------------------------------------------------------
