# distutils: language = c++
# distutils: extra_compile_args = ["-std=c++11", "-O3"]

import json
import os
from libc.stdio cimport printf
from libcpp.string cimport string, npos
from libcpp.vector cimport vector
from libcpp cimport bool

# Import the optimized parser from the previous module
from idd_parser import parseIDDClassString

cdef extern from "<cctype>" namespace "std":
    int isspace(int)

# ———————————————————————————————————————————————————————————————————————————
# Pure C++ String Parsing Functions
# ———————————————————————————————————————————————————————————————————————————

cdef string cpp_strip_comments(string input_str):
    """
    Strips inline comments starting with '!' up to the newline.
    Replaces: iddString.replace(/!.+(?:\r\n|\r|\n)/g, '');
    """
    cdef string result
    result.reserve(input_str.length())
    cdef size_t cursor = 0
    cdef size_t length = input_str.length()
    cdef bool in_comment = False
    cdef char c

    while cursor < length:
        c = input_str[cursor]
        if in_comment:
            # Wait for the end of the line to exit comment mode
            if c == b'\n' or c == b'\r':
                in_comment = False
                result.push_back(c) # Preserve the newline structure
        else:
            if c == b'!':
                in_comment = True
            else:
                result.push_back(c)
        cursor += 1

    return result

cdef vector[string] cpp_extract_class_blocks(string idd_string):
    """
    Extracts individual class blocks from the IDD file.
    A class block starts with a Name and ends with the first ';'
    (including any trailing '\\' comment lines immediately following the ';').
    """
    cdef vector[string] blocks
    cdef size_t cursor = 0
    cdef size_t length = idd_string.length()
    cdef size_t start_pos = 0
    cdef size_t temp_cursor = 0
    cdef bool in_class = False
    cdef bool found_semi = False

    while cursor < length:
        if not in_class:
            # -- State 0: Searching for the start of a new class --

            # 1. Skip whitespace
            while cursor < length and isspace(idd_string[cursor]):
                cursor += 1
            if cursor >= length:
                break

            # 2. Skip standalone metadata lines (e.g., \group)
            if idd_string[cursor] == b'\\':
                cursor = idd_string.find(b'\n', cursor)
                if cursor == npos:
                    break
                cursor += 1
                continue

            # 3. Found a valid alphanumeric start to a class
            start_pos = cursor
            in_class = True
            found_semi = False

        else:
            # -- State 1 & 2: Inside a class --

            if not found_semi:
                # State 1: Scan forward until we hit the terminating semicolon ';'
                while cursor < length and idd_string[cursor] != b';':
                    cursor += 1
                if cursor < length:
                    found_semi = True
                    cursor += 1 # Step past the semicolon
            else:
                # State 2: Semicolon found. Capture any trailing '\' metadata lines.
                temp_cursor = cursor

                # Skip spaces/newlines to see what comes next
                while temp_cursor < length and isspace(idd_string[temp_cursor]):
                    temp_cursor += 1

                if temp_cursor >= length:
                    # Reached EOF, save the final block
                    blocks.push_back(idd_string.substr(start_pos))
                    break

                if idd_string[temp_cursor] == b'\\':
                    # It's a metadata comment for the last field (e.g., \default). Consume it.
                    temp_cursor = idd_string.find(b'\n', temp_cursor)
                    if temp_cursor == npos:
                        cursor = length # Force EOF next loop
                    else:
                        cursor = temp_cursor + 1
                else:
                    # Found a non-comment character! This means the NEXT class is starting.
                    # Slice the block from start_pos to temp_cursor (includes trailing spaces)
                    blocks.push_back(idd_string.substr(start_pos, temp_cursor - start_pos))

                    # Reset states for the next class
                    cursor = temp_cursor
                    in_class = False

    return blocks

# ———————————————————————————————————————————————————————————————————————————
# Helper Functions
# ———————————————————————————————————————————————————————————————————————————

def export_idd_to_ts_js(str version_code, dict idd, str file_path, bint mini=False):
    """
    Exports the processed IDD dictionary to a JS/TS file.
    """
    try:
        if mini:
            json_string = json.dumps(idd, separators=(',', ':'))
        else:
            json_string = json.dumps(idd, indent=2)

        output_string = f"export const iddVersion = '{version_code}';\n"
        output_string += f"export const iddString = String.raw`{json_string}`"

        directory = os.path.dirname(file_path)
        if directory and not os.path.exists(directory):
            os.makedirs(directory)

        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(output_string)

        print(f"Successfully exported data to {file_path}")

    except Exception as e:
        print(f"Error writing file: {e}")

# ———————————————————————————————————————————————————————————————————————————
# Core Logic
# ———————————————————————————————————————————————————————————————————————————

def preprocess_idd(str version_code, bint test=False):
    """
    Reads .idd file, removes comments, parses classes, and exports result.
    """
    cdef str file_path = f"./src/idds-preprocess/idds/V{version_code}-0-Energy+.idd"
    cdef str raw_idd = ""

    try:
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            raw_idd = f.read()
    except IOError:
        raise RuntimeError(f"Error reading the file '{file_path}'")

    # Convert to C++ String for fast memory access
    cdef string cpp_raw_idd = raw_idd.encode('utf-8')

    # 1. Strip Comments (Pure String parsing)
    cdef string no_comments_idd = cpp_strip_comments(cpp_raw_idd)

    # 2. Extract Class Blocks (Pure String parsing)
    cdef vector[string] class_blocks = cpp_extract_class_blocks(no_comments_idd)

    # 3. Parse Classes
    cdef dict idd = {}
    cdef dict class_prop
    cdef str class_key
    cdef size_t num_blocks = class_blocks.size()
    cdef size_t i

    for i in range(num_blocks):
        # Decode back to Python str since your parseIDDClassString expects `str`
        class_prop = parseIDDClassString(class_blocks[i].decode('utf-8'), True)
        class_key = class_prop['className'].lower()
        idd[class_key] = class_prop

    # 4. Export
    if not test:
        out_path = f"./idds/v{version_code}-idd.js"
        export_idd_to_ts_js(version_code, idd, out_path, True)
    else:
        out_path = f"./src/idds-preprocess/test-v{version_code}-idd.ts"
        export_idd_to_ts_js(version_code, idd, out_path, False)

# ———————————————————————————————————————————————————————————————————————————
# Batch Runner
# ———————————————————————————————————————————————————————————————————————————

def run_preprocess():
    cdef list version_list = [
        '8-9', '9-0', '9-1', '9-2', '9-3', '9-4', '9-5', '9-6',
        '22-1', '22-2', '23-1', '23-2', '24-1', '24-2', '25-1'
    ]

    for version_code in version_list:
        print(f"—— {version_code} ——————")
        preprocess_idd(version_code)
        print()

if __name__ == "__main__":
    run_preprocess()