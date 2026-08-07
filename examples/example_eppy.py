# -*- coding: utf-8 -*-
import sys
from pathlib import Path
sys.path.insert(0, str(Path("../src").resolve()))

from epedit.eppy import IDF
# from eppy.modeleditor import IDF

def example_eppy():
    IDF.setiddname(Path("./idds/V24-2-0-Energy+.idd"))
    idf = IDF(Path("./files/RefBldgMediumOfficeNew2004_Chicago.idf"))

    print()
    print("== Parse test ====")
    obj = idf.idfobjects["BuildingSurface:Detailed".upper()][0]
    print(obj)

    print()
    print("== Get value test ====")
    print(type(obj.Number_of_Vertices), repr(obj.Number_of_Vertices))
    print(type(obj.Vertex_1_Xcoordinate), repr(obj.Vertex_1_Xcoordinate))
    print(type(obj.Vertex_10_Xcoordinate), repr(obj.Vertex_10_Xcoordinate))

    print()
    print("== Set value test ====")
    print(type(obj.Vertex_10_Xcoordinate), repr(obj.Vertex_10_Xcoordinate))

    print()
    print("== Get object test ====")
    print(idf.getobject("BuildingSurface:Detailed", "Core_bot_ZN_5_Wall_East"))
    print(idf.getobject("BuildingSurface:Detailed", "asdf"))
    '''
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
    '''

if __name__ == "__main__":
    example_eppy()
