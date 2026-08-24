import pytest
from pathlib import Path
from epedit import IDD, IDF
from epedit.idd import debug_find_field_index, debug_get_field_name

TEST_DIR = Path(__file__).resolve().parent  # tests/


# * Fixtures for common loading

@pytest.fixture(scope="module")
def idd():
    """Load IDD"""
    return IDD.from_file(str(TEST_DIR/"data/V24-2-0-Energy+.idd"))

# @pytest.fixture(scope="module")
@pytest.fixture
def idf(idd: IDD):
    return IDF.from_file(
        idd,
        str(TEST_DIR/"data/RefBldgMediumOfficeNew2004_Chicago.idf")
    )

# @pytest.fixture(scope="module")
@pytest.fixture
def idf_simple(idd: IDD):
    return IDF.from_file(
        idd,
        str(TEST_DIR/"data/test.idf")
    )


# * IDD test

def test_idd_parser(idd: IDD):
    assert idd.num_classes == 848

def test_idd_fields(idd: IDD):

    class_names_head = ["Version", "SimulationControl", "PerformancePrecisionTradeoffs", "Building", "ShadowCalculation", "SurfaceConvectionAlgorithm:Inside", "SurfaceConvectionAlgorithm:Outside", "HeatBalanceAlgorithm", "HeatBalanceSettings:ConductionFiniteDifference", "ZoneAirHeatBalanceAlgorithm"]
    for i, class_name in enumerate(class_names_head):
        assert idd.get_class_name(i) == class_name

    assert debug_find_field_index(idd, "BuildingSurface:Detailed", "Zone Name") == 3
    assert debug_find_field_index(idd, "BuildingSurface:Detailed", "Vertex 10 X-coordinate") == 38
    assert debug_find_field_index(idd, "BuildingSurface:Detailed", "Vertex 30 X-coordinate") == 98
    assert debug_find_field_index(idd, "BuildingSurface:Detailed", "Vertex 30 Z-coordinate") == 100

    assert debug_get_field_name(idd, "BuildingSurface:Detailed", 3, True) == "Zone Name"
    assert debug_get_field_name(idd, "BuildingSurface:Detailed", 38, True) == "Vertex 10 X-coordinate {m}"
    assert debug_get_field_name(idd, "BuildingSurface:Detailed", 98, True) == "Vertex 30 X-coordinate {m}"
    assert debug_get_field_name(idd, "BuildingSurface:Detailed", 100, True) == "Vertex 30 Z-coordinate {m}"


# * IDF test

def test_idf_get_and_set_values(idf: IDF):

    # ——— Parse test ——————
    obj = idf["BuIldIngsurFAce:detaiLed"][0]
    assert obj.class_name == "BuildingSurface:Detailed"
    assert obj[2] == obj["Construction Name"]

    # ——— Get value test ——————
    assert type(obj["Number of Vertices"]).__name__ == "str"
    assert obj["Number of Vertices"] == "4"
    assert type(obj["Vertex 1 X-coordinate"]).__name__ == "float"
    assert obj["Vertex 1 X-coordinate"] == 49.911
    assert type(obj["Vertex 10 X-coordinate"]).__name__ == "NoneType"
    assert obj["Vertex 10 X-coordinate"] is None
    assert type(idf["SimulationControl"][0]["Maximum Number of HVAC Sizing Simulation Passes"]).__name__ == "int"
    assert idf["SimulationControl"][0]["Maximum Number of HVAC Sizing Simulation Passes"] == 1

    assert obj.get_values() == ['Building_Roof', 'Roof', 'IEAD Non-res Roof', 'TopFloor_Plenum', '', 'Outdoors', '', 'SunExposed', 'WindExposed', 'Autocalculate', '4', 49.911, 0.0, 11.8872, 49.911, 33.2738, 11.8872, 0.0, 33.2738, 11.8872, 0.0, 0.0, 11.8872]

    # ——— Set value test ——————

    obj["Vertex 10 X-coordinate"] = 10
    assert type(obj["Vertex 10 X-coordinate"]).__name__ == "float"
    assert obj["Vertex 10 X-coordinate"] == 10.0

    # ——— Set multiple values test ——————
    obj.update({
        98: 12.3,  # Vertex 30 X-coordinate
        "Vertex 30 Y-coordinate": 12.4,
        99: 12.45,  # Vertex 30 Y-coordinate
        "Vertex 30 Z-coordinate": 12.5,
        101: "",
    })
    assert obj["Vertex 30 X-coordinate"] == 12.3
    assert obj["Vertex 30 Y-coordinate"] == 12.45
    assert obj["Vertex 30 Z-coordinate"] == 12.5
    assert obj["Vertex 31 X-coordinate"] is None


IDFOBJECT_STR_EXAMPLE = """BuildingSurface:Detailed,
    Core_bot_ZN_5_Wall_East, !- Name
    Wall,                    !- Surface Type
    int-walls,               !- Construction Name
    Core_bottom,             !- Zone Name
    ,                        !- Space Name
    Surface,                 !- Outside Boundary Condition
    Perimeter_bot_ZN_2_Wall_West,  !- Outside Boundary Condition Object
    NoSun,                   !- Sun Exposure
    NoWind,                  !- Wind Exposure
    AutoCalculate,           !- View Factor to Ground
    4,                       !- Number of Vertices
    45.3375,                 !- Vertex 1 X-coordinate {m}
    4.5732,                  !- Vertex 1 Y-coordinate {m}
    2.7432,                  !- Vertex 1 Z-coordinate {m}
    45.3375,                 !- Vertex 2 X-coordinate {m}
    4.5732,                  !- Vertex 2 Y-coordinate {m}
    0.0000,                  !- Vertex 2 Z-coordinate {m}
    45.3375,                 !- Vertex 3 X-coordinate {m}
    28.7006,                 !- Vertex 3 Y-coordinate {m}
    0.0000,                  !- Vertex 3 Z-coordinate {m}
    45.3375,                 !- Vertex 4 X-coordinate {m}
    28.7006,                 !- Vertex 4 Y-coordinate {m}
    2.7432;                  !- Vertex 4 Z-coordinate {m}
"""
def test_idf_object_management(idf: IDF):

    # ——— Get object test ——————
    surf_names_head = ['Building_Roof', 'Core_bot_ZN_5_Floor', 'Core_bot_ZN_5_Wall_East', 'Core_bot_ZN_5_Wall_North', 'Core_bot_ZN_5_Wall_South', 'Core_bot_ZN_5_Wall_West', 'Core_bottom_ceiling', 'Core_mid_ZN_5_Floor', 'Core_mid_ZN_5_Wall_East', 'Core_mid_ZN_5_Wall_North']

    objs = idf.get_objects("BuildingSurface:Detailed".lower())

    for i, surf_name in enumerate(surf_names_head):
        assert objs[i]["name"] == surf_name

    # ——— __repr__ test ——————
    assert str(idf.get_object_by_name("BuildingSurface:Detailed", "Core_bot_ZN_5_Wall_East")) == IDFOBJECT_STR_EXAMPLE


def test_idf_add_and_default_values(idf: IDF):

    # ——— Default values test ——————
    obj = idf.add_object("OutputControl:Files", default_values=False)
    assert obj["Output CSV"] == ""
    obj = idf.add_object("OutputControl:Files", default_values=True)
    assert obj["Output CSV"] == "No"
    obj = idf.add_object("OutputControl:Files", initial_values={"Output CSV": True})
    assert obj["Output CSV"] == "Yes"


def test_idf_remove_object(idf: IDF):

    # ——— Remove object test ——————
    # Count before adding
    assert len(idf.get_objects("BuildingSurface:Detailed")) == 128
    # Add three objs
    new_objs = [
        idf.add_object("BuildingSurface:Detailed")
        for _ in range(3)
    ]
    # Count after adding
    assert len(idf["buildinGsurFaCe:detailed"]) == 131
    # Remove
    for obj in new_objs:
        idf.remove_object(obj)
    # Count after deleting
    assert len(idf.get_objects("BuildingSurface:Detailed")) == 128
    # Delete all objects
    assert idf.remove_all_objects('BuildingSurface:Detailed') == 128
    # Count after
    assert len(idf.get_objects("buildinGsurFaCe:detailed")) == 0


IDF_FMT_DEFAULT_EXAMPLE = "! ***SIMULATION PARAMETERS***\n\nVersion,\n    24.2;                    !- Version Identifier\n\nSimulationControl,\n    YES,                     !- Do Zone Sizing Calculation\n    YES,                     !- Do System Sizing Calculation\n    YES,                     !- Do Plant Sizing Calculation\n    YES,                     !- Run Simulation for Sizing Periods\n    NO,                      !- Run Simulation for Weather File Run Periods\n    No,                      !- Do HVAC Sizing Simulation for Sizing Periods\n    1;                       !- Maximum Number of HVAC Sizing Simulation Passes\n\n! ***LOCATION AND CLIMATE***\n\nRunPeriodControl:SpecialDays,\n    New Years Day,           !- Name\n    January 1,               !- Start Date\n    1,                       !- Duration {days}\n    Holiday;                 !- Special Day Type\n\nRunPeriodControl:SpecialDays,\n    Veterans Day,            !- Name\n    November 11,             !- Start Date\n    1,                       !- Duration {days}\n    Holiday;                 !- Special Day Type"
IDF_FMT_COMPACT_EXAMPLE = "Version,24.2;\n\nSimulationControl,YES,YES,YES,YES,NO,No,1;\n\nRunPeriodControl:SpecialDays,New Years Day,January 1,1,Holiday;\nRunPeriodControl:SpecialDays,Veterans Day,November 11,1,Holiday;"
def test_idf_format_output(idf_simple: IDF):
    assert idf_simple.format(0, 4, 24) == IDF_FMT_DEFAULT_EXAMPLE
    assert idf_simple.format(compact=True) == IDF_FMT_COMPACT_EXAMPLE


def test_idf_references(idf: IDF):

    # ——— Basics ——————
    surf = idf["BuildingSurface:Detailed"][0]
    ref_zone = surf.get_referenced_object("Zone Name")
    assert ref_zone.class_name == "Zone"
    assert ref_zone["Name"] == surf["Zone Name"]

    zone = idf["Zone"][0]
    referencers = zone.get_referencing_objects("Name")
    assert len(referencers) == 15
    # print(referencers)

    # ——— Add object ——————
    surf["Zone Name"] = "test"
    assert surf.get_referenced_object("Zone Name") is None
    idf.add_object("Zone", ["test"])
    ref_zone = surf.get_referenced_object("Zone Name")
    assert ref_zone.class_name == "Zone"
    assert ref_zone["Name"] == "test"

    # ——— Remove object ——————
    idf.remove_object(referencers[0])
    assert sorted(set(obj.class_name for obj in zone.get_referencing_objects("Name"))) \
            == ['BuildingSurface:Detailed', 'ElectricEquipment', 'InternalMass', 'Lights', 'People', 'Sizing:Zone', 'WaterUse:Equipment', 'ZoneControl:Thermostat', 'ZoneHVAC:EquipmentConnections']

    referencer_count = len(zone.get_referencing_objects("Name"))
    assert referencer_count == 14
    referencing_surfs_count = len([
        obj
        for obj in zone.get_referencing_objects("Name")
        if obj.class_name.lower() == "BuildingSurface:Detailed".lower()
    ])
    assert referencing_surfs_count == 5
    idf.remove_all_objects("BuildingSurface:Detailed")
    assert referencer_count - referencing_surfs_count == len(zone.get_referencing_objects("Name"))
