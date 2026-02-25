# distutils: language = c++
# distutils: extra_compile_args = -std=c++11

from libcpp.string cimport string, npos
from libcpp.pair cimport pair
from libcpp cimport bool as cbool

cdef extern from '<cctype>' namespace 'std':
    int isspace(int)
    int isdigit(int)
    int toupper(int)
    int tolower(int)

cdef string trim(const string& s):
    """Remove leading and trailing whitespace from a C++ string."""
    cdef size_t start = 0
    cdef size_t end = s.size()

    while start < end and isspace(s[start]):
        start += 1

    while end > start and isspace(s[end - 1]):
        end -= 1

    return s.substr(start, end - start)

cdef string to_uppercase(const string& s):
    """Convert string to uppercase."""
    cdef string result = s
    cdef size_t i
    cdef char c

    for i in range(result.size()):
        c = result[i]
        if c >= b'a' and c <= b'z':
            result[i] = c - 32

    return result

cdef string to_titlecase(const string& s):
    # Port of toTitleCase (simplified for standard space delimiters)
    if s.empty():
        return ''

    cdef string result = s
    cdef size_t i
    cdef char c
    cdef cbool new_word = True

    for i in range(result.size()):
        c = result[i]
        if new_word and not isspace(c):
            result[i] = toupper(c)
            new_word = False
        else:
            result[i] = tolower(c)

        if isspace(c):
            new_word = True

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

cdef string fieldname_to_key(string& name):
    """Remove illegal characters: -/*(), replace spaces with _"""
    cdef string trimmed_name = trim(name)
    cdef string key = ''
    cdef char c
    cdef size_t i

    for i in range(trimmed_name.length()):
        c = trimmed_name[i]
        if c == b'-' or c == b'/' or c == b'*' or c == b'(' or c == b')':
            continue
        if c == b' ':
            key.push_back(b'_')
        else:
            key.push_back(c)

    return key

cdef string extract_tag(string& block, string tag):
    # Finds '\tag <value>\r\n'
    # Tag should include the backslash, e.g., '\\field '

    cdef size_t start_pos = block.find(tag)
    if start_pos == npos:
        return string()

    start_pos += tag.length()
    cdef size_t end_pos = block.find(b'\n', start_pos)
    if end_pos == npos:
        end_pos = block.length()

    # Handle \r if present
    if end_pos > start_pos and block[end_pos - 1] == b'\r':
        return trim(block.substr(start_pos, end_pos - start_pos - 1))

    return trim(block.substr(start_pos, end_pos - start_pos))

cdef pair[string, string] match_extensible_name(string& fieldname):
    # Logic to split "Field 1" into prefix "Field " and suffix ""
    # Since std::regex is cumbersome to wrap, we use manual parsing for efficiency here
    # Start from end, look for digits
    pass

# --- Python Wrapper Functions ---

def test_trim(str s):
    # Encode to bytes for C++, then decode result back to Python str
    cdef string c_s = s.encode('utf-8')
    print(trim(c_s).decode('utf-8'))
    print(c_s.decode('utf-8'))

def test_to_uppercase(str s):
    return to_uppercase(s.encode('utf-8')).decode('utf-8')

def test_to_titlecase(str s):
    return to_titlecase(s.encode('utf-8')).decode('utf-8')

def test_find_char(str s, str c):
    if not c: return False
    # Convert single-char string to a C char (byte)
    return find_char(s.encode('utf-8'), ord(c))

def test_find_char_pos(str s, str c):
    if not c: return len(s)
    return find_char_pos(s.encode('utf-8'), ord(c))

def test_fieldname_to_key(str s):
    return fieldname_to_key(s.encode('utf-8')).decode('utf-8')

def test_extract_tag(str block, str tag):
    cdef string c_block = block.encode('utf-8')
    print(extract_tag(c_block, tag.encode('utf-8')).decode('utf-8'))
    print(c_block.decode('utf-8'))
