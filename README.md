<p align="center">
    <a href="https://pypi.org/project/epedit/"><img src="https://github.com/chp-rubicell/EPEdit.py/raw/main/docs/assets/epeditpy.svg" width="300" alt="EPEdit.py" /></a>
    <br/>
    <a href="https://pypi.org/project/epedit/"><img src="https://img.shields.io/pypi/v/epedit.svg?style=flat-square&maxAge=600" alt="pypi" /></a>
</p>

**EPEdit.py** is a high-performance, *Cython-based* Python library for parsing, editing, and formatting EnergyPlus Input Data Files (`.idf`).

## Features

- **Parse IDF Files**: Load `.idf` file content into a structured object model.
- **Modify IDF**: Create, update, or delete any object within the IDF model.
- **Find IDF Objects**: Easily find and retrieve objects by their type (e.g., `Building`, `Material`) and name.
- **Modify Fields**: Get and set values for any field of an IDF object.
- **Export to IDF**: Serialize the modified model back into a valid `.idf` file string.


## Installation

```bash
pip install epedit
```


## Usage

See `examples/example_readme.py`.

### Open IDD and IDF files

```python
from epedit import IDD, IDF

# Load the EnergyPlus IDD schema.
idd = IDD.from_file("Energy+.idd")

# Load an existing IDF file using the parsed IDD.
idf = IDF.from_file(idd, "input.idf")
```

### Find and update objects

```python
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
```
```
Building,
    My Building,             !- Name
    0.0,                     !- North Axis {deg}
    City,                    !- Terrain
    0.0400,                  !- Loads Convergence Tolerance Value {W}
    0.2000,                  !- Temperature Convergence Tolerance Value {deltaC}
    FullInteriorAndExterior, !- Solar Distribution
    50,                      !- Maximum Number of Warmup Days
    5;                       !- Minimum Number of Warmup Days
```

### Add new objects

```python
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
```

### Remove objects

```python
# Remove an object
obj = idf.get_object_by_name("RunPeriod", "annual")
success = idf.remove_object(obj)
```

### Save IDF files
```python
# Save the modified IDF file.
idf.save("output.idf")
```


## Related projects

<p align="center">
    <a href="https://github.com/chp-rubicell/EPEdit.go"><img src="https://github.com/chp-rubicell/EPEdit.go/raw/main/_assets/epeditgo.svg" width="200" alt="EPEdit.go" /></a>
    &nbsp;&nbsp;&nbsp;&nbsp;
    <a href="https://github.com/chp-rubicell/EPEdit.js"><img src="https://github.com/chp-rubicell/EPEdit.js/raw/main/doc/epedit.svg" width="200" alt="EPEdit.js" /></a>
</p>


## License

Distributed under the [MIT License](https://github.com/chp-rubicell/EPEdit.py/blob/main/LICENSE).
