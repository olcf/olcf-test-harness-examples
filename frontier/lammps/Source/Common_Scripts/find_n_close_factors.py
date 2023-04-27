#!/usr/bin/env python3

################################################################################
# Finds close factors of a number to create a near-square box, n
# Author: Nick Hagerty
# Last Modified: Nov 5, 2021
################################################################################

import sys

if len(sys.argv) < 2:
    print("Usage: ./find_n_close_factors.py <nFactors> <n>")
    sys.exit(1)


def get_prime_factors(n):
    # helper method
    def get_smallest_prime_factor(num):
        i = 2
        while i * i <= n:
            if n % i == 0:
                return i
            i += 1
        return n
    # list of factors
    factors = []
    while True:
        next_smallest = get_smallest_prime_factor(n)
        factors.append(next_smallest)
        n /= next_smallest
        if n == 1:
            return factors

def get_n_factors(factors, n_fact):
    # helper method
    def find_min_pos(factors_n):
        min_pos = 0
        pos = 0
        while pos < len(factors_n):
            if factors_n[pos] < factors_n[min_pos]:
                min_pos = pos
            pos += 1
        return min_pos
    # assume largest factors are at the end, since list is reverse-sorted
    index = len(factors) - 1
    factors_n = [1] * n_fact
    while index >= 0:
        to_mult = find_min_pos(factors_n)
        factors_n[to_mult] = factors_n[to_mult] * factors[index]
        index -= 1
    return factors_n

if __name__ == '__main__':
    n_fact = int(sys.argv[1])
    n = int(sys.argv[2])
    factors = get_prime_factors(n)
    list_factors = [ str(int(a)) for a in get_n_factors(factors, n_fact) ]
    print(' '.join(list_factors))

