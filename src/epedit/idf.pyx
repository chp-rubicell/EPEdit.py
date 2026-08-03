# distutils: language = c++

from cython.operator cimport dereference as deref
# from libc.stdlib cimport atof, atoi  # replaced with stof, stoi
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
    find_field_index, resolve_key_to_field_index, get_field_name,
)
from .utils cimport to_lower, to_upper, equal_fold, any_to_string

cdef extern from "<string>" namespace "std" nogil:
    double stod(const string& str) except +
    int stoi(const string& str) except +


# * C-level IDFObject definition

# C level temporary object for fast processing
cdef struct c_IDFObject:
    string class_name
    vector[string] values


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

            last_text.clear()

    return 0


# * Python-level IDFObject definition

cdef class IDFObject:
    cdef IDD idd
    cdef size_t class_idx
    cdef vector[string] values
    cdef readonly size_t obj_idx  # for preserve_order option (readonly for Python sort() function)

    # Inline function for getting ClassDef pointer
    cdef inline ClassDef* get_class_def(self) noexcept nogil:
        return &self.idd.c_idd.ordered_classes[self.class_idx]

    # ——— Properties ——————

    @property
    def class_name(self) -> str:
        return self.get_class_def().name.decode("utf-8")

    # ——— Initializations ——————

    # C-level initialization
    cdef void c_init(self, IDD idd, size_t class_idx, vector[string]& values) noexcept:
        self.idd = idd
        self.class_idx = class_idx
        self.values = move(values)

    def __init__(self, IDD idd, str class_name):
        """Python-level initialization"""
        cdef string search_key = to_upper(class_name.encode("utf-8"))
        cdef c_IDD* c_idd_ptr = &idd.c_idd

        if c_idd_ptr.class_map.find(search_key) == c_idd_ptr.class_map.end():
            raise ValueError(f"Unknown class: {class_name}")

        cdef size_t class_idx = c_idd_ptr.class_map[search_key]
        cdef ClassDef* class_def = &c_idd_ptr.ordered_classes[class_idx]

        cdef vector[string] empty_values
        if class_def.min_fields > 0:
            empty_values.resize(class_def.min_fields, <const char*>b"")

        self.c_init(idd, class_idx, empty_values)

    # ——— Retrieve or update field values ——————

    def __getitem__(self, key):
        """
        Get item from key

        Args:
            key (int | str): field index or field name.

        Returns:
            str | int | float: field value based on field_type.
        """
        cdef const ClassDef* cls = self.get_class_def()
        cdef int idx = resolve_key_to_field_index(cls, key)

        cdef int base_idx = idx
        cdef const ExtensibleDef* ext = &cls.extensible
        if (
            ext.is_extensible
            and ext.begin_index >= 0
            and ext.size > 0
            and idx > ext.begin_index + ext.size
        ):
            base_idx = ext.begin_index + (idx - ext.begin_index) % ext.size

        cdef const FieldDef* field = &cls.fields[base_idx]

        cdef const string* val_ptr = NULL
        if idx < <int>self.values.size():
            val_ptr = &self.values[idx]

        # If field has not been entered or is an empty value ""
        if val_ptr == NULL or val_ptr.empty():
            # If int or float type return None
            if field.field_type == FIELDTYPE_INTEGER or field.field_type == FIELDTYPE_REAL:
                return None
            return ""

        if field.autosizable and equal_fold(deref(val_ptr), <const char*>b"autosize"):
            return "Autosize"
        elif field.autocalculatable and equal_fold(deref(val_ptr), <const char*>b"autocalculate"):
            return "Autocalculate"
        elif field.field_type == FIELDTYPE_INTEGER:
            return stoi(deref(val_ptr))
        elif field.field_type == FIELDTYPE_REAL:
            return stod(deref(val_ptr))

        return deref(val_ptr).decode("utf-8")

    # Set value of field using field index
    cdef int set_by_index(self, int field_idx, object value) except -1:
        # If value is None or empty string, don't resize self.values
        if value is None or value == "":
            # adding empty value
            if field_idx >= <int>self.values.size():
                return 0
            elif field_idx == <int>self.values.size() - 1:
                self.values.pop_back()
                # TODO: consider shrinking self.values array size
                # while not self.values.empty() and self.values.back().empty():
                #     self.values.pop_back()
            else:
                self.values[field_idx] = <const char*>b""
            return 0

        # Resize self.values
        if field_idx >= <int>self.values.size():
            self.values.resize(field_idx+1, <const char*>b"")

        self.values[field_idx] = any_to_string(value)
        return 0

    def __setitem__(self, key, value):
        cdef const ClassDef* cls = self.get_class_def()
        cdef int idx = resolve_key_to_field_index(cls, key)

        self.set_by_index(idx, value)

    def update(self, values):
        """
        Update multiple field values

        Args:
            values (None | list | dict): [value] or {field_idx: value} or {field_name: value}
        """
        if values is None:
            return

        cdef const ClassDef* cls = self.get_class_def()
        cdef int idx
        cdef int max_idx = -1
        cdef list pending_updates = []  # precompute field_idx and validity check

        if isinstance(values, list):
            for i, value in enumerate(values):
                pending_updates.append((i, value))
            max_idx = len(values)
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

    # ——— File write ——————
    # TODO


# * Python-level IDF definition

cdef class IDF:
    cdef IDD idd
    cdef public dict objects  # {CLASSNAME: [IDFObject,...],...}
    cdef size_t next_obj_idx

    # ——— Initializations ——————

    def __init__(self, IDD idd, bytes idf_content):
        self.idd = idd
        self.objects = {}

        # Initialize lexer
        cdef Lexer lexer = Lexer(idf_content, True)

        cdef vector[c_IDFObject] c_objects

        # Parse IDF
        with nogil:
            parse_idf(lexer, c_objects)

        # Build Python-level objects
        self.build_objects(c_objects)

    @classmethod
    def from_file(cls, IDD idd, str filepath) -> IDF:
        """Parse IDF file"""
        cdef bytes raw_bytes

        with open(filepath, "rb") as file:
            raw_bytes = file.read()

        return cls(idd, raw_bytes)

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
                raise ValueError(f"IDF parsing error: Unknown class: {c_object.class_name.decode('utf-8')}")

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

    # ——— File write ——————
    # TODO

    # ——— IDF manipulation API (Create, Update, Delete) ——————

    def get_objects(self, str class_name) -> list:
        """Get object by class name"""
        return self.objects.get(class_name.upper(), [])

    def get_object_by_name(self, str class_name, str obj_name) -> IDFObject|None:
        """Get object by first field (likely name)"""
        cdef string c_obj_name = obj_name.encode("utf-8")
        cdef list candidates = self.get_objects(class_name)
        cdef IDFObject obj
        cdef size_t i
        for i in range(<size_t>len(candidates)):
            obj = candidates[i]
            if equal_fold(obj.values[0], c_obj_name):
                return obj
        return None

    def add_object(self, str class_name, dict initial_values=None, bint default_values=True) -> IDFObject:
        """
        Add object to IDF

        Returns:
            IDFObject: Generated IDFObject.
        """
        cdef IDFObject new_obj = IDFObject(self.idd, class_name)

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
        Remove all objects of a certain class from ID

        Returns:
            int: Number of objects removed. 0 if class was not found.
        """
        cdef str py_search_key = class_name.upper()

        cdef list removed = self.objects.pop(py_search_key, None)

        if removed is None:
            return 0  # None were found

        return len(removed)
