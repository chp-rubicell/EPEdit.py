from libcpp.string cimport string, npos
from libcpp cimport bool as cbool


# * Function declarations

cdef string any_to_string(object value) except *
cdef (int, int) get_continuous_digits_indices(const string& name) noexcept nogil


# * Inline function declarations

# Convert string to lowercase.
cdef inline string to_lower(string s) noexcept nogil:
    cdef size_t i
    for i in range(s.length()):
        if b'A' <= s[i] <= b'Z':
            s[i] = s[i] + 32
    return s

# Convert string to uppercase.
cdef inline string to_upper(string s) noexcept nogil:
    cdef size_t i
    for i in range(s.length()):
        if b'a' <= s[i] <= b'z':
            s[i] = s[i] - 32
    return s

# Remove leading and trailing whitespace from a C++ string.
cdef inline string trim_string(const string& s) noexcept nogil:
    cdef size_t first = s.find_first_not_of(b" \t\r\n")
    if first == npos:
        return <const char*>b""
    cdef size_t last = s.find_last_not_of(b" \t\r\n")
    return s.substr(first, (last - first + 1))

# Similar to Go's strings.HasPrefix()
cdef inline cbool has_prefix(const string&s, const string& prefix) noexcept nogil:
    cdef size_t p_len = prefix.length()
    return s.length() >= p_len and s.compare(0, p_len, prefix) == 0

# Similar to Go's strings.HasSuffix()
cdef inline cbool has_suffix(const string&s, const string& suffix) noexcept nogil:
    cdef size_t s_len = suffix.length()
    return s.length() >= s_len and s.compare(s.length() - s_len, s_len, suffix) == 0

# Similar to Go's stringsCutPrefix()
cdef inline (string, cbool) cut_prefix(const string& s, const string& prefix) noexcept nogil:
    cdef size_t p_len = prefix.length()

    if s.length() >= p_len and s.compare(0, p_len, prefix) == 0:
        return (s.substr(p_len), True)

    return (s, False)
