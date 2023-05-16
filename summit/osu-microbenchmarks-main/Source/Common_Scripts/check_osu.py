#!/usr/bin/env python3

import os
import sys

current_dir = os.getcwd()
os.chdir("workdir")
files_in_dir = os.listdir('.')

def check_file(result):
    hashes_done = False
    def should_be_numeric(c):
        if c == "Hello_World":
            return False
        elif c == "Init":
            return False
        return True

    def check_numeric_columns(ln, c):
        ln = ln.strip().split()
        # Barrier tests only have 1 column
        if "Barrier" in c:
            print("Checking barrier")
            if not ln[0].replace('.', '', 1).isnumeric():
                return False
        else:
            if not ln[0].isnumeric():
                return False
            if not ln[1].replace('.', '', 1).isnumeric():
                return False
        return True

    line_num = 1
    num_numeric_lines = 0
    got_title_line = False
    code = ''
    # Cuts out osu_ and .out
    short_name = result[4:len(result)-4]
    labels = []
    metric = ''
    last_line = ''
    with open(result, 'r') as f:
        for line in f:
            if len(line) > 1 and not got_title_line:
                got_title_line = True
                # then in the form "# OSU MPI-ROCM Reduce Latency Test v5.7.1"
                line = line.split()
                mode = line[2] # MPI, MPI-ROCM
                code = '_'.join(line[3:len(line)-2])
                line = ' '.join(line)  # reform the line so the other conditionals work
                print(f"Processing {mode} {code}")
            if not hashes_done and len(line) > 1:
                if not line.startswith('#'):
                    hashes_done = True
                    # Last line is the labels
                    labels_tmp = last_line.strip().split()
                    # TODO: Condense entries so that ['Avg', 'Latency(us)'] is combined
                    if labels_tmp[1] == 'Size':
                        # Add ['#', 'Size']
                        labels.extend(labels_tmp[0:2])
                        tmplabel = []
                        for i in range(2, len(labels_tmp)):
                            if not '(' in labels_tmp[i]:
                                tmplabel.append(labels_tmp[i])
                            else:
                                tmplabel.append(labels_tmp[i])
                                labels.append('-'.join(tmplabel))
                                tmplabel = []
                        print(f"Found the fields: {labels[2:]}")
                    else:
                        print(f"Assuming only one line. Fields: {labels[1:]}")
            if hashes_done and len(line) > 1:
                if should_be_numeric(code) and not check_numeric_columns(line, code):
                    if num_numeric_lines > 0:
                        print(f"In file {result}[{line_num}]: {line}")
                        return False
                    else:
                        print(f"Non-numeric line appeared before any numeric lines: {line}")
                elif should_be_numeric(code):
                    num_numeric_lines += 1
                else:
                    print(f"Found startup code")
                    # then this should be the startup suite
                    if not 'This is a test' in line or not 'nprocs' in line:
                        print(f"Detected a startup code, but did not have the required substrings")
                        return False
            last_line = line
            line_num += 1
    if num_numeric_lines < 1:
        print(f"{num_numeric_lines} is less than 1.")
        return False
    return True

ret_code = 0
for f in files_in_dir:
    if f.startswith("osu") and f.endswith(".out"):
        # then check to make sure it matches expected format
        if not check_file(f):
            ret_code = 1

os.chdir(current_dir)

sys.exit(ret_code)
