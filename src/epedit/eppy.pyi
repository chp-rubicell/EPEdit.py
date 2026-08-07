# from .idd cimport (
#     FieldDef, ClassDef,
#     IDD as CoreIDD,
# )
# from .idf cimport (
#     IDFObject as CoreIDFObject,
#     IDF as CoreIDF,
# )

class IDFObject:

    def __getattr__(self, name: str):
        ...

    def __setattr__(self, name: str, value):
        ...

    def __repr__(self):
        ...


class IDFObjectsProxy:

    def __getitem__(self, class_name: str):
        ...


class IDF:

    @classmethod
    def setiddname(cls, iddname, *args, **kwargs):
        ...

    @classmethod
    def getiddname(cls) -> str:
        ...

    def __init__(self, idfname, *args, **kwargs):
        ...

    # ——— IDF manipulation API (Create, Update, Delete) ——————

    @property
    def idfobjects(self):
        ...

    def newidfobject(self, class_name: str, defaultvalues: bool = True, **kwargs) -> IDFObject:
        """Add a new idfobject to the model."""
        ...

    def removeidfobject(self, idfobject: IDFObject):
        """Remove an IDF object from the IDF."""
        ...

    def removeallidfobjects(self, class_name: str):
        """Remove all IDF object of a certain type from the IDF."""
        ...

    def getobject(self, key: str, name: str) -> IDFObject|None:
        """Fetch an IDF object given key and name."""
        ...

    # ——— Export ——————

    def __repr__(self):
        return repr(self.core_idf)

    def printidf(self):
        """Print the IDF."""
        ...

    def idfstr(self) -> str:
        """String representation of the IDF."""
        ...

    def save(self, idfname, *args, **kwargs):
        """Save the IDF as a text file with the filename passed."""
        ...

    def saveas(self, idfname, *args, **kwargs):
        """Save the IDF as a text file with the filename passed."""
        ...
