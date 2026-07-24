from libcpp.string cimport string

cdef string to_lower(string s) noexcept nogil
cdef string to_upper(string s) noexcept nogil
cdef string trim_string(const string& s) noexcept nogil
cdef (string, cbool) cut_prefix(const string& s, const string& prefix) noexcept nogil
cdef string any_to_string(object value) except *
cdef (int, int) get_continuous_digits_indices(const string& name) noexcept nogil
