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
    print("== Set multiple values test ====")
    obj.update({
        98: 12.3,  # Vertex 30 X-coordinate
        "Vertex 30 Y-coordinate": 12.4,
        99: 12.45,  # Vertex 30 Y-coordinate
        "Vertex 30 Z-coordinate": 12.5,
        101: "",
    })
    print(obj["Vertex 30 X-coordinate"], obj["Vertex 30 Y-coordinate"], obj["Vertex 30 Z-coordinate"], obj["Vertex 31 X-coordinate"])

    print()
    print("== Get object test ====")
    objs = idf.get_objects("BuildingSurface:Detailed".lower())
    print(len(objs))
    print([obj['name'] for obj in objs[:10]] + ["..."])
    print()
    print(idf.get_object_by_name("BuildingSurface:Detailed", "Core_bot_ZN_5_Wall_East"))
    print(idf.get_object_by_name("BuildingSurface:Detailed", "asdf"))

    print()
    print("== Add object test ====")
    new_objs = []
    for i in range(3):
        obj = idf.add_object("BuildingSurface:Detailed")
        new_objs.append(obj)
        print(obj.obj_idx, ":", obj)

    print()
    print("== Default values test ====")
    obj = idf.add_object("OutputControl:Files", default_values=False)
    print(repr(obj["Output CSV"]))
    obj = idf.add_object("OutputControl:Files", default_values=True)
    print(repr(obj["Output CSV"]))
    obj = idf.add_object("OutputControl:Files", initial_values={"Output CSV": True})
    print(repr(obj["Output CSV"]))

    print()
    print("== Remove object test ====")
    print(len(idf.get_objects("BuildingSurface:Detailed")))
    for obj in new_objs:
        print(["Failed","Removed"][idf.remove_object(obj)])
    print(len(idf.get_objects("BuildingSurface:Detailed")))
    print(f"{idf.remove_all_objects('BuildingSurface:Detailed')} objects removed.")
    print(idf.get_objects("BuildingSurface:Detailed"))

    print()

def test_idf_format():
    idd = IDD.from_file("./idds/V24-2-0-Energy+.idd")
    # idf = IDF.from_file(idd, "./files/RefBldgMediumOfficeNew2004_Chicago.idf")
    idf = IDF.from_file(idd, "./files/test.idf")

    # obj = idf.get_objects("BuildingSurface:Detailed".lower())[0]
    # obj["Vertex 4 X-coordinate"] = 0.0
    # obj["Vertex 4 Y-coordinate"] = 0.0
    # print(obj)

    # new_obj = idf.add_object("BuildingSurface:Detailed", default_values=False)
    # print(new_obj)

    print()
    print("== Default format ====")
    print(idf.format())
    print("====")

    print()
    print("== Default format (preserve order) ====")
    print(idf.format(preserve_order=True))
    print("====")

    print()
    print("== No indents ====")
    print(idf.format(0, 0, 0))
    print("====")

    print()
    print("== Compact mode ====")
    print(idf.format(compact=True))
    print("====")

def measure_idf_format_size():
    idd = IDD.from_file("./idds/V24-2-0-Energy+.idd")
    # idf = IDF.from_file(idd, "./files/RefBldgMediumOfficeNew2004_Chicago.idf")
    idf = IDF.from_file(idd, "/Applications/EnergyPlus-24-2-0/ExampleFiles/RefBldgOutPatientNew2004_Chicago.idf")

    total_obj_count = sum([len(objs) for objs in idf.objects.values()])

    print()
    print("== Default format ====")
    s = idf.format()
    print(len(s) / total_obj_count)
    print("====")

    print()
    print("== Default format (preserve order) ====")
    s = idf.format(preserve_order=True)
    print(len(s) / total_obj_count)
    print("====")

    print()
    print("== No indents ====")
    s = idf.format(0, 0, 0)
    print(len(s) / total_obj_count)
    print("====")

    print()
    print("== Compact mode ====")
    s = idf.format(compact=True)
    print(len(s) / total_obj_count)
    print("====")

def test_save():
    idd = IDD.from_file("./idds/V24-2-0-Energy+.idd")
    idf = IDF.from_file(idd, "./files/RefBldgMediumOfficeNew2004_Chicago.idf")

    # idf.save("./files/RefBldgMediumOfficeNew2004_Chicago_edited.idf")
    idf.save("./files/ExportTest.idf")

if __name__ == "__main__":
    # test_idf()
    # test_idf_format()
    # measure_idf_format_size()
    test_save()
