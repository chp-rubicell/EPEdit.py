# distutils: language = c++
# distutils: extra_compile_args = -std=c++11

from libcpp.string cimport string
from libcpp cimport bool as cbool

cdef string trim(const string& s):
    """Remove leading and trailing whitespace from a C++ string."""
    cdef size_t start = 0
    cdef size_t end = s.size()
    cdef char c

    while start < end:
        c = s[start]
        if c != b' ' and c != b'\t' and c != b'\n' and c != b'\r':
            break
        start += 1

    while end > start:
        c = s[end - 1]
        if c != b' ' and c != b'\t' and c != b'\n' and c != b'\r':
            break
        end -= 1

    return s.substr(start, end - start)

cdef string to_upper(const string& s):
    """Convert string to uppercase."""
    cdef string result = s
    cdef size_t i
    cdef char c
    for i in range(result.size()):
        c = result[i]
        if c >= b'a' and c <= b'z':
            result[i] = c - 32
    return result

cdef cbool find_char(const string& s, char c):
    """Check if character exists in string."""
    cdef size_t i
    for i in range(s.size()):
        if s[i] == c:
            return True
    return False

cdef size_t find_char_pos(const string& s, char c):
    """Find position of character, returns s.size() if not found."""
    cdef size_t i
    # Fixed: Changed loop variable from 'f' to 'i' to match the logic
    for i in range(s.size()):
        if s[i] == c:
            return i
    return s.size()

# --- Python Wrapper Functions ---

def test_trim(str s):
    # Encode to bytes for C++, then decode result back to Python str
    return trim(s.encode('utf-8')).decode('utf-8')

def test_to_upper(str s):
    return to_upper(s.encode('utf-8')).decode('utf-8')

def test_find_char(str s, str c):
    if not c: return False
    # Convert single-char string to a C char (byte)
    return find_char(s.encode('utf-8'), ord(c))

def test_find_char_pos(str s, str c):
    if not c: return len(s)
    return find_char_pos(s.encode('utf-8'), ord(c))
