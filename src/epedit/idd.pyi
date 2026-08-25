from os import PathLike

class IDD:
    """
    IDD data structure.
    """

    # ——— Properties ——————

    @property
    def version(self) -> str:
        """IDD version"""
        ...

    @property
    def num_classes(self) -> int:
        """Total number of parsed classes"""
        ...

    # ——— Initializations ——————

    def __init__(self):
        """IDD cannot be instantiated directly. Use IDD.from_file()."""
        ...

    @classmethod
    def from_file(cls, filepath: str|PathLike, encoding: str|None = None) -> IDD:
        """
        Parse IDD file

        Args:
            filepath (str | PathLike): IDD file path
            encoding (str, optional): IDD file encoding

        Returns:
            IDD: parsed IDD data structure
        """
        ...

    @classmethod
    def from_string(cls, content: str) -> IDD:
        """
        Parse IDD file

        Args:
            content (str): IDF string

        Returns:
            IDD: parsed IDD data structure
        """
        ...

    # ——— Helper functions ——————

    def get_class_name(self, index: int) -> str:
        """
        Get class name from index

        Args:
            index (int): class index

        Returns:
            str: class name
        """
        ...
