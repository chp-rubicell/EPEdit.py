# -*- coding: utf-8 -*-
import sys
from pathlib import Path
sys.path.append(str(Path("../src").resolve()))

from epedit import IDD, IDF

def test_idf():
    idd = IDD.from_file("./idds/V24-2-0-Energy+.idd")
    idf = IDF.from_file(idd, "./files/RefBldgMediumOfficeNew2004_Chicago.idf")

if __name__ == "__main__":
    test_idf()
