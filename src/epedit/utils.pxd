from libcpp.string cimport string

cdef string trim_string(const string& s) noexcept nogil
cdef string any_to_string(object value) except *
cdef (int, int) get_continuous_digits_indices(const string& name) noexcept nogil
