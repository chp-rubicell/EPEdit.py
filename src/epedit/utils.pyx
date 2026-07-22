# distutils: language = c++

from libcpp.string cimport string
from libcpp cimport bool as cbool

cdef extern from "<string>" namespace "std":
    string to_string(long long val)
    string to_string(double val)

cdef string trim_string(const string& s) nogil:
    """Remove leading and trailing whitespace from a C++ string."""
    cdef size_t first = s.find_first_not_of(b" \t\r\n")
    if first == string.npos:
        return b""
    cdef size_t last = s.find_last_not_of(b" \t\r\n")
    return s.substr(first, (last - first + 1))

cdef string any_to_string(object value) except *:
    """
    Get Python object and convert it to C++ std::string.
    """
    if value is None:
        return b""
    elif isinstance(value, bool):
        # EnergyPlus Yes/No convention
        return b"Yes" if value else b"No"
    elif isinstance(value, int):
        return to_string(<long long>value)
    elif isinstance(value, float):
        # Note: to_string(double) only preserves until six decimal places
        # consider using str(value).encode('utf-8')
        return to_string(<double>value)
    elif isinstance(value, str):
        # Fast cast from Python str to C++ std::string using UTF-8 encoding
        return (<str>value).encode('utf-8')
    else:
        # Fallback for other types.
        # Uses Python's built-in str() function, then encodes it.
        return str(value).encode('utf-8')

cdef (int, int) get_continuous_digits_indices(const string& name) nogil:
    """
    Get start and end indices of continous digits (first appearance)
    """
    cdef int start_idx = -1
    cdef int end_idx = -1
    cdef size_t i = 0
    cdef char c

    for i in range(name.length()):
        c = name[i]
        # Check if the character is a digit (ASCII 0-9)
        if b'0' <= c <= b'9':
            if start_idx == -1:
                start_idx = i
        elif start_idx != -1:
            end_idx = i
            break

    if start_idx != -1 and end_idx == -1:
        end_idx = name.length()

    return start_idx, end_idx
