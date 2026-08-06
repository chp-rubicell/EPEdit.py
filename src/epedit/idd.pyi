class IDD:
    """
    IDD data structure.
    """

    # ——— Properties ——————

    @property
    def num_classes(self) -> int:
        """Returns the total number of classes parsed."""
        return self.c_idd.ordered_classes.size()

    # ——— Initializations ——————

    @classmethod
    def from_file(cls, filepath: str, encoding: str|None = None) -> IDD:
        """
        Parse IDD file

        Args:
            filepath (str): IDD file path
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
