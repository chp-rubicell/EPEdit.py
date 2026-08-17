from .idd import IDD
from os import PathLike

class IDFObject:

    class_name: str

    # ——— Initializations ——————

    def __init__(self, idd: IDD, class_name: str):
        """Python-level initialization"""
        ...

    # ——— Retrieve or update field values ——————

    def __getitem__(self, key: int|str):
        """
        Get field value by key

        Args:
            key (int | str): field index or field name (case-insensitive)

        Returns:
            str | int | float | None: field value based on field_type
        """
        ...

    def get_values(self) -> list[str|int|float|None]:
        """
        Get all field values as list

        Returns:
            list[str | int | float | None]: list of field values based on field_types
        """
        ...

    def __setitem__(self, key: int|str, value: bool|int|float|str|None):
        """
        Set field value by key

        Args:
            key (int | str): field index or field name (case-insensitive)
            value (bool | int | float | str | None)
        """
        ...

    def update(self, values: None|list|dict, trim_empty_trails: bool = True):
        """
        Update multiple field values

        Args:
            values (None | list | dict): [value] or {field_idx: value} or {field_name: value}
            trim_empty_trails (bool, optional): Whether to trim trailing empty fields
        """
        ...

    # ——— Get references ——————

    def get_referenced_objects(self, key=None) -> IDFObjectTuple:
        """
        Return objects referenced by this object.
        If key is None, search for all fields.

        Args:
            key (int | str): field index or field name (case-insensitive)

        Returns:
            IDFObjectTuple[IDFObject, ...]: tuple of IDFObjects (references)
        """
        ...

    def get_referencing_objects(self, key=None) -> IDFObjectTuple:
        """
        Return objects that are referencing this object.
        If key is None, search for all fields.

        Args:
            key (int | str): field index or field name (case-insensitive)

        Returns:
            IDFObjectTuple[IDFObject, ...]: tuple of IDFObjects (references)
        """
        ...

    # ——— Export ——————

    def __repr__(self):
        ...


# * Tuple of IDFObjects for usability (error handling)

class IDFObjectTuple(tuple[IDFObject, ...]):
    """tuple of IDFObjects with custom error messages"""
    ...


# * Python-level IDF definition

class IDF:

    # ——— Initializations ——————

    def __init__(self):
        """IDF cannot be instantiated directly. Use IDF.from_file() or IDF.from_string()."""
        ...

    @classmethod
    def from_file(cls, idd: IDD, filepath: str|PathLike, encoding: str|None = None) -> IDF:
        """
        Parse IDF file

        Args:
            idd (IDD): IDD data structure
            filepath (str | PathLike): IDF file path
            encoding (str, optional): IDF file encoding

        Returns:
            IDF: parsed IDF data
        """
        ...

    @classmethod
    def from_string(cls, idd: IDD, content: str) -> IDF:
        """
        Parse IDF from string

        Args:
            idd (IDD): IDD data structure
            content (str): IDF string

        Returns:
            IDF: parsed IDF data
        """
        ...

    # ——— IDF information ——————

    def get_class_names(self) -> list[str]:
        """
        Get list of class names

        Returns:
            list[str]: class names
        """
        ...

    # ——— IDF manipulation API (Create, Update, Delete) ——————

    def __getitem__(self, class_name: str) -> IDFObjectTuple:
        """
        Get tuple of IDFObjects from class name

        Args:
            class_name (str): class name (case-insensitive)

        Returns:
            IDFObjectTuple[IDFObject, ...]: tuple of IDFObjects (references)
        """
        ...

    def get_objects(self, class_name: str) -> IDFObjectTuple:
        """
        Get tuple of IDFObjects from class name

        Args:
            class_name (str): class name (case-insensitive)

        Returns:
            IDFObjectTuple[IDFObject, ...]: tuple of IDFObjects (references)
        """
        ...

    def get_object_by_name(self, class_name: str, obj_name:str) -> IDFObject|None:
        """Get object by first field (likely name)"""
        ...

    def add_object(self, class_name: str, initial_values: None|list|dict = None, default_values: bool = True) -> IDFObject:
        """
        Add object to IDF

        Args:
            class_name (str): class name (case-insensitive)
            initial_values (None | list | dict): [value] or {field_idx: value} or {field_name: value}
            default_values (bool): Whether to include default values

        Returns:
            IDFObject: Generated IDFObject
        """
        ...

    def remove_object(self, obj: IDFObject):
        """
        Remove object from IDF

        Returns:
            bool: True if successfully removed, False if object was not found.
        """
        ...

    def remove_all_objects(self, class_name: str) -> int:
        """
        Remove all objects of a certain class from IDF

        Returns:
            int: Number of objects removed. 0 if class was not found.
        """
        ...

    # ——— Export ——————

    def __repr__(self):
        ...

    def format(
        self,
        class_indent_size: int = 0,
        field_indent_size: int = 4,
        field_size       : int = 24,
        *,
        compact          : bool = False,
        preserve_order   : bool = False,
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
        ...

    def save(
        self,
        output_path      : str|PathLike,
        class_indent_size: int = 0,
        field_indent_size: int = 4,
        field_size       : int = 24,
        *,
        compact          : bool = False,
        preserve_order   : bool = False,
    ):
        """
        Convert IDF to str with format config

        Args:
            output_path (str | PathLike): Target IDF file path
            class_indent_size (int): Indent for class names
            field_indent_size (int): Indent for fields
            field_size (int): Minimum size for field values
            compact (bint, optional): Whether to enable compact output. Overrides other style settings
            preserve_order (bint, optional): Whether to preserve object order

        Returns:
            str: IDF str
        """
        ...
