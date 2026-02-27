# distutils: language = c++
# distutils: extra_compile_args = ["-std=c++11", "-O3"]

cimport utils  # utils.pxd

from libcpp.string cimport string, npos
from libcpp.vector cimport vector
from libcpp.map cimport map as cmap
from libcpp.pair cimport pair
from libcpp cimport bool as cbool
from libc.stdlib cimport atoi, atof
from libc.stdio cimport printf
from cython.operator cimport dereference as deref, preincrement as inc

cimport cython

#+ —— C++ External Definitions ——————

cdef extern from "<algorithm>" namespace "std":
    void replace(string.iterator, string.iterator, char, char)
    string.iterator find(string.iterator, string.iterator, char)

cdef extern from "<cctype>" namespace "std":
    int isspace(int)
    int isdigit(int)
    int toupper(int)
    int tolower(int)

cdef extern from "<string>" namespace "std":
    string to_string(int)
    string to_string(double)

#+ —— Data Structures ——————

cdef struct EPField:
    string name
    string type
    string units
    cbool has_default
    string default_val_str
    double default_val_num # used for int or float
    cbool default_is_num # flag to distinguish string vs number types in default

cdef struct EPExtensible:
    int start_idx # start index of the extensible fields
    int size # size of the extensible fields
    vector[string] key_regexp # RegExp pattern for extensible field search
    vector[pair[string, string]] fieldnames # prefix, suffix -> (prefix)(n)(suffix)

cdef struct EPClass:
    string name
    cmap[string, EPField] fields
    int last_default_field_idx
    cbool has_extensible
    EPExtensible extensible

#+ —— RegExp Pattern ——————
r"""
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
"""

#+ —— Helper functions ——————

cdef struct MatchFieldsResult:
    string header_string
    vector[string] field_strings

cdef MatchFieldsResult match_fields(string class_string):
    """Splits the raw IDD string into the Header and a vector of Field Blocks."""
    #? Logic mimics regex: / *[^\s,]+ *[,;](?: *\\.*(?:\r\n|\r|\n))*/g

    cdef MatchFieldsResult result
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
            if class_string[search_pos] == b"\\" or class_string[search_pos] == b"!":
                search_pos = class_string.find(b"\n", search_pos)
                if search_pos == npos: break
                search_pos += 1
            else:
                break

        # Extract the chunk
        if parsing_header:
            result.header_string = class_string.substr(last_chunk_end, search_pos - last_chunk_end)
            parsing_header = False
        else:
            result.field_strings.push_back(class_string.substr(last_chunk_end, search_pos - last_chunk_end))

        last_chunk_end = search_pos
        cursor = search_pos

    return result

def test_match_fields(str s):
    cdef MatchFieldsResult result = match_fields(s.encode("utf-8"))
    print("-----------")
    print(result.header_string.decode("utf-8"))
    for field in result.field_strings:
        print("-----------")
        print(field.decode("utf-8"))

cdef string extract_tag(string& block, string tag):
    # Finds "\tag <value>\r\n"
    # Tag should include the backslash, e.g., "\\field "

    cdef size_t start_pos = block.find(tag)
    if start_pos == npos:
        return string()

    start_pos += tag.length()
    cdef size_t end_pos = block.find(b"\n", start_pos)
    if end_pos == npos:
        end_pos = block.length()

    # Handle \r if present
    if end_pos > start_pos and block[end_pos - 1] == b"\r":
        return utils.trim(block.substr(start_pos, end_pos - start_pos - 1))

    return utils.trim(block.substr(start_pos, end_pos - start_pos))

def test_extract_tag(str block, str tag):
    cdef string c_block = block.encode("utf-8")
    print(extract_tag(c_block, tag.encode("utf-8")).decode("utf-8"))
    print(c_block.decode("utf-8"))

cdef struct ExtensibleNameMatchResult:
    string prefix
    string suffix
    cbool success

cdef ExtensibleNameMatchResult match_extensible_name(string& fieldname):
    """
    'Field 1' -> 'Field ' + n + ''
    'Vertex 1 X-coordinate' -> 'Vertex ' + n + ' X-coordinate'
    """
    cdef ExtensibleNameMatchResult result
    cdef string number = b""

    cdef size_t length = fieldname.length()
    cdef size_t pos = 0

    # prefix
    while pos < length and not isdigit(fieldname[pos]):
        pos += 1
    if pos > 0:
        result.prefix = fieldname.substr(0, pos)

    # number
    if pos == length:
        # hit the end, no number found
        result.success = False
        result.prefix += <char*>b" "
        return result # suffix is already empty (default value)

    # suffix
    while pos < length and not isdigit(fieldname[pos]):
        pos += 1

    result.success = True

    if pos < length:
        result.suffix = fieldname.substr(pos)

    return result

def test_match_extensible_name(str s):
    cdef fieldname = s.encode("utf-8")
    cdef ExtensibleNameMatchResult result = match_extensible_name(fieldname)
    print(result.prefix.decode("utf-8"))
    print(result.suffix.decode("utf-8"))
    print(result.success)
    print(fieldname.decode("utf-8"))

#+ —— Parsing class info ——————

cdef EPClass parse_idd_class_string(string class_string, cbool verbose = False):
    """
    Parse a class idd string and creates a EPClass object.
    """

    cdef size_t sep_pos # for tracking position of separators (,/;)

    #? Parse class_string into header_string and field_strings
    cdef MatchFieldsResult match_result = match_fields(class_string)

    #? EPClass result
    cdef EPClass epclass
    epclass.last_default_field_idx = -2 # -2 indicates undefined/none, -1 indicates present but no fields yet
    epclass.has_extensible = False

    #? Extract class name
    sep_pos = match_result.header_string.find(b",")
    if sep_pos != npos:
        epclass.name = utils.trim(match_result.header_string.substr(0, sep_pos))
    else:
        if verbose:
            printf("> Cannot find name of class -\n%s", match_result.header_string.c_str())
        epclass.name = utils.trim(match_result.header_string) # fallback

    #? Check for \default in header
    if match_result.header_string.find(b"\\default ") != npos:
        epclass.last_default_field_idx = -1

    #? Check for \extensible:<number>
    cdef string ext_tag = b"\\extensible:"
    cdef size_t ext_pos = match_result.header_string.find(ext_tag)
    cdef size_t num_start
    cdef size_t num_end
    if ext_pos != npos:
        epclass.has_extensible = True
        epclass.extensible.start_idx = -1 # update during the field parsing
        # Parse the number
        num_start = ext_pos + ext_tag.length()
        num_end = num_start
        while num_end < match_result.header_string.length() and isdigit(match_result.header_string[num_end]):
            num_end += 1
        if num_end > num_start:
            epclass.extensible.size = atoi(match_result.header_string.substr(num_start, num_end - num_start).c_str()) # use atoi (ASCII to Integer) (need to convert string to C-string buffer first)
        else:
            epclass.extensible.size = 0

    #? Parse fields
    cdef EPField current_field

    cdef string field_string
    cdef string fieldname
    cdef string fieldkey
    cdef string fieldtype_raw # fieldtype in original IDD term

    cdef size_t field_idx
    for field_idx in range(match_result.field_strings.size()):
        if epclass.has_extensible \
                and epclass.extensible.start_idx >= 0 \
                and field_idx >= epclass.extensible.start_idx + epclass.extensible.size:
            # if has extensibles, and all first extensible fields are processed
            break

        field_string = match_result.field_strings[field_idx]

        #? field name
        fieldname = extract_tag(field_string, b"\\field ")
        if fieldname.empty():
            # fallback to using field code (e.g., N1)
            sep_pos = field_string.find_first_of(b",;")
            if sep_pos != npos:
                fieldname = utils.trim(field_string.substr(0, sep_pos))
            else:
                fieldname = to_string(field_idx)
            if verbose:
                printf(
                    "> No fieldName match for '%s' - %zu. Using '%s' instead.",
                    epclass.name.c_str(),
                    field_idx,
                    fieldname.c_str()
                )
        fieldkey = utils.fieldname_to_key(fieldname)

        current_field.name = fieldname

        #? field type
        fieldtype_raw = utils.to_lowercase(extract_tag(field_string, b"\\units "))
        if fieldtype_raw == b"integer":
            current_field.type = b"int"
        elif fieldtype_raw == b"real":
            current_field.tpe == b"float"
        else:
            current_field.tpe == b"string" # default

    return epclass

def test_parse_idd_class_string(str s, bool verbose = False):
    cdef EPClass epclass = parse_idd_class_string(s.encode("utf-8"), verbose)
    print("-----------")
    print(epclass.name.decode("utf-8"))
    print("-----------")
    print(epclass.extensible.size)
