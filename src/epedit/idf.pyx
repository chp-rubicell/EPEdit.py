# distutils: language = c++
# distutils: extra_compile_args = ["-std=c++11", "-O3"]

cimport utils  # utils.pxd
from idd cimport IDD

from libcpp.string cimport string, npos
from libcpp.vector cimport vector

cdef class IDFObject:
    """
    Represents a single IDF object (e.g., Wall, Zone).
    """
    cdef string classname

    def __cinit__(self):
        pass



cdef class _IDFObject:
    """
    Represents a single IDF object (e.g., Wall, Zone).
    Stores data in C++ containers for performance.
    """
    cdef string _type_name
    cdef vector[string] _fields
    cdef string _comment
    cdef object _model_ref  # Keep reference to model to prevent GC

    def __cinit__(self):
        self._model_ref = None

    @property
    def type_name(self):
        """Get the object type name (e.g., 'WALL', 'ZONE')."""
        return self._type_name.decode('utf-8')

    @property
    def comment(self):
        """Get the inline comment."""
        return self._comment.decode('utf-8')

    @comment.setter
    def comment(self, value):
        """Set the inline comment."""
        self._comment = value.encode('utf-8')

    def get_field(self, int index):
        """
        Get field value by index (0 = type name, 1+ = data fields).
        Automatically converts to int, float, or str based on the value.
        """
        if index < 0 or index >= <int>self._fields.size():
            raise IndexError(f"Field index {index} out of range [0, {self._fields.size()-1}]")
        cdef str str_value = self._fields[index].decode('utf-8')
        return _convert_field_value(str_value)

    def get_field_str(self, int index):
        """
        Get field value by index as a string (no type conversion).
        Use this when you need the raw string value.
        """
        if index < 0 or index >= <int>self._fields.size():
            raise IndexError(f"Field index {index} out of range [0, {self._fields.size()-1}]")
        return self._fields[index].decode('utf-8')

    def set_field(self, int index, value):
        """Set field value by index. Changes are immediate."""
        if index < 0 or index >= <int>self._fields.size():
            raise IndexError(f"Field index {index} out of range [0, {self._fields.size()-1}]")

        cdef string new_value = str(value).encode('utf-8')
        self._fields[index] = new_value

        if index == 0:
            self._type_name = to_upper(new_value)


cdef class IDFModel:
    """
    Main IDF model class.
    Manages the entire IDF file structure and provides efficient access to objects.
    """
    cdef list _all_objects
    cdef dict _objects_by_type

    def __cinit__(self):
        self._all_objects = []
        self._objects_by_type = {}
