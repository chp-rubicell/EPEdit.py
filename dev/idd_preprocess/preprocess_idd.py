import sys
sys.path.append('../../src')

from epedit.idd import parse_IDDClass_str

import re
from types import SimpleNamespace

def export_IDD_to_JSON(
    version_code: str,
    idd: SimpleNamespace,
    file_path: str,
    mini: bool = False
) -> None:
    pass

def preprocess_IDD(
    version_code: str,
    test: bool = False
) -> None:
    
    filepath = f'./idds/V{version_code}-0-Energy+.idd'

    with open(filepath, 'r', encoding='utf-8') as file:
        idd_str = file.read()

    idd_str = idd_str[:30000]

    idd_str = re.sub(r'!.+(?:\r\n|\r|\n)', '', idd_str)

    idd = SimpleNamespace()

    class_matches = re.findall(r'[^\s,]+,(?:\r\n|\r|\n)(?: *\\.*(?:\r\n|\r|\n))+(?: *[^\s,]+ *[,;](?: *\\.*(?:\r\n|\r|\n))+)+', idd_str)

    for class_match in class_matches:
        class_str = str(class_match)

        parse_IDDClass_str(class_str)

preprocess_IDD('23-2')