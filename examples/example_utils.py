# -*- coding: utf-8 -*-
import sys
from pathlib import Path
sys.path.append(str(Path("../src/epedit").resolve()))

import utils

def example_utils():
    print()
    print("== Basics ====")
    print(repr(utils.debug_to_lower("ssd!@SFD")))
    print(repr(utils.debug_to_upper("ssd!@SFD")))
    print(repr(utils.debug_equal_fold("ssd!@SFD가", "SsD!@sfD가")))
    print(repr(utils.debug_trim_string("  A$ test\n\t")))
    print(repr(utils.debug_trim_newlines("\n\r  A$ test\n\t\n")))

    print()
    print("== has_prefix test ====")
    print(repr(utils.debug_has_prefix("test", "te")))
    print(repr(utils.debug_has_prefix("test", "st")))
    print(repr(utils.debug_has_prefix("test", "")))

    print()
    print("== has_suffix test ====")
    print(repr(utils.debug_has_suffix("test", "te")))
    print(repr(utils.debug_has_suffix("test", "st")))
    print(repr(utils.debug_has_suffix("test", "")))

    print()
    print("== cut_prefix test ====")
    print(repr(utils.debug_cut_prefix("test", "te")))
    print(repr(utils.debug_cut_prefix("test", "st")))
    print(repr(utils.debug_cut_prefix("test", "")))

    print()
    print("== cut_suffix test ====")
    print(repr(utils.debug_cut_suffix("test", "te")))
    print(repr(utils.debug_cut_suffix("test", "st")))
    print(repr(utils.debug_cut_suffix("test", "")))

    print()
    print("== get_current_time test ====")
    print(repr(utils.debug_get_current_time()))

    print()

if __name__ == "__main__":
    example_utils()
