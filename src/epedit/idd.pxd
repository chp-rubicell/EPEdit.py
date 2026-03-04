from libcpp.string cimport string
from libcpp.vector cimport vector
from libcpp.unordered_map cimport unordered_map as cmap
from libcpp.pair cimport pair
from libcpp cimport bool as cbool

cdef struct EPField:
    string name
    string type
    string units
    cbool has_default
    string default

cdef struct EPExtensible:
    int start_idx # start index of the extensible fields
    int size # size of the extensible fields
    # vector[string] key_regexp # RegExp pattern for extensible field search
    vector[pair[string, string]] fields # prefix, suffix -> (prefix)(n)(suffix)

cdef struct EPClass:
    string name
    cmap[string, EPField] fields
    vector[string] fieldnames
    int last_default_field_idx # -2 indicates undefined/none, -1 indicates present but no fields yet
    cbool has_extensible
    EPExtensible extensible

cdef class IDD:
    cdef string _version
    cdef cmap[string, EPClass] classes
    cdef vector[string] classnames
