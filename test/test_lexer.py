# -*- coding: utf-8 -*-
import sys
from pathlib import Path
sys.path.append(str(Path("../src/epedit").resolve()))

from lexer import Lexer

# test data (as byte)
mock_idd_data = rb"""
! **************************************************************************

\group Simulation Parameters

Version,
      \memo Specifies the EnergyPlus version of the IDF file.
      \unique-object
      \format singleLine
  A1 ; \field Version Identifier
      \default 24.2

SimulationControl,
      \unique-object
      \memo Note that the following 3 fields are related to the Sizing:Zone, Sizing:System,
      \memo and Sizing:Plant objects. Having these fields set to Yes but no corresponding
      \memo Sizing object will not cause the sizing to be done. However, having any of these
      \memo fields set to No, the corresponding Sizing object is ignored.
      \memo Note also, if you want to do system sizing, you must also do zone sizing in the same
      \memo run or an error will result.
      \min-fields 7
  A1, \field Do Zone Sizing Calculation
      \note If Yes, Zone sizing is accomplished from corresponding Sizing:Zone objects
      \note and autosize fields.
      \type choice
      \key Yes
      \key No
      \default No
  A2, \field Do System Sizing Calculation
      \note If Yes, System sizing is accomplished from corresponding Sizing:System objects
      \note and autosize fields.
      \note If Yes, Zone sizing (previous field) must also be Yes.
      \type choice
      \key Yes
      \key No
      \default No
  A3, \field Do Plant Sizing Calculation
      \note If Yes, Plant sizing is accomplished from corresponding Sizing:Plant objects
      \note and autosize fields.
      \type choice
      \key Yes
      \key No
      \default No
  A4, \field Run Simulation for Sizing Periods
      \note If Yes, SizingPeriod:* objects are executed and results from those may be displayed..
      \type choice
      \key Yes
      \key No
      \default Yes
  A5, \field Run Simulation for Weather File Run Periods
      \note If Yes, RunPeriod:* objects are executed and results from those may be displayed..
      \type choice
      \key Yes
      \key No
      \default Yes
  A6, \field Do HVAC Sizing Simulation for Sizing Periods
      \note If Yes, SizingPeriod:* objects are executed additional times for advanced sizing.
      \note Currently limited to use with coincident plant sizing, see Sizing:Plant object
      \type choice
      \key Yes
      \key No
      \default No
  N1; \field Maximum Number of HVAC Sizing Simulation Passes
      \note the entire set of SizingPeriod:* objects may be repeated to fine tune size results
      \note this input sets a limit on the number of passes that the sizing algorithms can repeat the set
      \type integer
      \minimum 1
      \default 1
"""
mock_idf_data = b"""
! ==========================================
! This is a test IDF file
! ==========================================
Version, 8.9;

Zone,
  Test Zone 1, ! This is a zone name
  0.0,         ! X
  0.0,         ! Y
  0.0;         ! Z

  ! Empty lines and spaces above should be ignored
"""

def run_test():
    #? Test IDD
    print("Testing IDD")

    lexer = Lexer(mock_idd_data, True)
    tokens = lexer.test()

    # Print result
    print(f"{'TYPE':<5} | {'VALUE'}")
    print("-" * 30)
    for t_type, t_value in tokens:
        print(f"{t_type:<5} | {repr(t_value)}")

    #? Test IDF
    print()
    print("Testing IDF")

    lexer = Lexer(mock_idf_data, False)
    tokens = lexer.test()

    # Print result
    print(f"{'TYPE':<5} | {'VALUE'}")
    print("-" * 30)
    for t_type, t_value in tokens:
        print(f"{t_type:<5} | {repr(t_value)}")

if __name__ == "__main__":
    run_test()
