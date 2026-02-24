# distutils: language = c++
# distutils: extra_compile_args = ["-std=c++11", "-O3"]

cimport utils  # utils.pxd

from libcpp.string cimport string, npos
from libcpp.vector cimport vector
from libcpp.map cimport map as cmap
from libcpp.pair cimport pair
from libcpp cimport bool as cbool
from libc.stdlib cimport atoi, atof
from cython.operator cimport dereference as deref, preincrement as inc

cimport cython

#+ —— C++ External Definitions ——————

cdef extern from '<algorithm>' namespace 'std':
    void replace(string.iterator, string.iterator, char, char)
    string::iterator find(string.iterator, string.iterator, char)

cdef extern from '<cctype>' namespace 'std':
    int isspace(int)
    int isdigit(int)
    int toupper(int)
    int tolower(int)

cdef extern from '<string>' namespace 'std':
    string to_string(int)
    string to_string(double)

#+ —— Data Structures ——————

cdef struct FieldProps:
    string name
    string type
    string units
    cbool has_default
    string default_val_str
    double default_val_num # used for int or float
    cbool default_is_num # flag to distinguish string vs number types in default

cdef struct ExtensibleProps:
    int startidx # start index of the extensible fields
    int size # size of the extensible fields
    vector[string] key_regexp # RegExp pattern for extensible field search
    vector[pair[string, string]] fieldnames # prefix, suffix -> (prefix)(n)(suffix)

cdef struct ClassProps:
    string classname
    int last_default_fieldidx
    cbool has_extensible
    ExtensibleProps extensible

#+ —— RegExp Pattern ——————
r'''
#linebreak#
/(?:\r\n|\r|\n)/

#head#
/[^\s,]+,#linebreak#(?: *\\.*#linebreak#)+/
Version,
      \memo Specifies the EnergyPlus version of the IDF file.
      \unique-object
      \format singleLine

#field#
/ *[^\s,]+ *[,;](?: *\\.*#linebreak#)+/
  A1 ; \field Version Identifier
      \default 23.2

#head#(#field#)+
/[^\s,]+,#linebreak#(?: *\\.*#linebreak#)+(?: *[^\s,]+ *[,;](?: *\\.*#linebreak#)+)+/g
 ^head                                ^fields
/[^\s,]+,(?:\r\n|\r|\n)(?: *\\.*(?:\r\n|\r|\n))+(?: *[^\s,]+ *[,;](?: *\\.*(?:\r\n|\r|\n))+)+/g
'''

#+ —— Parse ——————

cdef struct HeaderFieldMatchResult:
    string header_string
    vector[string] fields

cdef HeaderFieldMatchResult match_fields(string class_string):
    """Splits the raw IDD string into the Header and a vector of Field Blocks."""
    #? Logic mimics regex: / *[^\s,]+ *[,;](?: *\\.*(?:\r\n|\r|\n))*/g

    cdef SplitResult result
    cdef size_t cursor = 0 # beginning of the "unprocessed" text
    cdef size_t length = class_string.length()
    cdef size_t sep_pos = 0 # separator (,/;) positions
    cdef size_t search_pos = 0 # search beyond the separator for metadata/comments
    cdef cbool parsing_header = True
    cdef size_t last_chunk_end = 0 # index of the end of last chunk + 1 (= start of current chunk)

    # Find first comma or newline to identify class name line
    sep_pos = class_string.find_first_of(b",;")
    if sep_pos == npos: return result

    while cursor < length:
        # Find next separator
        sep_pos = class_string.find_first_of(b",;", cursor)
        if sep_pos == npos: break

        # Scan forward to find start of NEXT value (skipping comments/whitespace)
        search_pos = sep_pos + 1

        while search_pos < length:
            # Skip whitespace
            while search_pos < length and isspace(class_string[search_pos]):
                search_pos += 1

            if search_pos >= length: break

            # Check if this line is a comment/metadata
            if class_string[search_pos] == b'\\' or class_string[search_pos] == b'!':
                search_pos = class_string.find(b'\n', search_pos)
                if search_pos == npos: break
                search_pos += 1
            else:
                break

        # Extract the chunk
        if parsing_header:
            result.header = class_string.substr(last_chunk_end, search_pos - last_chunk_end)
            parsing_header = False
        else:
            result.fields.push_back(class_string.substr(last_chunk_end, search_pos - last_chunk_end))

        last_chunk_end = search_pos
        cursor = search_pos

    return result
