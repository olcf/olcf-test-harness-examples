#!/bin/bash -l
#
# Script to build minisweep.
# 

# HIP_PATH is no longer set by the module, quick fix
export HIP_PATH=${ROCM_PATH}

BUILDTYPE=$1
echo "BUILDTYPE $BUILDTYPE"
BUILDSCRIPT=cmake_${BUILDTYPE}.sh

# Release is needed to get good performance
env NM_VALUE=16 BUILD=Release SOURCE=./minisweep INSTALL=./install ./minisweep/scripts/$BUILDSCRIPT 2>&1 | tee out_cmake.txt

make VERBOSE=1 2>&1 | tee out_make.txt

cp sweep ../
cp tester ../

