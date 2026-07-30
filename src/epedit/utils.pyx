# distutils: language = c++

from libcpp.string cimport string
from libcpp cimport bool as cbool

cdef extern from "<string>" namespace "std":
    string to_string(long long val)
    string to_string(double val)

# Get Python object and convert it to C++ std::string.
cdef string any_to_string(object value) except *:
    if value is None:
        return <const char*>b""
    elif isinstance(value, bool):
        # EnergyPlus Yes/No convention
        return <const char*>b"Yes" if value else <const char*>b"No"
    elif isinstance(value, int):
        return to_string(<long long>value)
    elif isinstance(value, float):
        # Note: to_string(double) only preserves until six decimal places
        # consider using str(value).encode("utf-8")
        return to_string(<double>value)
    elif isinstance(value, str):
        # Fast cast from Python str to C++ std::string using UTF-8 encoding
        return (<str>value).encode("utf-8")
    else:
        # Fallback for other types.
        # Uses Python's built-in str() function, then encodes it.
        return str(value).encode("utf-8")

# Get start and end indices of continous digits (first appearance).
cdef (int, int) get_continuous_digits_indices(const string& name) noexcept nogil:
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

def test_to_lower(str s):
    return to_lower((<str>s).encode("utf-8")).decode("utf-8")
def test_to_upper(str s):
    return to_upper((<str>s).encode("utf-8")).decode("utf-8")
def test_trim_string(str s):
    return trim_string((<str>s).encode("utf-8")).decode("utf-8")
def test_has_prefix(str s, str prefix):
    return has_prefix(
        (<str>s).encode("utf-8"),
        (<str>prefix).encode("utf-8"),
    )
def test_has_suffix(str s, str suffix):
    return has_suffix(
        (<str>s).encode("utf-8"),
        (<str>suffix).encode("utf-8"),
    )
def test_cut_prefix(str s, str prefix):
    cdef string after
    cdef cbool found
    after, found = cut_prefix(
        (<str>s).encode("utf-8"),
        (<str>prefix).encode("utf-8"),
    )
    return (after.decode("utf-8"), found)
