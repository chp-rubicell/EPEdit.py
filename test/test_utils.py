# -*- coding: utf-8 -*-
import sys
from pathlib import Path
sys.path.append(str(Path("../src/epedit").resolve()))

import utils

def run_test():
    print(repr(utils.test_to_lower("ssd!@SFD")))
    print(repr(utils.test_to_upper("ssd!@SFD")))
    print(repr(utils.test_trim_string("  A$ test\n\t")))
    print()
    print(repr(utils.test_has_prefix("test", "te")))
    print(repr(utils.test_has_prefix("test", "st")))
    print(repr(utils.test_has_prefix("test", "")))
    print()
    print(repr(utils.test_has_suffix("test", "te")))
    print(repr(utils.test_has_suffix("test", "st")))
    print(repr(utils.test_has_suffix("test", "")))
    print()
    print(repr(utils.test_cut_prefix("test", "te")))
    print(repr(utils.test_cut_prefix("test", "st")))

if __name__ == "__main__":
    run_test()
