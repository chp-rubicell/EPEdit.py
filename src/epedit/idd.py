# -*- coding: utf-8 -*-
from .utilities import fieldname_to_key, parse_fieldvalue_str

from dataclasses import dataclass
from typing import Union, List, Tuple, Literal, Optional
from types import SimpleNamespace

import re

@dataclass
class FieldProps:
    """"""
    name: str
    type: Literal['str', 'int', 'float']
    units: Union[str, None]
    default: Optional[Union[str, int, float]] = None # default value

@dataclass
class ExtensibleProps:
    start_idx: int  # start index of the extensible fields
    size: int  # size of the extensible fields
    key_re_strs: List[str]  # RegExp pattern for extensible field search
    fieldnames: List[Tuple[str, str]] # prefix, suffix -> (prefix)(n)(suffix)

@dataclass
class ClassProps:
    """A predefined, immutable data structure using NamedTuple."""
    classname: str
    fields: SimpleNamespace  # fieldKey: fieldProps (excluding extensibles)
    last_default_field_idx: int = -1  # index of the last default field
    extensible: Optional[ExtensibleProps] = None

def parse_IDDClass_str(class_str: str, verbose: bool = False) -> ClassProps:

    #? get top-level class info
    class_info_str_match = re.search(r'[^\s,]+,(?:\r\n|\r|\n)(?: *\\.*(?:\r\n|\r|\n))+', class_str)  # Version, \~~, \~~
    if class_info_str_match:
        class_info_str = str(class_info_str_match.group(0))
    else:
        raise ValueError('No class info found!')
    
    classname_match = re.search(r'([^\s,]+),', class_info_str)
    if classname_match:
        classname = str(classname_match.group(1))
    else:
        raise ValueError

    #? create classProps instance for this class
    classprop = ClassProps(
        classname = classname,
        fields = SimpleNamespace()
    )

    #? check extensible
    extensible_match = re.search(r'\\extensible:(\d+)', class_info_str)
    if extensible_match:
        classprop.extensible = ExtensibleProps(
            start_idx   = -1,  # update during the field parsing
            size        = int(extensible_match.group(1)),
            key_re_strs = [],
            fieldnames  = []
        )

    field_matches = re.findall(r' *[^\s,]+ *[,;](?: *\\.*(?:\r\n|\r|\n))*', class_str[len(class_info_str):])

    print(classname)
    for fieldidx, field_match in enumerate(field_matches):
        if (
            classprop.extensible
            and classprop.extensible.start_idx >= 0
            and fieldidx >= classprop.extensible.start_idx + classprop.extensible.size
        ):
            break
        
        field_str = str(field_match)

        fieldname_match = re.search(r'\\field (.+)(?:\r\n|\r|\n)', field_str)
        if fieldname_match:
            fieldname = str(fieldname_match.group(1))
            fieldkey = fieldname_to_key(fieldname)
        else:
            print(f'> No fieldName match for "{classname}" - {fieldidx}!')
            fieldcode_match = re.search(r' *([^\s,]+) *[,;]', field_str)
            fieldcode = fieldcode_match.group(1) if fieldcode_match else str(fieldidx)
            fieldname = fieldcode
            fieldkey = fieldcode
            print(f'  using "{fieldcode}" instead.')

        #? field type
        fieldtype_match = re.search(r'\\type ([^\s,]+)(?:\r\n|\r|\n)', field_str)
        if fieldtype_match:
            fieldtype_raw = str(fieldtype_match.group(1))
        else:
            fieldtype_raw = ''  # default to str
        #* integer, real, alpha, choice, object-list, external-list, node
        fieldtype = 'int' if fieldtype_raw == 'integer' else 'float' if fieldtype_raw == 'real' else 'str'

        #? field units
        fieldunits_match = re.search(r'\\units (.+)(?:\r\n|\r|\n)', field_str)
        if fieldunits_match:
            fieldunits = str(fieldunits_match.group(1))
        else:
            fieldunits = None
        
        #? default value
        defaultvalue_match = re.search(r'/\\default (.+)(?:\r\n|\r|\n)', field_str)
        if defaultvalue_match:
            classprop.last_default_field_idx = fieldidx
            defaultvalue_str = str(defaultvalue_match.group(1))
            defaultvalue = parse_fieldvalue_str(defaultvalue_str)
            if (
                isinstance(defaultvalue, str)
                and (
                    defaultvalue.lower() == 'autosize'
                    or defaultvalue.lower() == 'autocalculate'
                )
            ):
                defaultvalue = defaultvalue.title()
        else:
            defaultvalue = None
        
        #? create FieldProps object
        fieldprop = FieldProps(
            name    = fieldname,
            type    = fieldtype,
            units   = fieldunits,
            default = defaultvalue
        )
        
        #? extensible
        # start of extensible
        if classprop.extensible and re.search(r'\\begin-extensible', field_str):
            classprop.extensible.start_idx = fieldidx
        # if extensible field
        #TODO

        setattr(classprop, fieldkey, fieldprop)

    return classprop
