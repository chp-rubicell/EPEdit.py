# -*- coding: utf-8 -*-

import re
from typing import Union
from types import SimpleNamespace

#? —— Field Key and Name Related ——————

def fieldname_to_key(fieldname: str) -> str:
    fieldkey = fieldname
    fieldkey = re.sub(r'[-/*()]', '', fieldkey)  # remove illegal characters
    fieldkey = fieldkey.replace(' ', '_')
    return fieldkey

def rename_fieldnames_to_keys(obj: SimpleNamespace) -> SimpleNamespace:
    """Creates a new record with all keys converted to lowercase.

    Parameters
    ----------
    - obj : The input record.

    Returns
    -------
    A new SimpleNamespace with lowercase 
    """
    return SimpleNamespace(
        **{
            fieldname_to_key(key): value
            for key, value in vars(obj).items()
        }
    )

#? —— Field Value Type ——————
def parse_fieldvalue_str(value_str: str) -> Union[int, float, str]:
    """
    Casts a string to an int, then float, falling back to the original string.
    """
    #? try int
    try:
        return int(value_str)
    except ValueError:
        #? try float
        try:
            return float(value_str)
        except ValueError:
            #? return as str
            return value_str
