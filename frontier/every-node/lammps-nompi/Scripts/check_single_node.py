#!/usr/bin/env python3

import argparse
import os
import re

parser = argparse.ArgumentParser(description="Flexible check script for LAMMPS")
parser.add_argument('--prefix', type=str, default='.', action='store', help="Relative or absolute path of directory to search for LAMMPS log files.")
parser.add_argument('--rfp', type=str, default='./validation/lammps-validation.log', action='store', help="Relative or absolute path of LAMMPS RFP log file.")
parser.add_argument('--printfom', default=False, action='store_true', help="If True, prints the FOM in parentheses for each successful run.")
parser.add_argument('--quiet', default=False, action='store_true', help="If True, only prints the SUCCESS/FAIL message at the end.")

args = parser.parse_args()

# Given a file name, these 2 functions check for the important bits, then report metrics from them

# Eventually, we should add ref files for each system and rank combination for validation
def check_file(f):
    """ Checks for graceful exits of LAMMPS runs """
    found_walltime_line = False
    reached_run = False
    completed_run = False
    state = 'SUCCESS'
    message = ''
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
                        return ['FAIL', 'Bus error detected']
                    elif 'MPICH ERROR' in line:
                        return ['FAIL', 'MPI error detected']
                    elif 'Memory access fault' in line:
                        return ['FAIL', 'Memory access fault detected']
                # else the line passes
            elif 'HSA_STATUS_ERROR' in line:
                hsa_err = [ a for a in line.replace(':', '').split() if a.startswith('HSA_STATUS') ]
                t_status = 'FAIL'
                if not 'APERTURE' in hsa_err[0]:
                    t_status = 'HW-FAIL'
                return [t_status, f'Detected HSA status error: {hsa_err[0]}']
            elif 'Bus error' in line:
                return ['FAIL', 'Bus error detected']
            elif 'MPICH ERROR' in line:
                return ['FAIL', 'MPI error detected']
            elif 'Memory access fault' in line:
                return ['FAIL', 'Memory access fault detected']

    if not completed_run:
        if not args.quiet:
            print(f"Did not detect the LAMMPS run completed gracefully")
        state = 'FAIL'
        if message == '':
            message = 'Did not find Loop time line'
    elif not found_walltime_line:
        if not args.quiet:
            print(f"Did not find walltime line")
        state = 'FAIL'
        if message == '':
            message = 'LAMMPS run failed between end of simulation and program exit'
    return [state, message]

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
                    if not args.quiet:
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
        if not args.quiet:
            print(f"Simulations of different lengths found: {len(sim1)} != {len(sim2)}. Aborting energy breakdown check.")
        return False
    correct = True
    for i in range(0, len(sim1)):
        if not check_step(sim1[i], sim2[i]):
            if not args.quiet:
                print(f"check_step failed at step: {sim1[i]['Step']}")
            correct = False
    return correct

# Returns [status_code, perf_metric, message]
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
        if not args.quiet:
            print(f"Did not find loop time line")
        return [1, 'did not find loop time line in log file']
    loop_time_line = loop_time_line.split()
    # natoms * steps /s
    atom_steps_per_sec = float(loop_time_line[11]) * float(loop_time_line[8]) / float(loop_time_line[3])
    # A typical Frontier node hits about 24mil-atom-steps-per-second
    target = 2600000
    if atom_steps_per_sec < target * 0.80:
        return [1, atom_steps_per_sec, f"Performance: {atom_steps_per_sec}, missed target of 80% x {target}"]
    else:
        return [0, atom_steps_per_sec, f"Perf check passed with {atom_steps_per_sec}"]

if not args.quiet:
    print(f"Searching {args.prefix} for runs")

# This just aggregates a bunch of stuff I want to track
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

log_file_regex = re.compile('lammps-[0-8]{1}.log')

for f in os.listdir(f"{args.prefix}"):
    if log_file_regex.match(f):
        if not args.quiet:
            print(f"Checking: {f}")
        ret.num_logs += 1
        if not f in ret.node_status:
            ret.node_status[f] = 'SUCCESS'
            ret.reasons[f] = 'NONE'
        check_result = check_file(f"{args.prefix}/{f}")
        if not check_result[0] == 'SUCCESS':
            ret.failed += 1
            ret.node_status[f] = check_result[0]
            ret.reasons[f] = check_result[1]
            continue
        if not energy_breakdown(f"{args.rfp}", f"{args.prefix}/{f}"):
            ret.incorrect_answers += 1
            ret.node_status[f] = 'INCORRECT'
            ret.reasons[f] = 'energy breakdown failed'
        else:
            perf_level, perf_metric, perf_reason = check_performance(f"{args.prefix}/{f}")
            if perf_level == 1:
                ret.node_status[f] = 'PERF-FAIL'
                ret.reasons[f] = perf_reason
            if args.printfom:
                ret.reasons[f] = int(perf_metric)  # units are atoms x steps/s

for f in ret.node_status.keys():
    print(f'{f}: {ret.node_status[f]} ({ret.reasons[f]})')
