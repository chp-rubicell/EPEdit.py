# distutils: language = c++

from libc.time cimport time, time_t, tm, localtime, strftime
from libcpp.string cimport string
from libcpp cimport bool as cbool

cdef extern from "<string>" namespace "std" nogil:
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
        # return to_string(<double>value)
        # consider using str(value).encode("utf-8")
        return str(value).encode("utf-8")
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

# Get current time as string
cdef string get_current_time() noexcept nogil:
    # Get current time as seconds
    cdef time_t rawtime
    time(&rawtime)
    # Convert to local time structure (struct tm)
    cdef tm* timeinfo = localtime(&rawtime)
    # Prepare a C char array ("YYYY-MM-DD HH:MM:SS" + null terminator \0)
    cdef char buffer[25]
    # Format time
    cdef size_t written_len
    written_len = strftime(buffer, 25, b"%Y-%m-%d %H:%M:%S", timeinfo)
    if written_len <= 0:
        return string(b"")
    return string(<const char*>buffer, written_len)

# Read file as UTF-8 bytes
cdef bytes read_utf8_bytes(object filepath, str encoding=None):
    """Parse IDD file"""
    cdef bytes raw_bytes

    with open(filepath, "rb") as file:
        raw_bytes = file.read()

    # Remove UTF-8 BOM
    if raw_bytes.startswith(b'\xef\xbb\xbf'):
        raw_bytes = raw_bytes[3:]

    # Normalized encoding
    if encoding is not None:
        if encoding.lower() not in ("utf-8", "utf8"):
            raw_bytes = raw_bytes.decode(encoding).encode("utf-8")
    else:
        # Check if UTF-8
        try:
            raw_bytes.decode("utf-8")
        except UnicodeDecodeError as e:
            raise UnicodeError(
                f"'{filepath}' cannot be read in UTF-8. Encoding needs to be specified."
            ) from e

    return raw_bytes

def debug_to_lower(str s):
    return to_lower((<str>s).encode("utf-8")).decode("utf-8")
def debug_to_upper(str s):
    return to_upper((<str>s).encode("utf-8")).decode("utf-8")
def debug_equal_fold(str a, str b):
    return equal_fold(a.encode("utf-8"), b.encode("utf-8"))
def debug_trim_string(str s):
    return trim_string((<str>s).encode("utf-8")).decode("utf-8")
def debug_has_prefix(str s, str prefix):
    return has_prefix(
        (<str>s).encode("utf-8"),
        (<str>prefix).encode("utf-8"),
    )
def debug_has_suffix(str s, str suffix):
    return has_suffix(
        (<str>s).encode("utf-8"),
        (<str>suffix).encode("utf-8"),
    )
def debug_cut_prefix(str s, str prefix):
    cdef string after
    cdef cbool found
    after, found = cut_prefix(
        (<str>s).encode("utf-8"),
        (<str>prefix).encode("utf-8"),
    )
    return (after.decode("utf-8"), found)
def debug_cut_suffix(str s, str suffix):
    cdef string after
    cdef cbool found
    after, found = cut_suffix(
        (<str>s).encode("utf-8"),
        (<str>suffix).encode("utf-8"),
    )
    return (after.decode("utf-8"), found)
def debug_get_current_time():
    return get_current_time().decode("utf-8")
