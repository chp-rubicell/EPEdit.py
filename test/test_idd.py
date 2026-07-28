# -*- coding: utf-8 -*-
import sys
from pathlib import Path
sys.path.append(str(Path("../src/epedit").resolve()))

from idd import IDD

def test_idd_parser(file_path: str):
    idd = IDD.from_file(file_path)

    print(idd.num_classes)

    for i in range(min(10, idd.num_classes)):
    # for i in range(idd.num_classes):
        print(idd.get_class_name(i))

if __name__ == "__main__":
    test_idd_parser("../dev/idds/V24-2-0-Energy+.idd")
