#!/bin/bash

for f in $(find . -name "osu_collective_single_code.*"); do
    grep -q "User defined signal 2" $f
    if [ "$?" == "0" ]; then
        bid=$(echo $f | cut -d'.' -f4 | cut -d'/' -f1)
        bhist -l $bid | grep -q "TERM_RUNLIMIT" && echo "Test walltimed: $f"
    fi
done
