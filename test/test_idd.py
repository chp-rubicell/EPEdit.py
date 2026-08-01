# -*- coding: utf-8 -*-
import sys
from pathlib import Path
sys.path.append(str(Path("../src/epedit").resolve()))

from idd import IDD, test_find_field_index, test_get_field_name

def test_idd_parser(file_path: str):
    idd = IDD.from_file(file_path)

    print("====")
    print("Parse test")
    print(idd.num_classes)

    for i in range(min(10, idd.num_classes)):
    # for i in range(idd.num_classes):
        print(idd.get_class_name(i))

    print()
    print("====")
    print("Find field index test")
    print(test_find_field_index(idd, "BuildingSurface:Detailed", "Zone Name"))  # 3
    print(test_find_field_index(idd, "BuildingSurface:Detailed", "Vertex 10 X-coordinate"))  # 38
    print(test_find_field_index(idd, "BuildingSurface:Detailed", "Vertex 30 X-coordinate"))  # 98
    print(test_find_field_index(idd, "BuildingSurface:Detailed", "Vertex 30 Z-coordinate"))  # 100

    print()
    print("====")
    print("Get field name test")
    print(test_get_field_name(idd, "BuildingSurface:Detailed", 3, True))
    print(test_get_field_name(idd, "BuildingSurface:Detailed", 38, True))
    print(test_get_field_name(idd, "BuildingSurface:Detailed", 98, True))
    print(test_get_field_name(idd, "BuildingSurface:Detailed", 100, True))

if __name__ == "__main__":
    test_idd_parser("../dev/idds/V24-2-0-Energy+.idd")
