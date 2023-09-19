#!/bin/bash

# MPI Rank to GCD index map:
#   0: 4
#   1: 5
#   2: 2
#   3: 3
#   4: 6
#   5: 7
#   6: 0
#   7: 1
declare -A gpu_id_lookup=(
[0]=4
[1]=5
[2]=2
[3]=3
[4]=6
[5]=7
[6]=0
[7]=1
)

GCD_ID=${gpu_id_lookup[${SLURM_LOCALID}]}

mkdir ${NODE_LOCAL_TMP}/lammps_run_${GCD_ID}
cd ${NODE_LOCAL_TMP}/lammps_run_${GCD_ID}

tar -xf ${NODE_LOCAL_TMP}/inputs.tar.gz

# Create a directory & extract input files

${NODE_LOCAL_TMP}/lmp_gfx90a_serial \
    -k on g 1 -sf kk -pk kokkos gpu/aware on neigh half neigh/qeq full newton on comm device \
    -in ${input_file}.kokkos -log none \
    -v x 13 -v y 26 -v z 21 -v thermo_step 5 -v steps 2000 &> lammps-${GCD_ID}.log

exit 0
