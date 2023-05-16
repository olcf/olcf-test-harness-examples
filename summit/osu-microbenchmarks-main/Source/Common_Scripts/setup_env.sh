#!/bin/bash


# Unless RGT_OSU_COMPILER is set, just stick with the current compiler & optionally load CUDA
[ ! "x${RGT_OSU_COMPILER}" == "x" ] && module load $RGT_OSU_COMPILER

# If cuda is not loaded, load it. Set `RGT_OSU_CUDA` to load a specific module
module -t list | grep -q "nvhpc" || module load ${RGT_OSU_CUDA:-cuda}


module -t list
