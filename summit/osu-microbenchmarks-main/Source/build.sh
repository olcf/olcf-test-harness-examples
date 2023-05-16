#!/bin/bash

exit_check() {
    if [[ $1 -ne 0 ]]; then 
        echo "Command failed. Exiting..."
        exit 1
    fi
}

source ./Common_Scripts/setup_env.sh

echo $'\nModules loaded:\n'
module -t list
exit_check $?

echo $'\nChanging directory to hipOMB...\n'
cd osu-micro-benchmarks
exit_check $?

echo $'\nRunning autoreconf...\n'
autoreconf -ivf
exit_check $?

echo $'\nConfiguring...\n'
./configure CC=$(which mpicc) \
            CXX=$(which mpicxx) \
            --enable-cuda --with-cuda=$OLCF_CUDA_ROOT \
            --with-cuda-include=$OLCF_CUDA_ROOT/include --with-cuda-lib=$OLCF_CUDA_ROOT/lib64 \
            --prefix=$PWD/..

exit_check $?

echo $'\nCompiling...\n'
make
#exit_check $? #UPC doesn't compile for some reason, but it's not needed

echo $'\nInstalling...\n'
make install
#exit_check $? #UPC doesn't compile for some reason, but it's not needed

echo $'\nhipOMB installed successfully.\n'
