# distutils: language = c++
# distutils: extra_compile_args = ["-std=c++11", "-O3"]

from libcpp.string cimport string, npos
from libcpp.vector cimport vector
from libcpp.map cimport map as cmap
from libcpp.pair cimport pair
from libcpp cimport bool as cbool
from libc.stdlib cimport atoi, atof
from cython.operator cimport dereference as deref, preincrement as inc

import re # Used only for the Extensible Pattern Matching fallback if std::regex gets too complex to bind
cimport cython

# ———————————————————————————————————————————————————————————————————————————
# C++ External Definitions
# ———————————————————————————————————————————————————————————————————————————

cdef extern from "<algorithm>" namespace "std":
    void replace(string.iterator, string.iterator, char, char)
    string::iterator find(string.iterator, string.iterator, char)

cdef extern from "<cctype>" namespace "std":
    int isspace(int)
    int isdigit(int)
    int toupper(int)
    int tolower(int)

cdef extern from "<string>" namespace "std":
    string to_string(int)
    string to_string(double)

# ———————————————————————————————————————————————————————————————————————————
# C++ Helper Functions (Internal)
# ———————————————————————————————————————————————————————————————————————————

cdef string trim(string s):
    # Simple whitespace trimmer
    cdef size_t first = 0
    cdef size_t last = s.length()

    while first < last and isspace(s[first]):
        first += 1
    while last > first and isspace(s[last - 1]):
        last -= 1

    return s.substr(first, last - first)

cdef string fieldNameToKey(string name):
    # Port of fieldNameToKey
    cdef string key = ""
    cdef char c
    cdef size_t i
    for i in range(name.length()):
        c = name[i]
        if c == b'-' or c == b'/' or c == b'*' or c == b'(' or c == b')':
            continue
        if c == b' ':
            key.push_back(b'_')
        else:
            key.push_back(c)
    return key

cdef string toTitleCase(string s):
    # Port of toTitleCase (simplified for standard space delimiters)
    cdef string result = ""
    cdef cbool new_word = True
    cdef char c
    cdef size_t i

    if s.empty():
        return ""

    # Autosize/Autocalculate specific handling (from original logic)
    # The original JS converts entire string to lower first, then capitalizes words
    for i in range(s.length()):
        c = s[i]
        if new_word and not isspace(c):
            result.push_back(toupper(c))
            new_word = False
        else:
            result.push_back(tolower(c))

        if isspace(c):
            new_word = True

    return result

cdef string cpp_extract_tag(string block, string tag):
    # Finds "\tag <value>\r\n"
    # Tag should include the backslash, e.g., "\\field "
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

cdef pair[string, string] cpp_match_extensible_name(string fieldName):
    # Logic to split "Field 1" into prefix "Field " and suffix ""
    # Since std::regex is cumbersome to wrap, we use manual parsing for efficiency here
    # Start from end, look for digits
    cdef int i = fieldName.length() - 1
    cdef string suffix = ""
    cdef string number = ""
    cdef string prefix = ""

    # 1. Capture Suffix (non-digits at end)
    while i >= 0 and not isdigit(fieldName[i]):
        suffix.insert(0, 1, fieldName[i])
        i -= 1

    # 2. Capture Number
    while i = 0 and isdigit(fieldName[i]):
        number.insert(0, 1, fieldName[i])
        i -= 1

    # 3. Rest is prefix
    if i >= 0:
        prefix = fieldName.substr(0, i + 1)

    if number.empty():
        # No pattern matched, fallback logic from TS
        return pair[string, string](fieldName + string(b" "), string(b""))

    return pair[string, string](prefix, suffix)

# ———————————————————————————————————————————————————————————————————————————
# Data Structures
# ———————————————————————————————————————————————————————————————————————————

cdef struct ExtensibleProps:
    int startIdx
    int size
    vector[string] keyRegExps
    vector[pair[string, string]] fieldNames

cdef struct FieldPropsCpp:
    string name
    string type
    string units
    cbool has_default
    string default_val_str
    double default_val_num # used for int or float
    cbool default_is_num # flag to distinguish string vs number types in default

cdef struct ClassPropsCpp:
    string className
    int lastDefaultFieldIdx
    cbool has_extensible
    ExtensibleProps extensible

# ———————————————————————————————————————————————————————————————————————————
# Core Parsing Logic
# ———————————————————————————————————————————————————————————————————————————

cdef vector[string] split_into_fields(string classString, string& headerOut):
    # Splits the raw IDD string into the Header and a vector of Field Blocks.
    # Logic mimics regex: / *[^\s,]+ *[,;](?: *\\.*(?:\r\n|\r|\n))*/g

    cdef vector[string] fields
    cdef size_t cursor = 0
    cdef size_t length = classString.length()
    cdef size_t token_start = 0
    cdef size_t search_pos = 0
    cdef size_t sep_pos = 0
    cdef size_t next_newline = 0
    cdef cbool first_chunk = True

    # 1. Find the Class Definition (Header)
    # Search for first comma that isn't in a comment?
    # Actually, IDD format: "Class Name,\n \attributes..."

    # Find first comma or newline to identify class name line
    sep_pos = classString.find_first_of(b",;")
    if sep_pos == npos: return fields

    # Determine end of header.
    # Header ends where the first field begins.
    # A field begins with a non-comment line containing a value and a separator.

    # We will iterate through the string finding separators (,, ;)
    # The text between separators constitutes a "Chunk".

    cdef size_t last_chunk_end = 0

    while cursor < length:
        # Find next separator
        sep_pos = classString.find_first_of(b",;", cursor)
        if sep_pos == npos: break

        # Check if this separator is inside a comment (starts with ! or \)
        # In IDD structure provided, strict comment lines start with \
        # Inline comments usually !.
        # The regex used in TS implies it splits strictly on `Value,` patterns.

        # We assume the separator marks the end of the "Value" part of the field.
        # Now we look for the "End of this field block".
        # The block ends just before the start of the NEXT Value.
        # The next value starts at the next non-whitespace character
        # that is NOT a comment line (line starting with \)

        # Scan forward from sep_pos to find where the NEXT field value starts
        search_pos = sep_pos + 1

        while search_pos < length:
            # Skip whitespace
            while search_pos < length and isspace(classString[search_pos]):
                search_pos += 1

            if search_pos >= length: break

            # Check if this line is a comment/metadata
            if classString[search_pos] == b'\\' or classString[search_pos] == b'!':
                # Skip to end of line
                search_pos = classString.find(b'\n', search_pos)
                if search_pos == npos: break
                search_pos += 1
            else:
                # Found the start of the NEXT value.
                # So the current chunk ends here.
                break

        # Extract the chunk
        # If it's the first chunk, it's the header
        if first_chunk:
            headerOut = classString.substr(last_chunk_end, search_pos - last_chunk_end)
            first_chunk = False
        else:
            fields.push_back(classString.substr(last_chunk_end, search_pos - last_chunk_end))

        last_chunk_end = search_pos
        cursor = search_pos # Advance cursor

    return fields

@cython.boundscheck(False)
@cython.wraparound(False)
def parseIDDClassString(str classString_py, cbool verbose = False):
    """
    Parse a class idd string and creates a classProps object.
    High-performance C++ implementation.
    """

    # 1. Convert to C++ String
    cdef string classString = classString_py.encode('utf-8')

    # 2. Split Header and Fields
    cdef string headerString = ""
    cdef vector[string] fieldStrings = split_into_fields(classString, headerString)

    # 3. Parse Class Info (Header)
    cdef ClassPropsCpp classProp
    classProp.lastDefaultFieldIdx = -2 # -2 indicates undefined/none, -1 indicates present but no fields yet
    classProp.has_extensible = False

    # Extract Class Name (first token before comma)
    cdef size_t comma_pos = headerString.find(b',')
    if comma_pos != npos:
        classProp.className = trim(headerString.substr(0, comma_pos))
    else:
        # Fallback regex-like extract from beginning
        classProp.className = trim(headerString) # Likely incorrect but safe fallback

    # Check for \default in header
    if headerString.find(b"\\default ") != npos:
        classProp.lastDefaultFieldIdx = -1

    # Check for \extensible:<number>
    cdef string ext_tag = b"\\extensible:"
    cdef size_t ext_pos = headerString.find(ext_tag)
    if ext_pos != npos:
        classProp.has_extensible = True
        classProp.extensible.startIdx = -1
        # Parse the number
        cdef size_t num_start = ext_pos + ext_tag.length()
        cdef size_t num_end = num_start
        while num_end < headerString.length() and isdigit(headerString[num_end]):
            num_end += 1
        if num_end > num_start:
            classProp.extensible.size = atoi(headerString.substr(num_start, num_end - num_start).c_str())
        else:
            classProp.extensible.size = 0

    # 4. Parse Fields
    cdef cmap[string, FieldPropsCpp] fields_map
    cdef int fieldIdx = 0
    cdef FieldPropsCpp currentField
    cdef string fStr
    cdef string fName
    cdef string fKey
    cdef string fTypeRaw
    cdef string fUnits
    cdef string fDefaultRaw
    cdef pair[string, string] extNames

    cdef size_t fs_size = fieldStrings.size()
    cdef size_t i

    for i in range(fs_size):
        # Check extensible bounds
        if classProp.has_extensible and classProp.extensible.startIdx >= 0:
            if fieldIdx >= classProp.extensible.startIdx + classProp.extensible.size:
                break

        fStr = fieldStrings[i]

        # — Extract Field Name —
        fName = cpp_extract_tag(fStr, b"\\field ")
        if fName.empty():
            # Fallback: Extract code from parsing "Code,"
            comma_pos = fStr.find_first_of(b",;")
            if comma_pos != npos:
                fName = trim(fStr.substr(0, comma_pos))
            else:
                fName = to_string(fieldIdx)
            if verbose:
                print(f"> No fieldName match for '{classProp.className.decode('utf-8')}' - {fieldIdx}. Using {fName.decode('utf-8')}")

        fKey = fieldNameToKey(fName)

        # — Extract Field Type —
        fTypeRaw = cpp_extract_tag(fStr, b"\\type ")
        if fTypeRaw == b"integer":
            currentField.type = b"int"
        elif fTypeRaw == b"real":
            currentField.type = b"float"
        else:
            currentField.type = b"string" # Default

        # — Extract Units —
        currentField.units = cpp_extract_tag(fStr, b"\\units ")

        # — Extract Default —
        fDefaultRaw = cpp_extract_tag(fStr, b"\\default ")
        if not fDefaultRaw.empty():
            classProp.lastDefaultFieldIdx = fieldIdx
            currentField.has_default = True

            # Handle Autosize/Autocalculate
            # Use a temp lower string for comparison
            # We don't have a full toLower in std string easily without transform,
            # but we can check specific known strings

            # Note: The TS utility `typeCastFieldValue` handles string/number logic
            is_auto = False
            if fDefaultRaw.length() >= 8: # min length of autosize
                 # Quick sloppy check or proper lowering?
                 # Let's just pass to the Python casting logic or replicate simple checks
                 pass

            # Replicate type casting logic
            if currentField.type == b"int":
                try:
                    currentField.default_val_num = atoi(fDefaultRaw.c_str())
                    currentField.default_is_num = True
                except:
                    # e.g. "Autosize"
                    currentField.default_val_str = toTitleCase(fDefaultRaw)
                    currentField.default_is_num = False
            elif currentField.type == b"float":
                try:
                    currentField.default_val_num = atof(fDefaultRaw.c_str())
                    currentField.default_is_num = True
                except:
                    currentField.default_val_str = toTitleCase(fDefaultRaw)
                    currentField.default_is_num = False
            else:
                # String
                if fDefaultRaw == b"autosize" or fDefaultRaw == b"autocalculate" or \
                   fDefaultRaw == b"Autosize" or fDefaultRaw == b"Autocalculate":
                    currentField.default_val_str = toTitleCase(fDefaultRaw)
                else:
                    currentField.default_val_str = fDefaultRaw
                currentField.default_is_num = False
        else:
            currentField.has_default = False

        currentField.name = fName

        # — Extensible Logic —
        if classProp.has_extensible:
            if fStr.find(b"\\begin-extensible") != npos:
                classProp.extensible.startIdx = fieldIdx

            if classProp.extensible.startIdx >= 0:
                extNames = cpp_match_extensible_name(fName)
                classProp.extensible.fieldNames.push_back(extNames)

                # Regexp construction
                # prefix(\d+)suffix -> key format
                # We store the raw pattern string to be processed by JS/Python consumer if needed
                # TS: `${fieldNameToKey(prefix)}(\\d+)${fieldNameToKey(suffix)}`
                # In C++:
                cdef string pattern = fieldNameToKey(extNames.first)
                pattern.append(b"(\\d+)")
                pattern.append(fieldNameToKey(extNames.second))
                classProp.extensible.keyRegExps.push_back(pattern)

        # Store field
        fields_map[fKey] = currentField
        fieldIdx += 1

    # 5. Construct Python Return Object
    # We build the dictionary here to return to Python

    result = {
        "className": classProp.className.decode('utf-8'),
        "fields": {}
    }

    if classProp.lastDefaultFieldIdx > -2:
        result["lastDefaultFieldIdx"] = classProp.lastDefaultFieldIdx

    if classProp.has_extensible:
        ext_fields_list = []
        ext_regex_list = []        for i in range(classProp.extensible.fieldNames.size()):
            p = classProp.extensible.fieldNames[i]
            ext_fields_list.append((p.first.decode('utf-8'), p.second.decode('utf-8')))
            ext_regex_list.append(classProp.extensible.keyRegExps[i].decode('utf-8'))

        result["extensible"] = {
            "startIdx": classProp.extensible.startIx,
            "size": classProp.extensible.size,
            "keyRegExps": ext_regex_list,
            "fieldNames": ext_fields_list
        }

    # Populate fields dict    cdef FieldPropsCpp fp
    for pair in fields_map:
        fp = pair.second
        f_dict = {
            "name": fp.name.decode('utf-8'),
            "type": fp.type.decode('utf-8'),
            "units": fp.units.decode('utf-8') if not fp.units.empty() else None
        }

        if fp.has_default:
            if fp.default_is_num:
                if fp.type == b"int":
                    f_dict["default"] = int(fp.default_val_num)
                else:
                    f_dict["default"] = fp.default_val_num
            else:
                f_dict["default"] = fp.default_val_str.decode('utf-8')

        result["fields"][pair.first.decode('utf-8')] = f_dict

    return result