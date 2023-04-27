#!/bin/bash

print_usage() {
    echo "Usage: ./build_prebuilt.sh <executable_path>"
}

if [[ ! $# -eq 1 ]]; then
    print_usage
    exit 1
fi

pre_built_path=/sw/acceptance/pre-built/${RGT_MACHINE_NAME}
exe_path=$1

if [ ! -f ${pre_built_path}/${exe_path} ]; then
    echo "Could not find ${exe_path} in ${pre_built_path}"
    exit 1
fi

# Then the application can use ${BUILD_DIR}/pre-built/${exe_path} to call the executable
#ln -s ${pre_build_path} ./pre-built
mkdir ./pre-built
# only want to copy this current application's tests (for the moment)
cp -r ${pre_built_path}/`echo $exe_path | cut -d'/' -f1` ./pre-built
