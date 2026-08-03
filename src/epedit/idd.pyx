# distutils: language = c++

from libc.stdlib cimport atoi
from libcpp.string cimport string, npos
from libcpp.vector cimport vector
from libcpp.unordered_map cimport unordered_map
from libcpp cimport bool as cbool

cdef extern from "<string>" namespace "std" nogil:
    string to_string(int val)

from .lexer cimport (
    Lexer, Token, TokenType,
    TOKEN_TEXT, TOKEN_COMMA, TOKEN_SEMICOLON, TOKEN_EOF, TOKEN_ERROR,
)
from .utils cimport (
    to_lower, to_upper, trim_string,
    has_prefix, has_suffix, cut_prefix, cut_suffix,
    get_continuous_digits_indices,
)


# * Helper functions for parsing class and field property

cdef void parse_class_property(ClassDef& cls, const string& val) noexcept nogil:
    cdef string after
    cdef cbool found
    cdef int start_idx, end_idx

    after, found = cut_prefix(val, <const char*>b"\\extensible")
    if found:
        cls.extensible.is_extensible = True
        cls.extensible.begin_index = -1  # -1 indicates before parsing the value
        cls.extensible.size = -1

        # parse \extensible:# info
        start_idx, end_idx = get_continuous_digits_indices(after)
        if start_idx > -1:
            # Extract number using atoi
            cls.extensible.size = atoi(after.substr(start_idx, end_idx - start_idx).c_str())
        return

    after, found = cut_prefix(val, <const char*>b"\\min-fields")
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

    after, found = cut_prefix(val, <const char*>b"\\field")
    if found:
        # replace temporary names (ex. A1, N1)
        field.name = trim_string(after)
        return

    if trimmed_val == <const char*>b"\\required-field":
        field.required = True
        return

    if trimmed_val == <const char*>b"\\begin-extensible":
        # current field is the starting field of extensibles
        if cls.extensible.is_extensible:
            cls.extensible.begin_index = <int>(cls.fields.size() - 1)
        return

    after, found = cut_prefix(val, <const char*>b"\\units")
    if found:
        field.units = trim_string(after)
        return

    after, found = cut_prefix(val, <const char*>b"\\default")
    if found:
        field.default_val = trim_string(after)
        # if field has default value, add index to cache
        if not field.default_val.empty():
            cls.field_idx_with_default.push_back(cls.fields.size() - 1)
        return

    if trimmed_val == <const char*>b"\\autosizable":
        field.autosizable = True
        return

    if trimmed_val == <const char*>b"\\autocalculatable":
        field.autocalculatable = True
        return

    after, found = cut_prefix(val, <const char*>b"\\type")
    if found:
        after = to_lower(trim_string(after))
        if after == <const char*>b"integer":
            field.field_type = FIELDTYPE_INTEGER
        elif after == <const char*>b"real":
            field.field_type = FIELDTYPE_REAL
        elif after == <const char*>b"alpha":
            field.field_type = FIELDTYPE_ALPHA
        elif after == <const char*>b"choice":
            field.field_type = FIELDTYPE_CHOICE
        else:
            field.field_type = FIELDTYPE_DEFAULT
        return

    after, found = cut_prefix(val, <const char*>b"\\key")
    if found:
        field.choices.push_back(trim_string(after))
        return

    # TODO: add more later


# * Helper functions for building IDD

# Helper function for adding a new class to c_IDD
cdef inline void add_new_class(
    c_IDD& c_idd,
    const string& class_name,
    const string& group_name,
    int& current_class_idx,
    int& current_field_idx,
) noexcept nogil:

    cdef ClassDef new_class
    new_class.name                     = class_name
    new_class.group                    = group_name
    new_class.min_fields               = 0
    new_class.extensible.is_extensible = False
    new_class.extensible.begin_index   = -1
    new_class.extensible.size          = -1

    c_idd.ordered_classes.push_back(new_class)
    current_class_idx = <int>(c_idd.ordered_classes.size() - 1)
    # add to class_map (for fast searching)
    c_idd.class_map[to_upper(new_class.name)] = current_class_idx

    current_field_idx = -1


# Helper function for adding a new field to class
cdef inline void add_new_field(
    ClassDef& current_class,
    const string& field_name,
    int& current_field_idx,
) noexcept nogil:

    cdef FieldDef new_field

    # Check extensible field limits
    cdef int limit = -1  # field count limit (cap to first extensible fields set)
    if (
        current_class.extensible.is_extensible
        and current_class.extensible.begin_index >= 0
    ):
        # first set of extensible fields
        limit = (
            current_class.extensible.begin_index
            + current_class.extensible.size
        )

    if limit >= 0 and current_class.fields.size() >= <size_t>limit:
        current_field_idx = -1  # Do not add more fields
    else:
        # Add new field
        # last_text is new field name (ex. A1)
        new_field.name             = field_name
        new_field.required         = False
        new_field.autosizable      = False
        new_field.autocalculatable = False

        current_class.fields.push_back(new_field)
        current_field_idx = <int>(current_class.fields.size() - 1)


# Helper function for extracting prefix and suffix from extensible field name.
cdef ExtPattern extract_prefix_suffix(const string& name) noexcept nogil:
    cdef ExtPattern extpat
    cdef int start_idx, end_idx
    start_idx, end_idx = get_continuous_digits_indices(name)

    if start_idx > -1:
        extpat.prefix = name.substr(0, start_idx)
        extpat.suffix = name.substr(end_idx)
    else:
        extpat.prefix = name + <const char*>b""
        extpat.suffix = <const char*>b""

    extpat.search_prefix = to_lower(extpat.prefix)
    extpat.search_suffix = to_lower(extpat.suffix)
    return extpat


# Helper function for fixing classes with missing \begin-extensible tag.
cdef void fix_missing_begin_index(ClassDef& cls) noexcept nogil:
    # Use pointer(*) to reference extensible
    cdef ExtensibleDef* ext = &cls.extensible

    # filter when size is defined but begin_index is -1
    if not ext.is_extensible or ext.begin_index != -1 or ext.size <= 0:
        return

    cdef int num_fields = <int>cls.fields.size()
    if num_fields < ext.size:
        return

    # 1. Extract patterns(prefix/suffix) from the last fields
    cdef vector[ExtPattern] patterns  # temporary patterns for matching

    cdef int i
    for i in range(ext.size):
        patterns.push_back(
            extract_prefix_suffix(cls.fields[num_fields - ext.size + i].name)
        )

    # 2. Match pattern from back
    cdef int begin_idx = num_fields
    cdef int offset  # offset within extensible group
    cdef ExtPattern extpat
    cdef string name_lower  # for lowercase name

    for i in range(num_fields - 1, -1, -1):
        # get offset within extensible group
        offset = ext.size - 1 - ((num_fields - 1 - i) % ext.size)
        extpat = patterns[offset]
        name_lower = to_lower(cls.fields[i].name)

        # if pattern does not match, that is the beginning index
        if not has_prefix(name_lower, extpat.search_prefix) or not has_suffix(name_lower, extpat.search_suffix):
            break

        # if matched, move the beginning index
        begin_idx = i

    ext.begin_index = begin_idx


# Run after IDD parsing to build indices.
cdef void build_indices(ClassDef& cls) noexcept nogil:
    cdef int limit = <int>cls.fields.size()
    if cls.extensible.is_extensible and cls.extensible.begin_index >= 0:
        limit = cls.extensible.begin_index

    cdef int i

    # Add non-extensible fields to base_field_index_map
    for i in range(limit):
        # Base fields map for fast search (lowercased)
        cls.base_field_index_map[to_lower(cls.fields[i].name)] = i

    # Add extensible fields to extensible.patterns
    if cls.extensible.is_extensible and limit < <int>cls.fields.size():
        cls.extensible.patterns.clear()
        for i in range(cls.extensible.size):
            if limit + i < <int>cls.fields.size():
                cls.extensible.patterns.push_back(
                    extract_prefix_suffix(cls.fields[limit + i].name)
                )


# * Parse IDD file into c_IDD

# state for tracking current parser mode
cdef enum ParseState:
    STATE_LOOKING_FOR_CLASS = 0
    STATE_IN_CLASS          = 1

# Input parsed data in Lexer to given c_IDD.
cdef int parse_idd(Lexer lexer, c_IDD& c_idd) except -1 nogil:

    c_idd.version.clear()
    c_idd.class_map.clear()
    c_idd.ordered_classes.clear()

    cdef ParseState state = STATE_LOOKING_FOR_CLASS  # state machine

    cdef Token tok
    cdef string current_group

    # temporary text until comma or semicolon token
    cdef string last_text

    # Use index (-1) to track current position
    cdef int current_class_idx = -1
    cdef int current_field_idx = -1

    # Temporary variables for \group cut_prefix()
    cdef string after
    cdef cbool found

    while True:
        tok = lexer.next_token()

        # 1. Handle EOF and errors
        if tok.type == TOKEN_EOF:
            break
        elif tok.type == TOKEN_ERROR:
            # Raise Python exception (requires GIL)
            with gil:
                raise ValueError(f"IDD parsing error (Line {lexer.line_num}): {repr(tok.value.decode('utf-8'))}")

        # 2. Handle text tokens (class/field names or property tags)
        if tok.type == TOKEN_TEXT:
            if not tok.value.empty() and tok.value.front() == b'\\':
                # property
                after, found = cut_prefix(tok.value, <const char*>b"\\group")
                if found:
                    current_group = trim_string(after)

                elif current_field_idx != -1:
                    # If there is active field, add as field property
                    if current_class_idx == -1:
                        # Raise Python exception (requires GIL)
                        with gil:
                            raise ValueError(f"IDD parsing error (Line {lexer.line_num}): Field property '{tok.value.decode('utf-8')}' found, but no class exists.")
                    parse_field_property(
                        c_idd.ordered_classes[current_class_idx],
                        c_idd.ordered_classes[current_class_idx].fields[current_field_idx],
                        tok.value,
                    )

                elif current_class_idx != -1:
                    # If no active field but have active class, add as class property
                    parse_class_property(c_idd.ordered_classes[current_class_idx], tok.value)

                else:
                    # If no active field and active class
                    with gil:
                        raise ValueError(f"Syntax error (Line {lexer.line_num}): Orphaned property '{tok.value.decode('utf-8')}' found before any class definition.")

            else:
                last_text = tok.value

        # 3. Handle comma tokens (register new class or field)
        elif tok.type == TOKEN_COMMA:
            if state == STATE_LOOKING_FOR_CLASS:
                # No current active class -> create new class
                # last_text is the new class name
                add_new_class(
                    c_idd,
                    last_text,
                    current_group,
                    current_class_idx,
                    current_field_idx,
                )
                state = STATE_IN_CLASS

            elif state == STATE_IN_CLASS:
                # Add new field to current class
                add_new_field(
                    c_idd.ordered_classes[current_class_idx],
                    last_text,
                    current_field_idx,
                )

            last_text.clear()

        # 4. Handle semicolon tokens (terminate current class)
        elif tok.type == TOKEN_SEMICOLON:
            if state == STATE_IN_CLASS:
                # Add final field to current class
                add_new_field(
                    c_idd.ordered_classes[current_class_idx],
                    last_text,
                    current_field_idx,
                )

            last_text.clear()
            state = STATE_LOOKING_FOR_CLASS
            # don't reset current_class_idx and current_field_idx to -1
            # more field info can follow after ;

    # Post processing: Fix indices and build cache
    cdef size_t i
    for i in range(c_idd.ordered_classes.size()):
        # fix extensible.begin_index if broken
        fix_missing_begin_index(c_idd.ordered_classes[i])
        build_indices(c_idd.ordered_classes[i])

    return 0


# * Python Wrapper Class (End User API)

cdef class IDD:
    """
    Python wrapper for the C++ c_IDD data structure.
    """

    # ——— Properties ——————

    @property
    def num_classes(self) -> int:
        """Returns the total number of classes parsed."""
        return self.c_idd.ordered_classes.size()

    # ——— Initializations ——————

    def __init__(self, bytes idd_content):
        if self.initialized:
            raise RuntimeError(f"{type(self).__name__} is already initialized.")

        # Initialize lexer
        cdef Lexer lexer = Lexer(idd_content, True)

        # Parse IDD
        with nogil:
            parse_idd(lexer, self.c_idd)

        # Precache Python str of uppercase class names
        cdef size_t i
        cdef const ClassDef* cls
        cdef size_t num_classes = self.c_idd.ordered_classes.size()
        self.py_class_names_upper = [None] * <int>num_classes
        for i in range(num_classes):
            cls = &self.c_idd.ordered_classes[i]
            self.py_class_names_upper[i] = to_upper(cls.name).decode("utf-8")

        # Flag as initialized
        self.initialized = True

    @classmethod
    def from_file(cls, str filepath) -> IDD:
        """Parse IDD file"""
        cdef bytes raw_bytes

        with open(filepath, "rb") as file:
            raw_bytes = file.read()

        return cls(raw_bytes)

    # ——— Helper functions ——————

    def get_class_name(self, int index) -> str:
        if index < 0 or index >= <int>self.c_idd.ordered_classes.size():
            raise IndexError("Class index out of range.")

        return self.c_idd.ordered_classes[index].name.decode("utf-8")

    # ——— Debugging ——————

    def _get_field_names(self, str class_name):
        cdef const ClassDef* cls = &self.c_idd.ordered_classes.at(
            self.c_idd.class_map[class_name.upper().encode("utf-8")]
        )
        cdef const FieldDef* field
        cdef size_t i
        cdef list field_names = []
        for i in range(cls.fields.size()):
            field = &cls.fields[i]
            field_names.append(field.name.decode("utf-8"))
        return field_names


# * API (Read)

# Get index from field name (case-insensitive)
cdef int find_field_index(const ClassDef* cls, const string& field_name) noexcept nogil:
    if cls == NULL or field_name.empty():
        return -1

    cdef string search_key = to_lower(field_name)

    # 1. Base fields
    if cls.base_field_index_map.find(search_key) != cls.base_field_index_map.end():
        return cls.base_field_index_map.at(search_key)

    # 2. Extensible fields

    # Use pointer(*) to reference extensible
    cdef const ExtensibleDef* ext = &cls.extensible


    cdef size_t offset
    cdef const ExtPattern* pat

    # Temporary variables for cut_prefix(), cut_suffix()
    cdef string after
    cdef cbool found

    cdef int group_num

    if ext.is_extensible and ext.begin_index >= 0 and ext.size > 0:
        for offset in range(ext.patterns.size()):
            pat = &ext.patterns[offset]

            after, found = cut_prefix(search_key, pat.search_prefix)
            if found:
                after, found = cut_suffix(after, pat.search_suffix)
                if found:
                    group_num = atoi(after.c_str())
                    if group_num > 0:
                        return ext.begin_index + (group_num-1) * ext.size + offset

    return -1


# Get index from key(int or str) with error handling
cdef int resolve_key_to_field_index(const ClassDef* cls, object key) except -1:
    cdef int idx = -1

    if isinstance(key, int):
        idx = key
        if idx < 0:
            raise KeyError("Field index should be >= 0.")
        if not cls.extensible.is_extensible and idx >= <int>cls.fields.size():
            raise IndexError(f"Index {idx} out of range. '{cls.name.decode('utf-8')}' has max {cls.fields.size()} fields.")

    elif isinstance(key, str):
        idx = find_field_index(cls, key.encode("utf-8"))
        if idx < 0:
            raise KeyError(f"Field '{key}' not found in class '{cls.name.decode('utf-8')}'.")

    else:
        raise TypeError(f"Invalid key type: {type(key).__name__}. Expected int or str")

    return idx


# Get field name from index
cdef string get_field_name(const ClassDef* cls, int field_idx, cbool add_units) noexcept nogil:
    if cls == NULL or field_idx < 0:
        return <const char*>b""

    cdef const ExtensibleDef* ext = &cls.extensible
    cdef const FieldDef* field
    cdef string field_name

    # 1. Base fields
    if not ext.is_extensible or ext.begin_index < 0 or field_idx < ext.begin_index:
        if field_idx >= <int>cls.fields.size():
            return <const char*>b""
        field = &cls.fields[field_idx]
        field_name = field.name
        if add_units and not field.units.empty():
            field_name += <const char*>b" {"
            field_name += field.units
            field_name += <const char*>b"}"
        return field_name

    # 2. Extensible fields
    cdef int group_num = (field_idx - ext.begin_index) // ext.size + 1
    cdef size_t offset = (field_idx - ext.begin_index) % ext.size

    if offset >= ext.patterns.size():
        return <const char*>b""

    cdef const ExtPattern* pat = &ext.patterns[offset]
    field = &cls.fields[ext.begin_index + offset]

    field_name = pat.prefix
    field_name += to_string(group_num)
    field_name +=  pat.suffix

    if add_units and not field.units.empty():
        field_name += <const char*>b" {"
        field_name += field.units
        field_name += <const char*>b"}"
    return field_name


# Get FieldDef from field index
cdef const FieldDef* get_field_def(const ClassDef* cls, size_t field_idx) noexcept nogil:
    cdef size_t base_idx = field_idx
    cdef const ExtensibleDef* ext = &cls.extensible
    if (
        ext.is_extensible
        and ext.begin_index >= 0
        and ext.size > 0
        and field_idx >= <size_t>(ext.begin_index + ext.size)
    ):
        base_idx = <size_t>ext.begin_index + (field_idx - <size_t>ext.begin_index) % <size_t>ext.size

    if base_idx >= cls.fields.size():
        return NULL

    return &cls.fields[base_idx]


# * Test functions

def test_find_field_index(IDD idd, str class_name, str field_name):
    cdef const ClassDef* cls = &idd.c_idd.ordered_classes.at(
        idd.c_idd.class_map[class_name.upper().encode("utf-8")]
    )
    cdef int field_idx = find_field_index(cls, field_name.encode("utf-8"))
    if field_idx < 0:
        raise ValueError
    return field_idx

def test_get_field_name(IDD idd, str class_name, int field_idx, bool add_units):
    cdef const ClassDef* cls = &idd.c_idd.ordered_classes.at(
        idd.c_idd.class_map[class_name.upper().encode("utf-8")]
    )
    return get_field_name(cls, field_idx, add_units).decode("utf-8")
