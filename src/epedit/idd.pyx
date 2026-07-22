# distutils: language = c++

from libc.stdlib cimport atoi
from libcpp.string cimport string, npos

from lexer cimport Lexer, Token, TokenType, TOKEN_TEXT, TOKEN_COMMA, TOKEN_SEMICOLON, TOKEN_EOF, TOKEN_ERROR
from idd cimport c_IDD, ClassDef, FieldDef, ExtensibleDef, ExtPattern
from utils cimport cut_prefix, get_continuous_digits_indices


# * Helper functions for parsing class and field property

cdef void parse_class_property(ClassDef& cls, const string& val) noexcept nogil:
    cdef string after
    cdef cbool found
    cdef int start_idx, end_idx

    after, found = cut_prefix(val, b"\\extensible")
    if found:
        cls.extensible.has_extensible = True
        cls.extensible.begin_index = -1  # -1 indicates before parsing the value
        cls.extensible.size = -1

        # parse \extensible:# info
        start_idx, end_idx = get_continuous_digits_indices(after)
        if start_idx > -1:
            # Extract number using atoi
            cls.extensible.size = atoi(after.substr(start_idx, end_idx - start_idx).c_str())
        return

    after, found = cut_prefix(val, b"\\min-fields")
    if found:
        start_idx, end_idx = get_continuous_digits_indices(after)
        if start_idx > -1:
            # Extract number using atoi
            cls.min_fields = atoi(after.substr(start_idx, end_idx - start_idx).c_str())
        return

    # TODO: \memo, etc.


cdef void parse_field_property(ClassDef& cls, FieldDef& field, const string& val) noexcept nogil:
    cdef string trimmed_val = trim_string(val)
    cdef string after
    cdef cbool found

    after, found = cut_prefix(val, b"\\field")
    if found:
        # replace temporary names (ex. A1, N1)
        field.name = trim_string(after)
        return

    if trimmed_val == b"\\required-field":
        field.required = True
        return

    if trimmed_val == b"\\begin-extensible":
        # current field is the starting field of extensibles
        if cls.extensible.has_extensible:
            cls.extensible.begin_index = <int>(cls.fields.size() - 1)
        return

    after, found = cut_prefix(val, b"\\units")
    if found:
        field.units = trim_string(after)
        return

    after, found = cut_prefix(val, b"\\default")
    if found:
        field.default_val = trim_string(after)
        # if field has default value, add index to cache
        if not field.default_val.empty():
            cls.field_idx_with_default.push_back(<int>(cls.fields.size() - 1))
        return

    if trimmed_val == b"\\autosizable":
        field.autosizable = True
        return

    if trimmed_val == b"\\autocalculatable":
        field.autocalculatable = True
        return

    after, found = cut_prefix(val, b"\\type")
    if found:
        field.field_type = trim_string(after)
        return

    after, found = cut_prefix(val, b"\\key")
    if found:
        field.choices.push_back(trim_string(after))
        return

    # TODO: add more later


# * Helper functions for building IDD

cdef ExtPattern extract_prefix_suffix(const string& name) noexcept nogil:
    """
    Helper function for extracting prefix and suffix from extensible field name.
    """
    pass


cdef void fix_missing_begin_index(ClassDef& cls) noexcept nogil:
    """
    Helper function for fixing classes with missing \begin-extensible tag.
    """
    pass


cdef void build_indices(ClassDef& cls) noexcept nogil:
    """
    Run after IDD parsing to build indices.
    """
    pass


# * Parse IDD file into c_IDD

# state for tracking current parser mode
cdef enum ParseState:
    STATE_LOOKING_FOR_CLASS = 0
    STATE_IN_CLASS          = 1


cdef c_IDD parse_idd(lexer Lexer) except *:
    """
    Returns parsed c_IDD struct using Lexer.
    """
    cdef c_IDD c_idd
    cdef ParseState state = STATE_LOOKING_FOR_CLASS  # state machine

    cdef Token tok
    cdef string current_group

    # temporary text until comma or semicolon token
    cdef string last_text

    # Use index (-1) to track current position
    cdef int current_class_idx = -1
    cdef int current_field_idx = -1

    cdef ClassDef current_class
    cdef FieldDef current_field
    cdef int limit

    # Temporary variables for \group cut_prefix()
    cdef string after
    cdef cbool found

    while True:
        # Release Python GIL
        with nogil:
            tok = lexer.next_token()

        # 1. Handle EOF and errors
        if tok.type == TOKEN_EOF:
            break
        elif tok.type == TOKEN_ERROR:
            # Raise Python exception (requires GIL)
            raise ValueError(f"Parsing error (Line {lexer.line_num}): {repl(tok.value.decode('utf-8'))}")

        # 2. Handle text tokens (class/field names or property tags)
        if tok.type == TOKEN_TEXT:
            if not tok.value.empty() and tok.value.front() == <const char*>b'\\':
                # property
                after, found = cut_prefix(tok.value, b"\\group")
                if found:
                    current_group = found
                elif current_field_idx != -1:
                    # if there is active field, add as field property
                    pass


# * Python Wrapper Class (End User API)
