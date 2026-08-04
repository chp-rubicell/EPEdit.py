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

    def __init__(self, idd_content: bytes):
        """
        Initialize IDD from bytes
        """
        ...

    @classmethod
    def from_file(cls, filepath: str) -> IDD:
        """
        Parse IDD file

        Args:
            filepath (str): IDD file path

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
