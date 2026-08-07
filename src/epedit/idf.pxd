from libcpp.string cimport string
from libcpp.vector cimport vector
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

cdef class IDFObject:
    cdef IDD             idd
    cdef size_t          class_idx
    cdef string          c_class_name
    cdef readonly str    class_name
    cdef vector[string]  values
    cdef readonly size_t obj_idx  # for preserve_order option (readonly for Python sort() function)

    cdef inline const ClassDef* get_class_def(self) noexcept nogil
    cdef void c_init(self, IDD idd, size_t class_idx, vector[string]& values) noexcept
    cdef int set_string_by_index(self, int field_idx, const string& value) except -1 nogil
    cdef int set_by_index(self, int field_idx, object value) except -1
    cdef void trim_trailing_empty_fields(self) nogil
    cdef void write_to_buffer(
        self,
        string& out_buffer,
        const FormatConfig* config,
    ) noexcept nogil

cdef class IDF:
    cdef IDD    idd
    cdef dict   objects  # {CLASSNAME: [IDFObject,...],...}
    cdef size_t next_obj_idx

    cdef int c_init(self, IDD idd, bytes idf_content) except -1
    cdef void build_objects(self, vector[c_IDFObject]& c_idf_objects)
    cdef list get_objects_raw(self, str class_name)
    cdef void write_to_buffer(
        self,
        string& out_buffer,
        const FormatConfig* config,
        cbool preserve_order=*,
    ) noexcept
