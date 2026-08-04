from libcpp.string cimport string, npos
from libcpp cimport bool as cbool


# * Function declarations

cdef string any_to_string(object value) except *  #TODO
cdef (int, int) get_continuous_digits_indices(const string& name) noexcept nogil
cdef string get_current_time() noexcept nogil
cdef bytes read_utf8_bytes(str filepath, str encoding=*)


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

# Similar to Go's strings.EqualFold() (only for case insensitive comparison, ignores locale)
cdef inline cbool equal_fold(const string& a, const string& b) noexcept nogil:
    if a.size() != b.size():
        return False

    cdef size_t i
    cdef char ca, cb
    for i in range(a.size()):
        ca = a[i]
        cb = b[i]
        if b'A' <= ca <= b'Z':
            ca += 32
        if b'A' <= cb <= b'Z':
            cb += 32
        if ca != cb:
            return False

    return True

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

# Similar to Go's strings.CutPrefix()
cdef inline (string, cbool) cut_prefix(const string& s, const string& prefix) noexcept nogil:
    cdef size_t p_len = prefix.length()

    if s.length() >= p_len and s.compare(0, p_len, prefix) == 0:
        return (s.substr(p_len), True)

    return (s, False)

# Similar to Go's strings.CutSuffix()
cdef inline (string, cbool) cut_suffix(const string& s, const string& suffix) noexcept nogil:
    cdef size_t str_len = s.length()
    cdef size_t s_len = suffix.length()

    if str_len >= s_len and s.compare(str_len-s_len, str_len, suffix) == 0:
        return (s.substr(0, str_len-s_len), True)

    return (s, False)
