#!/bin/bash

source ./Common_Scripts/env.sh

module list

exit_check() {
    if [[ $1 -ne 0 ]]; then 
        echo "Command failed. Exiting..."
        exit 1
    fi
}

echo $'\nModules loaded:\n'
module -t list
exit_check $?

echo $'\nChanging directory to hipOMB...\n'
cd osu-micro-benchmarks-5.7.1
exit_check $?

echo $'\nRunning autoreconf...\n'
autoreconf -ivf
exit_check $?

echo $'\nConfiguring...\n'
./configure CC=${CRAYPE_DIR}/bin/cc \
            CXX=${CRAYPE_DIR}/bin/CC \
            CFLAGS="-I${ROCM_PATH}/include" \
            CXXFLAGS="-I${ROCM_PATH}/include" \
            LDFLAGS="-L$ROCM_PATH/lib -lhsa-runtime64" \
            --enable-rocm --with-rocm=$ROCM_PATH \
            --prefix=$PWD/..

exit_check $?

echo $'\nCompiling...\n'
make
#exit_check $? #UPC doesn't compile for some reason, but it's not needed

echo $'\nInstalling...\n'
make install
#exit_check $? #UPC doesn't compile for some reason, but it's not needed

echo $'\nhipOMB installed successfully.\n'
