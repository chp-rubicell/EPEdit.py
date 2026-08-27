<p align="center">
    <a href="https://pypi.org/project/epedit/"><img src="https://github.com/chp-rubicell/EPEdit.py/raw/main/docs/assets/epeditpy.svg" width="300" alt="EPEdit.py" /></a>
    <br/>
    <a href="https://pypi.org/project/epedit/"><img src="https://img.shields.io/pypi/v/epedit.svg?style=flat-square&maxAge=600" alt="pypi" /></a>
</p>

**EPEdit.py** is a high-performance, *Cython-based* Python library for parsing, editing, and formatting EnergyPlus Input Data Files (`.idf`).

## Features

- **High Performance**: Core functionalities are implemented in *Cython* for fast and efficient parsing, editing, and serialization.
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

See [`examples/example_readme.py`](https://github.com/chp-rubicell/EPEdit.py/blob/main/examples/example_readme.py) for a complete example.

> [!NOTE]
> To use *EPEdit.py* with minimal changes to an existing [*eppy*](https://github.com/santoshphilip/eppy) codebase, see [eppy compatibility mode](#eppy-compatibility-mode).

### Import

```python
from epedit import IDD, IDF
```

### Open IDD and IDF files

```python
# Load the EnergyPlus IDD schema
idd = IDD.from_file("Energy+.idd")
```

```python
# Load an existing IDF file using the parsed IDD
idf = IDF.from_file(idd, "input.idf")

# Load IDF from string
idf = IDF.from_string(idd, "Version, 24.2;")
```

### Iterate over objects

```python
# Iterate over objects using idf[classname]
for sch_type_limits in idf["ScheduleTypeLimits"]:
    print(sch_type_limits["Name"])

# ... or idf.get_objects(classname)
for sch_type_limits in idf.get_objects("ScheduleTypeLimits"):
    print(sch_type_limits["Name"])
```
> ```
> Any Number
> Fraction
> Temperature
> On/Off
> Control Type
> Humidity
> Number
> ```

### Find and update objects

```python
# Find an object by class name and object name
building = idf.get_object_by_name("Building", "My Building")

# Update fields by their names
building["North Axis"] = 0.0
building["Terrain"] = "City"

# Update fields by their indices
building[5] = "FullExterior"

# Update multiple fields
building.update({
    "Maximum Number of Warmup Days": 50,
    "Minimum Number of Warmup Days": 5,
})

print(building)
```
> <pre>
> Building,
>     My Building,             !- Name
>     <b>0.0</b>,                     !- North Axis {deg}
>     <b>City</b>,                    !- Terrain
>     0.0400,                  !- Loads Convergence Tolerance Value {W}
>     0.2000,                  !- Temperature Convergence Tolerance Value {deltaC}
>     <b>FullExterior</b>,            !- Solar Distribution
>     <b>50</b>,                      !- Maximum Number of Warmup Days
>     <b>5</b>;                       !- Minimum Number of Warmup Days
> </pre>

### Add new objects

```python
# Add a new object with initial field values
obj = idf.add_object(
    "RunPeriod",
    {
        "Name"                      : "New Annual Run",
        "Begin Month"               : 1,
        "Begin Day of Month"        : 1,
        "End Month"                 : 12,
        "End Day of Month"          : 31,
        "Day of Week for Start Day" : "Monday",
    },
)
```

```python
# Add a new object without default values
obj = idf.add_object(
    "Material",
    {
        "Name"          : "New Insulation",
        "Thickness"     : 0.05,
        "Conductivity"  : 0.0314,
        "Density"       : 265,
        "Specific Heat" : 836.8,
    },
    False,
)
```

### Remove objects

```python
obj = idf.get_object_by_name("RunPeriod", "annual")

idf.remove_object(obj)
```

### Find referenced/referencing objects
```python
# Find referenced object
surf = idf["BuildingSurface:Detailed"][0]
print(surf)
zone = surf.get_referenced_object("Zone Name")
print(zone)
```
> <pre>
> BuildingSurface:Detailed,
>     Building_Roof,           !- Name
>     Roof,                    !- Surface Type
>     IEAD Non-res Roof,       !- Construction Name
>     <b>TopFloor_Plenum</b>,         !- Zone Name
>     ...
> </pre>
> <pre>
> Zone,
>     <b>TopFloor_Plenum</b>,         !- Name
>     0.0000,                  !- Direction of Relative North {deg}
>     0.0000,                  !- X Origin {m}
>     0.0000,                  !- Y Origin {m}
>     ...
> </pre>

```python
# Find referencing objects
referencers = zone.get_referencing_objects("Name")
print(len(referencers))
print(set(obj.class_name for obj in referencers))
```
> ```
> 12
> {'AirLoopHVAC:ReturnPlenum', 'BuildingSurface:Detailed', 'ZoneInfiltration:DesignFlowRate'}
> ```

### Save IDF files
```python
idf.save("output.idf")
```


## *eppy* compatibility mode

If you have an existing codebase that uses [*eppy*](https://github.com/santoshphilip/eppy), you can use *EPEdit.py* in compatibility mode with minimal changes to your code while benefiting from significant performance improvements.

**Simply replace:**

```python
from eppy.modeleditor import IDF
```

**with:**

```python
from epedit.eppy import IDF
```

See [`examples/example_eppy.py`](https://github.com/chp-rubicell/EPEdit.py/blob/main/examples/example_eppy.py) for a complete example.

> [!NOTE]
> Compatibility mode has not been tested with every *eppy* feature.


## Related projects

<p align="center">
    &nbsp;&nbsp;&nbsp;&nbsp;<a href="https://github.com/chp-rubicell/EPEdit.go"><img src="https://github.com/chp-rubicell/EPEdit.go/raw/main/_assets/epeditgo.svg" width="200" alt="EPEdit.go" /></a>&nbsp;&nbsp;&nbsp;&nbsp;
    &nbsp;&nbsp;&nbsp;&nbsp;<a href="https://github.com/chp-rubicell/EPEdit.js"><img src="https://github.com/chp-rubicell/EPEdit.js/raw/main/doc/epedit.svg" width="200" alt="EPEdit.js" /></a>&nbsp;&nbsp;&nbsp;&nbsp;
</p>


## License

Distributed under the [MIT License](https://github.com/chp-rubicell/EPEdit.py/blob/main/LICENSE).
