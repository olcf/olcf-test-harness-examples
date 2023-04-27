#!/usr/bin/env python3

import sys
import os

def check_file(f):
    """ Checks for graceful exits of LAMMPS runs """
    found_performance_line = False
    found_loop_time_line = False
    found_walltime_line = False
    with open(f, 'r') as f_in:
        for line in f_in:
            if line.startswith("Performance:"):
                found_performance_line = True
            elif line.startswith("Loop time of"):
                found_loop_time_line = True
            elif line.startswith("Total wall time"):
                found_walltime_line = True
    if not found_loop_time_line:
        print(f"Did not find loop time line")
    if not found_performance_line:
        print(f"Did not find performance line")
    if not found_walltime_line:
        print(f"Did not find walltime line")
    return found_performance_line and found_loop_time_line and found_walltime_line

def energy_breakdown(f_gpu, f_base):
    file1 = open(f_base, 'r')
    file2 = open(f_gpu, 'r')
    sim1 = {}
    sim2 = {}

    def check_step(sim1, sim2):
        correct = True
        for key in sim1.keys():
            if not key == 'Step':
                ratio = abs((sim1[key] - sim2[key]) / sim1[key]) * 100
                # 0.1% difference in energy breakdown
                if ratio > 0.1:
                    print(f"Key: {key}, ref: {sim1[key]}, calculated: {sim2[key]}, percentage diff: {ratio}")
                    correct = False
        return correct

    for line in file1:
        if line.find("Step") > -1:
            labels = line.split()
            line = next(file1)
            index_ct = 0
            while not line.split()[0].strip() == 'Loop':
                sim1[index_ct] = {}
                line = line.split()
                for j in range(0, len(line)):
                    sim1[index_ct][labels[j]] = float(line[j])
                line = next(file1)
                index_ct += 1
    for line in file2:
        if line.find("Step") > -1:
            labels = line.split()
            line = next(file2)
            index_ct = 0
            while not line.startswith('Loop'):
                sim2[index_ct] = {}
                line = line.split()
                for j in range(0, len(line)):
                    sim2[index_ct][labels[j]] = float(line[j])
                line = next(file2)
                index_ct += 1
    if not len(sim1) == len(sim2):
        print(f"Simulations of different lengths found: {len(sim1)} != {len(sim2)}. Aborting energy breakdown check.")
        return False
    correct = True
    for i in range(0, len(sim1)):
        if not check_step(sim1[i], sim2[i]):
            print(f"check_step failed at step: {sim1[i]['Step']}")
            correct = False
    return correct

def check_performance(f):
    """ Checks for graceful exits of LAMMPS runs """
    found_loop_time_line = False
    loop_time_line = ''
    with open(f, 'r') as f_in:
        for line in f_in:
            if line.startswith("Loop time of"):
                found_loop_time_line = True
                loop_time_line = line
    if not found_loop_time_line:
        print(f"Did not find loop time line")
        return [1, 'did not find loop time line in log file']
    loop_time_line = loop_time_line.split()
    # natoms * steps /s
    atom_steps_per_sec = float(loop_time_line[11]) * float(loop_time_line[8]) / float(loop_time_line[3])
    # A typical Frontier node hits about 16-17mil -- CORAL2-LAMMPS should hit 19mil
    # 8-node hit: 152696225.2195166
    perf_target = float(0.80 * 150000000)
    if atom_steps_per_sec < perf_target:
        return [1, atom_steps_per_sec, f"Performance: {atom_steps_per_sec}, missed target {perf_target} (80% of 150mil)"]
    else:
        return [0, atom_steps_per_sec, f"Perf check passed with {atom_steps_per_sec}"]


if not len(sys.argv) == 3:
    print('Usage: ./check_lammps.py logfile rfp.logfile')
    sys.exit(1)

# enable copy-less checking
workdir = os.environ['RGT_TEST_WORK_DIR'] if 'RGT_TEST_WORK_DIR' in os.environ else '.'
runarchive = os.environ['RGT_TEST_RUNARCHIVE_DIR'] if 'RGT_TEST_RUNARCHIVE_DIR' in os.environ else '.'

if not check_file(f"{workdir}/{sys.argv[1]}"):
    print(f'check_file failed, log file did not have a valid format')
    sys.exit(1)

if not energy_breakdown(f"{workdir}/{sys.argv[1]}", f"{workdir}/{sys.argv[2]}"):
    print(f'Energy breakdown failed. Incorrect answers found.')
    sys.exit(2)

perf_level, achieved_perf, perf_reason = check_performance(f"{workdir}/{sys.argv[1]}")
if perf_level == 1:
    print(f"Performance check failed: {perf_reason}")
    sys.exit(5)

sys.exit(0)
