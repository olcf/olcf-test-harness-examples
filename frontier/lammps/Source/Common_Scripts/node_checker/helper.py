#!/usr/bin/env python3

# Given a file name, these 2 functions check for the important bits, then report metrics from them

# Eventually, we should add ref files for each system and rank combination for validation
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

def report_file(f):
    """ Reports metrics from LAMMPS runs """
    m = {}
    found_performance_line = False
    performance_line = ''
    loop_time_line = ''
    walltime_line = ''
    with open(f, 'r') as f_in:
        for line in f_in:
            # if it's not an empty line, assign it to last_line
            if line.startswith("Total wall time"):
                walltime_line = line
            elif line.startswith("Loop time of"):
                loop_time_line = line
            elif line.startswith("Performance:"):
                performance_line = line
    if len(performance_line) <= 1 or len(loop_time_line) <=1 or len(walltime_line) <= 1:
        print(f"Couldn't find performance, loop time, or walltime line")
        return False
    # Else, we can assume that all 3 lines are formed properly
    walltime_arr = walltime_line.split()
    loop_time_arr = loop_time_line.split()
    performance_arr = performance_line.split()
    m['atom-steps-per-sec'] = float(loop_time_arr[8]) * float(loop_time_arr[11]) / float(loop_time_arr[3])
    return m

def energy_breakdown(f_base, f_gpu):
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
