# -*- coding: utf-8 -*-
from dataclasses import dataclass
from typing import Union, List, Tuple, Literal, Optional
from types import SimpleNamespace

import re

@dataclass
class FieldProps:
    """"""
    name: str
    type: Literal['string', 'int', 'float']
    units: Union[str, None]
    default: Optional[Union[str, int, float]] # default value

@dataclass
class ExtensibleProps:
    start_idx: int  # start index of the extensible fields
    size: int  # size of the extensible fields
    key_re_str: List[str]  # RegExp pattern for extensible field search
    fieldnames: List[Tuple[str, str]] # prefix, suffix -> (prefix)(n)(suffix)

@dataclass
class ClassProps:
    """A predefined, immutable data structure using NamedTuple."""
    classname: str
    fields: SimpleNamespace  # fieldKey: fieldProps (excluding extensibles)
    last_default_field_idx: int = -1  # index of the last default field
    extensible: Optional[ExtensibleProps] = None

def parse_IDDClass_string(class_str: str, verbose: bool = False) -> ClassProps:

    #? get top-level class info
    class_info_string_match = re.search(r'[^\s,]+,(?:\r\n|\r|\n)(?: *\\.*(?:\r\n|\r|\n))+', class_str)  # Version, \~~, \~~
    if class_info_string_match:
        class_info_string = class_info_string_match.group()
    else:
        raise ValueError('No class info found!')
    
    classname_match = re.search(r'([^\s,]+),', class_info_string)
    if classname_match:
        classname = classname_match.group(1)
    else:
        raise ValueError

    #? create classProps instance for this class
    classprops = ClassProps(
        classname = classname,
        fields=SimpleNamespace()
    )

    return classprops
