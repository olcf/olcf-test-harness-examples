#!/bin/bash -l
#------------------------------------------------------------------------------

if [ "$COMPILER" != "" -a "$COMPILER" != "nvcc" ] ; then
  COMPILER_FLAG="-ccbin;${COMPILER};"
else
  COMPILER_FLAG=""
  COMPILER_FLAGS_HOST="-Xcompiler;-O3;"
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
cmake \
  -DCMAKE_BUILD_TYPE:STRING="$BUILD" \
  -DCMAKE_INSTALL_PREFIX:PATH="$INSTALL" \
 \
  -DCMAKE_C_COMPILER:STRING="pgcc" \
  -DCMAKE_CXX_COMPILER:STRING="pgc++" \
  -DCMAKE_C_FLAGS:STRING="-DNM_VALUE=$NM_VALUE" \
 \
  -DUSE_MPI:BOOL=ON \
 \
  -DUSE_CUDA:BOOL=ON \
  -DCUDA_NVCC_FLAGS:STRING="${COMPILER_FLAG}${COMPILER_FLAGS_HOST}${DEBUG_FLAG};-gencode;arch=compute_70,code=sm_70;-O3;-use_fast_math;--maxrregcount;128;-Xptxas=-v" \
  -DCUDA_HOST_COMPILER:STRING=pgc++ \
  -DCUDA_PROPAGATE_HOST_FLAGS:BOOL=ON \
 \
 \
  $SOURCE

#------------------------------------------------------------------------------
