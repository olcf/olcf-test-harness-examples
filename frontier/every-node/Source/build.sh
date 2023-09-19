#!/bin/bash

# The envvar RGT_COPYLESS_BUILD bypasses the copying from $PREBUILT_PATH to save space. Set to '1' to enable

print_usage() {
    echo "Usage: ./build.sh <executable_path>"
}

if [ "x$PREBUILT_PATH" == "x" ]; then
    echo "The PREBUILT_PATH environment variable is required"
    exit 1
fi

if [[ ! $# -eq 1 ]]; then
    print_usage
    exit 1
fi

pre_built_path=${PREBUILT_PATH}/${RGT_MACHINE_NAME}
exe_path=$1

if [ ! -f ${pre_built_path}/${exe_path} ]; then
    echo "Could not find ${exe_path} in ${pre_built_path}"
    exit 1
fi

# Support for copy-less builds, in the event of limiting quotas
if [ "x${RGT_COPYLESS_BUILD}" == "x1" ]; then
    mkdir ./pre-built
    echo "ls -lh of ${pre_built_path}/$(echo $exe_path | cut -d'/' -f1):"
    ls -lh ${pre_built_path}/`echo $exe_path | cut -d'/' -f1`
else
    # Then the application can use ${BUILD_DIR}/pre-built/${exe_path} to call the executable
    mkdir ./pre-built && cp -r $(realpath ${pre_built_path}/`echo $exe_path | cut -d'/' -f1`) ./pre-built
fi
