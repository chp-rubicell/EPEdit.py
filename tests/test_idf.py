# -*- coding: utf-8 -*-
import sys
from pathlib import Path
sys.path.append(str(Path("../src").resolve()))

from epedit import IDD, IDF

def test_idf():
    idd = IDD.from_file("./idds/V24-2-0-Energy+.idd")
    idf = IDF.from_file(idd, "./files/RefBldgMediumOfficeNew2004_Chicago.idf")

    print()
    print("== Parse test ====")
    obj = idf.get_objects("BuildingSurface:Detailed".lower())[0]
    print(obj.class_name)

    print()
    print("== Get value test ====")
    print(obj[2], "==", obj["Construction Name"])
    print(type(obj["Number of Vertices"]), repr(obj["Number of Vertices"]))
    print(type(obj["Vertex 1 X-coordinate"]), repr(obj["Vertex 1 X-coordinate"]))
    print(type(obj["Vertex 10 X-coordinate"]), repr(obj["Vertex 10 X-coordinate"]))

    print()
    print("== Set value test ====")
    obj["Vertex 10 X-coordinate"] = 10
    print(type(obj["Vertex 10 X-coordinate"]), repr(obj["Vertex 10 X-coordinate"]))

    print()
    print("== Get object test ====")
    for obj in idf.get_objects("BuildingSurface:Detailed".lower()):
        print(obj["Name"])
    print()
    print(idf.get_object_by_name("BuildingSurface:Detailed", "Core_bot_ZN_5_Wall_East"))
    print(idf.get_object_by_name("BuildingSurface:Detailed", "asdf"))

    print()

if __name__ == "__main__":
    test_idf()
