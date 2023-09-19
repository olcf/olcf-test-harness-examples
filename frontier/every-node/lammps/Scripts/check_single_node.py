#!/usr/bin/env python3

import sys
import os
import shutil

# Given a file name, these 2 functions check for the important bits, then report metrics from them

# Eventually, we should add ref files for each system and rank combination for validation
def check_file(f):
    """ Checks for graceful exits of LAMMPS runs """
    found_walltime_line = False
    reached_run = False
    completed_run = False
    state = 'SUCCESS'
    reason = ''
    with open(f, 'r') as f_in:
        for line in f_in:
            if line.startswith("Performance:"):
                found_performance_line = True
            elif line.startswith("Loop time of"):
                completed_run = True
            elif line.startswith("Total wall time"):
                found_walltime_line = True
            # Try to capture failure if there is one
            if not reached_run and line.strip().startswith("Step"):
                reached_run = True
            elif reached_run and line.strip().startswith("Loop time"):
                completed_run = True
            elif reached_run and not completed_run:
                # Then it should be numerical lines
                line_splt = line.strip().split()
                are_numerical = [e.replace('.', '', 1).isnumeric() for e in line_splt]
                if False in are_numerical:
                    # Known failure modes here:
                    if 'Lost atoms' in line:
                        return [ 'INCORRECT', f'Lost atoms found in log file: {line}' ]
                    elif 'nan' in line:
                        return [ 'INCORRECT', f'Found `nan` in log file: {line}' ]
                    elif 'cg_solve convergence' in line:
                        return [ 'INCORRECT', f'Detected CG_solve convergence failure: {line}' ]
                    elif 'HSA_STATUS_ERROR' in line:
                        hsa_err = [ a for a in line.replace(':', '').split() if a.startswith('HSA_STATUS') ]
                        t_status = 'FAIL'
                        if not 'APERTURE' in hsa_err[0]:
                            t_status = 'HW-FAIL'
                        return [t_status, f'Detected HSA status error: {hsa_err[0]}']
                    elif 'Bus error' in line:
                        return ['HW-FAIL', f'Detected Bus error']
                    elif 'MPICH ERROR' in line:
                        return ['FAIL', f'Detected MPI error']
                # else the line passes
            elif 'HSA_STATUS_ERROR' in line:
                hsa_err = [ a for a in line.replace(':', '').split() if a.startswith('HSA_STATUS') ]
                t_status = 'FAIL'
                if not 'APERTURE' in hsa_err[0]:
                    t_status = 'HW-FAIL'
                return [t_status, f'Detected HSA status error: {hsa_err[0]}']
            elif 'Bus error' in line:
                return ['FAIL', f'Detected Bus error']
            elif 'MPICH ERROR' in line:
                return ['FAIL', f'Detected MPI error']
    if not completed_run:
        print(f"Did not detect the LAMMPS run completed gracefully")
        state = 'FAIL'
        if reason == '':
            reason = 'Did not find Loop time line'
    elif not found_walltime_line:
        print(f"Did not find walltime line")
        state = 'FAIL'
        if reason == '':
            reason = 'LAMMPS run failed between end of simulation and program exit'
    return [state, reason]

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
    # A typical Frontier node hits about 24mil-atom-steps-per-second for this size problem
    if atom_steps_per_sec < 20000000:
        return [1, f"Performance: {atom_steps_per_sec}, missed target 20000000"]
    else:
        return [0, f"Perf check passed with {atom_steps_per_sec}"]


if not len(sys.argv) == 2:
    print('Usage: ./check_single_node.py <node_subdirectory>')
    exit(1)

# enable copy-less checking
workdir = os.environ['WORK_DIR'] if 'WORK_DIR' in os.environ else '.'
node_subdir = sys.argv[1]
node_name = node_subdir

if not os.path.isdir(f"{workdir}/{node_subdir}"):
    print(f"Node subdirectory {node_subdir} does not exist. Exiting.")
    exit(0)


print(f"Searching {workdir}/{node_subdir} for runs")

class ReportValues:
    def __init__(self):
        self.num_logs = 0
        self.failed = 0
        self.incorrect_answers = 0
        # dict -- self.node_status[node_name] = 0 (success) || >0 (fail)
        self.node_status = {}
        # nested dict -- self.reasons[nodename][size] = 'Reason'
        self.reasons = {}

# pass this around to helper methods
ret = ReportValues()

for f in os.listdir(os.path.join(os.environ['NODE_LOCAL_TMP'])):
    if f.startswith('log.'):
        # first step: copy logs from ${NODE_LOCAL_TMP} to ${WORK_DIR}/${node_subdir}
        shutil.copy(os.path.join(os.environ['NODE_LOCAL_TMP'], f), os.path.join(workdir, node_subdir, f))
        ret.num_logs += 1
        f_split = f.split('.')
        size = f_split[len(f_split) - 1]
        if not node_name in ret.node_status:
            ret.node_status[node_name] = 'SUCCESS'
            ret.reasons[node_name] = {}
        check_result = check_file(os.path.join(os.environ['NODE_LOCAL_TMP'], f))
        if not check_result[0] == 'SUCCESS':
            ret.failed += 1
            ret.node_status[node_name] = check_result[0]
            ret.reasons[node_name][size] = check_result[1]
            continue
        rfp_log = f'rfp.log.{size}'
        if not energy_breakdown(f"{workdir}/{rfp_log}", os.path.join(os.environ['NODE_LOCAL_TMP'], f)):
            ret.incorrect_answers += 1
            ret.node_status[node_name] = 'INCORRECT'
            ret.reasons[node_name][size] = 'energy breakdown failed'
        else:
            perf_level, perf_reason = check_performance(os.path.join(os.environ['NODE_LOCAL_TMP'], f))
            if perf_level == 1:
                ret.node_status[node_name] = 'PERF-FAIL'
                ret.reasons[node_name][size] = perf_reason
        print(f"All checks passed for {node_name} at {size}")

with open(f'{workdir}/{node_subdir}/node_report.txt', 'w') as out_f:
    if len(ret.node_status) > 1:
        print("WARNING: >1 node found in the single-node check")
    elif len(ret.node_status) == 0:
        print("Found 0 logs in single-node check")
    # get first (and only) node name
    node_name = list(ret.node_status.keys())[0]
    expl_str = ';'.join([f'{node_name}.{s}: {m}' for s, m in ret.reasons[node_name].items()])
    out_f.write(f'{node_name} {ret.node_status[node_name]} {expl_str}\n')

exit(0)
