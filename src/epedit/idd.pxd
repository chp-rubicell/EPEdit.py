from libcpp.string cimport string
from libcpp.vector cimport vector
from libcpp.unordered_map cimport unordered_map
from libcpp cimport bool as cbool

from lexer cimport Lexer

# * Field and class definition

# store extensible field names as Prefix + # + Suffix
# ex. "Vertex 1 X-coordinate" -> "Vertex ", " X-coordinate"
cdef struct ExtPattern:
    string prefix
    string suffix
    string search_prefix  # for searching (lowercase)
    string search_suffix  # for searching (lowercase)

# IDD extensible field properties (used in ClassDef)
cdef struct ExtensibleDef:
    cbool is_extensible
    int begin_index  # start index of the extensible fields
    int size  # size of the extensible fields (ex. X, Y, Z coords -> 3)
    vector[ExtPattern] patterns

# IDD field definition (ex. Outside_Boundary_Condition)
cdef struct FieldDef:
    string name
    cbool required
    string units
    string default_val
    cbool autosizable
    cbool autocalculatable
    string field_type  # alpha, real, integer, choice, etc.
    vector[string] choices  # possible values for "\type choice"

# IDD class definition (ex. Building, Zone)
cdef struct ClassDef:
    string name  # original name with capitalization
    string group  # \group
    vector[FieldDef] fields  # array of FieldDefs
    int min_fields
    unordered_map[string, int] base_field_index_map  # for fast indexing of fields (lowercase)
    ExtensibleDef extensible
    vector[int] field_idx_with_default  # field indices with default value

# IDD object (C++ side) that contains all of the definitions
cdef struct c_IDD:
    string version
    unordered_map[string, size_t] class_map  # map for fast search (uppercase class name -> ordered_classes idx)
    vector[ClassDef] ordered_classes  # for preserving order during export
    # ! if more are added, must be initialized in parse_idd()

# Returns parsed c_IDD struct using Lexer.
cdef int parse_idd(Lexer lexer, c_IDD& c_idd) except -1 nogil

# Python wrapper for the C++ c_IDD data structure.
cdef class IDD:
    cdef c_IDD c_idd
    cdef cbool initialized  # to check if already initialized
