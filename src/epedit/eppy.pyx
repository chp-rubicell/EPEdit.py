from .idd cimport (
    FieldDef, ClassDef,
    IDD as CoreIDD,
)
from .idf cimport (
    IDFObject as CoreIDFObject,
    IDF as CoreIDF,
)
from .utils cimport get_continuous_digits_indices

cdef str shared_iddname = ""
cdef CoreIDD shared_idd

cdef dict field_key_to_name = {}  # {CLASSNAME: {field_key(lowercase): field_name}}

cdef void build_field_key_to_name_dict():
    if len(field_key_to_name) > 0:
        return

    cdef int i, j
    cdef str class_search_key, field_name
    cdef ClassDef* cls
    cdef FieldDef* field

    for i in range(shared_idd.c_idd.ordered_classes.size()):
        cls = &shared_idd.c_idd.ordered_classes.at(i)
        class_search_key = cls.name.decode("utf-8").upper()
        if class_search_key not in field_key_to_name:
            field_key_to_name[class_search_key] = {}
        for j in range(cls.fields.size()):
            field = &cls.fields.at(j)
            field_name = field.name.decode("utf-8")
            if "-" in field_name or "/" in field_name or "*" in field_name:
                # only add when field_name has illegal characters
                field_key_to_name[class_search_key][
                    field_name.lower().replace(" ","_").replace("-","").replace("/","").replace("*","")
                ] = field_name


cdef str resolve_field_key_to_field_name(str class_name, str field_key):
    cdef str base_field_key
    cdef int start_idx, end_idx
    class_name = class_name.upper()
    field_key = field_key.lower()
    if field_key in field_key_to_name[class_name]:
        return field_key_to_name[class_name][field_key]
    else:
        start_idx, end_idx = get_continuous_digits_indices(field_key.encode("utf-8"))
        if start_idx > -1:
            base_field_key = field_key[:start_idx] + "1" + field_key[end_idx:]
            if base_field_key in field_key_to_name[class_name]:
                return field_key_to_name[class_name][base_field_key].replace("1", field_key[start_idx: end_idx])
        return field_key.replace("_", " ")


cdef class IDFObject:
    cdef CoreIDFObject core_obj

    def __init__(self, CoreIDFObject core_obj):
        self.core_obj = core_obj

    def __getattr__(self, str name):
        cdef str field_name = resolve_field_key_to_field_name(self.core_obj.class_name, name)
        return self.core_obj[field_name]

    def __setattr__(self, str name, object value):
        cdef str field_name = resolve_field_key_to_field_name(self.core_obj.class_name, name)
        self.core_obj[field_name] = value

    def __repr__(self):
        return repr(self.core_obj)


cdef class IDFObjectsProxy:
    cdef IDF parent
    def __init__(self, IDF parent):
        self.parent = parent
    def __getitem__(self, str class_name):
        return [
            IDFObject(core_obj)
            for core_obj in self.parent.core_idf.get_objects(class_name)
        ]


cdef class IDF:
    cdef CoreIDF core_idf
    cdef IDFObjectsProxy idfobjsproxy

    @classmethod
    def setiddname(cls, object iddname, *args, **kwargs):
        global shared_iddname, shared_idd

        shared_iddname = str(iddname)
        shared_idd = CoreIDD.from_file(iddname)
        build_field_key_to_name_dict()

    @classmethod
    def getiddname(cls) -> str:
        return cls.iddname

    def __init__(self, object idfname, *args, **kwargs):
        self.core_idf = CoreIDF.from_file(shared_idd, idfname)
        self.idfobjsproxy = IDFObjectsProxy(self)

    # ——— IDF manipulation API (Create, Update, Delete) ——————

    @property
    def idfobjects(self):
        return self.idfobjsproxy

    def newidfobject(self, str class_name, bint defaultvalues=True, **kwargs) -> IDFObject:
        """Add a new idfobject to the model."""
        return IDFObject(self.core_idf.add_object(
            class_name,
            initial_values = kwargs,
            default_values = defaultvalues,
        ))

    def removeidfobject(self, CoreIDFObject idfobject):
        """Remove an IDF object from the IDF."""
        self.core_idf.remove_object(idfobject)

    def removeallidfobjects(self, str class_name):
        """Remove all IDF object of a certain type from the IDF."""
        self.core_idf.remove_all_objects(class_name)

    def getobject(self, str key, str name) -> IDFObject|None:
        """Fetch an IDF object given key and name."""
        cdef object core_obj = self.core_idf.get_object_by_name(key, name)
        if core_obj is None:
            return None
        return IDFObject(core_obj)

    # ——— Export ——————

    def __repr__(self):
        return repr(self.core_idf)

    def printidf(self):
        """Print the IDF."""
        print(self.core_idf)

    def idfstr(self):
        """String representation of the IDF."""
        return str(self.core_idf)

    def save(self, object idfname, *args, **kwargs):
        self.core_idf.save(idfname)

    def save(self, object idfname, *args, **kwargs):
        self.core_idf.save(idfname)
