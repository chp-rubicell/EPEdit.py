from libcpp.string cimport string
from libcpp.vector cimport vector
from libcpp.unordered_map cimport unordered_map
from libcpp.utility cimport pair
from libcpp cimport bool as cbool

from .idd cimport ClassDef, IDD

cdef struct FormatConfig:
    string class_indent  # indent for class names
    string field_indent  # indent for fields
    size_t field_size    # minimum size for field values
    cbool  compact       # compact mode

cdef struct c_IDFObject:
    string         class_name
    vector[string] values

# Location information (obj_idx, field_idx)
ctypedef pair[size_t, int] FieldLoc

cdef class IDF  # forward declaration to prevent circular dependency

cdef class IDFObject:
    cdef IDD             idd
    cdef IDF             parent_idf
    cdef size_t          class_idx
    cdef string          c_class_name
    cdef readonly str    class_name
    cdef vector[string]  values
    cdef size_t          obj_idx  # for preserve_order option (readonly for Python sort() function)

    cdef inline const ClassDef* get_class_def(self) noexcept nogil
    cdef int c_init(
        self,
        IDD             idd,
        IDF             parent_idf,
        size_t          class_idx,
        vector[string]& values,
    ) except -1
    cdef int set_string_by_index(self, int field_idx, const string& value) except -1 nogil
    cdef int set_by_index(self, int field_idx, object value) except -1
    cdef void trim_trailing_empty_fields(self) nogil
    cdef void write_to_buffer(
        self,
        string& out_buffer,
        const FormatConfig* config,
    ) noexcept nogil

cdef class IDF:
    cdef IDD idd
    cdef list objects  # obj_idx -> IDFObject | None
    cdef unordered_map[string, vector[size_t]] objects_index_map  # {CLASSNAME: [obj_idx,...],...}

    # Registry for object references
    # {TagName: {ObjName: [FieldLoc], ...}, ...}
    # ex. targets["ZoneNames"]["OFFICE 1"] -> [FieldLoc]
    #     (should be only one, but used vector for safety and validity check)
    # ex. referencers["ZoneNames"]["OFFICE 1"] -> [FieldLoc that references target]
    cdef unordered_map[string, unordered_map[string, vector[FieldLoc]]] targets
    cdef unordered_map[string, unordered_map[string, vector[FieldLoc]]] referencers

    cdef void register_target(self, const string& tag, const string& val, size_t obj_idx, int field_idx) noexcept nogil
    cdef void register_referencer(self, const string& tag, const string& val, size_t obj_idx, int field_idx) noexcept nogil
    cdef void unregister_target(self, const string& tag, const string& val, size_t obj_idx, int field_idx) noexcept nogil
    cdef void unregister_referencer(self, const string& tag, const string& val, size_t obj_idx, int field_idx) noexcept nogil

    cdef int c_init(self, IDD idd, bytes idf_content) except -1
    cdef void build_objects(self, vector[c_IDFObject]& c_idf_objects)
    cdef list get_objects_raw(self, str class_name)
    cdef void write_to_buffer(
        self,
        string& out_buffer,
        const FormatConfig* config,
        cbool preserve_order=*,
    ) noexcept
