# -*- coding: utf-8 -*-
import sys
from pathlib import Path
sys.path.append(str(Path("../src").resolve()))

from epedit import IDD, IDF

# * Open IDD and IDF files

# Load the EnergyPlus IDD schema.
idd = IDD.from_file("idds/V24-2-0-Energy+.idd")

# Load an existing IDF file using the parsed IDD.
idf = IDF.from_file(idd, "files/input.idf")

# * Find and update objects

# Find an object by class name and object name.
building = idf.get_object_by_name("Building", "My Building")

# Update fields by their IDD field names.
building["North Axis"] = 0.0
building["Terrain"] = "City"

# Update multiple fields
building.update({
    "Maximum Number of Warmup Days": 50,
    "Minimum Number of Warmup Days": 5,
})

print(building)

# * Add new objects

# Add a new object with initial field values.
obj = idf.add_object(
    "RunPeriod",
    {
        "Name":                      "New Annual Run",
        "Begin Month":               1,
        "Begin Day of Month":        1,
        "End Month":                 12,
        "End Day of Month":          31,
        "Day of Week for Start Day": "Monday",
    },
)

# Add a new object without default values.
obj = idf.add_object(
    "Material",
    {
    "Name":          "New Insulation",
    "Thickness":     0.05,
    "Conductivity":  0.0314,
    "Density":       265,
    "Specific Heat": 836.8,
    },
    False,
)

# * Remove objects

# Remove an object
obj = idf.get_object_by_name("RunPeriod", "annual")

success = idf.remove_object(obj)

# * Save IDF files

# Save the modified IDF file.
idf.save("files/output.idf")
