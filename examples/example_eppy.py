# -*- coding: utf-8 -*-
import sys
from pathlib import Path
sys.path.append(str(Path("../src").resolve()))

# from epedit.eppy import IDF
from eppy.modeleditor import IDF


# * Open IDF files

# Load the EnergyPlus IDD schema.
IDF.setiddname("idds/V24-2-0-Energy+.idd")

# Load an existing IDF file.
idf = IDF("files/input.idf")

# * Iterate over objects

# Iterate over objects using idf.idfobjects[classname]
for sch_type_limits in idf.idfobjects["ScheduleTypeLimits"]:
    print(sch_type_limits.Name)

# * Find and update objects

# Find an object by class name and object name.
building = idf.getobject("Building", "My Building")

# Update fields by their IDD field names.
building.North_Axis = 0.0
building.Terrain = "City"

print(building)

# * Add new objects

# Add a new object with initial field values.
obj = idf.newidfobject(
    "RunPeriod",
    Name                      = "New Annual Run",
    Begin_Month               = 1,
    Begin_Day_of_Month        = 1,
    End_Month                 = 12,
    End_Day_of_Month          = 31,
    Day_of_Week_for_Start_Day = "Monday",
)

# Add a new object without default values.
obj = idf.newidfobject(
    "Material",
    defaultvalues = False,
    Name          = "New Insulation",
    Thickness     = 0.05,
    Conductivity  = 0.0314,
    Density       = 265,
    Specific_Heat = 836.8,
)

# * Remove objects

# Remove an object
obj = idf.getobject("RunPeriod", "annual")
idf.removeidfobject(obj)

# * Save IDF files

# Save the modified IDF file.
idf.save("files/output_eppy.idf")
