#!/bin/bash

# collective_allgather_1n_6ppn_cpu
nnodes=8

for c in Source/osu-micro-benchmarks/c/mpi/collective/*.c; do
    new_c=$(echo $c | rev | cut -d'/' -f1 | rev | sed -e 's|osu_||g' -e 's|\.c||g')
    echo $new_c
    dname="collective_${new_c}_${nnodes}n_6ppn_gpu"
    if [ ! -d $dname ]; then
        mkdir -p $dname/Scripts
        sed -e "s|NNODES|$nnodes|" rgt.template > $dname/Scripts/rgt_test_input.ini
        cd $dname/Scripts
        ln -s ../../Source/Common_Scripts/lsf.template.collectives.singlecode ./lsf.template.x
        ln -s ../../Source/Common_Scripts/check_osu.py ./
        ln -s ../../Source/Common_Scripts/report_osu.py ./
        cd ../..
    else
        echo "Skipping $dname"
    fi
done
