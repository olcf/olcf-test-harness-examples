#!/bin/bash -l
#------------------------------------------------------------------------------

module -q load cmake
module -q load rocm
#module -q load rocm/3.9.0

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

HIPCC_FLAGS="-DUSE_HIP -D__HIP_PLATFORM_HCC__ -DHAVE_HIP -I$ROCM_PATH/include -fno-gpu-rdc -Wno-unused-command-line-argument --amdgpu-target=gfx90a -Wno-c99-designator -Wno-duplicate-decl-specifier -Wno-unused-variable -L$ROCM_PATH/lib -lrocblas -lrocsparse"
#HIPCC_FLAGS="-DHAVE_HIP -I$ROCM_PATH/include -fno-gpu-rdc -Wno-unused-command-line-argument --amdgpu-target=gfx906,gfx908 -Wno-c99-designator -Wno-duplicate-decl-specifier -Wno-unused-variable -DHAVE_HIP -L$ROCM_PATH/lib -lrocblas -lrocsparse"
#-DHAVE_HIP

#local COMET_MPI_COMPILE_OPTS="-I$OLCF_OPENMPI_ROOT/include"
#local COMET_MPI_LINK_OPTS="-L$OLCF_OPENMPI_ROOT/lib -Wl,-rpath,$OLCF_OPENMPI_ROOT/lib -lmpi"

#------------------------------------------------------------------------------

cmake \
  -DCMAKE_BUILD_TYPE:STRING="$BUILD" \
  -DCMAKE_INSTALL_PREFIX:PATH="$INSTALL" \
 \
  -DCMAKE_CXX_COMPILER:STRING="hipcc" \
  -DCMAKE_CXX_FLAGS:STRING="-DNM_VALUE=$NM_VALUE $HIPCC_FLAGS" \
 \
  -DUSE_HIP:BOOL=ON \
 \
  $SOURCE

#------------------------------------------------------------------------------

#  -DCMAKE_C_COMPILER:STRING="hipcc" \
#  -DCMAKE_C_FLAGS:STRING="-DNM_VALUE=$NM_VALUE $HIPCC_FLAGS" \
# \

#  -DCUDA_NVCC_FLAGS:STRING="-I$MPICH_DIR/include;-arch=sm_35;-O3;-use_fast_math;-DNDEBUG;--maxrregcount;128;-Xcompiler;-fstrict-aliasing;-Xcompiler;-fargument-noalias-global;-Xcompiler;-O3;-Xcompiler;-fomit-frame-pointer;-Xcompiler;-funroll-loops;-Xcompiler;-finline-limit=100000000;-Xptxas=-v" \
#  -DCUDA_HOST_COMPILER:STRING=/usr/bin/gcc \
#  -DCUDA_PROPAGATE_HOST_FLAGS:BOOL=ON \

#  -DMPI_EXEC="aprun" \
#  -DMPI_EXEC_MAX_NUMPROCS:STRING=16 \
#  -DMPI_EXEC_NUMPROCS_FLAG:STRING=-n \
