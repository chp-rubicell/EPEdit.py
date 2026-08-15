# distutils: language = c++

from cython.operator cimport dereference as deref
# from libc.stdlib cimport atof, atoi  # replaced with stof, stoi
from libc.stdlib cimport strtol, strtod
from libcpp.string cimport string
from libcpp.vector cimport vector
from libcpp.utility cimport move
from libcpp cimport bool as cbool

from .lexer cimport (
    Lexer, Token,
    TOKEN_TEXT, TOKEN_COMMA, TOKEN_SEMICOLON, TOKEN_EOF, TOKEN_ERROR,
)
from .idd cimport (
    ExtensibleDef, FIELDTYPE_INTEGER, FIELDTYPE_REAL, FieldDef, ClassDef,
    c_IDD, IDD,
    find_field_index, resolve_key_to_field_index, get_field_name, get_field_def,
)
from .utils cimport (
    to_lower, to_upper, equal_fold, trim_string,
    any_to_string, get_current_time, read_utf8_bytes
)

# cdef extern from "<string>" namespace "std" nogil:
#     double stod(const string& str) except +
#     int stoi(const string& str) except +


# * Export config definition

# Export format setting
# cdef struct FormatConfig (in .pxd)

cdef inline FormatConfig generate_format_config(
    size_t class_indent_size = 0,
    size_t field_indent_size = 4,
    size_t field_size        = 24,
) noexcept nogil:
    cdef FormatConfig config

    config.class_indent = string(class_indent_size, <char>b' ')
    config.field_indent = string(field_indent_size, <char>b' ')
    config.field_size   = field_size
    config.compact      = False

    return config

cdef FormatConfig DEFAULT_FORMAT_CONFIG = generate_format_config()

cdef FormatConfig MINIMAL_FORMAT_CONFIG = FormatConfig(
    class_indent = b'',
    field_indent = b'',
    field_size   = 0,
    compact      = True,
)


# * Helper functions

cdef inline object convert_field_value(const FieldDef* field, const string& val) noexcept:
    """
    Get field value by key

    Args:
        key (int | str): field index or field name (case-insensitive)

    Returns:
        str | int | float: field value based on field_type
    """
    if field == NULL:
        return val.decode("utf-8")

    if val.empty():
        # If int or float type return None
        if field.field_type == FIELDTYPE_INTEGER or field.field_type == FIELDTYPE_REAL:
            return None
        return ""

    cdef char* end_ptr  # for strtol, strtod
    cdef long c_int_val
    cdef double c_double_val

    if field.autosizable and equal_fold(val, <const char*>b"autosize"):
        return "Autosize"
    elif field.autocalculatable and equal_fold(val, <const char*>b"autocalculate"):
        return "Autocalculate"
    elif field.field_type == FIELDTYPE_INTEGER:
        c_int_val = strtol(val.c_str(), &end_ptr, 10)
        if deref(end_ptr) == b'\0':  # if null, parsing was successful
            return c_int_val
        else:  # parsing failed, return value as str
            return val.decode("utf-8")
    elif field.field_type == FIELDTYPE_REAL:
        c_double_val = strtod(val.c_str(), &end_ptr)
        if deref(end_ptr) == b'\0':  # if null, parsing was successful
            return c_double_val
        else:  # parsing failed, return value as str
            return val.decode("utf-8")

    return val.decode("utf-8")


# * C-level IDFObject definition

# C level temporary object for fast processing
# cdef struct c_IDFObject (in .pxd)


# Add parsed data in Lexer to given vector.
cdef int parse_idf(Lexer lexer, vector[c_IDFObject]& c_idf_objects) except -1 nogil:

    cdef Token tok
    cdef c_IDFObject current_obj

    # temporary text until comma or semicolon token
    cdef string last_text

    # whether looking for new object or inside an object
    cdef cbool object_started = False

    while True:
        tok = lexer.next_token()

        if tok.type == TOKEN_EOF:
            # If an object has started but no semicolon closed it,
            # do not silently drop it.
            if object_started or not last_text.empty():
                with gil:
                    raise ValueError(f"IDF parsing error (Line {lexer.line_num}): unterminated object before EOF; missing ';'.")
            break

        elif tok.type == TOKEN_ERROR:
            with gil:
                raise ValueError(f"IDF parsing error (Line {lexer.line_num}): {repr(tok.value.decode('utf-8'))}")

        elif tok.type == TOKEN_TEXT:
            # Normal IDF lines should not produce adjacent text tokens.
            # If this happens, the input is ambiguous.
            if not last_text.empty():
                with gil:
                    raise ValueError(f"IDF parsing error (Line {lexer.line_num}): missing delimiter before '{tok.value.decode('utf-8')}'.")
            last_text = tok.value

        elif tok.type == TOKEN_COMMA:
            if not object_started:
                # last_text is the class name
                current_obj.class_name = last_text
                object_started = True
            else:
                # last_text is a field value
                current_obj.values.push_back(last_text)
            last_text.clear()

        elif tok.type == TOKEN_SEMICOLON:
            if not object_started:
                current_obj.class_name = last_text
            else:
                current_obj.values.push_back(last_text)
            object_started = False

            # Leave checking and saving to IDFObject generation phase.
            c_idf_objects.push_back(move(current_obj))

            current_obj.class_name.clear()
            current_obj.values.clear()
            last_text.clear()

        else:
            with gil:
                raise ValueError(f"IDF parsing error (Line {lexer.line_num}): unrecognized token type '{tok.type}'.")

    # TODO: version check

    return 0


# * Python-level IDFObject definition

cdef class IDFObject:

    # Inline function for getting ClassDef pointer
    cdef inline const ClassDef* get_class_def(self) noexcept nogil:
        return &self.idd.c_idd.ordered_classes[self.class_idx]

    # ——— Initializations ——————

    # C-level initialization
    cdef void c_init(self, IDD idd, size_t class_idx, vector[string]& values) noexcept:
        self.idd = idd
        self.class_idx = class_idx
        self.c_class_name = self.get_class_def().name
        self.class_name = self.c_class_name.decode("utf-8")
        self.values = move(values)

    def __init__(self, IDD idd, str class_name):
        """Python-level initialization"""
        cdef string search_key = to_upper(class_name.encode("utf-8"))
        cdef c_IDD* c_idd_ptr = &idd.c_idd

        if c_idd_ptr.class_map.find(search_key) == c_idd_ptr.class_map.end():
            raise ValueError(f"Unknown class: '{class_name}'")

        cdef size_t class_idx = c_idd_ptr.class_map[search_key]
        cdef ClassDef* cls = &c_idd_ptr.ordered_classes[class_idx]

        cdef vector[string] empty_values
        if cls.min_fields > 0:
            empty_values.resize(cls.min_fields, <const char*>b"")
            # empty_values.reserve(cls.min_fields)  # maybe?

        self.c_init(idd, class_idx, empty_values)

    # ——— Retrieve or update field values ——————

    def __getitem__(self, key):
        """
        Get field value by key

        Args:
            key (int | str): field index or field name (case-insensitive)

        Returns:
            str | int | float | None: field value based on field_type
        """
        cdef const ClassDef* cls = self.get_class_def()
        cdef int idx = resolve_key_to_field_index(cls, key)
        cdef const FieldDef* field = get_field_def(cls, <size_t>idx)

        if idx >= <int>self.values.size():
            return convert_field_value(field, <const char*>b"")

        return convert_field_value(field, self.values[idx])

    def get_values(self):
        """
        Get all field values as list

        Returns:
            list[str | int | float | None]: list of field values based on field_types
        """
        cdef const ClassDef* cls = self.get_class_def()
        cdef size_t i
        cdef list values = [None] * <Py_ssize_t>self.values.size()
        for i in range(self.values.size()):
            values[i] = convert_field_value(
                get_field_def(cls, <size_t>i),
                self.values[i]
            )
        return values

    # Set field by field index using raw string value
    cdef int set_string_by_index(self, int field_idx, const string& value) except -1 nogil:
        if field_idx >= <int>self.values.size():
            if value.empty():
                # If value is an empty string, don't resize self.values and ignore
                return 0
            # Resize self.values
            self.values.resize(field_idx+1, <const char*>b"")

        cdef const ClassDef* cls = self.get_class_def()

        # TODO value validity check
        # cdef const FieldDef* field = get_field_def(cls, field_idx)

        self.values[field_idx] = value
        return 0

    # Set field by field index using Python value
    cdef int set_by_index(self, int field_idx, object value) except -1:
        # If value is None or empty string, don't resize self.values
        if value is None or value == "":
            return self.set_string_by_index(field_idx, <const char*>b"")
        return self.set_string_by_index(field_idx, any_to_string(value))

    # Shrink self.values and remove trailing empty values
    cdef void trim_trailing_empty_fields(self) nogil:
        while not self.values.empty() and self.values.back().empty():
            self.values.pop_back()

    def __setitem__(self, key, value):
        """
        Set field value by key

        Args:
            key (int | str): field index or field name (case-insensitive)
            value (bool | int | float | str | None)
        """
        cdef const ClassDef* cls = self.get_class_def()
        cdef int idx = resolve_key_to_field_index(cls, key)

        self.set_by_index(idx, value)
        self.trim_trailing_empty_fields()

    def update(self, object values, bint trim_empty_trails=True):
        """
        Update multiple field values

        Args:
            values (None | list | dict): [value] or {field_idx: value} or {field_name: value}
            trim_empty_trails (bool, optional): Whether to trim trailing empty fields
        """
        if values is None:
            return

        cdef const ClassDef* cls = self.get_class_def()
        cdef int idx
        cdef int max_idx = -1
        cdef list pending_updates = []  # precompute field_idx and validity check

        if isinstance(values, list):
            for i, value in enumerate(values):
                idx = resolve_key_to_field_index(cls, i)
                pending_updates.append((idx, value))
                if idx > max_idx:
                    max_idx = idx
        elif isinstance(values, dict):
            for key, value in values.items():
                idx = resolve_key_to_field_index(cls, key)
                pending_updates.append((idx, value))
                if idx > max_idx:
                    max_idx = idx
        else:
            raise TypeError(f"Invalid values type: {type(values).__name__}. Expected list or dict")

        # Memory pre-allocation
        if max_idx >= <int>self.values.size():
            self.values.reserve(max_idx + 1)

        for idx, value in pending_updates:
            self.set_by_index(idx, value)

        if trim_empty_trails:
            self.trim_trailing_empty_fields()

    # ——— Export ——————

    cdef void write_to_buffer(
        self,
        string& out_buffer,
        const FormatConfig* config,
    ) noexcept nogil:

        cdef const ClassDef* cls = self.get_class_def()
        cdef int i
        cdef size_t val_size

        # 1. Print class name
        out_buffer.append(config.class_indent)
        out_buffer.append(self.c_class_name)

        # 2. Find last field with non-empty value
        cdef int last_idx = -1
        for i in range(<int>self.values.size()-1, -1, -1):
            if not self.values[i].empty():
                last_idx = i
                break
        if cls.min_fields > 0 and last_idx < cls.min_fields-1:
            last_idx = cls.min_fields-1

        # 3. If all fields are empty, print ';' and return
        if last_idx < 0:
            out_buffer.push_back(<char>b';')
            if not config.compact:
                out_buffer.push_back(<char>b'\n')
            return

        # 4. If not, print ','
        out_buffer.push_back(<char>b',')
        if not config.compact:
            out_buffer.push_back(<char>b'\n')

        # 5. Print until last_idx
        for i in range(last_idx + 1):
            # Add field indent
            out_buffer.append(config.field_indent)

            # Add field value
            if i < <int>self.values.size():
                out_buffer.append(self.values[i])
                val_size = self.values[i].size()
            else:
                val_size = 0

            if i == last_idx:
                # If last field, add semicolon
                out_buffer.push_back(<char>b';')
            else:
                out_buffer.push_back(<char>b',')

            # Add padding
            if not config.compact and config.field_size > 0:
                if val_size <= config.field_size:  # TODO maybe inequal?
                    # add spaces to fit config.field_size
                    out_buffer.append(config.field_size - val_size, <char>b' ')
                else:
                    # add two spaces
                    out_buffer.append(2, <char>b' ')

            # Comment string
            if not config.compact:
                out_buffer.append(<const char*>b"!- ")
                out_buffer.append(get_field_name(cls, i, True))

            # Linebreak
            if not config.compact:
                out_buffer.push_back(<char>b'\n')

    def __repr__(self):
        cdef string out_buffer
        self.write_to_buffer(out_buffer, &DEFAULT_FORMAT_CONFIG)
        return out_buffer.decode("utf-8")


# * Tuple of IDFObjects for usability (error handling)

class IDFObjectTuple(tuple):
    """tuple of IDFObjects with custom error messages"""
    def __getattr__(self, name):
        # Add-type
        if name in {"append", "extend", "insert"}:
            raise AttributeError("This is a read-only tuple. To add new objects, use the idf.add_object() method.")
        elif name in {"remove", "pop", "clear"}:
            raise AttributeError("This is a read-only tuple. To remove objects, use the idf.remove_object() or idf.remove_all_objects() methods.")
        raise AttributeError(f"'{type(self).__name__}' object has no attribute '{name}'")


# * Python-level IDF definition

cdef class IDF:

    # ——— Initializations ——————

    def __init__(self):
        """IDF cannot be instantiated directly. Use IDF.from_file() or IDF.from_string()."""
        # Prevent user from directly instantiating using IDF()
        raise TypeError("IDF cannot be instantiated directly. Use IDF.from_file() or IDF.from_string().")

    # C-level initialization
    cdef int c_init(self, IDD idd, bytes idf_content) except -1:
        self.idd = idd
        self.objects = {}

        # Initialize lexer
        cdef Lexer lexer = Lexer.__new__(Lexer)
        lexer.c_init(idf_content, False)  # turn off IDD mode

        cdef vector[c_IDFObject] c_objects

        # Parse IDF
        with nogil:
            parse_idf(lexer, c_objects)

        # Build Python-level objects
        self.build_objects(c_objects)

        return 0

    @classmethod
    def from_file(cls, IDD idd, object filepath, str encoding=None) -> IDF:
        """
        Parse IDF file

        Args:
            idd (IDD): IDD data structure
            filepath (str | PathLike): IDF file path
            encoding (str, optional): IDF file encoding

        Returns:
            IDF: parsed IDF data
        """
        cdef bytes raw_bytes = read_utf8_bytes(filepath, encoding)
        cdef IDF idf = cls.__new__(cls)
        idf.c_init(idd, raw_bytes)
        return idf

    @classmethod
    def from_string(cls, IDD idd, str content) -> IDF:
        """
        Parse IDF from string

        Args:
            idd (IDD): IDD data structure
            content (str): IDF string

        Returns:
            IDF: parsed IDF data
        """
        cdef IDF idf = cls.__new__(cls)
        idf.c_init(idd, content.encode("utf-8"))
        return idf

    # ——— Build IDF from c_idf_objects ——————

    cdef void build_objects(self, vector[c_IDFObject]& c_idf_objects):
        cdef c_IDD* c_idd_ptr = &self.idd.c_idd
        cdef c_IDFObject* c_object
        cdef string search_key  # CLASSNAME (uppercase)
        cdef str py_search_key  # Python str version of search_key
        cdef size_t class_idx

        cdef IDFObject obj
        cdef size_t idx

        for idx in range(c_idf_objects.size()):
            c_object = &c_idf_objects[idx]

            search_key = to_upper(c_object.class_name)

            if c_idd_ptr.class_map.find(search_key) == c_idd_ptr.class_map.end():
                raise ValueError(f"IDF parsing error: Unknown class: '{c_object.class_name.decode('utf-8')}'")

            class_idx = c_idd_ptr.class_map.at(search_key)

            # Create IDFObject without __init__()
            obj = IDFObject.__new__(IDFObject)
            # Initialize using C-level initialization
            obj.c_init(self.idd, class_idx, c_object.values)
            obj.obj_idx = idx  # add order index

            py_search_key = self.idd.py_class_names_upper[class_idx]
            if py_search_key in self.objects:
                self.objects[py_search_key].append(obj)
            else:
                self.objects[py_search_key] = [obj]

        self.next_obj_idx = c_idf_objects.size()  # update index for next object

    # ——— IDF information ——————

    def get_class_names(self) -> list:
        """
        Get list of class names

        Returns:
            list[str]: class names
        """
        cdef list names = []
        cdef list obj_list
        cdef IDFObject obj
        for obj_list in self.objects.values():
            if obj_list:  # if at least one object exists
                obj = obj_list[0]
                names.append(obj.class_name)
        return names

    # ——— IDF manipulation API (Create, Update, Delete) ——————

    def __getitem__(self, str class_name) -> IDFObjectTuple:
        """
        Get tuple of IDFObjects from class name

        Args:
            class_name (str): class name (case-insensitive)

        Returns:
            IDFObjectTuple[IDFObject, ...]: tuple of IDFObjects
        """
        return self.get_objects(class_name)

    def get_objects(self, str class_name) -> IDFObjectTuple:
        """
        Get tuple of IDFObjects from class name.
        Alias of IDF[class_name]

        Args:
            class_name (str): class name (case-insensitive)

        Returns:
            IDFObjectTuple[IDFObject, ...]: tuple of IDFObjects
        """
        return IDFObjectTuple(self.get_objects_raw(class_name))

    # For internal use, invisible to user
    cdef list get_objects_raw(self, str class_name):
        return self.objects.get(class_name.upper(), [])

    def get_object_by_name(self, str class_name, str obj_name) -> IDFObject|None:
        """Get object by first field (likely name)"""
        cdef string c_obj_name = obj_name.encode("utf-8")
        cdef list candidates = self.get_objects_raw(class_name)
        cdef IDFObject obj
        cdef size_t i
        for i in range(<size_t>len(candidates)):
            obj = candidates[i]
            if obj.values.size() > 0 and equal_fold(obj.values[0], c_obj_name):
                return obj
        return None

    def add_object(self, str class_name, object initial_values=None, bint default_values=True) -> IDFObject:
        """
        Add object to IDF

        Args:
            class_name (str): class name (case-insensitive)
            initial_values (None | list | dict): [value] or {field_idx: value} or {field_name: value}
            default_values (bool): Whether to include default values

        Returns:
            IDFObject: Generated IDFObject
        """
        cdef IDFObject new_obj = IDFObject(self.idd, class_name)
        cdef const ClassDef* cls = new_obj.get_class_def()

        # Apply default values
        cdef size_t i
        cdef size_t default_idx
        if default_values:
            for i in range(cls.field_idx_with_default.size()):
                default_idx = cls.field_idx_with_default.at(i)
                new_obj.set_string_by_index(
                    default_idx,
                    cls.fields[default_idx].default_val,
                )

        # Apply initial values
        new_obj.update(initial_values, trim_empty_trails=True)

        # Apply obj_idx
        new_obj.obj_idx = self.next_obj_idx
        self.next_obj_idx += 1

        cdef str py_search_key = class_name.upper()
        if py_search_key in self.objects:
            self.objects[py_search_key].append(new_obj)
        else:
            self.objects[py_search_key] = [new_obj]

        return new_obj

    def remove_object(self, IDFObject obj) -> bool:
        """
        Remove object from IDF

        Returns:
            bool: True if successfully removed, False if object was not found.
        """
        cdef str py_search_key = obj.class_name.upper()

        if py_search_key not in self.objects:
            return False

        cdef list objs = self.objects[py_search_key]

        try:
            objs.remove(obj)
            # If no obj left in class, remove key:
            if not objs:
                del self.objects[py_search_key]
            return True

        except ValueError:
            return False

    def remove_all_objects(self, str class_name) -> int:
        """
        Remove all objects of a certain class from IDF

        Returns:
            int: Number of objects removed. 0 if class was not found.
        """
        cdef str py_search_key = class_name.upper()

        cdef list removed = self.objects.pop(py_search_key, None)

        if removed is None:
            return 0  # None were found

        return len(removed)

    # ——— Export ——————

    cdef void write_to_buffer(
        self,
        string& out_buffer,
        const FormatConfig* config,
        cbool preserve_order=False,
    ) noexcept:

        cdef list all_objs  # for preserve_order option
        cdef list objs = []
        cdef IDFObject obj

        cdef size_t i
        cdef const ClassDef* cls
        cdef str py_search_key
        cdef string current_group

        # Estimate buffer size
        cdef size_t total_objects = 0
        for objs in self.objects.values():
            total_objects += len(objs)

        cdef size_t size_per_obj = 800
        if config.compact:
            size_per_obj = 160

        cdef size_t estimated_size = out_buffer.size() + (total_objects*size_per_obj) + 4096  # 4KB padding

        if out_buffer.capacity() < estimated_size:
            out_buffer.reserve(estimated_size)

        # Write to buffer
        if preserve_order:
            # Preserve original object order
            all_objs = []
            for objs in self.objects.values():
                all_objs.extend(objs)

            # Sort based on object indices
            all_objs.sort(key=lambda x: x.obj_idx)

            for obj in all_objs:
                out_buffer.push_back(<char>b'\n')
                obj.write_to_buffer(out_buffer, config)

        else:
            # Group by class
            for i in range(self.idd.c_idd.ordered_classes.size()):
                cls = &self.idd.c_idd.ordered_classes[i]
                py_search_key = to_upper(cls.name).decode("utf-8")

                if py_search_key not in self.objects:
                    continue

                # Add group separator if changed
                if not config.compact and current_group != cls.group:
                    current_group = cls.group
                    if not current_group.empty():
                        out_buffer.append(<const char*>b"\n! ***")
                        out_buffer.append(to_upper(current_group))
                        out_buffer.append(<const char*>b"***\n")

                # Write objects
                for obj in self.objects[py_search_key]:
                    # Add newline
                    out_buffer.push_back(<char>b'\n')
                    # Write IDFObject
                    obj.write_to_buffer(out_buffer, config)

                # If compact mode, add linebreak between classes
                if config.compact:
                    out_buffer.push_back(<char>b'\n')

    def __repr__(self):
        cdef string out_buffer
        self.write_to_buffer(out_buffer, &DEFAULT_FORMAT_CONFIG)
        return out_buffer.decode("utf-8")

    def format(
        self,
        int  class_indent_size = 0,
        int  field_indent_size = 4,
        int  field_size        = 24,
        *,
        bint compact           = False,
        bint preserve_order    = False,
    ) -> str:
        """
        Convert IDF to str with format config

        Args:
            class_indent_size (int): Indent for class names
            field_indent_size (int): Indent for fields
            field_size (int): Minimum size for field values
            compact (bint, optional): Whether to enable compact output. Overrides other style settings
            preserve_order (bint, optional): Whether to preserve object order

        Returns:
            str: IDF str
        """
        cdef const FormatConfig* config
        cdef FormatConfig temp_config

        if compact:
            config = &MINIMAL_FORMAT_CONFIG
        else:
            temp_config = generate_format_config(
                class_indent_size,
                field_indent_size,
                field_size,
            )
            config = &temp_config

        cdef string out_buffer
        self.write_to_buffer(out_buffer, config, preserve_order)
        return trim_string(out_buffer).decode("utf-8")

    def save(
        self,
        object output_path,
        int    class_indent_size = 0,
        int    field_indent_size = 4,
        int    field_size        = 24,
        *,
        bint   compact           = False,
        bint   preserve_order    = False,
        bint   include_timestamp = True,
    ):
        """
        Convert IDF to str with format config

        Args:
            class_indent_size (int): Indent for class names
            field_indent_size (int): Indent for fields
            field_size (int): Minimum size for field values
            compact (bint, optional): Whether to enable compact output. Overrides other style settings
            preserve_order (bint, optional): Whether to preserve object order

        Returns:
            str: IDF str
        """
        cdef const FormatConfig* config
        cdef FormatConfig temp_config

        if compact:
            config = &MINIMAL_FORMAT_CONFIG
        else:
            temp_config = generate_format_config(
                class_indent_size,
                field_indent_size,
                field_size,
            )
            config = &temp_config

        cdef string out_buffer

        # Add header
        out_buffer.append(<const char*>b"! Generated using EPEdit.py\n")
        if include_timestamp:
            out_buffer.append(<const char*>b"! Saved at: ")
            out_buffer.append(get_current_time())
            out_buffer.push_back(<char>b'\n')

        # Write IDF to buffer
        self.write_to_buffer(out_buffer, config, preserve_order)

        # Write string buffer to file
        with open(output_path, 'wb') as f:
            f.write(out_buffer)
